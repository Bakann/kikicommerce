import 'product_search_repository.dart';
import 'search_query.dart';

class SearchProducts {
  final ProductSearchRepository repository;

  const SearchProducts(this.repository);

  Future<SearchResultPage> call(SearchQuery query) {
    return repository.searchProducts(query);
  }
}
