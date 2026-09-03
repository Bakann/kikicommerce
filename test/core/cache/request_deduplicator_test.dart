import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/cache/cache_metrics_logger.dart';
import 'package:kiki_commerce/core/cache/request_deduplicator.dart';

class _RecordingMetrics implements CacheMetricsLogger {
  final List<String> dedupeStarts = [];
  final List<String> dedupeJoins = [];
  final List<String> dedupeCompletes = [];
  final List<Duration> dedupeCompleteLatencies = [];
  final List<Object> dedupeErrors = [];

  @override
  void dedupeStart(String resourceType, String key) {
    dedupeStarts.add('$resourceType:$key');
  }

  @override
  void dedupeJoin(String resourceType, String key) {
    dedupeJoins.add('$resourceType:$key');
  }

  @override
  void dedupeComplete(String resourceType, String key, Duration latency) {
    dedupeCompletes.add('$resourceType:$key');
    dedupeCompleteLatencies.add(latency);
  }

  @override
  void dedupeError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) {
    dedupeErrors.add(error);
  }

  @override
  void hit(String resourceType, String key) {}
  @override
  void miss(String resourceType, String key) {}
  @override
  void stale(String resourceType, String key) {}
  @override
  void refreshSuccess(String resourceType, String key, Duration latency) {}
  @override
  void refreshError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) {}
  @override
  void eviction(String resourceType, String key) {}
}

class _MutableClock {
  _MutableClock(this.value);
  DateTime value;
  DateTime call() => value;
}

