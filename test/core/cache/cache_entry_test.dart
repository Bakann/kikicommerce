import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/cache/cache_entry.dart';
import 'package:kiki_commerce/core/cache/cache_policy.dart';
import 'package:kiki_commerce/core/cache/cache_refresh_strategy.dart';

void main() {
  group('CacheEntry.isExpired', () {
    final cachedAt = DateTime.utc(2026, 5, 1, 10);

    test('returns false when expiresAt is null', () {
      final entry = CacheEntry<String>(data: 'x', cachedAt: cachedAt);
      expect(entry.isExpired(cachedAt.add(const Duration(days: 365))), isFalse);
    });

    test('returns false when now is before expiresAt', () {
      final entry = CacheEntry<String>(
        data: 'x',
        cachedAt: cachedAt,
        expiresAt: cachedAt.add(const Duration(minutes: 5)),
      );
      expect(
        entry.isExpired(cachedAt.add(const Duration(minutes: 1))),
        isFalse,
      );
    });

    test('returns false when now equals expiresAt (boundary is inclusive)', () {
      final expiresAt = cachedAt.add(const Duration(minutes: 5));
      final entry = CacheEntry<String>(
        data: 'x',
        cachedAt: cachedAt,
        expiresAt: expiresAt,
      );
      expect(entry.isExpired(expiresAt), isFalse);
    });

    test('returns true when now is strictly after expiresAt', () {
      final expiresAt = cachedAt.add(const Duration(minutes: 5));
      final entry = CacheEntry<String>(
        data: 'x',
        cachedAt: cachedAt,
        expiresAt: expiresAt,
      );
      expect(
        entry.isExpired(expiresAt.add(const Duration(microseconds: 1))),
        isTrue,
      );
    });
  });

  group('CachePolicy', () {
    test('expiresAt returns null when ttl is null', () {
      const policy = CachePolicy(strategy: CacheRefreshStrategy.cacheFirst);
      expect(policy.expiresAt(DateTime.utc(2026, 1, 1)), isNull);
    });

    test('expiresAt adds ttl to now when ttl is set', () {
      const policy = CachePolicy(
        ttl: Duration(minutes: 10),
        strategy: CacheRefreshStrategy.staleWhileRevalidate,
      );
      final now = DateTime.utc(2026, 5, 1, 10);
      expect(policy.expiresAt(now), now.add(const Duration(minutes: 10)));
    });

    test('networkOnly disallows reads and writes', () {
      const policy = CachePolicy(strategy: CacheRefreshStrategy.networkOnly);
      expect(policy.allowsRead, isFalse);
      expect(policy.allowsWrite, isFalse);
    });

    test('non-networkOnly strategies allow reads and writes', () {
      const cacheFirst = CachePolicy(strategy: CacheRefreshStrategy.cacheFirst);
      const swr = CachePolicy(
        strategy: CacheRefreshStrategy.staleWhileRevalidate,
      );
      const networkFirst = CachePolicy(
        strategy: CacheRefreshStrategy.networkFirst,
      );

      for (final p in [cacheFirst, swr, networkFirst]) {
        expect(p.allowsRead, isTrue);
        expect(p.allowsWrite, isTrue);
      }
    });
  });
}
