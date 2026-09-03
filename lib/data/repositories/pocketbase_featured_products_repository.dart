import '../../application/cms/featured_products_repository.dart';
import '../../core/utils/pocketbase_filter_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../api/pocketbase_client.dart';
import '../mappers/catalog_mappers.dart';
import '../models/paginated_response.dart';
import '../models/price_row.dart';
import '../models/product.dart';
import '_translation_fetcher.dart';

class PocketBaseFeaturedProductsRepository
    implements FeaturedProductsRepository {
  final PocketBaseClient client;

  const PocketBaseFeaturedProductsRepository({required this.client});

  @override
  Future<List<FeaturedProductData>> getFeaturedProducts(
    List<String> productIds, {
    required String locale,
  }) async {
    if (productIds.isEmpty) return const [];

    final productFilter = productIds
        .map((id) => 'id="${escapeFilterValue(id)}"')
        .join(' || ');
    final productsResponse = await client.listRecords<Product>(
      'products',
      filter: '($productFilter) && isActive=true',
      expand: 'picture,thumbnail,galleryImages,galleryImages.medias',
      perPage: productIds.length,
      fromJson: Product.fromJson,
    );

    if (productsResponse.items.isEmpty) return const [];

    final priceFilter = productIds
        .map((id) => 'product="${escapeFilterValue(id)}"')
        .join(' || ');
    PaginatedResponse<PriceRow>? pricesResponse;
    try {
      pricesResponse = await client.listRecords<PriceRow>(
        'priceRows',
        filter: '($priceFilter) && isActive=true',
        expand: 'currency',
        perPage: productIds.length * 4,
        fromJson: PriceRow.fromJson,
      );
    } catch (_) {
      // Prices are best-effort: if the listing is forbidden or fails the
      // tiles still render with name + image (showPrices=false on config).
      pricesResponse = null;
    }

    final pricesByProduct = <String, List<CatalogPrice>>{};
    if (pricesResponse != null) {
      for (final row in pricesResponse.items) {
        final mapped = toCatalogPrice(row);
        pricesByProduct.putIfAbsent(row.productId, () => []).add(mapped);
      }
    }

    final translations = await fetchProductTranslations(
      client,
      productIds,
      locale: locale,
    );

    final productById = {for (final p in productsResponse.items) p.id: p};
    final ordered = <FeaturedProductData>[];
    for (final id in productIds) {
      final raw = productById[id];
      if (raw == null) continue;
      final mapped = toCatalogProduct(raw, translation: translations[id]);
      ordered.add(
        FeaturedProductData(
          product: mapped,
          prices: pricesByProduct[id] ?? const [],
          imageUrl: mapped.listingMedia?.listingUrl,
        ),
      );
    }
    return ordered;
  }
}
