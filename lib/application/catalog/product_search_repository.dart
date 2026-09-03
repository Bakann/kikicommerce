import '../../domain/catalog/catalog_entities.dart';
import 'search_query.dart';

class SearchResultPage {
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;
  final List<SearchResultItem> items;

  const SearchResultPage({
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
    required this.items,
  });

  const SearchResultPage.empty()
    : page = 1,
      perPage = 20,
      totalItems = 0,
      totalPages = 0,
      items = const [];
}

class SearchResultItem {
  final CatalogProduct product;
  final List<CatalogPrice> prices;

  const SearchResultItem({required this.product, required this.prices});
}

abstract interface class ProductSearchRepository {
  Future<SearchResultPage> searchProducts(SearchQuery query);

  /// Lightweight autocomplete: distinct active-product names matching [query],
  /// capped at [limit]. Fetches only the `name` field (no price/gallery
  /// expansion) so it stays cheap enough to run as the visitor types.
  Future<List<String>> suggestProductNames(String query, {int limit = 8});
}
