import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/cache_providers.dart';
import '../../application/navigation/drawer_navigation_models.dart';
import '../../core/cache/kiki_cache_policies.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../performance/drawer_performance_logger.dart';
import 'category_providers.dart';
import 'content_locale_provider.dart';
import 'navigation_providers.dart';

/// Lifecycle slot for the drawer warm-up. Used both for the overall
/// outcome and for each sub-task (drawer config, drawer categories).
enum DrawerPreloadStatus { notStarted, running, completed, failed }

/// Compound state of the post-first-frame drawer warm-up.
///
/// The preloader covers two sub-tasks:
/// - **drawer config**: the navigation menu structure
///   (`mainDrawerNavigationProvider`, visible variant only).
/// - **drawer categories**: only triggered when the drawer needs the
///   category fallback — i.e. when the config returned a fallback
///   (menu missing / inactive / fetch error / tree invalid) OR when
///   the menu's `liveSource` is [DrawerLiveSource.categories].
///   Otherwise [categoriesStatus] stays [DrawerPreloadStatus.notStarted].
///
/// Overall [status] is [DrawerPreloadStatus.completed] iff the user can
/// open the drawer with no further round-trip:
/// - drawer config completed, categories not needed → completed
/// - drawer config completed, categories completed → completed
/// - drawer config failed (fallback), categories completed → completed
///   (degraded UI but the open is still instant)
/// Otherwise [status] is [DrawerPreloadStatus.failed].
class DrawerPreloadState {
  const DrawerPreloadState._({
    required this.status,
    required this.configStatus,
    required this.categoriesStatus,
    this.startedAt,
    this.completedAt,
    this.error,
  });

  const DrawerPreloadState.notStarted()
    : this._(
        status: DrawerPreloadStatus.notStarted,
        configStatus: DrawerPreloadStatus.notStarted,
        categoriesStatus: DrawerPreloadStatus.notStarted,
      );

  const DrawerPreloadState.running(DateTime startedAt)
    : this._(
        status: DrawerPreloadStatus.running,
        configStatus: DrawerPreloadStatus.running,
        categoriesStatus: DrawerPreloadStatus.notStarted,
        startedAt: startedAt,
      );

  /// Standard "everything went fine" state. Categories sub-status defaults
  /// to [DrawerPreloadStatus.notStarted] (= not needed) when the menu was
  /// usable; pass [categoriesStatus] explicitly when categories were
  /// preloaded.
  const DrawerPreloadState.completed({
    required DateTime startedAt,
    required DateTime completedAt,
    DrawerPreloadStatus configStatus = DrawerPreloadStatus.completed,
    DrawerPreloadStatus categoriesStatus = DrawerPreloadStatus.notStarted,
  }) : this._(
         status: DrawerPreloadStatus.completed,
         configStatus: configStatus,
         categoriesStatus: categoriesStatus,
         startedAt: startedAt,
         completedAt: completedAt,
       );

  const DrawerPreloadState.failed({
    required DateTime startedAt,
    required DateTime completedAt,
    required Object error,
    DrawerPreloadStatus configStatus = DrawerPreloadStatus.failed,
    DrawerPreloadStatus categoriesStatus = DrawerPreloadStatus.notStarted,
  }) : this._(
         status: DrawerPreloadStatus.failed,
         configStatus: configStatus,
         categoriesStatus: categoriesStatus,
         startedAt: startedAt,
         completedAt: completedAt,
         error: error,
       );

  final DrawerPreloadStatus status;
  final DrawerPreloadStatus configStatus;
  final DrawerPreloadStatus categoriesStatus;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final Object? error;

  bool get hasCompletedSuccessfully => status == DrawerPreloadStatus.completed;

  bool get isRunning => status == DrawerPreloadStatus.running;

  /// True when the categories warm-up was triggered (either ran to
  /// completion or failed). False when it was skipped because the drawer
  /// config was usable and not in `liveSource: categories` mode.
  bool get categoriesWereNeeded =>
      categoriesStatus != DrawerPreloadStatus.notStarted;
}

