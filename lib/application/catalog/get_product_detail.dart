import 'catalog_read_models.dart';
import 'product_catalog_repository.dart';

class GetProductDetail {
  final ProductCatalogRepository repository;

  const GetProductDetail(this.repository);

  Future<ProductDetailData> call(String productId, {required String locale}) {
    return repository.getProductDetail(productId, locale: locale);
  }
}