void main() {
  group('RequestDeduplicator', () {
    test(
      '10 concurrent calls with same key execute the loader exactly once',
      () async {
        final metrics = _RecordingMetrics();
        final dedup = RequestDeduplicator(metricsLogger: metrics);
        var loaderCalls = 0;
        final completer = Completer<int>();

        Future<int> loader() {
          loaderCalls++;
          return completer.future;
        }

        final futures = List<Future<int>>.generate(
          10,
          (_) => dedup.run<int>('k', loader, resourceType: 'plp'),
        );
        completer.complete(42);
        final results = await Future.wait(futures);

        expect(loaderCalls, 1);
        expect(results, List.filled(10, 42));
        // 9 of 10 callers were deduped onto the in-flight future.
        expect(metrics.dedupeJoins.length, 9);
      },
    );

    test('different keys execute independent loaders', () async {
      final dedup = RequestDeduplicator();
      var aCalls = 0;
      var bCalls = 0;
      Future<int> loaderA() async {
        aCalls++;
        return 1;
      }

      Future<int> loaderB() async {
        bCalls++;
        return 2;
      }

      await Future.wait([
        dedup.run<int>('a', loaderA),
        dedup.run<int>('b', loaderB),
      ]);
      expect(aCalls, 1);
      expect(bCalls, 1);
    });

    test('errors clear the in-flight slot and allow retry', () async {
      final dedup = RequestDeduplicator();
      var attempt = 0;
      Future<int> loader() async {
        attempt++;
        if (attempt == 1) {
          throw StateError('boom');
        }
        return 99;
      }

      await expectLater(
        dedup.run<int>('k', loader),
        throwsA(isA<StateError>()),
      );
      expect(dedup.isInFlight('k'), isFalse);

      final retry = await dedup.run<int>('k', loader);
      expect(retry, 99);
      expect(attempt, 2);
    });

    test(
      'invalidate(key) drops the in-flight slot so new callers refetch',
      () async {
        final dedup = RequestDeduplicator();
        final completer = Completer<int>();
        var loaderCalls = 0;
        Future<int> loader() {
          loaderCalls++;
          return completer.future;
        }

        final f1 = dedup.run<int>('k', loader);
        expect(dedup.isInFlight('k'), isTrue);

        dedup.invalidate('k');
        expect(dedup.isInFlight('k'), isFalse);

        // A subsequent call starts a fresh loader instead of joining f1.
        final c2 = Completer<int>();
        final f2 = dedup.run<int>('k', () {
          loaderCalls++;
          return c2.future;
        });
        expect(loaderCalls, 2);

        completer.complete(1);
        c2.complete(2);
        expect(await f1, 1);
        expect(await f2, 2);
      },
    );

    test('invalidateByPrefix drops only matching in-flight slots', () async {
      final dedup = RequestDeduplicator();
      final cA = Completer<int>();
      final cB = Completer<int>();
      final fA = dedup.run<int>('drawer:a', () => cA.future);
      final fB = dedup.run<int>('product:b', () => cB.future);
      expect(dedup.isInFlight('drawer:a'), isTrue);
      expect(dedup.isInFlight('product:b'), isTrue);

      dedup.invalidateByPrefix('drawer:');
      expect(dedup.isInFlight('drawer:a'), isFalse);
      expect(dedup.isInFlight('product:b'), isTrue);

      cA.complete(1);
      cB.complete(2);
      expect(await fA, 1);
      expect(await fB, 2);
    });

    test('concurrent callers all receive the same error on failure', () async {
      final dedup = RequestDeduplicator();
      final completer = Completer<int>();

      final f1 = dedup.run<int>('k', () => completer.future);
      final f2 = dedup.run<int>('k', () => completer.future);

      // Attach error matchers BEFORE completing so we never observe a
      // transient unhandled-error window in the test zone.
      final pending1 = expectLater(f1, throwsA(isA<StateError>()));
      final pending2 = expectLater(f2, throwsA(isA<StateError>()));

      completer.completeError(StateError('fail'));

      await pending1;
      await pending2;
      expect(dedup.isInFlight('k'), isFalse);
    });
  });

  group('RequestDeduplicator observability', () {
    test('10 concurrent calls log 1 start, 9 joins, 1 complete (gain = 9 saved '
        'remote round-trips)', () async {
      final metrics = _RecordingMetrics();
      final dedup = RequestDeduplicator(metricsLogger: metrics);
      final completer = Completer<int>();
      var loaderCalls = 0;

      final futures = List<Future<int>>.generate(
        10,
        (_) => dedup.run<int>('plp:fr|cat=shoes', () {
          loaderCalls++;
          return completer.future;
        }, resourceType: 'plp'),
      );
      completer.complete(7);
      await Future.wait(futures);

      expect(loaderCalls, 1, reason: 'one shared loader');
      expect(metrics.dedupeStarts.length, 1);
      expect(
        metrics.dedupeJoins.length,
        9,
        reason: 'each join = one saved remote round-trip',
      );
      expect(metrics.dedupeCompletes.length, 1);
      expect(metrics.dedupeErrors, isEmpty);
    });

    test(
      'failing loader logs dedupeError exactly once and clears in-flight',
      () async {
        final metrics = _RecordingMetrics();
        final dedup = RequestDeduplicator(metricsLogger: metrics);
        final completer = Completer<int>();
        final pending = expectLater(
          dedup.run<int>('k', () => completer.future, resourceType: 'r'),
          throwsA(isA<StateError>()),
        );
        completer.completeError(StateError('boom'));
        await pending;

        expect(metrics.dedupeStarts.length, 1);
        expect(metrics.dedupeErrors.length, 1);
        expect(metrics.dedupeCompletes, isEmpty);
        expect(dedup.isInFlight('k'), isFalse);
      },
    );

    test(
      'different keys log independent start/complete pairs (no joins)',
      () async {
        final metrics = _RecordingMetrics();
        final dedup = RequestDeduplicator(metricsLogger: metrics);

        await dedup.run<int>('a', () async => 1, resourceType: 'r');
        await dedup.run<int>('b', () async => 2, resourceType: 'r');

        expect(metrics.dedupeStarts.length, 2);
        expect(metrics.dedupeCompletes.length, 2);
        expect(metrics.dedupeJoins, isEmpty);
      },
    );

    test(
      'dedupeComplete latency is measured against the injected clock',
      () async {
        final metrics = _RecordingMetrics();
        final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
        final dedup = RequestDeduplicator(
          metricsLogger: metrics,
          now: clock.call,
        );

        final result = await dedup.run<int>('k', () async {
          // Simulate 250ms of remote work by advancing the clock before
          // the loader resolves.
          clock.value = clock.value.add(const Duration(milliseconds: 250));
          return 1;
        }, resourceType: 'r');
        expect(result, 1);
        expect(
          metrics.dedupeCompleteLatencies.single,
          const Duration(milliseconds: 250),
        );
      },
    );
  });
}
