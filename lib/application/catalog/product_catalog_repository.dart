import 'catalog_read_models.dart';

abstract interface class ProductCatalogRepository {
  Future<ProductDetailData> getProductDetail(
    String productId, {
    required String locale,
  });
}
