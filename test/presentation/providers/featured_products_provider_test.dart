import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/cms/featured_products_repository.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/featured_products_provider.dart';

class _CountingFeaturedRepo implements FeaturedProductsRepository {
  int callCount = 0;
  final List<List<String>> calls = [];

  @override
  Future<List<FeaturedProductData>> getFeaturedProducts(
    List<String> productIds, {
    required String locale,
  }) async {
    callCount++;
    calls.add(List.unmodifiable(productIds));
    return [
      for (final id in productIds)
        FeaturedProductData(
          product: CatalogProduct(id: id, code: id, name: id),
          prices: const [],
          imageUrl: null,
        ),
    ];
  }
}

void main() {
  group('featuredProductsProvider', () {
    test('empty productIds short-circuits without calling the repo', () async {
      final repo = _CountingFeaturedRepo();
      final container = ProviderContainer(
        overrides: [featuredProductsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        featuredProductsProvider(const []).future,
      );
      expect(result, isEmpty);
      expect(repo.callCount, 0);
    });

    test('preserves caller-supplied order in the result', () async {
      final repo = _CountingFeaturedRepo();
      final container = ProviderContainer(
        overrides: [featuredProductsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        featuredProductsProvider(const ['c', 'a', 'b']).future,
      );
      expect(result.map((p) => p.product.id).toList(), ['c', 'a', 'b']);
      expect(repo.calls.single, ['c', 'a', 'b']);
    });

    test(
      'different orders produce distinct cache slots and preserve caller order',
      () async {
        final repo = _CountingFeaturedRepo();
        final container = ProviderContainer(
          overrides: [
            featuredProductsRepositoryProvider.overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);

        final ascending = await container.read(
          featuredProductsProvider(const ['a', 'b', 'c']).future,
        );
        final descending = await container.read(
          featuredProductsProvider(const ['c', 'b', 'a']).future,
        );

        // The result list is ordered, so two different orderings cannot
        // share a cache slot — each call hits the repo with its own order.
        expect(repo.callCount, 2);
        expect(ascending.map((p) => p.product.id).toList(), ['a', 'b', 'c']);
        expect(descending.map((p) => p.product.id).toList(), ['c', 'b', 'a']);
      },
    );
  });
}
