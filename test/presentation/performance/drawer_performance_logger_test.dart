import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/performance/drawer_performance_logger.dart';

void main() {
  group('ConsoleDrawerPerformanceLogger', () {
    final logs = <String>[];

    setUp(() {
      logs.clear();
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
    });

    tearDown(() {
      debugPrint = debugPrintThrottled;
    });

    const logger = ConsoleDrawerPerformanceLogger();

    test('preloadStart emits a structured PRELOAD_START line', () {
      logger.preloadStart('drawer:k');
      expect(logs.single, '[perf] DRAWER_PRELOAD_START key=drawer:k');
    });

    test('preloadComplete includes latency and already_ready flag', () {
      logger.preloadComplete(
        'drawer:k',
        const Duration(milliseconds: 715),
        alreadyReady: false,
      );
      expect(
        logs.single,
        '[perf] DRAWER_PRELOAD_OK key=drawer:k 715ms already_ready=false',
      );
    });

    test('preloadFallback uses FALLBACK and includes the reason', () {
      logger.preloadFallback(
        'drawer:k',
        const Duration(milliseconds: 300),
        'fetchError',
      );
      expect(
        logs.single,
        '[perf] DRAWER_PRELOAD_FALLBACK key=drawer:k 300ms reason=fetchError',
      );
    });

    test('preloadError uses ERR and includes the error', () {
      logger.preloadError(
        'drawer:k',
        const Duration(milliseconds: 600),
        StateError('boom'),
        StackTrace.current,
      );
      expect(logs.single, contains('DRAWER_PRELOAD_ERR key=drawer:k 600ms'));
    });

    test('openReady emits the snake_case state label', () {
      logger.openReady(
        latency: const Duration(milliseconds: 4),
        state: DrawerOpenDataState.preloadedReady,
      );
      logger.openReady(
        latency: const Duration(milliseconds: 650),
        state: DrawerOpenDataState.coldLoading,
      );
      logger.openReady(
        latency: const Duration(milliseconds: 0),
        state: DrawerOpenDataState.cacheHitReady,
      );
      logger.openReady(
        latency: Duration.zero,
        state: DrawerOpenDataState.preloadRunning,
      );
      logger.openReady(
        latency: Duration.zero,
        state: DrawerOpenDataState.fallbackOrError,
      );

      expect(logs[0], '[perf] DRAWER_OPEN_READY state=preloaded_ready 4ms');
      expect(logs[1], '[perf] DRAWER_OPEN_READY state=cold_loading 650ms');
      expect(logs[2], '[perf] DRAWER_OPEN_READY state=cache_hit_ready 0ms');
      expect(logs[3], '[perf] DRAWER_OPEN_READY state=preload_running 0ms');
      expect(logs[4], '[perf] DRAWER_OPEN_READY state=fallback_or_error 0ms');
    });
  });

  group('NoopDrawerPerformanceLogger', () {
    test('does not emit any log line', () {
      final logs = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      addTearDown(() => debugPrint = debugPrintThrottled);

      const logger = NoopDrawerPerformanceLogger();
      logger.preloadStart('k');
      logger.preloadComplete('k', Duration.zero, alreadyReady: true);
      logger.preloadFallback('k', Duration.zero, 'reason');
      logger.preloadError('k', Duration.zero, 'err', StackTrace.current);
      logger.openStart();
      logger.openReady(
        latency: Duration.zero,
        state: DrawerOpenDataState.preloadedReady,
      );
      expect(logs, isEmpty);
    });
  });
}
