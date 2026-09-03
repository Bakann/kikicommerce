import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

/// Read-only catalog access for the commercetools lab, returning the app's
/// shared [CatalogListingItem] so the lab pages never depend on the raw Worker
/// model. Implemented by [CommercetoolsCatalogRepositoryImpl].
abstract interface class CommercetoolsCatalogRepository {
  /// Page size used to resolve a single product by route key. A temporary lab
  /// fallback (the Worker has no `GET /products/:slug` yet); a deep link to a
  /// product beyond this window resolves to null.
  static const int defaultRouteKeyLookupLimit = 100;

  Future<List<CatalogListingItem>> getProducts({int limit = 20});

  /// Resolves a product by its route key, matching `slug`, then `key`, then
  /// `id` (deterministic precedence). Returns null when nothing matches within
  /// [lookupLimit].
  Future<CatalogListingItem?> getProductByRouteKey(
    String routeKey, {
    int lookupLimit = defaultRouteKeyLookupLimit,
  });
}
