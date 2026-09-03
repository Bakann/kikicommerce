import '../../domain/catalog/catalog_entities.dart';
import 'category_catalog_repository.dart';

class GetCategoryBySlug {
  final CategoryCatalogRepository repository;

  const GetCategoryBySlug(this.repository);

  Future<CatalogCategory?> call(String slug, {required String locale}) {
    return repository.getCategoryBySlug(slug, locale: locale);
  }
}