/// One-shot warm-up for the drawer. Lives outside the build pipeline so
/// it can be triggered from `addPostFrameCallback` without risking a
/// build-time read.
///
/// What gets warmed:
/// 1. **Drawer config** (always): the storefront variant of
///    `mainDrawerNavigationProvider` (`includeHidden=false`).
/// 2. **Drawer categories** (conditional): the same cache slot that
///    [drawerCategoriesProvider] uses at open-time, ALSO
///    `includeHidden=false`. Triggered when:
///       - the drawer config returned a fallback (menu missing, inactive,
///         fetch error, tree invalid), so the drawer widget will fall
///         back to the category list;
///       - OR the menu's `liveSource` is [DrawerLiveSource.categories].
///
/// We deliberately bypass `mainDrawerNavigationProvider` and
/// `drawerCategoriesProvider` and call the cache reader directly with the
/// public cache-key helpers (`drawerCacheKey`, `drawerCategoriesCacheKey`).
/// Going through the FutureProviders would respect `editModeProvider`,
/// and we never speculate on the admin variant — it's not worth the
/// round-trip and would populate the wrong cache slot for storefront users.
///
/// Idempotency: [preload] is a no-op after the first call within the
/// lifetime of this notifier (one warm-up per [ProviderContainer]).
/// Multiple calls produce at most one drawer-config fetch and at most one
/// categories fetch.
///
/// Errors and fallback results are recorded in [state] — the preloader
/// never rethrows.
class DrawerNavigationPreloader extends Notifier<DrawerPreloadState> {
  bool _started = false;

  @override
  DrawerPreloadState build() => const DrawerPreloadState.notStarted();

  /// Warms the drawer config and, if needed, the drawer categories cache.
  /// Subsequent calls are no-ops. Never throws.
  Future<void> preload() async {
    if (_started) return;
    _started = true;

    final clock = ref.read(cacheClockProvider);
    final logger = ref.read(drawerPerformanceLoggerProvider);

    final startedAt = clock();
    state = DrawerPreloadState.running(startedAt);

    final config = await _preloadDrawerConfig(clock, logger, startedAt);

    var categories = const _SubOutcome.notStarted();
    if (_needsCategoriesWarmUp(config.result)) {
      categories = await _preloadDrawerCategories(clock, logger);
    }

    final completedAt = clock();
    state = _composeFinalState(
      startedAt: startedAt,
      completedAt: completedAt,
      config: config,
      categories: categories,
    );
  }

  bool _needsCategoriesWarmUp(DrawerNavigationLoadResult? result) {
    // Hard error path: drawer config threw before producing anything →
    // the widget will render its fallback (category list).
    if (result == null) return true;
    // Soft-failure: any fallback reason makes the drawer fall back to
    // the category list (storefront_category_drawer.dart:591).
    if (result.fallbackReason != null) return true;
    // Live-source: the merchant configured the drawer to display
    // categories instead of the managed nav tree.
    if (result.menu?.liveSource == DrawerLiveSource.categories) return true;
    return false;
  }

