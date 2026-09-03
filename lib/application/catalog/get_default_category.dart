import '../../domain/catalog/catalog_entities.dart';
import 'category_catalog_repository.dart';

class GetDefaultCategory {
  final CategoryCatalogRepository repository;

  const GetDefaultCategory(this.repository);

  Future<CatalogCategory?> call({required String locale}) {
    return repository.getDefaultCategory(locale: locale);
  }
}
