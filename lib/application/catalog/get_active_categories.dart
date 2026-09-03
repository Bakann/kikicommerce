import '../../domain/catalog/catalog_entities.dart';
import 'category_catalog_repository.dart';

class GetActiveCategories {
  final CategoryCatalogRepository repository;

  const GetActiveCategories(this.repository);

  Future<List<CatalogCategory>> call({
    required String locale,
    bool includeHidden = false,
  }) {
    return repository.getActiveCategories(
      locale: locale,
      includeHidden: includeHidden,
    );
  }
}