  Future<_ConfigOutcome> _preloadDrawerConfig(
    DateTime Function() clock,
    DrawerPerformanceLogger logger,
    DateTime startedAt,
  ) async {
    final locale = ref.read(contentLocaleProvider);
    final reader = ref.read(cachedRemoteReaderProvider);
    final cache = ref.read(localReadCacheProvider);
    final repository = ref.read(drawerNavigationRepositoryProvider);
    final cacheKey = drawerCacheKey(locale: locale, includeHidden: false);

    logger.preloadStart(cacheKey);

    final preExisting = await cache.peek<DrawerNavigationLoadResult>(cacheKey);
    final alreadyReady =
        preExisting != null && preExisting.data.fallbackReason == null;

    try {
      final result = await reader.read<DrawerNavigationLoadResult>(
        key: cacheKey,
        resourceType: 'drawer',
        policy: KikiCachePolicies.drawer,
        remoteLoader: () =>
            repository.fetchMainDrawer(locale: locale, includeHidden: false),
        cachePredicate: (r) => r.fallbackReason == null,
        // dedupe:true (default) is intentional. The warm-up runs at
        // first-frame, before any UI reads the drawer provider, so there
        // is no "stale in-flight" risk to avoid. Sharing the in-flight
        // slot means that if the user taps the menu *while the preload is
        // still flying*, their read joins the same request instead of
        // firing a duplicate one. Post-mutation safety is preserved by
        // CatalogInvalidator clearing the dedup slot before forcing a
        // refresh.
      );
      final latency = clock().difference(startedAt);

      if (result.fallbackReason != null) {
        logger.preloadFallback(cacheKey, latency, result.fallbackReason!);
        return _ConfigOutcome.fallback(result.fallbackReason!, result);
      }

      logger.preloadComplete(cacheKey, latency, alreadyReady: alreadyReady);
      return _ConfigOutcome.success(result);
    } catch (error, stackTrace) {
      final latency = clock().difference(startedAt);
      logger.preloadError(cacheKey, latency, error, stackTrace);
      return _ConfigOutcome.error(error);
    }
  }

  Future<_SubOutcome> _preloadDrawerCategories(
    DateTime Function() clock,
    DrawerPerformanceLogger logger,
  ) async {
    final locale = ref.read(contentLocaleProvider);
    final reader = ref.read(cachedRemoteReaderProvider);
    final cache = ref.read(localReadCacheProvider);
    final getActiveCategories = ref.read(getActiveCategoriesProvider);
    final cacheKey = drawerCategoriesCacheKey(
      locale: locale,
      includeHidden: false,
    );

    final startedAt = clock();
    logger.preloadStart(cacheKey);

    final preExisting = await cache.peek<List<CatalogCategory>>(cacheKey);
    final alreadyReady = preExisting != null;

    try {
      await reader.read<List<CatalogCategory>>(
        key: cacheKey,
        resourceType: 'drawerCategories',
        policy: KikiCachePolicies.categories,
        remoteLoader: () =>
            getActiveCategories(includeHidden: false, locale: locale),
        // dedupe:true (default) is critical here. drawerCategoriesProvider
        // also uses dedupe:true. If the user taps the menu while this
        // warm-up is still flying, their read joins the same in-flight
        // loader → ONE network request total. With dedupe:false, the
        // open would start a parallel request and the user would still
        // see the categories fetch land at open-time.
      );
      final latency = clock().difference(startedAt);
      logger.preloadComplete(cacheKey, latency, alreadyReady: alreadyReady);
      return const _SubOutcome.completed();
    } catch (error, stackTrace) {
      final latency = clock().difference(startedAt);
      logger.preloadError(cacheKey, latency, error, stackTrace);
      return _SubOutcome.failed(error);
    }
  }

  DrawerPreloadState _composeFinalState({
    required DateTime startedAt,
    required DateTime completedAt,
    required _ConfigOutcome config,
    required _SubOutcome categories,
  }) {
    // The user can open the drawer with no further round-trip iff:
    //   - config completed (categories may be notStarted=not-needed
    //     or completed because liveSource was categories)
    //   - OR config failed but categories completed (degraded but instant)
    final overallReady =
        (config.status == DrawerPreloadStatus.completed &&
            categories.status != DrawerPreloadStatus.failed) ||
        (config.status == DrawerPreloadStatus.failed &&
            categories.status == DrawerPreloadStatus.completed);

    if (overallReady) {
      return DrawerPreloadState.completed(
        startedAt: startedAt,
        completedAt: completedAt,
        configStatus: config.status,
        categoriesStatus: categories.status,
      );
    }

    final dominantError = config.error ?? categories.error ?? 'unknown';
    return DrawerPreloadState.failed(
      startedAt: startedAt,
      completedAt: completedAt,
      error: dominantError,
      configStatus: config.status,
      categoriesStatus: categories.status,
    );
  }

