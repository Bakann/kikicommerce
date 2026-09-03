import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/cache_providers.dart';
import '../../application/cms/featured_products_repository.dart';
import '../../core/cache/kiki_cache_policies.dart';
import 'content_locale_provider.dart';

const _placeholderCurrency = 'global';

/// Featured-products feed for the CMS section. Cached through
/// [CachedRemoteReader] with the SWR `homepage` policy. The cache key
/// includes [productIds] verbatim because the repository contract is
/// order-preserving (`PocketBaseFeaturedProductsRepository` reorders the
/// PocketBase response back into the requested order). Two sections that
/// ask for the same ids in different orders therefore get distinct cache
/// slots, each preserving its caller's order.
final featuredProductsProvider =
    FutureProvider.family<List<FeaturedProductData>, List<String>>((
      ref,
      productIds,
    ) {
      if (productIds.isEmpty) return Future.value(const []);
      final locale = ref.watch(contentLocaleProvider);
      final repo = ref.watch(featuredProductsRepositoryProvider);
      final reader = ref.watch(cachedRemoteReaderProvider);

      // URL-encode each id before joining so that, if an id ever contains a
      // comma or other reserved character, two distinct id lists can never
      // collapse into the same cache key.
      final encodedIds = productIds.map(Uri.encodeComponent).join(',');
      final key =
          'featuredProducts:locale=$locale|currency=$_placeholderCurrency'
          '|ids=$encodedIds';

      return reader.read<List<FeaturedProductData>>(
        key: key,
        resourceType: 'featuredProducts',
        policy: KikiCachePolicies.homepage,
        remoteLoader: () =>
            repo.getFeaturedProducts(productIds, locale: locale),
      );
    });
