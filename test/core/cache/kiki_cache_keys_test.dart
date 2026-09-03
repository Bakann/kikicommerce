import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/cache/cache_refresh_strategy.dart';
import 'package:kiki_commerce/core/cache/kiki_cache_keys.dart';
import 'package:kiki_commerce/core/cache/kiki_cache_policies.dart';

void main() {
  group('KikiCacheKeys.plp - canonicalisation', () {
    test('different filter map orders produce the same key', () {
      final a = KikiCacheKeys.plp(
        locale: 'fr',
        currency: 'EUR',
        categorySlug: 'shoes',
        filters: {
          'color': ['red', 'blue'],
          'size': 'M',
        },
      );
      final b = KikiCacheKeys.plp(
        locale: 'fr',
        currency: 'EUR',
        categorySlug: 'shoes',
        filters: {
          'size': 'M',
          'color': ['red', 'blue'],
        },
      );
      expect(a, b);
    });

    test('different list value orders produce the same key', () {
      final a = KikiCacheKeys.plp(
        locale: 'fr',
        currency: 'EUR',
        categorySlug: 'shoes',
        filters: {
          'color': ['red', 'blue'],
        },
      );
      final b = KikiCacheKeys.plp(
        locale: 'fr',
        currency: 'EUR',
        categorySlug: 'shoes',
        filters: {
          'color': ['blue', 'red'],
        },
      );
      expect(a, b);
    });

    test('null and empty values are dropped', () {
      final withEmpties = KikiCacheKeys.plp(
        locale: 'fr',
        currency: 'EUR',
        categorySlug: 'shoes',
        filters: {
          'color': null,
          'size': '',
          'tags': <String>[],
          'brand': 'nike',
        },
      );
      final pruned = KikiCacheKeys.plp(
        locale: 'fr',
        currency: 'EUR',
        categorySlug: 'shoes',
        filters: {'brand': 'nike'},
      );
      expect(withEmpties, pruned);
    });

    test('locale and currency are part of the key', () {
      final fr = KikiCacheKeys.plp(
        locale: 'fr',
        currency: 'EUR',
        categorySlug: 'shoes',
      );
      final en = KikiCacheKeys.plp(
        locale: 'en',
        currency: 'EUR',
        categorySlug: 'shoes',
      );
      final usd = KikiCacheKeys.plp(
        locale: 'fr',
        currency: 'USD',
        categorySlug: 'shoes',
      );
      expect(fr, isNot(en));
      expect(fr, isNot(usd));
    });

    test(
      'customerSegment is omitted by default and included when supplied',
      () {
        final without = KikiCacheKeys.plp(
          locale: 'fr',
          currency: 'EUR',
          categorySlug: 'shoes',
        );
        final withSegment = KikiCacheKeys.plp(
          locale: 'fr',
          currency: 'EUR',
          categorySlug: 'shoes',
          customerSegment: 'vip',
        );
        expect(without, isNot(withSegment));
        expect(without.contains('segment='), isFalse);
        expect(withSegment.contains('segment=vip'), isTrue);
      },
    );

    test('empty customerSegment is treated as absent', () {
      final none = KikiCacheKeys.plp(
        locale: 'fr',
        currency: 'EUR',
        categorySlug: 'shoes',
      );
      final empty = KikiCacheKeys.plp(
        locale: 'fr',
        currency: 'EUR',
        categorySlug: 'shoes',
        customerSegment: '',
      );
      expect(none, empty);
    });

    test('keys are prefixed by resource type', () {
      expect(
        KikiCacheKeys.plp(locale: 'fr', currency: 'EUR', categorySlug: 'shoes'),
        startsWith('plp:'),
      );
      expect(
        KikiCacheKeys.product(locale: 'fr', currency: 'EUR', productId: '1'),
        startsWith('product:'),
      );
      expect(
        KikiCacheKeys.drawer(locale: 'fr', currency: 'EUR', menuCode: 'main'),
        startsWith('drawer:'),
      );
    });
  });

  group('KikiCachePolicies', () {
    test('drawer = SWR 10 minutes', () {
      expect(KikiCachePolicies.drawer.ttl, const Duration(minutes: 10));
      expect(
        KikiCachePolicies.drawer.strategy,
        CacheRefreshStrategy.staleWhileRevalidate,
      );
    });

    test('homepage = SWR 5 minutes', () {
      expect(KikiCachePolicies.homepage.ttl, const Duration(minutes: 5));
      expect(
        KikiCachePolicies.homepage.strategy,
        CacheRefreshStrategy.staleWhileRevalidate,
      );
    });

    test('plp = SWR 3 minutes', () {
      expect(KikiCachePolicies.plp.ttl, const Duration(minutes: 3));
      expect(
        KikiCachePolicies.plp.strategy,
        CacheRefreshStrategy.staleWhileRevalidate,
      );
    });

    test('product = SWR 2 minutes', () {
      expect(KikiCachePolicies.product.ttl, const Duration(minutes: 2));
      expect(
        KikiCachePolicies.product.strategy,
        CacheRefreshStrategy.staleWhileRevalidate,
      );
    });

    test('categories = SWR 15 minutes', () {
      expect(KikiCachePolicies.categories.ttl, const Duration(minutes: 15));
      expect(
        KikiCachePolicies.categories.strategy,
        CacheRefreshStrategy.staleWhileRevalidate,
      );
    });

    test('mediaMetadata = cacheFirst 7 days', () {
      expect(KikiCachePolicies.mediaMetadata.ttl, const Duration(days: 7));
      expect(
        KikiCachePolicies.mediaMetadata.strategy,
        CacheRefreshStrategy.cacheFirst,
      );
    });

    test('transactional = networkOnly with no TTL', () {
      expect(KikiCachePolicies.transactional.ttl, isNull);
      expect(
        KikiCachePolicies.transactional.strategy,
        CacheRefreshStrategy.networkOnly,
      );
      expect(KikiCachePolicies.transactional.allowsRead, isFalse);
      expect(KikiCachePolicies.transactional.allowsWrite, isFalse);
    });
  });
}
