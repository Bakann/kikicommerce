import 'catalog_read_models.dart';
import 'category_catalog_repository.dart';

class ResolveProductRoute {
  final CategoryCatalogRepository repository;

  const ResolveProductRoute(this.repository);

  Future<CatalogProductRouteData?> call({
    required String categorySlug,
    required String productSlug,
    required String locale,
  }) {
    return repository.resolveProductRoute(
      categorySlug: categorySlug,
      productSlug: productSlug,
      locale: locale,
    );
  }
}
