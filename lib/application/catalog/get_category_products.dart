import 'catalog_read_models.dart';
import 'category_catalog_repository.dart';

class GetCategoryProducts {
  final CategoryCatalogRepository repository;

  const GetCategoryProducts(this.repository);

  Future<CatalogPageData> call(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) {
    return repository.getCategoryProducts(
      categoryId,
      locale: locale,
      page: page,
      perPage: perPage,
    );
  }
}
