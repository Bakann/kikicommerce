import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/cache_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_invalidations.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/core/cache/cache_entry.dart';
import 'package:kiki_commerce/core/cache/cache_policy.dart';
import 'package:kiki_commerce/core/cache/kiki_cache_keys.dart';
import 'package:kiki_commerce/core/cache/local_read_cache.dart';
import 'package:kiki_commerce/core/cache/request_deduplicator.dart';
import 'package:kiki_commerce/presentation/providers/catalog_invalidator_provider.dart';
import 'package:kiki_commerce/presentation/providers/locale_provider.dart';
import 'package:kiki_commerce/presentation/providers/navigation_providers.dart';

// A catalog mutation clears the exact key for every supported content locale
// (the cache key embeds locale). The currency axis is still a placeholder.
const _currency = 'global';
final _localeCodes = [
  for (final locale in kSupportedLocales) locale.languageCode,
];

// Probe that hands back the [Ref] of a live provider so the apply(Ref, ...)
// entry point can be exercised against the same container/overrides.
final _refProbeProvider = Provider<Ref>((ref) => ref);

void main() {
  // Local (not top-level) so the return type can be inferred without
  // referencing the non-exported `Override` symbol; the list shape is what
  // ProviderScope/ProviderContainer expect.
  overrides(_RecordingCache cache, _RecordingDeduplicator dedup) => [
    localReadCacheProvider.overrideWithValue(cache),
    requestDeduplicatorProvider.overrideWithValue(dedup),
    // Keep the drawer refresh offline so the contract test never hits a
    // repository; only the cache/dedup sweep is under test here.
    mainDrawerNavigationProvider.overrideWith(
      (ref) async => const DrawerNavigationLoadResult.fallback(
        fallbackReason: DrawerNavigationFallbackReason.menuMissing,
      ),
    ),
  ];

  group('CatalogInvalidator cache/dedup coupling', () {
    late _RecordingCache cache;
    late _RecordingDeduplicator dedup;
    late ProviderContainer container;

    setUp(() {
      cache = _RecordingCache();
      dedup = _RecordingDeduplicator();
      container = ProviderContainer(overrides: overrides(cache, dedup));
    });

    tearDown(() => container.dispose());

    void apply(CatalogInvalidationTarget target) {
      container.read(catalogInvalidatorProvider).applyToContainer(container, [
        target,
      ]);
    }

    test('ProductDetailInvalidation drops the product key per locale', () {
      apply(const ProductDetailInvalidation('p1'));
      final keys = [
        for (final locale in _localeCodes)
          KikiCacheKeys.product(
            locale: locale,
            currency: _currency,
            productId: 'p1',
          ),
        KikiCacheKeys.productFoil(productId: 'p1'),
      ];
      expect(cache.invalidatedKeys, keys);
      expect(dedup.invalidatedKeys, keys);
      expect(cache.invalidatedPrefixes, isEmpty);
    });

    test('CategoryPlpInvalidation drops the plp key per locale', () {
      apply(const CategoryPlpInvalidation('cat-1'));
      final keys = [
        for (final locale in _localeCodes)
          KikiCacheKeys.plp(
            locale: locale,
            currency: _currency,
            categorySlug: 'cat-1',
          ),
      ];
      expect(cache.invalidatedKeys, keys);
      expect(dedup.invalidatedKeys, keys);
    });

    test('CategoryBySlugInvalidation drops the slug key per locale', () {
      apply(const CategoryBySlugInvalidation('roses'));
      final keys = [
        for (final locale in _localeCodes)
          KikiCacheKeys.categoryBySlug(
            locale: locale,
            currency: _currency,
            slug: 'roses',
          ),
      ];
      expect(cache.invalidatedKeys, keys);
      expect(dedup.invalidatedKeys, keys);
    });

    test('CategoryTreeInvalidation sweeps all category prefixes in both', () {
      apply(const CategoryTreeInvalidation());
      const expected = [
        'categories:',
        'drawerCategories:',
        'defaultCategory:',
        'categoryBySlug:',
      ];
      expect(cache.invalidatedPrefixes, expected);
      expect(dedup.invalidatedPrefixes, expected);
    });

    test(
      'AllProductListsInvalidation sweeps plp + featured prefixes in both',
      () {
        apply(const AllProductListsInvalidation());
        expect(cache.invalidatedPrefixes, ['plp:', 'featuredProducts:']);
        expect(dedup.invalidatedPrefixes, ['plp:', 'featuredProducts:']);
      },
    );

    test('AllProductDetailsInvalidation sweeps product + featured in both', () {
      apply(const AllProductDetailsInvalidation());
      expect(cache.invalidatedPrefixes, [
        'product:',
        'productFoil:',
        'featuredProducts:',
      ]);
      expect(dedup.invalidatedPrefixes, [
        'product:',
        'productFoil:',
        'featuredProducts:',
      ]);
    });

    test('DrawerNavigationInvalidation sweeps the drawer prefix in both', () {
      apply(const DrawerNavigationInvalidation());
      expect(cache.invalidatedPrefixes, ['drawer:']);
      expect(dedup.invalidatedPrefixes, ['drawer:']);
    });

    test('CmsPagesInvalidation sweeps the cms prefix in both', () {
      apply(const CmsPagesInvalidation());
      expect(cache.invalidatedPrefixes, ['cms:']);
      expect(dedup.invalidatedPrefixes, ['cms:']);
    });

    test('provider-only targets touch neither cache nor dedup', () {
      apply(const AllProductRoutesInvalidation());
      apply(const AllSearchResultsInvalidation());
      apply(const MediaLibraryInvalidation());
      expect(cache.invalidatedKeys, isEmpty);
      expect(cache.invalidatedPrefixes, isEmpty);
      expect(dedup.invalidatedKeys, isEmpty);
      expect(dedup.invalidatedPrefixes, isEmpty);
    });

    // The Ref and WidgetRef entry points duplicate the container switch, so a
    // representative target confirms they reach the same cache/dedup sweep.
    test('apply(Ref, ...) drops the same product keys in both', () {
      final ref = container.read(_refProbeProvider);
      container.read(catalogInvalidatorProvider).apply(ref, const [
        ProductDetailInvalidation('p1'),
      ]);
      final keys = [
        for (final locale in _localeCodes)
          KikiCacheKeys.product(
            locale: locale,
            currency: _currency,
            productId: 'p1',
          ),
        KikiCacheKeys.productFoil(productId: 'p1'),
      ];
      expect(cache.invalidatedKeys, keys);
      expect(dedup.invalidatedKeys, keys);
    });
  });

  testWidgets('applyFromWidget(WidgetRef, ...) drops the same product key', (
    tester,
  ) async {
    final cache = _RecordingCache();
    final dedup = _RecordingDeduplicator();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(cache, dedup),
        child: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );

    capturedRef.read(catalogInvalidatorProvider).applyFromWidget(
      capturedRef,
      const [ProductDetailInvalidation('p1')],
    );

    final keys = [
      for (final locale in _localeCodes)
        KikiCacheKeys.product(
          locale: locale,
          currency: _currency,
          productId: 'p1',
        ),
      KikiCacheKeys.productFoil(productId: 'p1'),
    ];
    expect(cache.invalidatedKeys, keys);
    expect(dedup.invalidatedKeys, keys);
  });
}

class _RecordingCache implements LocalReadCache {
  final invalidatedKeys = <String>[];
  final invalidatedPrefixes = <String>[];

  @override
  Future<void> invalidate(String key) async => invalidatedKeys.add(key);

  @override
  Future<void> invalidateByPrefix(String prefix) async =>
      invalidatedPrefixes.add(prefix);

  @override
  Future<CacheEntry<T>?> get<T>(String key) async => null;

  @override
  Future<CacheEntry<T>?> peek<T>(String key) async => null;

  @override
  Future<void> touch(String key) async {}

  @override
  int generation(String key) => 0;

  @override
  Future<void> put<T>(
    String key,
    T value,
    CachePolicy policy, {
    int? expectedGeneration,
  }) async {}

  @override
  Future<void> clear() async {}
}

class _RecordingDeduplicator extends RequestDeduplicator {
  final invalidatedKeys = <String>[];
  final invalidatedPrefixes = <String>[];

  @override
  void invalidate(String key) => invalidatedKeys.add(key);

  @override
  void invalidateByPrefix(String prefix) => invalidatedPrefixes.add(prefix);
}
