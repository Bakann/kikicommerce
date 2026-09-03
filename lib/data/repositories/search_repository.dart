import '../../application/catalog/product_search_repository.dart';
import '../../application/catalog/search_query.dart';
import '../../core/utils/pocketbase_filter_utils.dart';
import '../api/pocketbase_client.dart';
import '../mappers/catalog_mappers.dart';
import '../models/product.dart';
import '_listing_gallery_fallback.dart';
import '_price_fetcher.dart';

class PocketBaseSearchRepository implements ProductSearchRepository {
  final PocketBaseClient client;

  const PocketBaseSearchRepository({required this.client});

  @override
  Future<SearchResultPage> searchProducts(SearchQuery query) async {
    final searchFilter = buildSearchFilter(
      fieldName: 'searchIndex',
      query: query.query,
    );

    if (searchFilter == null) {
      return const SearchResultPage.empty();
    }

    final filter = combineFilters(['isActive=true', searchFilter]);

    final productsData = await client.listRecords<Product>(
      'products',
      filter: filter,
      sort: query.sort.toPocketBaseSort(),
      expand: 'picture,thumbnail',
      page: query.page,
      perPage: query.perPage,
      fromJson: Product.fromJson,
    );

    final productIds = productsData.items.map((p) => p.id).toSet();

    final pricesByProduct = await fetchPricesByProductIds(client, productIds);
    final galleryFallbacks = await fetchListingGalleryFallbacks(
      client,
      productsData.items,
    );

    final items = productsData.items.map((product) {
      final effectiveProduct = product.copyWith(
        galleryImages: galleryFallbacks[product.id],
      );
      return SearchResultItem(
        product: toCatalogProduct(effectiveProduct),
        prices: pricesByProduct[product.id] ?? const [],
      );
    }).toList();

    return SearchResultPage(
      page: productsData.page,
      perPage: productsData.perPage,
      totalItems: productsData.totalItems,
      totalPages: productsData.totalPages,
      items: items,
    );
  }

  @override
  Future<List<String>> suggestProductNames(
    String query, {
    int limit = 8,
  }) async {
    final searchFilter = buildSearchFilter(
      fieldName: 'searchIndex',
      query: query,
    );
    if (searchFilter == null) {
      return const <String>[];
    }

    final filter = combineFilters(['isActive=true', searchFilter]);

    // `fields: name` keeps the payload tiny and skips the price/gallery
    // fan-out — this runs per debounced keystroke, so it must stay light.
    final data = await client.listRecords<String>(
      'products',
      filter: filter,
      sort: '-created',
      fields: 'name',
      page: 1,
      // Over-fetch a little so de-duplication still yields up to [limit] names.
      perPage: limit * 2,
      fromJson: (json) => (json['name'] as String?)?.trim() ?? '',
    );

    final seen = <String>{};
    final names = <String>[];
    for (final name in data.items) {
      if (name.isEmpty) continue;
      if (seen.add(name.toLowerCase())) {
        names.add(name);
      }
      if (names.length >= limit) break;
    }
    return names;
  }
}
