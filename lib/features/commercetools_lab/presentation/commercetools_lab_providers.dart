import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kiki_commerce/config/api_config.dart';
import 'package:kiki_commerce/core/network/http_client_provider.dart';
import 'package:kiki_commerce/core/error/app_exception.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import '../data/commercetools_catalog_api.dart';
import '../data/commercetools_catalog_repository.dart';
import '../data/commercetools_catalog_repository_impl.dart';

/// Resolved Cloudflare Worker URL for the commercetools lab. Exposed as a
/// provider (rather than reading [ApiConfig.ctCatalogProxyUrl] directly) so
/// tests can override it without a build-time `--dart-define`.
final ctCatalogProxyUrlProvider = Provider<String>((ref) {
  return ApiConfig.ctCatalogProxyUrl;
});

/// Isolated API client for the commercetools lab. Reuses the shared
/// [httpClientProvider] so tests can inject a `MockClient`.
final commercetoolsCatalogApiProvider = Provider<CommercetoolsCatalogApi>((
  ref,
) {
  return CommercetoolsCatalogApi(
    client: ref.watch(httpClientProvider),
    baseUrl: ref.watch(ctCatalogProxyUrlProvider),
  );
});

/// Repository that exposes commercetools products as shared [CatalogListingItem]
/// values, so the lab pages never touch the raw Worker model.
final commercetoolsCatalogRepositoryProvider =
    Provider<CommercetoolsCatalogRepository>((ref) {
      return CommercetoolsCatalogRepositoryImpl(
        api: ref.watch(commercetoolsCatalogApiProvider),
      );
    });

/// Commercetools products as [CatalogListingItem]s for the lab PLP.
///
/// Intentionally separate from the PocketBase catalog providers and the catalog
/// cache — it does not touch `plpProvider`/`pdpProvider` or the
/// `CatalogInvalidator`. Throws a clear, user-facing message when the proxy URL
/// is absent or invalid.
final commercetoolsListingItemsProvider =
    FutureProvider<List<CatalogListingItem>>((ref) {
      final url = ref.watch(ctCatalogProxyUrlProvider);
      if (!ApiConfig.isCtCatalogProxyUrlValueUsable(url)) {
        throw const ApiException('CT_CATALOG_PROXY_URL is not configured.');
      }
      return ref.watch(commercetoolsCatalogRepositoryProvider).getProducts();
    });

/// Resolves a single commercetools product by its route key (slug/key/id) for
/// the lab PDP deep-link / refresh path.
final commercetoolsListingItemByRouteKeyProvider =
    FutureProvider.family<CatalogListingItem?, String>((ref, routeKey) {
      final url = ref.watch(ctCatalogProxyUrlProvider);
      if (!ApiConfig.isCtCatalogProxyUrlValueUsable(url)) {
        throw const ApiException('CT_CATALOG_PROXY_URL is not configured.');
      }
      return ref
          .watch(commercetoolsCatalogRepositoryProvider)
          .getProductByRouteKey(routeKey);
    });
