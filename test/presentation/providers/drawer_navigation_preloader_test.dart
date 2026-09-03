import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/app/cache_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_invalidations.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/performance/drawer_performance_logger.dart';
import 'package:kiki_commerce/presentation/providers/catalog_invalidator_provider.dart';
import 'package:kiki_commerce/presentation/providers/category_providers.dart';
import 'package:kiki_commerce/presentation/providers/drawer_navigation_preloader.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/providers/navigation_providers.dart';

class _RecordingPerfLogger implements DrawerPerformanceLogger {
  final List<String> preloadStartKeys = [];
  final List<String> preloadCompleteKeys = [];
  final List<String> preloadFallbackKeys = [];
  final List<String> preloadErrorKeys = [];
  int openStartCalls = 0;
  final List<DrawerOpenDataState> openReadyStates = [];
  final List<Duration> openReadyLatencies = [];
  final List<bool> preloadAlreadyReadyFlags = [];
  final List<Duration> preloadCompleteLatencies = [];

  int get preloadStartCalls => preloadStartKeys.length;
  int get preloadCompleteCalls => preloadCompleteKeys.length;
  int get preloadFallbackCalls => preloadFallbackKeys.length;
  int get preloadErrorCalls => preloadErrorKeys.length;

  bool get sawDrawerStart =>
      preloadStartKeys.any((k) => k.startsWith('drawer:'));
  bool get sawCategoriesStart =>
      preloadStartKeys.any((k) => k.startsWith('drawerCategories:'));
  bool get sawCategoriesComplete =>
      preloadCompleteKeys.any((k) => k.startsWith('drawerCategories:'));
  bool get sawCategoriesError =>
      preloadErrorKeys.any((k) => k.startsWith('drawerCategories:'));

  @override
  void preloadStart(String key) => preloadStartKeys.add(key);

  @override
  void preloadComplete(
    String key,
    Duration latency, {
    required bool alreadyReady,
  }) {
    preloadCompleteKeys.add(key);
    preloadAlreadyReadyFlags.add(alreadyReady);
    preloadCompleteLatencies.add(latency);
  }

  @override
  void preloadFallback(String key, Duration latency, Object reason) =>
      preloadFallbackKeys.add(key);

  @override
  void preloadError(
    String key,
    Duration latency,
    Object error,
    StackTrace stackTrace,
  ) => preloadErrorKeys.add(key);

  @override
  void openStart() => openStartCalls++;

  @override
  void openReady({
    required Duration latency,
    required DrawerOpenDataState state,
  }) {
    openReadyStates.add(state);
    openReadyLatencies.add(latency);
  }
}

class _CountingDrawerRepo implements DrawerNavigationRepository {
  _CountingDrawerRepo(this._results);
  final List<Future<DrawerNavigationLoadResult> Function()> _results;
  int callCount = 0;
  final List<bool> includeHiddenCalls = [];

  @override
  Future<DrawerNavigationLoadResult> fetchMainDrawer({
    required String locale,
    bool includeHidden = false,
  }) {
    includeHiddenCalls.add(includeHidden);
    final f = _results[callCount.clamp(0, _results.length - 1)]();
    callCount++;
    return f;
  }
}

/// Categories repo whose `getActiveCategories` doesn't resolve until the
/// caller completes the [_gate] future. Used to simulate a slow network
/// so we can deterministically verify "tap-during-in-flight-preload"
/// behaviour.
class _GatedCategoryRepo implements CategoryCatalogRepository {
  _GatedCategoryRepo(this._gate);
  final Future<List<CatalogCategory>> _gate;
  int activeCalls = 0;

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async {
    activeCalls++;
    return _gate;
  }

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async =>
      null;
  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async => null;
  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async => throw UnimplementedError();
  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String locale,
    required String categorySlug,
    required String productSlug,
  }) async => throw UnimplementedError();
}

