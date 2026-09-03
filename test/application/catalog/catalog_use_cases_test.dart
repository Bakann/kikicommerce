import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/catalog/get_active_categories.dart';
import 'package:kiki_commerce/application/catalog/get_category_products.dart';
import 'package:kiki_commerce/application/catalog/get_category_by_slug.dart';
import 'package:kiki_commerce/application/catalog/get_default_category.dart';
import 'package:kiki_commerce/application/catalog/get_product_detail.dart';
import 'package:kiki_commerce/application/catalog/product_catalog_repository.dart';
import 'package:kiki_commerce/application/catalog/resolve_product_route.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

void main() {
  group('Catalog use cases', () {
    test('GetDefaultCategory delegates to repository', () async {
      const expected = CatalogCategory(
        id: 'cat-1',
        code: 'CAT-1',
        name: 'Robes',
      );
      final repository = _FakeCategoryCatalogRepository(
        defaultCategory: expected,
      );

      final result = await GetDefaultCategory(repository)(locale: 'fr');

      expect(result, expected);
      expect(repository.getDefaultCategoryCalls, 1);
    });

    test('GetCategoryProducts forwards pagination arguments', () async {
      const category = CatalogCategory(
        id: 'cat-1',
        code: 'CAT-1',
        name: 'Robes',
      );
      const product = CatalogProduct(
        id: 'prod-1',
        code: 'PROD-1',
        name: 'Robe',
      );
      const pageData = CatalogPageData(
        page: 2,
        perPage: 24,
        totalItems: 1,
        totalPages: 1,
        categoryId: 'cat-1',
        categoryName: 'Robes',
        items: [
          CatalogListingItem(
            id: 'cp-1',
            categoryId: 'cat-1',
            productId: 'prod-1',
            category: category,
            product: product,
          ),
        ],
      );
      final repository = _FakeCategoryCatalogRepository(pageData: pageData);

      final result = await GetCategoryProducts(repository)(
        'cat-1',
        locale: 'fr',
        page: 2,
        perPage: 24,
      );

      expect(result, pageData);
      expect(repository.lastCategoryId, 'cat-1');
      expect(repository.lastPage, 2);
      expect(repository.lastPerPage, 24);
    });

    test('GetActiveCategories delegates to repository', () async {
      const categories = [
        CatalogCategory(
          id: 'cat-1',
          code: 'CAT-1',
          name: 'Accessoires Totoro',
          slug: 'accessoires-totoro',
        ),
      ];
      final repository = _FakeCategoryCatalogRepository(
        activeCategories: categories,
      );

      final result = await GetActiveCategories(repository)(locale: 'fr');

      expect(result, categories);
      expect(repository.getActiveCategoriesCalls, 1);
    });

    test('GetCategoryBySlug delegates to repository', () async {
      const category = CatalogCategory(
        id: 'cat-1',
        code: 'CAT-1',
        name: 'Accessoires Totoro',
        slug: 'accessoires-totoro',
      );
      final repository = _FakeCategoryCatalogRepository(
        categoryBySlug: category,
      );

      final result = await GetCategoryBySlug(repository)(
        'accessoires-totoro',
        locale: 'fr',
      );

      expect(result, category);
      expect(repository.lastCategorySlug, 'accessoires-totoro');
    });

    test('GetProductDetail delegates to repository', () async {
      const detail = ProductDetailData(
        product: CatalogProduct(id: 'prod-1', code: 'PROD-1', name: 'Robe'),
        prices: [
          CatalogPrice(
            id: 'price-1',
            productId: 'prod-1',
            price: 89.0,
            isDefault: true,
            currencySymbol: '€',
            currencyCode: 'EUR',
          ),
        ],
      );
      final repository = _FakeProductCatalogRepository(detail: detail);

      final result = await GetProductDetail(repository)('prod-1', locale: 'fr');

      expect(result, detail);
      expect(repository.lastProductId, 'prod-1');
    });

    test('ResolveProductRoute delegates to repository', () async {
      const category = CatalogCategory(
        id: 'cat-1',
        code: 'CAT-1',
        name: 'Accessoires Totoro',
        slug: 'accessoires-totoro',
      );
      const routeData = CatalogProductRouteData(
        category: category,
        productId: 'prod-1',
        productSlug: 'sac-totoro-nuage',
      );
      final repository = _FakeCategoryCatalogRepository(
        resolvedProductRoute: routeData,
      );

      final result = await ResolveProductRoute(repository)(
        categorySlug: 'accessoires-totoro',
        locale: 'fr',
        productSlug: 'sac-totoro-nuage',
      );

      expect(result?.productId, 'prod-1');
      expect(repository.lastResolvedCategorySlug, 'accessoires-totoro');
      expect(repository.lastResolvedProductSlug, 'sac-totoro-nuage');
    });
  });
}

class _FakeCategoryCatalogRepository implements CategoryCatalogRepository {
  final CatalogCategory? defaultCategory;
  final CatalogCategory? categoryBySlug;
  final List<CatalogCategory> activeCategories;
  final CatalogProductRouteData? resolvedProductRoute;
  final CatalogPageData? pageData;

  int getDefaultCategoryCalls = 0;
  int getActiveCategoriesCalls = 0;
  String? lastCategoryId;
  String? lastCategorySlug;
  String? lastResolvedCategorySlug;
  String? lastResolvedProductSlug;
  int? lastPage;
  int? lastPerPage;

  _FakeCategoryCatalogRepository({
    this.defaultCategory,
    this.categoryBySlug,
    this.activeCategories = const [],
    this.resolvedProductRoute,
    this.pageData,
  });

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async {
    getDefaultCategoryCalls += 1;
    return defaultCategory;
  }

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async {
    getActiveCategoriesCalls += 1;
    return activeCategories;
  }

  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async {
    lastCategorySlug = slug;
    return categoryBySlug;
  }

  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String locale,
    required String categorySlug,
    required String productSlug,
  }) async {
    lastResolvedCategorySlug = categorySlug;
    lastResolvedProductSlug = productSlug;
    return resolvedProductRoute;
  }

  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async {
    lastCategoryId = categoryId;
    lastPage = page;
    lastPerPage = perPage;
    return pageData ??
        CatalogPageData(
          page: page,
          perPage: perPage,
          totalItems: 0,
          totalPages: 0,
          categoryId: categoryId,
          items: const [],
        );
  }
}

class _FakeProductCatalogRepository implements ProductCatalogRepository {
  final ProductDetailData detail;

  String? lastProductId;

  _FakeProductCatalogRepository({required this.detail});

  @override
  Future<ProductDetailData> getProductDetail(
    String productId, {
    required String locale,
  }) async {
    lastProductId = productId;
    return detail;
  }
}
