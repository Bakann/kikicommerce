import '../../domain/catalog/catalog_entities.dart';

/// Display-side bundle for one featured product tile: the product itself,
/// its prices, and the precomputed listing image URL. The CMS section is
/// the only consumer today; if other surfaces start displaying products
/// alongside metadata of their own, broaden this type instead of returning
/// raw catalog/data layer types from the repository.
class FeaturedProductData {
  final CatalogProduct product;
  final List<CatalogPrice> prices;
  final String? imageUrl;

  const FeaturedProductData({
    required this.product,
    required this.prices,
    required this.imageUrl,
  });
}

abstract interface class FeaturedProductsRepository {
  /// Returns the featured products in the same order as [productIds].
  /// Missing or inactive products are dropped silently. Empty input
  /// returns an empty list without hitting the network.
  Future<List<FeaturedProductData>> getFeaturedProducts(
    List<String> productIds, {
    required String locale,
  });
}
