import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/cache_providers.dart';
import '../../application/catalog/catalog_read_models.dart';
import '../../core/cache/kiki_cache_keys.dart';
import '../../core/cache/kiki_cache_policies.dart';
import 'content_locale_provider.dart';

export '../../application/catalog/catalog_read_models.dart'
    show CatalogPageData, CatalogProductRouteData, ProductDetailData;

typedef ProductRouteRequest = ({String categorySlug, String productSlug});

// Currency is still a `'global'` placeholder (a separate axis, out of scope);
// locale is now the resolved content locale so each language gets its own cache
// slot and the matching translated content.
const _placeholderCurrency = 'global';

/// PLP feed cached through [CachedRemoteReader] with the SWR `plp` policy.
/// We pass [categoryId] as the `categorySlug` axis of [KikiCacheKeys.plp]:
/// the cache key just needs to be unique per category and the storefront
/// only fetches PLPs by id today.
final plpProvider = FutureProvider.family<CatalogPageData, String>((
  ref,
  categoryId,
) {
  final locale = ref.watch(contentLocaleProvider);
  final reader = ref.watch(cachedRemoteReaderProvider);
  return reader.read<CatalogPageData>(
    key: KikiCacheKeys.plp(
      locale: locale,
      currency: _placeholderCurrency,
      categorySlug: categoryId,
    ),
    resourceType: 'plp',
    policy: KikiCachePolicies.plp,
    remoteLoader: () =>
        ref.watch(getCategoryProductsProvider)(categoryId, locale: locale),
  );
});

/// PDP detail cached through [CachedRemoteReader] with the SWR `product`
/// policy.
final pdpProvider = FutureProvider.family<ProductDetailData, String>((
  ref,
  productId,
) {
  final locale = ref.watch(contentLocaleProvider);
  final reader = ref.watch(cachedRemoteReaderProvider);
  return reader.read<ProductDetailData>(
    key: KikiCacheKeys.product(
      locale: locale,
      currency: _placeholderCurrency,
      productId: productId,
    ),
    resourceType: 'product',
    policy: KikiCachePolicies.product,
    remoteLoader: () =>
        ref.watch(getProductDetailProvider)(productId, locale: locale),
  );
});

final productRouteProvider =
    FutureProvider.family<CatalogProductRouteData?, ProductRouteRequest>((
      ref,
      request,
    ) {
      final locale = ref.watch(contentLocaleProvider);
      return ref.watch(resolveProductRouteProvider)(
        categorySlug: request.categorySlug,
        productSlug: request.productSlug,
        locale: locale,
      );
    });
