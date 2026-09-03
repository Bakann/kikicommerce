import '../../domain/catalog/catalog_entities.dart';
import 'catalog_read_models.dart';

abstract interface class CategoryCatalogRepository {
  Future<CatalogCategory?> getDefaultCategory({required String locale});

  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  });

  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  });

  Future<CatalogProductRouteData?> resolveProductRoute({
    required String categorySlug,
    required String productSlug,
    required String locale,
  });

  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  });
}