class _CountingCategoryRepo implements CategoryCatalogRepository {
  _CountingCategoryRepo({this.shouldThrow = false});
  final bool shouldThrow;
  int activeCalls = 0;
  final List<bool> includeHiddenCalls = [];

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async {
    activeCalls++;
    includeHiddenCalls.add(includeHidden);
    if (shouldThrow) throw StateError('category fetch failed');
    return const [
      CatalogCategory(id: 'cat-1', code: 'c1', name: 'C1', slug: 'c1'),
    ];
  }

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async =>
      null;
  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async => null;
  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async => throw UnimplementedError();
  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String locale,
    required String categorySlug,
    required String productSlug,
  }) async => throw UnimplementedError();
}

DrawerNavigationLoadResult _success({
  String menuId = 'menu-1',
  String displayMode = 'drawer',
}) {
  return DrawerNavigationLoadResult.success(
    menu: DrawerNavigationMenuData(
      id: menuId,
      name: 'Main',
      code: 'main_drawer',
      displayMode: displayMode,
      isActive: true,
    ),
    normalized: const DrawerNavigationNormalizedResult.usable(roots: []),
  );
}

class _MutableClock {
  _MutableClock(this.value);
  DateTime value;
  DateTime call() => value;
}

ProviderContainer _container({
  required DrawerNavigationRepository drawerRepo,
  required _RecordingPerfLogger perfLogger,
  CategoryCatalogRepository? categoryRepo,
  DateTime Function()? clock,
}) {
  final container = ProviderContainer(
    overrides: [
      drawerNavigationRepositoryProvider.overrideWithValue(drawerRepo),
      drawerPerformanceLoggerProvider.overrideWithValue(perfLogger),
      categoryCatalogRepositoryProvider.overrideWithValue(
        categoryRepo ?? _CountingCategoryRepo(),
      ),
      if (clock != null) cacheClockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('DrawerNavigationPreloader - drawer config only path', () {
    test(
      'usable menu with liveSource=navigation does NOT preload categories',
      () async {
        final drawerRepo = _CountingDrawerRepo([
          () async => _success(displayMode: 'drawer'),
        ]);
        final categoryRepo = _CountingCategoryRepo();
        final perf = _RecordingPerfLogger();
        final container = _container(
          drawerRepo: drawerRepo,
          categoryRepo: categoryRepo,
          perfLogger: perf,
        );

        await container
            .read(drawerNavigationPreloaderProvider.notifier)
            .preload();

        expect(drawerRepo.callCount, 1);
        expect(
          categoryRepo.activeCalls,
          0,
          reason: 'usable menu does not need the category fallback',
        );
        final s = container.read(drawerNavigationPreloaderProvider);
        expect(s.status, DrawerPreloadStatus.completed);
        expect(s.configStatus, DrawerPreloadStatus.completed);
        expect(s.categoriesStatus, DrawerPreloadStatus.notStarted);
        expect(s.categoriesWereNeeded, isFalse);
        expect(perf.sawDrawerStart, isTrue);
        expect(perf.sawCategoriesStart, isFalse);
      },
    );

    test(
      'preload is idempotent — repo called once on repeated invocations',
      () async {
        final drawerRepo = _CountingDrawerRepo([
          () async => _success(),
          () async => _success(),
        ]);
        final perf = _RecordingPerfLogger();
        final container = _container(drawerRepo: drawerRepo, perfLogger: perf);

        final notifier = container.read(
          drawerNavigationPreloaderProvider.notifier,
        );

        await Future.wait([
          notifier.preload(),
          notifier.preload(),
          notifier.preload(),
        ]);
        await notifier.preload();

        expect(drawerRepo.callCount, 1);
        expect(
          perf.preloadStartCalls,
          1,
          reason: 'no categories preload, exactly one config start',
        );
        expect(perf.preloadCompleteCalls, 1);
        expect(
          container.read(drawerNavigationPreloaderProvider).status,
          DrawerPreloadStatus.completed,
        );
      },
    );

    test(
      'preload only loads the visible variant (includeHidden=false)',
      () async {
        final drawerRepo = _CountingDrawerRepo([() async => _success()]);
        final perf = _RecordingPerfLogger();
        final container = _container(drawerRepo: drawerRepo, perfLogger: perf);

        // Edit mode is active, but the preload must NOT pass includeHidden=true.
        container.read(editModeProvider.notifier).state = true;

        await container
            .read(drawerNavigationPreloaderProvider.notifier)
            .preload();

        expect(drawerRepo.includeHiddenCalls, [false]);
      },
    );

    test('preload latency reflects the injected clock', () async {
      final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
      final drawerRepo = _CountingDrawerRepo([
        () async {
          // Simulate 250ms of remote work.
          clock.value = clock.value.add(const Duration(milliseconds: 250));
          return _success();
        },
      ]);
      final perf = _RecordingPerfLogger();
      final container = _container(
        drawerRepo: drawerRepo,
        perfLogger: perf,
        clock: clock.call,
      );

      await container
          .read(drawerNavigationPreloaderProvider.notifier)
          .preload();

      expect(
        perf.preloadCompleteLatencies.single,
        const Duration(milliseconds: 250),
      );
    });

    test(
      'preload reports already_ready=true when slot was warmed earlier',
      () async {
        final drawerRepo = _CountingDrawerRepo([() async => _success()]);
        final perf = _RecordingPerfLogger();
        final container = _container(drawerRepo: drawerRepo, perfLogger: perf);

        // Warm the provider before the preloader runs.
        await container.read(mainDrawerNavigationProvider.future);
        expect(drawerRepo.callCount, 1);

        await container
            .read(drawerNavigationPreloaderProvider.notifier)
            .preload();

        expect(drawerRepo.callCount, 1);
        expect(perf.preloadCompleteCalls, 1);
        expect(perf.preloadAlreadyReadyFlags.single, isTrue);
      },
    );
  });

  group('DrawerNavigationPreloader - categories warm-up path', () {
    test(
      'menu with liveSource=categories DOES preload drawerCategories',
      () async {
        final drawerRepo = _CountingDrawerRepo([
          () async => _success(displayMode: 'categories'),
        ]);
        final categoryRepo = _CountingCategoryRepo();
        final perf = _RecordingPerfLogger();
        final container = _container(
          drawerRepo: drawerRepo,
          categoryRepo: categoryRepo,
          perfLogger: perf,
        );

        await container
            .read(drawerNavigationPreloaderProvider.notifier)
            .preload();

        expect(drawerRepo.callCount, 1);
        expect(
          categoryRepo.activeCalls,
          1,
          reason: 'liveSource=categories triggers the category warm-up',
        );
        expect(
          categoryRepo.includeHiddenCalls,
          [false],
          reason: 'never speculate on the admin variant',
        );

        final s = container.read(drawerNavigationPreloaderProvider);
        expect(s.status, DrawerPreloadStatus.completed);
        expect(s.configStatus, DrawerPreloadStatus.completed);
        expect(s.categoriesStatus, DrawerPreloadStatus.completed);

        expect(perf.sawCategoriesStart, isTrue);
        expect(perf.sawCategoriesComplete, isTrue);
      },
    );

    test('fallback drawer DOES preload drawerCategories (drawer falls back to '
        'category list at open-time)', () async {
      final drawerRepo = _CountingDrawerRepo([
        () async => const DrawerNavigationLoadResult.fallback(
          fallbackReason: DrawerNavigationFallbackReason.menuMissing,
        ),
      ]);
      final categoryRepo = _CountingCategoryRepo();
      final perf = _RecordingPerfLogger();
      final container = _container(
        drawerRepo: drawerRepo,
        categoryRepo: categoryRepo,
        perfLogger: perf,
      );

      await container
          .read(drawerNavigationPreloaderProvider.notifier)
          .preload();

      expect(categoryRepo.activeCalls, 1);
      final s = container.read(drawerNavigationPreloaderProvider);
      // Degraded but ready: config failed, categories warm → user can
      // still open instantly (drawer renders the category list).
      expect(s.status, DrawerPreloadStatus.completed);
      expect(s.configStatus, DrawerPreloadStatus.failed);
      expect(s.categoriesStatus, DrawerPreloadStatus.completed);
      expect(perf.preloadFallbackCalls, 1);
    });

    test(
      'fallback drawer + categories failure → overall failed (no warm path)',
      () async {
        final drawerRepo = _CountingDrawerRepo([
          () async => const DrawerNavigationLoadResult.fallback(
            fallbackReason: DrawerNavigationFallbackReason.fetchError,
          ),
        ]);
        final categoryRepo = _CountingCategoryRepo(shouldThrow: true);
        final perf = _RecordingPerfLogger();
        final container = _container(
          drawerRepo: drawerRepo,
          categoryRepo: categoryRepo,
          perfLogger: perf,
        );

        await container
            .read(drawerNavigationPreloaderProvider.notifier)
            .preload();

        final s = container.read(drawerNavigationPreloaderProvider);
        expect(s.status, DrawerPreloadStatus.failed);
        expect(s.configStatus, DrawerPreloadStatus.failed);
        expect(s.categoriesStatus, DrawerPreloadStatus.failed);
        expect(perf.sawCategoriesError, isTrue);
      },
    );

    test(
      'liveSource=categories + categories preload error → overall failed',
      () async {
        final drawerRepo = _CountingDrawerRepo([
          () async => _success(displayMode: 'categories'),
        ]);
        final categoryRepo = _CountingCategoryRepo(shouldThrow: true);
        final perf = _RecordingPerfLogger();
        final container = _container(
          drawerRepo: drawerRepo,
          categoryRepo: categoryRepo,
          perfLogger: perf,
        );

        await container
            .read(drawerNavigationPreloaderProvider.notifier)
            .preload();

        final s = container.read(drawerNavigationPreloaderProvider);
        expect(
          s.status,
          DrawerPreloadStatus.failed,
          reason: 'config ok but categories failed when needed',
        );
        expect(s.configStatus, DrawerPreloadStatus.completed);
        expect(s.categoriesStatus, DrawerPreloadStatus.failed);
      },
    );

    test('idempotence covers BOTH config and categories sub-tasks', () async {
      final drawerRepo = _CountingDrawerRepo([
        () async => _success(displayMode: 'categories'),
      ]);
      final categoryRepo = _CountingCategoryRepo();
      final perf = _RecordingPerfLogger();
      final container = _container(
        drawerRepo: drawerRepo,
        categoryRepo: categoryRepo,
        perfLogger: perf,
      );

      final notifier = container.read(
        drawerNavigationPreloaderProvider.notifier,
      );
      await Future.wait([
        notifier.preload(),
        notifier.preload(),
        notifier.preload(),
      ]);

      expect(drawerRepo.callCount, 1);
      expect(categoryRepo.activeCalls, 1);
      expect(
        perf.preloadStartCalls,
        2,
        reason: 'one start per sub-task, no repeats',
      );
      expect(perf.preloadCompleteCalls, 2);
    });
  });

  group('classifyDrawerOpenState', () {
    AsyncValue<DrawerNavigationLoadResult> data(DrawerNavigationLoadResult v) =>
        AsyncValue.data(v);

    final t0 = DateTime.utc(2026, 5, 1);
    final completedPreload = DrawerPreloadState.completed(
      startedAt: t0,
      completedAt: t0.add(const Duration(seconds: 1)),
    );
    final runningPreload = DrawerPreloadState.running(t0);

    test('preloadedReady when preload completed and provider has a value', () {
      expect(
        classifyDrawerOpenState(
          providerState: data(_success()),
          preloadState: completedPreload,
        ),
        DrawerOpenDataState.preloadedReady,
      );
    });

    test('cacheHitReady when provider has a value but preload never ran', () {
      expect(
        classifyDrawerOpenState(
          providerState: data(_success()),
          preloadState: const DrawerPreloadState.notStarted(),
        ),
        DrawerOpenDataState.cacheHitReady,
      );
    });

    test('preloadRunning when loading and preload is in flight', () {
      expect(
        classifyDrawerOpenState(
          providerState: const AsyncValue<DrawerNavigationLoadResult>.loading(),
          preloadState: runningPreload,
        ),
        DrawerOpenDataState.preloadRunning,
      );
    });

    test('fallbackOrError when AsyncValue carries an error', () {
      expect(
        classifyDrawerOpenState(
          providerState: AsyncValue<DrawerNavigationLoadResult>.error(
            StateError('x'),
            StackTrace.current,
          ),
          preloadState: const DrawerPreloadState.notStarted(),
        ),
        DrawerOpenDataState.fallbackOrError,
      );
    });

    test('fallbackOrError when value carries fallbackReason', () {
      expect(
        classifyDrawerOpenState(
          providerState: data(
            const DrawerNavigationLoadResult.fallback(
              fallbackReason: DrawerNavigationFallbackReason.menuMissing,
            ),
          ),
          preloadState: const DrawerPreloadState.notStarted(),
        ),
        DrawerOpenDataState.fallbackOrError,
      );
    });

    test('coldLoading when no value and no preload', () {
      expect(
        classifyDrawerOpenState(
          providerState: const AsyncValue<DrawerNavigationLoadResult>.loading(),
          preloadState: const DrawerPreloadState.notStarted(),
        ),
        DrawerOpenDataState.coldLoading,
      );
    });
  });

  group('recordOpen', () {
    test(
      'open after a successful preload reports preloaded_ready exactly once',
      () async {
        final drawerRepo = _CountingDrawerRepo([() async => _success()]);
        final perf = _RecordingPerfLogger();
        final container = _container(drawerRepo: drawerRepo, perfLogger: perf);

        final notifier = container.read(
          drawerNavigationPreloaderProvider.notifier,
        );
        await notifier.preload();

        await notifier.recordOpen();

        expect(perf.openStartCalls, 1);
        expect(perf.openReadyStates, [DrawerOpenDataState.preloadedReady]);
      },
    );

    test(
      'open with cache warmed by another path reports cache_hit_ready',
      () async {
        final drawerRepo = _CountingDrawerRepo([() async => _success()]);
        final perf = _RecordingPerfLogger();
        final container = _container(drawerRepo: drawerRepo, perfLogger: perf);

        // Warm the provider WITHOUT going through the preloader.
        await container.read(mainDrawerNavigationProvider.future);
        expect(
          container.read(drawerNavigationPreloaderProvider).status,
          DrawerPreloadStatus.notStarted,
        );

        await container
            .read(drawerNavigationPreloaderProvider.notifier)
            .recordOpen();

        expect(perf.openReadyStates, [DrawerOpenDataState.cacheHitReady]);
      },
    );

    test('open while still cold waits for the future and emits exactly one '
        'openReady', () async {
      final completer = Completer<DrawerNavigationLoadResult>();
      final drawerRepo = _CountingDrawerRepo([() => completer.future]);
      final perf = _RecordingPerfLogger();
      final container = _container(drawerRepo: drawerRepo, perfLogger: perf);

      final openFuture = container
          .read(drawerNavigationPreloaderProvider.notifier)
          .recordOpen();
      expect(perf.openReadyStates, isEmpty);

      completer.complete(_success());
      await openFuture;

      expect(perf.openReadyStates.length, 1);
      expect(perf.openReadyStates.single, DrawerOpenDataState.cacheHitReady);
    });

    test(
      'invalidation after preload forces refetch on the next read',
      () async {
        final drawerRepo = _CountingDrawerRepo([
          () async => _success(menuId: 'v1'),
          () async => _success(menuId: 'v2'),
        ]);
        final perf = _RecordingPerfLogger();
        final container = _container(drawerRepo: drawerRepo, perfLogger: perf);

        await container
            .read(drawerNavigationPreloaderProvider.notifier)
            .preload();
        expect(drawerRepo.callCount, 1);

        container.read(catalogInvalidatorProvider).applyToContainer(
          container,
          const [DrawerNavigationInvalidation()],
        );
        final result = await container.read(
          mainDrawerNavigationProvider.future,
        );
        expect(drawerRepo.callCount, 2);
        expect(result.menu?.id, 'v2');
      },
    );
  });

  group('product requirement: opening a category-mode drawer is silent', () {
    test('open during in-flight preload joins the same in-flight loader → '
        'exactly ONE category fetch (no duplicate request at open)', () async {
      // Drawer config resolves immediately as a fallback so the
      // preloader proceeds to the categories step.
      final drawerRepo = _CountingDrawerRepo([
        () async => const DrawerNavigationLoadResult.fallback(
          fallbackReason: DrawerNavigationFallbackReason.menuMissing,
        ),
      ]);

      // Categories resolution is gated on a Completer so we can
      // simulate a slow network and open the drawer mid-flight.
      final completer = Completer<List<CatalogCategory>>();
      final categoryRepo = _GatedCategoryRepo(completer.future);

      final perf = _RecordingPerfLogger();
      final container = _container(
        drawerRepo: drawerRepo,
        categoryRepo: categoryRepo,
        perfLogger: perf,
      );

      // Kick off the preload but DO NOT await it.
      final preloadFuture = container
          .read(drawerNavigationPreloaderProvider.notifier)
          .preload();

      // Yield once so the categories step starts and registers its
      // in-flight slot in the deduplicator.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        categoryRepo.activeCalls,
        1,
        reason: 'preload started its categories fetch',
      );

      // Now simulate the user opening the drawer mid-flight: the drawer
      // reads drawerCategoriesProvider. With dedupe:true on both sides,
      // the read MUST join the in-flight loader, not start a parallel
      // network request.
      final openRead = container.read(drawerCategoriesProvider.future);

      // Resolve the gated network response.
      completer.complete(const [
        CatalogCategory(id: 'c1', code: 'c1', name: 'C1', slug: 'c1'),
      ]);

      await preloadFuture;
      await openRead;

      expect(
        categoryRepo.activeCalls,
        1,
        reason: 'open MUST NOT trigger a second network request',
      );
    });

    test('after preload of a categories-mode drawer, reading '
        'drawerCategoriesProvider triggers NO new repo call', () async {
      final drawerRepo = _CountingDrawerRepo([
        () async => _success(displayMode: 'categories'),
      ]);
      final categoryRepo = _CountingCategoryRepo();
      final perf = _RecordingPerfLogger();
      final container = _container(
        drawerRepo: drawerRepo,
        categoryRepo: categoryRepo,
        perfLogger: perf,
      );

      // Preload completes both sub-tasks.
      await container
          .read(drawerNavigationPreloaderProvider.notifier)
          .preload();
      expect(categoryRepo.activeCalls, 1);

      // Simulate the user tapping the hamburger menu: the drawer reads
      // its categories provider. No additional repo call should happen
      // — the cache is already warm.
      final cats = await container.read(drawerCategoriesProvider.future);
      expect(cats, isNotEmpty);
      expect(
        categoryRepo.activeCalls,
        1,
        reason: 'open after preload must not trigger a new fetch',
      );
    });

    test('after preload of a fallback drawer, reading drawerCategoriesProvider '
        'triggers NO new repo call', () async {
      final drawerRepo = _CountingDrawerRepo([
        () async => const DrawerNavigationLoadResult.fallback(
          fallbackReason: DrawerNavigationFallbackReason.menuMissing,
        ),
      ]);
      final categoryRepo = _CountingCategoryRepo();
      final perf = _RecordingPerfLogger();
      final container = _container(
        drawerRepo: drawerRepo,
        categoryRepo: categoryRepo,
        perfLogger: perf,
      );

      await container
          .read(drawerNavigationPreloaderProvider.notifier)
          .preload();
      expect(categoryRepo.activeCalls, 1);

      final cats = await container.read(drawerCategoriesProvider.future);
      expect(cats, isNotEmpty);
      expect(categoryRepo.activeCalls, 1);
    });
  });
}
