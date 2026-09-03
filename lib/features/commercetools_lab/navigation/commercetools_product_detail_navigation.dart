import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/navigation/product_detail_navigation.dart'
    show warmProductHeroShuttleImage;

/// Route hint passed from the commercetools lab PLP to its detail page so the
/// product can be shown immediately (and the Hero flight paired) without a
/// network round-trip. Deliberately separate from `ProductDetailRouteHint`,
/// which is PocketBase-specific.
class CommercetoolsProductDetailRouteHint {
  final CatalogListingItem listingItem;
  final CatalogMedia? listingMedia;
  final String? imageHeroTag;

  const CommercetoolsProductDetailRouteHint({
    required this.listingItem,
    this.listingMedia,
    this.imageHeroTag,
  });
}

/// Opens the commercetools lab detail route. Mirrors the visual warm-up of
/// [openProductDetail] (precaches the Hero shuttle image) but deliberately does
/// NOT read `pdpProvider` or any PocketBase/cart state — these products have no
/// PocketBase identity.
Future<void> openCommercetoolsProductDetail(
  BuildContext context, {
  required CatalogListingItem item,
  required String routeName,
  CatalogMedia? heroListingMedia,
  bool heroEligible = false,
  String? imageHeroTag,
}) async {
  if (heroListingMedia != null) {
    await warmProductHeroShuttleImage(context, heroListingMedia.listingUrl);
    if (!context.mounted) return;
  }

  if (!context.mounted) return;
  context.push(
    routeName,
    extra: CommercetoolsProductDetailRouteHint(
      listingItem: item,
      listingMedia: heroListingMedia,
      imageHeroTag: heroEligible ? imageHeroTag : null,
    ),
  );
}
