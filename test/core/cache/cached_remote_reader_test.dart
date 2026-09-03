import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/cache/cache_metrics_logger.dart';
import 'package:kiki_commerce/core/cache/cache_policy.dart';
import 'package:kiki_commerce/core/cache/cache_refresh_strategy.dart';
import 'package:kiki_commerce/core/cache/cached_remote_reader.dart';
import 'package:kiki_commerce/core/cache/memory_local_read_cache.dart';
import 'package:kiki_commerce/core/cache/request_deduplicator.dart';

class _RecordingMetrics implements CacheMetricsLogger {
  final List<String> events = [];

  @override
  void hit(String resourceType, String key) =>
      events.add('hit:$resourceType:$key');

  @override
  void miss(String resourceType, String key) =>
      events.add('miss:$resourceType:$key');

  @override
  void stale(String resourceType, String key) =>
      events.add('stale:$resourceType:$key');

  @override
  void refreshSuccess(String resourceType, String key, Duration latency) =>
      events.add('refreshSuccess:$resourceType:$key');

  @override
  void refreshError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) => events.add('refreshError:$resourceType:$key');

  @override
  void dedupeStart(String resourceType, String key) =>
      events.add('dedupeStart:$resourceType:$key');

  @override
  void dedupeJoin(String resourceType, String key) =>
      events.add('dedupeJoin:$resourceType:$key');

  @override
  void dedupeComplete(String resourceType, String key, Duration latency) =>
      events.add('dedupeComplete:$resourceType:$key');

  @override
  void dedupeError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) => events.add('dedupeError:$resourceType:$key');

  @override
  void eviction(String resourceType, String key) =>
      events.add('eviction:$resourceType:$key');
}

class _MutableClock {
  _MutableClock(this.value);
  DateTime value;
  DateTime call() => value;
}

CachedRemoteReader _buildReader({
  DateTime Function()? now,
  _RecordingMetrics? metrics,
  MemoryLocalReadCache? cache,
}) {
  final m = metrics ?? _RecordingMetrics();
  final c = cache ?? MemoryLocalReadCache(now: now);
  final dedup = RequestDeduplicator(metricsLogger: m);
  return CachedRemoteReader(
    cache: c,
    deduplicator: dedup,
    metricsLogger: m,
    now: now,
  );
}

