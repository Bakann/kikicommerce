import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

import 'commercetools_catalog_adapter.dart';
import 'commercetools_catalog_api.dart';
import 'commercetools_catalog_product.dart';
import 'commercetools_catalog_repository.dart';

class CommercetoolsCatalogRepositoryImpl
    implements CommercetoolsCatalogRepository {
  final CommercetoolsCatalogApi api;

  const CommercetoolsCatalogRepositoryImpl({required this.api});

  @override
  Future<List<CatalogListingItem>> getProducts({int limit = 20}) async {
    final products = await api.fetchProducts(limit: limit);
    return products
        .map(CommercetoolsCatalogAdapter.toListingItem)
        .toList(growable: false);
  }

  @override
  Future<CatalogListingItem?> getProductByRouteKey(
    String routeKey, {
    int lookupLimit = CommercetoolsCatalogRepository.defaultRouteKeyLookupLimit,
  }) async {
    final products = await api.fetchProducts(limit: lookupLimit);
    // Deterministic precedence: slug first, then key, then id — so a collision
    // (one product's slug == another's key) resolves predictably.
    final match =
        _firstWhere(products, (p) => p.slug == routeKey) ??
        _firstWhere(products, (p) => p.key == routeKey) ??
        _firstWhere(products, (p) => p.id == routeKey);
    return match == null
        ? null
        : CommercetoolsCatalogAdapter.toListingItem(match);
  }

  CommercetoolsCatalogProduct? _firstWhere(
    List<CommercetoolsCatalogProduct> products,
    bool Function(CommercetoolsCatalogProduct) test,
  ) {
    for (final product in products) {
      if (test(product)) return product;
    }
    return null;
  }
}
