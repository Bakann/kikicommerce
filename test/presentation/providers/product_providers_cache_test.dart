import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_invalidations.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/catalog/product_catalog_repository.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/catalog_invalidator_provider.dart';
import 'package:kiki_commerce/presentation/providers/product_providers.dart';

class _CountingCategoryRepo implements CategoryCatalogRepository {
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

class _CountingProductRepo implements ProductCatalogRepository {
  int detailCalls = 0;

  @override
  Future<ProductDetailData> getProductDetail(
    String productId, {
    required String locale,
  }) async {
    detailCalls++;
    return ProductDetailData(
      product: CatalogProduct(id: productId, code: productId, name: productId),
      prices: const [],
    );
  }
}

void main() {
  group('plpProvider caching', () {
    test('second read after Riverpod invalidate hits the cache', () async {
      final repo = _CountingCategoryRepo();
      final container = ProviderContainer(
        overrides: [categoryCatalogRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(plpProvider('cat-1').future);
      expect(repo.productCalls, 1);

      // Riverpod-only invalidate: cache layer still serves the value.
      container.invalidate(plpProvider('cat-1'));
      await container.read(plpProvider('cat-1').future);
      expect(repo.productCalls, 1);
    });

    test('CategoryPlpInvalidation forces a fresh fetch', () async {
      final repo = _CountingCategoryRepo();
      final container = ProviderContainer(
        overrides: [categoryCatalogRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(plpProvider('cat-1').future);
      expect(repo.productCalls, 1);

      const invalidator = CatalogInvalidator();
      invalidator.applyToContainer(container, const [
        CategoryPlpInvalidation('cat-1'),
      ]);
      await container.read(plpProvider('cat-1').future);
      expect(repo.productCalls, 2);
    });

    test('AllProductListsInvalidation clears every category', () async {
      final repo = _CountingCategoryRepo();
      final container = ProviderContainer(
        overrides: [categoryCatalogRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(plpProvider('cat-1').future);
      await container.read(plpProvider('cat-2').future);
      expect(repo.productCalls, 2);

      const invalidator = CatalogInvalidator();
      invalidator.applyToContainer(container, const [
        AllProductListsInvalidation(),
      ]);
      await container.read(plpProvider('cat-1').future);
      await container.read(plpProvider('cat-2').future);
      expect(repo.productCalls, 4);
    });
  });

  group('pdpProvider caching', () {
    test('second read after Riverpod invalidate hits the cache', () async {
      final repo = _CountingProductRepo();
      final container = ProviderContainer(
        overrides: [productCatalogRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(pdpProvider('prod-1').future);
      expect(repo.detailCalls, 1);

      container.invalidate(pdpProvider('prod-1'));
      await container.read(pdpProvider('prod-1').future);
      expect(repo.detailCalls, 1);
    });

    test('ProductDetailInvalidation forces a fresh fetch', () async {
      final repo = _CountingProductRepo();
      final container = ProviderContainer(
        overrides: [productCatalogRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(pdpProvider('prod-1').future);
      expect(repo.detailCalls, 1);

      const invalidator = CatalogInvalidator();
      invalidator.applyToContainer(container, const [
        ProductDetailInvalidation('prod-1'),
      ]);
      await container.read(pdpProvider('prod-1').future);
      expect(repo.detailCalls, 2);
    });
  });
}