void main() {
  const swr = CachePolicy(
    ttl: Duration(minutes: 5),
    strategy: CacheRefreshStrategy.staleWhileRevalidate,
  );
  const cacheFirst = CachePolicy(
    ttl: Duration(minutes: 5),
    strategy: CacheRefreshStrategy.cacheFirst,
  );
  const networkFirst = CachePolicy(
    ttl: Duration(minutes: 5),
    strategy: CacheRefreshStrategy.networkFirst,
  );
  const networkOnly = CachePolicy(strategy: CacheRefreshStrategy.networkOnly);

  group('cacheFirst', () {
    test(
      'fresh cache hit returns cached value without calling remote',
      () async {
        final metrics = _RecordingMetrics();
        final reader = _buildReader(metrics: metrics);
        var calls = 0;
        Future<String> loader() async {
          calls++;
          return 'fresh';
        }

        final first = await reader.read<String>(
          key: 'product:1',
          resourceType: 'product',
          policy: cacheFirst,
          remoteLoader: loader,
        );
        final second = await reader.read<String>(
          key: 'product:1',
          resourceType: 'product',
          policy: cacheFirst,
          remoteLoader: loader,
        );
        expect(first, 'fresh');
        expect(second, 'fresh');
        expect(calls, 1);
        expect(metrics.events, contains('hit:product:product:1'));
      },
    );

    test('cache miss calls remote and writes back', () async {
      final metrics = _RecordingMetrics();
      final reader = _buildReader(metrics: metrics);
      final result = await reader.read<int>(
        key: 'product:9',
        resourceType: 'product',
        policy: cacheFirst,
        remoteLoader: () async => 7,
      );
      expect(result, 7);
      expect(metrics.events.first, 'miss:product:product:9');
    });
  });

  group('staleWhileRevalidate', () {
    test(
      'stale hit returns stale immediately and refreshes in background',
      () async {
        final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
        final cache = MemoryLocalReadCache(now: clock.call);
        final metrics = _RecordingMetrics();
        final reader = _buildReader(
          now: clock.call,
          metrics: metrics,
          cache: cache,
        );

        // Seed.
        await reader.read<String>(
          key: 'product:1',
          resourceType: 'product',
          policy: swr,
          remoteLoader: () async => 'v1',
        );

        // Move past TTL.
        clock.value = clock.value.add(const Duration(minutes: 6));

        final completer = Completer<String>();
        final freshValues = <String>[];
        final staleValues = <String>[];

        final result = await reader.read<String>(
          key: 'product:1',
          resourceType: 'product',
          policy: swr,
          remoteLoader: () => completer.future,
          onStaleData: staleValues.add,
          onFreshData: freshValues.add,
        );

        // Stale value returned immediately.
        expect(result, 'v1');
        expect(staleValues, ['v1']);
        // Refresh has not yet completed.
        expect(freshValues, isEmpty);

        // Complete the background refresh.
        completer.complete('v2');
        // Yield so the background future fires its callbacks.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(freshValues, ['v2']);
        // Cache now has fresh value (peek bypasses freshness).
        final peeked = await cache.peek<String>('product:1');
        expect(peeked!.data, 'v2');
        expect(metrics.events, contains('stale:product:product:1'));
        expect(metrics.events, contains('refreshSuccess:product:product:1'));
      },
    );

    test('refresh error calls onRefreshError and keeps stale value', () async {
      final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
      final cache = MemoryLocalReadCache(now: clock.call);
      final metrics = _RecordingMetrics();
      final reader = _buildReader(
        now: clock.call,
        metrics: metrics,
        cache: cache,
      );

      await reader.read<String>(
        key: 'product:1',
        resourceType: 'product',
        policy: swr,
        remoteLoader: () async => 'v1',
      );
      clock.value = clock.value.add(const Duration(minutes: 6));

      final errors = <Object>[];
      final stacks = <StackTrace>[];

      final result = await reader.read<String>(
        key: 'product:1',
        resourceType: 'product',
        policy: swr,
        remoteLoader: () async => throw StateError('network down'),
        onRefreshError: (e, s) {
          errors.add(e);
          stacks.add(s);
        },
      );
      expect(result, 'v1');

      // Wait for the background refresh to settle.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(errors.length, 1);
      expect(errors.first, isA<StateError>());
      expect(stacks.length, 1);
      // Stale value preserved.
      final peeked = await cache.peek<String>('product:1');
      expect(peeked!.data, 'v1');
      expect(metrics.events, contains('refreshError:product:product:1'));
    });

    test('absent cache calls remote and returns fresh value', () async {
      final reader = _buildReader();
      final result = await reader.read<String>(
        key: 'product:42',
        resourceType: 'product',
        policy: swr,
        remoteLoader: () async => 'fresh',
      );
      expect(result, 'fresh');
    });

    test('SWR refresh background does not block the stale return', () async {
      final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
      final cache = MemoryLocalReadCache(now: clock.call);
      final reader = _buildReader(now: clock.call, cache: cache);

      await reader.read<String>(
        key: 'k',
        resourceType: 'r',
        policy: swr,
        remoteLoader: () async => 'v1',
      );
      clock.value = clock.value.add(const Duration(minutes: 6));

      // Loader never completes — but the stale read must still resolve.
      final blocker = Completer<String>();
      final result = await reader.read<String>(
        key: 'k',
        resourceType: 'r',
        policy: swr,
        remoteLoader: () => blocker.future,
      );
      expect(result, 'v1');
      // Tidy: complete the future so the test doesn't leak a pending task.
      blocker.complete('done');
    });

    test('background refresh that resolves after invalidation does not '
        'resurrect the cache or notify listeners', () async {
      final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
      final cache = MemoryLocalReadCache(now: clock.call);
      final reader = _buildReader(now: clock.call, cache: cache);

      await reader.read<String>(
        key: 'product:1',
        resourceType: 'product',
        policy: swr,
        remoteLoader: () async => 'v1',
      );
      clock.value = clock.value.add(const Duration(minutes: 6));

      final completer = Completer<String>();
      final freshValues = <String>[];
      final result = await reader.read<String>(
        key: 'product:1',
        resourceType: 'product',
        policy: swr,
        remoteLoader: () => completer.future,
        onFreshData: freshValues.add,
      );
      expect(result, 'v1');

      // A mutation invalidates the key while the refresh is still in flight.
      await cache.invalidate('product:1');

      // The slow background refresh now resolves with the value it had
      // started fetching before the invalidation.
      completer.complete('v2-stale');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // The stale write must not resurrect the invalidated entry...
      expect(await cache.peek<String>('product:1'), isNull);
      // ...nor push the stale value to listeners.
      expect(freshValues, isEmpty);
    });

    test(
      'background refresh writes back when no invalidation intervenes',
      () async {
        final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
        final cache = MemoryLocalReadCache(now: clock.call);
        final reader = _buildReader(now: clock.call, cache: cache);

        await reader.read<String>(
          key: 'product:1',
          resourceType: 'product',
          policy: swr,
          remoteLoader: () async => 'v1',
        );
        clock.value = clock.value.add(const Duration(minutes: 6));

        final completer = Completer<String>();
        final freshValues = <String>[];
        await reader.read<String>(
          key: 'product:1',
          resourceType: 'product',
          policy: swr,
          remoteLoader: () => completer.future,
          onFreshData: freshValues.add,
        );

        completer.complete('v2');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(freshValues, ['v2']);
        expect((await cache.peek<String>('product:1'))!.data, 'v2');
      },
    );

    test(
      'cold-miss load invalidated by prefix while in flight is not cached',
      () async {
        final cache = MemoryLocalReadCache();
        final reader = _buildReader(cache: cache);

        // First read for this key: nothing cached yet, so the loader runs in
        // the foreground (cacheFirst miss path).
        final started = Completer<void>();
        final completer = Completer<String>();
        final read = reader.read<String>(
          key: 'product:1',
          resourceType: 'product',
          policy: cacheFirst,
          remoteLoader: () {
            started.complete();
            return completer.future;
          },
        );

        // Wait until the loader has begun, so its generation is captured
        // before the invalidation below.
        await started.future;

        // A global product invalidation lands before the slow load resolves,
        // even though 'product:1' is not yet in the cache.
        await cache.invalidateByPrefix('product:');

        completer.complete('pre-invalidation');
        final result = await read;

        // The caller still receives the value it loaded, but the pre-
        // invalidation value must not be persisted.
        expect(result, 'pre-invalidation');
        expect(await cache.peek<String>('product:1'), isNull);
      },
    );
  });

  group('networkFirst', () {
    test('success writes cache and returns fresh value', () async {
      final cache = MemoryLocalReadCache();
      final reader = _buildReader(cache: cache);
      final result = await reader.read<int>(
        key: 'k',
        resourceType: 'r',
        policy: networkFirst,
        remoteLoader: () async => 5,
      );
      expect(result, 5);
      expect((await cache.peek<int>('k'))!.data, 5);
    });

    test('failure falls back to cache when present', () async {
      final cache = MemoryLocalReadCache();
      // Seed.
      await cache.put<int>('k', 99, networkFirst);
      final reader = _buildReader(cache: cache);
      final result = await reader.read<int>(
        key: 'k',
        resourceType: 'r',
        policy: networkFirst,
        remoteLoader: () async => throw StateError('down'),
      );
      expect(result, 99);
    });

    test('failure with no cache propagates error', () async {
      final reader = _buildReader();
      await expectLater(
        reader.read<int>(
          key: 'k',
          resourceType: 'r',
          policy: networkFirst,
          remoteLoader: () async => throw StateError('down'),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('SWR fresh hit promotes LRU', () {
    test('SWR fresh hits keep the entry from being evicted as cold', () async {
      // Cache size 2: insert a, b; SWR-read a; insert c. Without LRU
      // promotion on read, 'a' would be the oldest and evicted. With
      // promotion, 'b' is the LRU and gets evicted.
      final cache = MemoryLocalReadCache(maxEntries: 2);
      final reader = _buildReader(cache: cache);

      await cache.put<String>('a', 'va', swr);
      await cache.put<String>('b', 'vb', swr);

      // SWR fresh hit on 'a' — must touch LRU.
      final got = await reader.read<String>(
        key: 'a',
        resourceType: 'r',
        policy: swr,
        remoteLoader: () async => fail('should not call remote on fresh hit'),
      );
      expect(got, 'va');

      // Adding 'c' should evict 'b' (now the LRU), not 'a'.
      await cache.put<String>('c', 'vc', swr);
      expect(await cache.peek<String>('a'), isNotNull);
      expect(await cache.peek<String>('b'), isNull);
      expect(await cache.peek<String>('c'), isNotNull);
    });
  });

  group('cachePredicate', () {
    test('values failing the predicate are returned but not cached', () async {
      final cache = MemoryLocalReadCache();
      final reader = _buildReader(cache: cache);
      var calls = 0;
      Future<String> loader() async {
        calls++;
        return 'fallback';
      }

      // First call — predicate rejects, so nothing lands in cache.
      final v1 = await reader.read<String>(
        key: 'k',
        resourceType: 'r',
        policy: cacheFirst,
        remoteLoader: loader,
        cachePredicate: (v) => v != 'fallback',
      );
      expect(v1, 'fallback');
      expect(await cache.peek<String>('k'), isNull);

      // Second call — still hits the loader (no cache).
      final v2 = await reader.read<String>(
        key: 'k',
        resourceType: 'r',
        policy: cacheFirst,
        remoteLoader: loader,
        cachePredicate: (v) => v != 'fallback',
      );
      expect(v2, 'fallback');
      expect(calls, 2);
    });
  });

  group('dedupe flag', () {
    test('dedupe: false skips the deduplicator entirely', () async {
      final reader = _buildReader();
      var calls = 0;
      final c1 = Completer<int>();
      final c2 = Completer<int>();
      final loaders = <Completer<int>>[c1, c2];

      Future<int> Function() loader() {
        return () {
          final c = loaders[calls];
          calls++;
          return c.future;
        };
      }

      // Two concurrent reads with dedupe: false → two loader invocations.
      final fa = reader.read<int>(
        key: 'k',
        resourceType: 'r',
        policy: const CachePolicy(strategy: CacheRefreshStrategy.networkOnly),
        remoteLoader: loader(),
        dedupe: false,
      );
      final fb = reader.read<int>(
        key: 'k',
        resourceType: 'r',
        policy: const CachePolicy(strategy: CacheRefreshStrategy.networkOnly),
        remoteLoader: loader(),
        dedupe: false,
      );
      expect(calls, 2);

      c1.complete(1);
      c2.complete(2);
      expect(await fa, 1);
      expect(await fb, 2);
    });
  });

  group('networkOnly', () {
    test('does not read from cache and does not write to cache', () async {
      final cache = MemoryLocalReadCache();
      // Seed something.
      await cache.put<String>('k', 'cached', cacheFirst);
      final reader = _buildReader(cache: cache);
      var calls = 0;
      final result = await reader.read<String>(
        key: 'k',
        resourceType: 'r',
        policy: networkOnly,
        remoteLoader: () async {
          calls++;
          return 'fresh';
        },
      );
      expect(result, 'fresh');
      expect(calls, 1);
      // Original cached value untouched.
      expect((await cache.peek<String>('k'))!.data, 'cached');
    });
  });
}
