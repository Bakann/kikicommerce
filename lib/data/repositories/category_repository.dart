import '../../application/catalog/catalog_read_models.dart';
import '../../application/catalog/category_catalog_repository.dart';
import '../../core/utils/pocketbase_filter_utils.dart';
import '../../core/utils/slug_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../api/pocketbase_client.dart';
import '../mappers/catalog_mappers.dart';
import '../models/category.dart';
import '../models/category_product.dart';
import '../models/paginated_response.dart';
import '../models/product.dart';
import '_listing_gallery_fallback.dart';
import '_price_fetcher.dart';
import '_translation_fetcher.dart';

class PocketBaseCategoryRepository implements CategoryCatalogRepository {
  final PocketBaseClient client;

  PocketBaseCategoryRepository({required this.client});

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async {
    final data = await _listActiveCategories(page: 1, perPage: 1);
    if (data.items.isEmpty) return null;
    final category = data.items.first;
    final translations = await fetchCategoryTranslations(client, [
      category.id,
    ], locale: locale);
    return toCatalogCategory(category, translation: translations[category.id]);
  }

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async {
    final data = await _listActiveCategories(
      page: 1,
      perPage: 200,
      includeHidden: includeHidden,
    );
    final translations = await fetchCategoryTranslations(
      client,
      data.items.map((c) => c.id),
      locale: locale,
    );
    return data.items
        .map((c) => toCatalogCategory(c, translation: translations[c.id]))
        .toList();
  }

  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async {
    final data = await client.listRecords<Category>(
      'categories',
      filter: 'isActive=true && slug="${escapeFilterValue(slug)}"',
      sort: 'name',
      page: 1,
      perPage: 1,
      fromJson: Category.fromJson,
    );

    if (data.items.isEmpty) {
      return null;
    }

    final category = data.items.first;
    final translations = await fetchCategoryTranslations(client, [
      category.id,
    ], locale: locale);
    return toCatalogCategory(category, translation: translations[category.id]);
  }

  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String categorySlug,
    required String productSlug,
    required String locale,
  }) async {
    // requestedCategory is localized; the listing items below stay on the base
    // product so slug matching (canonicalProductSlug) is locale-invariant.
    final requestedCategory = await getCategoryBySlug(
      categorySlug,
      locale: locale,
    );
    if (requestedCategory == null) {
      return null;
    }

    final requestedRelations = await _listActiveCategoryProducts(
      categoryId: requestedCategory.id,
      expand: 'category,product',
    );

    final requestedItems = requestedRelations
        .where((categoryProduct) => categoryProduct.product != null)
        .map(
          (categoryProduct) => toCatalogListingItem(categoryProduct, const []),
        )
        .toList();

    final requestedSiblingProducts = requestedItems
        .map((listingItem) => listingItem.product)
        .toList(growable: false);

    CatalogListingItem? matchedItem;
    for (final item in requestedItems) {
      final requestedSlug = canonicalProductSlug(
        product: item.product,
        siblingProducts: requestedSiblingProducts,
      );
      if (requestedSlug == productSlug) {
        matchedItem = item;
        break;
      }
    }

    if (matchedItem == null) {
      return null;
    }

    final productRelations = await _listActiveProductRelations(
      productId: matchedItem.productId,
    );
    final canonicalRelation = _selectCanonicalRelation(productRelations);
    final canonicalCategory = canonicalRelation?.category;

    if (canonicalRelation == null || canonicalCategory == null) {
      return CatalogProductRouteData(
        category: matchedItem.category ?? requestedCategory,
        productId: matchedItem.productId,
        productSlug: canonicalProductSlug(
          product: matchedItem.product,
          siblingProducts: requestedSiblingProducts,
        ),
      );
    }

    final canonicalSiblingProducts =
        canonicalCategory.id == requestedCategory.id
        ? requestedSiblingProducts
        : (await _listActiveCategoryProducts(
                categoryId: canonicalCategory.id,
                expand: 'product',
              ))
              .where((relation) => relation.product != null)
              .map((relation) => toCatalogProduct(relation.product!))
              .toList(growable: false);

    final canonicalCategoryTranslations = await fetchCategoryTranslations(
      client,
      [canonicalCategory.id],
      locale: locale,
    );
    return CatalogProductRouteData(
      category: toCatalogCategory(
        canonicalCategory,
        translation: canonicalCategoryTranslations[canonicalCategory.id],
      ),
      productId: matchedItem.productId,
      productSlug: canonicalProductSlug(
        product: matchedItem.product,
        siblingProducts: canonicalSiblingProducts,
      ),
    );
  }

  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async {
    final cpData = await client.listRecords<CategoryProduct>(
      'categoryProducts',
      filter:
          'category="$categoryId" && isActive=true && product.isActive=true',
      sort: 'position',
      expand: 'category,product,product.picture,product.thumbnail',
      page: page,
      perPage: perPage,
      fromJson: CategoryProduct.fromJson,
    );

    final productIds = cpData.items
        .where((cp) => cp.product != null)
        .map((cp) => cp.productId)
        .toSet();

    // Run prices, gallery fallbacks, sibling products, and translations in
    // parallel: none depend on each other and each may early-return without
    // hitting PocketBase. Sequential awaits used to stack their latencies.
    final pricesFuture = fetchPricesByProductIds(client, productIds);
    final galleryFallbacksFuture = fetchListingGalleryFallbacks(
      client,
      cpData.items
          .map((categoryProduct) => categoryProduct.product)
          .whereType<Product>(),
    );
    final siblingProductsFuture = _loadCategorySiblingProducts(
      categoryId: categoryId,
      pageItems: cpData.items,
      totalItems: cpData.totalItems,
    );
    final productTranslationsFuture = fetchProductTranslations(
      client,
      productIds,
      locale: locale,
    );
    final categoryTranslationsFuture = fetchCategoryTranslations(client, [
      categoryId,
    ], locale: locale);

    final pricesByProduct = await pricesFuture;
    final galleryFallbacks = await galleryFallbacksFuture;
    final siblingProducts = await siblingProductsFuture;
    final productTranslations = await productTranslationsFuture;
    final categoryTranslations = await categoryTranslationsFuture;

    final items = cpData.items
        .where((categoryProduct) => categoryProduct.product != null)
        .map((categoryProduct) {
          final product = categoryProduct.product!;
          final effectiveProduct = product.copyWith(
            galleryImages: galleryFallbacks[product.id],
          );
          final effectiveCategoryProduct = categoryProduct.copyWith(
            product: effectiveProduct,
          );
          return toCatalogListingItem(
            effectiveCategoryProduct,
            pricesByProduct[categoryProduct.productId] ?? const [],
            // Slug is derived from the BASE product so routes stay
            // locale-invariant; only the displayed strings are localized.
            productRouteSlug: canonicalProductSlug(
              product: toCatalogProduct(effectiveProduct),
              siblingProducts: siblingProducts,
            ),
            productTranslation: productTranslations[categoryProduct.productId],
            categoryTranslation:
                categoryTranslations[categoryProduct.categoryId],
          );
        })
        .toList();

    return toCatalogPageData(
      categoryId: categoryId,
      page: cpData.page,
      perPage: cpData.perPage,
      totalItems: cpData.totalItems,
      totalPages: cpData.totalPages,
      items: items,
    );
  }

  Future<PaginatedResponse<Category>> _listActiveCategories({
    required int page,
    required int perPage,
    bool includeHidden = false,
  }) {
    return client.listRecords<Category>(
      'categories',
      filter: [
        'isActive=true',
        if (!includeHidden) 'isHidden=false',
      ].join(' && '),
      sort: 'position,name',
      page: page,
      perPage: perPage,
      fromJson: Category.fromJson,
    );
  }

  Future<List<CatalogProduct>> _loadCategorySiblingProducts({
    required String categoryId,
    required List<CategoryProduct> pageItems,
    required int totalItems,
  }) async {
    if (pageItems.isEmpty && totalItems <= 0) {
      return const [];
    }

    if (pageItems.isNotEmpty && totalItems <= pageItems.length) {
      return pageItems
          .where((categoryProduct) => categoryProduct.product != null)
          .map((categoryProduct) => toCatalogProduct(categoryProduct.product!))
          .toList(growable: false);
    }

    final allCategoryProducts = await _listActiveCategoryProducts(
      categoryId: categoryId,
      expand: 'product',
      perPage: totalItems > 500 ? 500 : totalItems,
    );

    return allCategoryProducts
        .where((categoryProduct) => categoryProduct.product != null)
        .map((categoryProduct) => toCatalogProduct(categoryProduct.product!))
        .toList(growable: false);
  }

  Future<List<CategoryProduct>> _listActiveCategoryProducts({
    required String categoryId,
    required String expand,
    int perPage = 500,
  }) async {
    final response = await client.listRecords<CategoryProduct>(
      'categoryProducts',
      filter:
          'category="${escapeFilterValue(categoryId)}" && isActive=true && product.isActive=true',
      sort: 'position',
      expand: expand,
      page: 1,
      perPage: perPage,
      fromJson: CategoryProduct.fromJson,
    );

    return response.items;
  }

  Future<List<CategoryProduct>> _listActiveProductRelations({
    required String productId,
  }) async {
    final response = await client.listRecords<CategoryProduct>(
      'categoryProducts',
      filter:
          'product="${escapeFilterValue(productId)}" && isActive=true && product.isActive=true',
      sort: 'position',
      expand: 'category,product',
      page: 1,
      perPage: 500,
      fromJson: CategoryProduct.fromJson,
    );

    return response.items;
  }

  CategoryProduct? _selectCanonicalRelation(List<CategoryProduct> relations) {
    final eligibleRelations = relations
        .where(
          (relation) =>
              relation.category != null && relation.category!.isActive,
        )
        .toList();

    if (eligibleRelations.isEmpty) {
      return null;
    }

    eligibleRelations.sort((left, right) {
      final primaryComparison = _compareBoolDescending(
        left.isPrimary,
        right.isPrimary,
      );
      if (primaryComparison != 0) {
        return primaryComparison;
      }

      final positionComparison = _compareNullableInt(
        left.position,
        right.position,
      );
      if (positionComparison != 0) {
        return positionComparison;
      }

      final categoryNameComparison = left.category!.name.compareTo(
        right.category!.name,
      );
      if (categoryNameComparison != 0) {
        return categoryNameComparison;
      }

      return left.id.compareTo(right.id);
    });

    return eligibleRelations.first;
  }

  int _compareBoolDescending(bool left, bool right) {
    if (left == right) {
      return 0;
    }
    return left ? -1 : 1;
  }

  int _compareNullableInt(int? left, int? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return left.compareTo(right);
  }
}
