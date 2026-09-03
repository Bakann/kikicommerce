import '../../domain/catalog/catalog_entities.dart';

class CatalogPageData {
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;
  final String categoryId;
  final String? categoryName;

  /// The resolved catalog category for this PLP, when the feed exposes it.
  /// Carries [CatalogCategory.parentId], letting back-navigation resolve a
  /// real parent before falling back to URL-only derivation.
  final CatalogCategory? category;
  final List<CatalogListingItem> items;

  const CatalogPageData({
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
    required this.categoryId,
    required this.items,
    this.categoryName,
    this.category,
  });
}

class CatalogProductRouteData {
  final CatalogCategory category;
  final String productId;
  final String productSlug;

  const CatalogProductRouteData({
    required this.category,
    required this.productId,
    required this.productSlug,
  });
}

class ProductDetailData {
  final CatalogProduct product;
  final List<CatalogPrice> prices;
  final List<NarrativeChapter> chapters;

  const ProductDetailData({
    required this.product,
    required this.prices,
    this.chapters = const [],
  });
}
