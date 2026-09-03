import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/cache/cache_metrics_logger.dart';
import 'package:kiki_commerce/core/cache/cache_policy.dart';
import 'package:kiki_commerce/core/cache/cache_refresh_strategy.dart';
import 'package:kiki_commerce/core/cache/memory_local_read_cache.dart';

class _RecordingMetrics implements CacheMetricsLogger {
  final List<String> evictions = [];

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
  void dedupeStart(String resourceType, String key) {}
  @override
  void dedupeJoin(String resourceType, String key) {}
  @override
  void dedupeComplete(String resourceType, String key, Duration latency) {}
  @override
  void dedupeError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) {}
  @override
  void eviction(String resourceType, String key) {
    evictions.add(key);
  }
}

class _MutableClock {
  _MutableClock(this.value);
  DateTime value;
  DateTime call() => value;
}

void main() {
  const swr5min = CachePolicy(
    ttl: Duration(minutes: 5),
    strategy: CacheRefreshStrategy.staleWhileRevalidate,
  );
  const cacheFirstNoTtl = CachePolicy(
    strategy: CacheRefreshStrategy.cacheFirst,
  );
  const networkOnly = CachePolicy(strategy: CacheRefreshStrategy.networkOnly);

  group('MemoryLocalReadCache - basic get/put', () {
    test('put then get returns the cached entry', () async {
      final cache = MemoryLocalReadCache();
      await cache.put<String>('k', 'value', cacheFirstNoTtl);
      final entry = await cache.get<String>('k');
      expect(entry, isNotNull);
      expect(entry!.data, 'value');
    });

    test('get returns null when key is absent', () async {
      final cache = MemoryLocalReadCache();
      expect(await cache.get<String>('missing'), isNull);
    });

    test('put with networkOnly policy does not write', () async {
      final cache = MemoryLocalReadCache();
      await cache.put<String>('k', 'v', networkOnly);
      expect(await cache.get<String>('k'), isNull);
    });
  });

  group('MemoryLocalReadCache - expiration', () {
    test('expired entry is dropped at get and returns null', () async {
      final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
      final cache = MemoryLocalReadCache(now: clock.call);
      await cache.put<String>('k', 'v', swr5min);
      expect(cache.debugLength, 1);

      clock.value = clock.value.add(const Duration(minutes: 6));
      expect(await cache.get<String>('k'), isNull);
      // Entry was lazily removed.
      expect(cache.debugLength, 0);
    });

    test('peek returns expired entry without removing it', () async {
      final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
      final cache = MemoryLocalReadCache(now: clock.call);
      await cache.put<String>('k', 'v', swr5min);

      clock.value = clock.value.add(const Duration(minutes: 6));
      final peeked = await cache.peek<String>('k');
      expect(peeked, isNotNull);
      expect(peeked!.data, 'v');
      expect(cache.debugLength, 1);
    });

    test('put cleans up expired entries before LRU eviction', () async {
      final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
      final cache = MemoryLocalReadCache(maxEntries: 2, now: clock.call);
      await cache.put<String>('a', '1', swr5min);
      await cache.put<String>('b', '2', swr5min);

      // Both expire.
      clock.value = clock.value.add(const Duration(minutes: 10));

      // Putting 'c' should clean a and b first, leaving room without LRU
      // eviction of a non-expired entry.
      await cache.put<String>('c', '3', swr5min);
      expect(cache.debugLength, 1);
      expect((await cache.peek<String>('c'))!.data, '3');
      expect(await cache.peek<String>('a'), isNull);
      expect(await cache.peek<String>('b'), isNull);
    });
  });

  group('MemoryLocalReadCache - LRU semantics', () {
    test(
      'eviction targets the least-recently-used entry, not insertion FIFO',
      () async {
        final metrics = _RecordingMetrics();
        final cache = MemoryLocalReadCache(
          maxEntries: 3,
          metricsLogger: metrics,
        );
        await cache.put<int>('a', 1, cacheFirstNoTtl);
        await cache.put<int>('b', 2, cacheFirstNoTtl);
        await cache.put<int>('c', 3, cacheFirstNoTtl);

        // Touch 'a' so it becomes most-recent.
        await cache.get<int>('a');

        // Adding 'd' must evict 'b' (the new LRU), not 'a'.
        await cache.put<int>('d', 4, cacheFirstNoTtl);
        expect(metrics.evictions, ['b']);
        expect(await cache.peek<int>('a'), isNotNull);
        expect(await cache.peek<int>('b'), isNull);
        expect(await cache.peek<int>('c'), isNotNull);
        expect(await cache.peek<int>('d'), isNotNull);
      },
    );

    test('respects maxEntries when adding many entries', () async {
      final cache = MemoryLocalReadCache(maxEntries: 5);
      for (var i = 0; i < 20; i++) {
        await cache.put<int>('k$i', i, cacheFirstNoTtl);
      }
      expect(cache.debugLength, 5);
    });

    test('asserts maxEntries > 0', () {
      expect(
        () => MemoryLocalReadCache(maxEntries: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('MemoryLocalReadCache - invalidation', () {
    test('invalidate removes only the targeted key', () async {
      final cache = MemoryLocalReadCache();
      await cache.put<int>('a', 1, cacheFirstNoTtl);
      await cache.put<int>('b', 2, cacheFirstNoTtl);
      await cache.invalidate('a');
      expect(await cache.peek<int>('a'), isNull);
      expect(await cache.peek<int>('b'), isNotNull);
    });

    test('invalidateByPrefix removes only matching keys', () async {
      final cache = MemoryLocalReadCache();
      await cache.put<int>('plp:fr|cat=a', 1, cacheFirstNoTtl);
      await cache.put<int>('plp:fr|cat=b', 2, cacheFirstNoTtl);
      await cache.put<int>('product:1', 3, cacheFirstNoTtl);
      await cache.invalidateByPrefix('plp:');
      expect(await cache.peek<int>('plp:fr|cat=a'), isNull);
      expect(await cache.peek<int>('plp:fr|cat=b'), isNull);
      expect(await cache.peek<int>('product:1'), isNotNull);
    });

    test('clear empties everything', () async {
      final cache = MemoryLocalReadCache();
      await cache.put<int>('a', 1, cacheFirstNoTtl);
      await cache.put<int>('b', 2, cacheFirstNoTtl);
      await cache.clear();
      expect(cache.debugLength, 0);
    });

    test('invalidate bumps the key generation', () async {
      final cache = MemoryLocalReadCache();
      expect(cache.generation('a'), 0);
      await cache.invalidate('a');
      expect(cache.generation('a'), 1);
      await cache.invalidate('a');
      expect(cache.generation('a'), 2);
    });

    test('put with a stale expectedGeneration is discarded', () async {
      final cache = MemoryLocalReadCache();
      final captured = cache.generation('a');
      await cache.invalidate('a');
      await cache.put<int>(
        'a',
        1,
        cacheFirstNoTtl,
        expectedGeneration: captured,
      );
      expect(await cache.peek<int>('a'), isNull);
    });

    test('put with the current expectedGeneration succeeds', () async {
      final cache = MemoryLocalReadCache();
      await cache.invalidate('a');
      await cache.put<int>(
        'a',
        1,
        cacheFirstNoTtl,
        expectedGeneration: cache.generation('a'),
      );
      expect((await cache.peek<int>('a'))!.data, 1);
    });

    test('invalidateByPrefix bumps generation for absent matching keys', () {
      final cache = MemoryLocalReadCache();
      final captured = cache.generation('product:1');
      expect(captured, 0);
      cache.invalidateByPrefix('product:');
      // The key was never stored, yet its generation moved because the prefix
      // it shares was invalidated.
      expect(cache.generation('product:1'), greaterThan(captured));
      expect(cache.generation('plp:1'), 0);
    });

    test('clear bumps generation for every key', () {
      final cache = MemoryLocalReadCache();
      final captured = cache.generation('anything');
      cache.clear();
      expect(cache.generation('anything'), greaterThan(captured));
    });
  });

  group('MemoryLocalReadCache - touch promotes LRU position', () {
    test('touch on a present key makes it most-recently-used', () async {
      final metrics = _RecordingMetrics();
      final cache = MemoryLocalReadCache(maxEntries: 3, metricsLogger: metrics);
      await cache.put<int>('a', 1, cacheFirstNoTtl);
      await cache.put<int>('b', 2, cacheFirstNoTtl);
      await cache.put<int>('c', 3, cacheFirstNoTtl);

      // Touch 'a' so it becomes most-recent (without changing its data).
      await cache.touch('a');

      // Adding 'd' must evict 'b' (the new LRU), not 'a'.
      await cache.put<int>('d', 4, cacheFirstNoTtl);
      expect(metrics.evictions, ['b']);
      expect(await cache.peek<int>('a'), isNotNull);
      expect(await cache.peek<int>('d'), isNotNull);
    });

    test('touch on an absent key is a no-op', () async {
      final cache = MemoryLocalReadCache();
      await cache.touch('missing');
      expect(cache.debugLength, 0);
    });

    test('touch does not change the entry value or expiry', () async {
      final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
      final cache = MemoryLocalReadCache(now: clock.call);
      await cache.put<String>('k', 'v', swr5min);
      final before = await cache.peek<String>('k');

      clock.value = clock.value.add(const Duration(minutes: 1));
      await cache.touch('k');
      final after = await cache.peek<String>('k');

      expect(after!.data, before!.data);
      expect(after.cachedAt, before.cachedAt);
      expect(after.expiresAt, before.expiresAt);
    });
  });

  group(
    'MemoryLocalReadCache - put computes timestamps via injected clock',
    () {
      test(
        'cachedAt = now() and expiresAt = policy.expiresAt(now())',
        () async {
          final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
          final cache = MemoryLocalReadCache(now: clock.call);
          await cache.put<String>('k', 'v', swr5min);
          final entry = await cache.peek<String>('k');
          expect(entry!.cachedAt, clock.value);
          expect(entry.expiresAt, clock.value.add(const Duration(minutes: 5)));
        },
      );
    },
  );
}
