import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Coarse classification of the drawer's data state at the moment the user
/// opens it. Reported via [DrawerPerformanceLogger.openReady] so we can tell
/// at a glance whether the preload paid off:
///
/// - [preloadedReady]: the post-first-frame preloader had already completed
///   successfully — opening the drawer is a pure UI cost.
/// - [cacheHitReady]: the drawer's AsyncValue was resolved by some other
///   path (e.g. a previous open, an explicit `read`) without going through
///   the preloader. Still instant, but the preload didn't contribute.
/// - [preloadRunning]: the preload is in flight at the moment of open. The
///   user waits for it to finish.
/// - [coldLoading]: neither preload nor cache have produced a value yet.
///   The user pays the full network latency in front of the open animation.
/// - [fallbackOrError]: the drawer is in an error/fallback state.
enum DrawerOpenDataState {
  preloadedReady,
  cacheHitReady,
  preloadRunning,
  coldLoading,
  fallbackOrError,
}

/// Sink for drawer open / preload performance events. Kept abstract so a
/// real telemetry backend (Firebase, OTel, …) can replace the console
/// implementation later without touching call sites.
abstract class DrawerPerformanceLogger {
  /// A new preload was kicked off for [key].
  void preloadStart(String key);

  /// A preload finished successfully after [latency].
  /// [alreadyReady] is true when the underlying provider had already resolved
  /// before the preloader awaited it (i.e. the preload was a no-op);
  /// distinguishing this is essential to avoid attributing zero-cost
  /// preloads to the warm-up effort.
  void preloadComplete(
    String key,
    Duration latency, {
    required bool alreadyReady,
  });

  /// A preload completed but landed on a fallback result (e.g. menu missing
  /// / fetch error). NOT counted as success — reported separately so we can
  /// see how often degraded state poisons the warm-up.
  void preloadFallback(String key, Duration latency, Object reason);

  /// A preload threw. Reported once per attempt; the preloader itself
  /// swallows the exception so the app never crashes on warm-up failure.
  void preloadError(
    String key,
    Duration latency,
    Object error,
    StackTrace stackTrace,
  );

  /// The user just tapped the drawer-open trigger. Optional companion event
  /// to [openReady] when callers want both endpoints; most code paths only
  /// need [openReady].
  void openStart();

  /// The drawer's data was ready. [latency] is measured from the user's
  /// open action to the moment the data became available (zero-ish when
  /// already cached, real round-trip otherwise). [state] explains where the
  /// data came from so cold/warm/preloaded paths can be split in dashboards.
  ///
  /// MUST be called at most once per open.
  void openReady({
    required Duration latency,
    required DrawerOpenDataState state,
  });
}

/// Default development logger writing structured lines to [debugPrint].
class ConsoleDrawerPerformanceLogger implements DrawerPerformanceLogger {
  const ConsoleDrawerPerformanceLogger();

  @override
  void preloadStart(String key) {
    debugPrint('[perf] DRAWER_PRELOAD_START key=$key');
  }

  @override
  void preloadComplete(
    String key,
    Duration latency, {
    required bool alreadyReady,
  }) {
    debugPrint(
      '[perf] DRAWER_PRELOAD_OK key=$key '
      '${latency.inMilliseconds}ms already_ready=$alreadyReady',
    );
  }

  @override
  void preloadFallback(String key, Duration latency, Object reason) {
    debugPrint(
      '[perf] DRAWER_PRELOAD_FALLBACK key=$key '
      '${latency.inMilliseconds}ms reason=$reason',
    );
  }

  @override
  void preloadError(
    String key,
    Duration latency,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint(
      '[perf] DRAWER_PRELOAD_ERR key=$key '
      '${latency.inMilliseconds}ms error=$error',
    );
  }

  @override
  void openStart() {
    debugPrint('[perf] DRAWER_OPEN_START');
  }

  @override
  void openReady({
    required Duration latency,
    required DrawerOpenDataState state,
  }) {
    debugPrint(
      '[perf] DRAWER_OPEN_READY state=${_stateLabel(state)} '
      '${latency.inMilliseconds}ms',
    );
  }

  String _stateLabel(DrawerOpenDataState s) {
    switch (s) {
      case DrawerOpenDataState.preloadedReady:
        return 'preloaded_ready';
      case DrawerOpenDataState.cacheHitReady:
        return 'cache_hit_ready';
      case DrawerOpenDataState.preloadRunning:
        return 'preload_running';
      case DrawerOpenDataState.coldLoading:
        return 'cold_loading';
      case DrawerOpenDataState.fallbackOrError:
        return 'fallback_or_error';
    }
  }
}

class NoopDrawerPerformanceLogger implements DrawerPerformanceLogger {
  const NoopDrawerPerformanceLogger();

  @override
  void preloadStart(String key) {}
  @override
  void preloadComplete(
    String key,
    Duration latency, {
    required bool alreadyReady,
  }) {}
  @override
  void preloadFallback(String key, Duration latency, Object reason) {}
  @override
  void preloadError(
    String key,
    Duration latency,
    Object error,
    StackTrace stackTrace,
  ) {}
  @override
  void openStart() {}
  @override
  void openReady({
    required Duration latency,
    required DrawerOpenDataState state,
  }) {}
}

/// Riverpod entry point. Stays quiet in release builds (matches the
/// project's existing telemetry convention); emits structured lines through
/// `debugPrint` in dev/profile/test.
final drawerPerformanceLoggerProvider = Provider<DrawerPerformanceLogger>((
  ref,
) {
  return kReleaseMode
      ? const NoopDrawerPerformanceLogger()
      : const ConsoleDrawerPerformanceLogger();
});
