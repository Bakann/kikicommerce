import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_invalidations.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/catalog_invalidator_provider.dart';
import 'package:kiki_commerce/presentation/providers/cms_mixed_grid_products_provider.dart';

class _CountingRepo implements CategoryCatalogRepository {
  int productCalls = 0;

  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async {
    productCalls++;
    return CatalogPageData(
      page: page,
      perPage: perPage,
      totalItems: 0,
      totalPages: 0,
      categoryId: categoryId,
      categoryName: categoryId,
      items: const [],
    );
  }

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async => const [];

  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async => null;

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async =>
      null;

  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String locale,
    required String categorySlug,
    required String productSlug,
  }) async => null;
}

void main() {
  group('CatalogInvalidator + cmsMixedGridProductsProvider', () {
    test('CategoryPlpInvalidation refetches the CMS mixed grid', () async {
      final repo = _CountingRepo();
      final container = ProviderContainer(
        overrides: [categoryCatalogRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      const request = (categoryId: 'cat-1', limit: 12);
      await container.read(cmsMixedGridProductsProvider(request).future);
      expect(repo.productCalls, 1);

      const invalidator = CatalogInvalidator();
      invalidator.applyToContainer(container, const [
        CategoryPlpInvalidation('cat-1'),
      ]);

      await container.read(cmsMixedGridProductsProvider(request).future);
      expect(
        repo.productCalls,
        2,
        reason: 'CMS grid must refetch after CategoryPlpInvalidation',
      );
    });

    test('AllProductListsInvalidation refetches the CMS mixed grid', () async {
      final repo = _CountingRepo();
      final container = ProviderContainer(
        overrides: [categoryCatalogRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      const request = (categoryId: 'cat-1', limit: 12);
      await container.read(cmsMixedGridProductsProvider(request).future);
      expect(repo.productCalls, 1);

      const invalidator = CatalogInvalidator();
      invalidator.applyToContainer(container, const [
        AllProductListsInvalidation(),
      ]);

      await container.read(cmsMixedGridProductsProvider(request).future);
      expect(repo.productCalls, 2);
    });
  });
}
