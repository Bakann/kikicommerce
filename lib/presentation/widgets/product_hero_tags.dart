import 'package:flutter/material.dart';

import '../screens/product_detail_layout_spec.dart';

/// Hero tag for a product image. Includes an optional [sourceScope] so the
/// same product can carry distinct Hero identities depending on the surface
/// it was tapped from (PLP card vs. PDP cross-sell). Without a scope, every
/// occurrence of the product would pair indiscriminately, e.g. on a back
/// transition PDP B → PLP the cross-sell A still mounted on PDP B would
/// match the PLP card A and fly alongside B.
String productImageHeroTag(String productId, {String? sourceScope}) {
  if (sourceScope == null || sourceScope.isEmpty) {
    return 'product-image-hero-$productId';
  }
  return 'product-image-hero-$sourceScope-$productId';
}

/// Scope for Heroes mounted by the PLP. Keyed on the listing's category id
/// so two PLPs visible in different shells (rare today) don't collide.
String productListingHeroScope({required String? categoryId}) {
  final safeCategory = categoryId == null || categoryId.isEmpty
      ? 'catalog'
      : categoryId;
  return 'plp-$safeCategory';
}

/// Scope for Heroes mounted on a PDP's cross-sell section. Derived from
/// the PDP's own main image tag so the cross-sell Hero of product X
/// mounted on PDP A cannot collide with the PLP card of product X.
String productPdpCrossSellHeroScope({
  required String currentProductId,
  required String? currentMainImageHeroTag,
}) {
  final safeCurrentHeroTag =
      currentMainImageHeroTag == null || currentMainImageHeroTag.isEmpty
      ? 'pdp-$currentProductId'
      : currentMainImageHeroTag;
  return 'pdp-cross-sell-$safeCurrentHeroTag';
}

// Hero tags must be unique within a route. Do not add these to cross-sells
// without deduplicating products against the current PDP.
HeroFlightShuttleBuilder productImageHeroFlightShuttleBuilder({
  required String imageUrl,
  required BoxFit fit,
}) {
  return imageHeroFlightShuttleBuilder(
    imageUrl: imageUrl,
    fit: fit,
    color: productDetailImageSurfaceColor,
  );
}

/// Generic shuttle for a network-image Hero flight, reused by the PLP→PDP
/// transition and the category-tile→PLP transition.
///
/// Skia codec path (NetworkImage), not CachedNetworkImageProvider. On Flutter
/// Web (CanvasKit/Skwasm — the only renderers since 3.29)
/// CachedNetworkImageProvider routes through flutter_cache_manager, which is
/// empty on web, so a freshly built shuttle resolves async and the first
/// flight paints blank. NetworkImage goes straight through the browser fetch +
/// Skia ImageCache, so an awaited precacheImage(NetworkImage(imageUrl)) on the
/// source side makes the shuttle paint synchronously on flight frame one. With
/// the host's max-age this is normally satisfied from the browser HTTP cache.
HeroFlightShuttleBuilder imageHeroFlightShuttleBuilder({
  required String imageUrl,
  required BoxFit fit,
  required Color color,
}) {
  return (
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: color,
        child: Image(
          image: NetworkImage(imageUrl),
          fit: fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  };
}
