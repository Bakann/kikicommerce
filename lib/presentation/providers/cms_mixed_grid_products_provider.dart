import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../application/catalog/catalog_read_models.dart';
import 'content_locale_provider.dart';

typedef CmsMixedGridProductsRequest = ({String categoryId, int limit});

/// Products feed used by the CMS `mixed_product_grid` section. Distinct from
/// [plpProvider] because the CMS grid lets each section pick its own page
/// size (`config.source.limit`). Hooked into `catalogInvalidatorProvider`
/// for the same lifecycle as the classic PLP — see
/// `catalog_invalidator_provider.dart`.
final cmsMixedGridProductsProvider =
    FutureProvider.family<CatalogPageData, CmsMixedGridProductsRequest>((
      ref,
      request,
    ) {
      final locale = ref.watch(contentLocaleProvider);
      return ref
          .watch(categoryCatalogRepositoryProvider)
          .getCategoryProducts(
            request.categoryId,
            locale: locale,
            perPage: request.limit,
          );
    });