  /// Test/diagnostic helper: true once [preload] has been called, regardless
  /// of outcome.
  bool get debugStarted => _started;

  /// Record a drawer-open event. Call exactly once per user tap (do NOT call
  /// from `build`). The notifier classifies the current data state, emits a
  /// single `DRAWER_OPEN_READY` event, and — if the data is still loading —
  /// awaits the resolution so the latency reflects actual user wait.
  ///
  /// Errors from the underlying future are swallowed; we only care about
  /// the classification + timing for telemetry. Returns when the event has
  /// been emitted; callers typically `unawaited(...)` it.
  Future<void> recordOpen() async {
    final clock = ref.read(cacheClockProvider);
    final logger = ref.read(drawerPerformanceLoggerProvider);
    final initial = ref.read(mainDrawerNavigationProvider);

    final start = clock();
    logger.openStart();

    if (initial.hasValue || initial.hasError) {
      logger.openReady(
        latency: clock().difference(start),
        state: classifyDrawerOpenState(
          providerState: initial,
          preloadState: state,
        ),
      );
      return;
    }

    try {
      await ref.read(mainDrawerNavigationProvider.future);
    } catch (_) {
      // Errors are exposed to the UI via AsyncValue; here we just want to
      // classify the final state for telemetry.
    }
    logger.openReady(
      latency: clock().difference(start),
      state: classifyDrawerOpenState(
        providerState: ref.read(mainDrawerNavigationProvider),
        preloadState: state,
      ),
    );
  }
}

/// Internal: outcome of the drawer-config sub-task.
class _ConfigOutcome {
  const _ConfigOutcome._({required this.status, this.result, this.error});

  const _ConfigOutcome.success(DrawerNavigationLoadResult value)
    : this._(status: DrawerPreloadStatus.completed, result: value);

  _ConfigOutcome.fallback(Object reason, DrawerNavigationLoadResult value)
    : this._(status: DrawerPreloadStatus.failed, result: value, error: reason);

  _ConfigOutcome.error(Object err)
    : this._(status: DrawerPreloadStatus.failed, error: err);

  final DrawerPreloadStatus status;
  final DrawerNavigationLoadResult? result;
  final Object? error;
}

/// Internal: outcome of a sub-task tracked only by status/error
/// (no value to expose).
class _SubOutcome {
  const _SubOutcome._({required this.status, this.error});

  const _SubOutcome.notStarted()
    : this._(status: DrawerPreloadStatus.notStarted);

  const _SubOutcome.completed() : this._(status: DrawerPreloadStatus.completed);

  _SubOutcome.failed(Object err)
    : this._(status: DrawerPreloadStatus.failed, error: err);

  final DrawerPreloadStatus status;
  final Object? error;
}

final drawerNavigationPreloaderProvider =
    NotifierProvider<DrawerNavigationPreloader, DrawerPreloadState>(
      DrawerNavigationPreloader.new,
    );

/// Convenience extension: classify the drawer's data state at the moment
/// the user opens it. Used by the open-trigger instrumentation to choose
/// the right [DrawerOpenDataState] label.
DrawerOpenDataState classifyDrawerOpenState({
  required AsyncValue<DrawerNavigationLoadResult> providerState,
  required DrawerPreloadState preloadState,
}) {
  if (providerState.hasError) return DrawerOpenDataState.fallbackOrError;

  if (providerState.hasValue && providerState.value!.fallbackReason != null) {
    return DrawerOpenDataState.fallbackOrError;
  }

  if (providerState.hasValue && preloadState.hasCompletedSuccessfully) {
    return DrawerOpenDataState.preloadedReady;
  }
  if (providerState.hasValue) {
    return DrawerOpenDataState.cacheHitReady;
  }
  if (providerState.isLoading && preloadState.isRunning) {
    return DrawerOpenDataState.preloadRunning;
  }
  return DrawerOpenDataState.coldLoading;
}
