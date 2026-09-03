import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/cache_providers.dart';
import '../../app/catalog_routes.dart';
import '../../app/locale_route_resolver.dart';
import '../../application/storefront/storefront_sport_segment.dart';
import '../../core/utils/media_image_support.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../performance/pdp_loading_performance_logger.dart';
import '../providers/content_locale_provider.dart';
import '../providers/pdp_loading_commerce_provider.dart';
import '../screens/product_detail_route_page.dart';

enum ProductDetailEntrySource { plp, pdpCrossSell, unknown }

Future<void> openProductDetail(
  BuildContext context,
  WidgetRef ref, {
  required CatalogProduct product,
  required List<CatalogPrice> prices,
  required String routeName,
  CatalogCategory? category,
  CatalogMedia? heroListingMedia,
  bool heroEligible = false,
  // Exact Hero tag worn by the source widget. Forwarded to the destination
  // PDP so the flight pairs only with that source, not with any other route
  // also rendering the same product (e.g. a PLP card behind a PDP whose
  // cross-sell led here — see [ProductDetailRouteHint.imageHeroTag]).
  String? imageHeroTag,
  ProductDetailEntrySource source = ProductDetailEntrySource.unknown,
}) async {
  final tappedAt = ref.read(cacheClockProvider)();
  if (kDebugMode) {
    debugPrint(
      '[pdp-nav] source=${source.name} product=${product.id} '
      'hint=${heroListingMedia != null} hero=$heroEligible',
    );
  }

  ref
      .read(pdpLoadingPerformanceLoggerProvider)
      .tap(productId: product.id, heroEligible: heroEligible);
  ref
      .read(pdpLoadingTapTraceProvider(product.id).notifier)
      .state = PdpLoadingTapTrace(
    productId: product.id,
    tappedAt: tappedAt,
    heroEligible: heroEligible,
  );
  ref
      .read(pdpLoadingCommerceSnapshotProvider(product.id).notifier)
      .state = heroEligible
      ? PdpLoadingCommerceSnapshot(
          product: product,
          prices: prices,
          capturedAt: tappedAt,
          hasVariantSelector: false,
        )
      : null;

  if (heroListingMedia != null) {
    await warmProductHeroShuttleImage(context, heroListingMedia.listingUrl);
    if (!context.mounted) {
      return;
    }
  }

  final localizedRouteName = CatalogRoutes.localizedLocation(
    _sportContextualProductRouteName(context, routeName),
    locale: ref.read(contentLocaleProvider),
  );
  context.push(
    localizedRouteName,
    extra: ProductDetailRouteHint(
      productId: product.id,
      category: category,
      listingMedia: heroListingMedia,
      imageHeroTag: heroEligible ? imageHeroTag : null,
    ),
  );
}

String _sportContextualProductRouteName(
  BuildContext context,
  String routeName,
) {
  final trimmed = routeName.trim();
  if (trimmed.isEmpty) return trimmed;

  final slugs = _catalogProductSlugsFromRouteName(trimmed);
  if (slugs == null) return trimmed;

  final segment = _currentSportSegment(context);
  if (segment == null) return trimmed;

  final sourceUri = Uri.tryParse(trimmed);
  if (sourceUri == null) return trimmed;

  return Uri(
    path: CatalogRoutes.sportProductLocation(
      segment: segment,
      categorySlug: slugs.categorySlug,
      productSlug: slugs.productSlug,
    ),
    queryParameters: sourceUri.queryParametersAll.isEmpty
        ? null
        : sourceUri.queryParametersAll,
    fragment: sourceUri.fragment.isEmpty ? null : sourceUri.fragment,
  ).toString();
}

({String categorySlug, String productSlug})? _catalogProductSlugsFromRouteName(
  String routeName,
) {
  final uri = Uri.tryParse(routeName);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return null;

  final routePath = resolveLocaleRoute(uri).routePath;
  final segments = Uri(path: routePath).pathSegments;
  if (segments.length == 3 &&
      segments.first == 'catalog' &&
      segments[1].isNotEmpty &&
      segments[2].isNotEmpty) {
    return (categorySlug: segments[1], productSlug: segments[2]);
  }
  return null;
}

StorefrontSportSegment? _currentSportSegment(BuildContext context) {
  final Uri currentUri;
  try {
    currentUri = GoRouterState.of(context).uri;
  } catch (_) {
    return null;
  }

  final routePath = resolveLocaleRoute(currentUri).routePath;
  final segments = Uri(path: routePath).pathSegments;
  if (segments.length < 2 || segments.first != 'sport') {
    return null;
  }
  return StorefrontSportSegment.tryParse(segments[1]);
}

Future<void> warmProductHeroShuttleImage(
  BuildContext context,
  String? imageUrl,
) {
  if (imageUrl == null || isKnownUnsupportedImageFormat(url: imageUrl)) {
    return Future<void>.value();
  }
  return precacheImage(
    NetworkImage(imageUrl),
    context,
    onError: (_, _) {},
  ).timeout(const Duration(milliseconds: 800), onTimeout: () {});
}
