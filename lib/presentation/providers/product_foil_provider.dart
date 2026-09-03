import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/cache_providers.dart';
import '../../core/cache/kiki_cache_keys.dart';
import '../../core/cache/kiki_cache_policies.dart';
import '../../data/models/product_foil.dart';

/// Holo foil of one product, cached through [CachedRemoteReader] with the
/// SWR `productFoil` policy. `null` (no foil saved) is a valid cached
/// value; the PDP renders unchanged in that case.
final productFoilProvider = FutureProvider.family<ProductFoil?, String>((
  ref,
  productId,
) {
  final reader = ref.watch(cachedRemoteReaderProvider);
  return reader.read<ProductFoil?>(
    key: KikiCacheKeys.productFoil(productId: productId),
    resourceType: 'productFoil',
    policy: KikiCachePolicies.productFoil,
    remoteLoader: () =>
        ref.watch(productFoilRepositoryProvider).fetchForProduct(productId),
  );
});
