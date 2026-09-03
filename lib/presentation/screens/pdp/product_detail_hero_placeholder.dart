import 'package:flutter/material.dart';

import '../../../domain/catalog/catalog_entities.dart';
import '../../widgets/pdp_water_ripple_image.dart';
import '../../widgets/product_hero_tags.dart';
import '../../widgets/storefront_layout.dart';
import '../product_detail_layout_spec.dart';
import 'product_detail_loading_skeleton.dart';

/// Loading-branch hero that mounts the Hero destination immediately so the
/// PLP→PDP image flight lands on the same rect the data branch will paint.
class PdpHeroPlaceholder extends StatelessWidget {
  final String productId;
  // Exact Hero tag forwarded by the source widget that pushed this PDP.
  // When null we fall back to the global product-id tag so deep links still
  // produce a tagged placeholder (no source to pair against, but the loaded
  // carousel needs a consistent tag for pull-to-hero-back on pop).
  final String? imageHeroTag;
  final CatalogMedia listingMedia;
  final ProductDetailLayoutSpec layout;
  final Widget? loadingQuickAdd;
  final CatalogProduct? loadingProduct;

  const PdpHeroPlaceholder({
    super.key,
    required this.productId,
    required this.listingMedia,
    required this.layout,
    this.imageHeroTag,
    this.loadingQuickAdd,
    this.loadingProduct,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = listingMedia.listingUrl;
    final resolvedHeroTag = imageHeroTag ?? productImageHeroTag(productId);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
    final imagePanel = Container(
      color: productDetailImageSurfaceColor,
      child: Padding(
        padding: layout.imagePanelPadding,
        child: AspectRatio(
          aspectRatio: layout.heroAspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final origin = layout.isMobile
                  ? pdpWaterRippleBackButtonOrigin(context, constraints.biggest)
                  : kPdpWaterRippleDefaultOrigin;
              return Hero(
                tag: resolvedHeroTag,
                flightShuttleBuilder: pdpHeroFlightShuttleBuilder(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  color: productDetailImageSurfaceColor,
                ),
                // The route scope holds this pulse until the Hero flight lands
                // and shares it with the loaded carousel if data resolves
                // mid-ripple. The shuttle above remains a plain image, so the
                // sampler never enters the Overlay flight.
                child: PdpWaterRipple(
                  enabled: !reduceMotion,
                  origin: origin,
                  duration: isPhone
                      ? const Duration(milliseconds: 650)
                      : const Duration(milliseconds: 1000),
                  intensity: isPhone ? 0.60 : 1.0,
                  child: Image(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    if (layout.isMobile) {
      // Mirrors MobileHeroBody, which wraps its image strip in
      // StorefrontFullBleed (product_detail_hero.dart MobileHeroBody.build).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StorefrontFullBleed(child: imagePanel),
          Padding(
            padding: layout.detailsPanelPadding,
            child: ProductDetailLoadingSkeleton(
              layout: layout,
              commerceSlot: loadingQuickAdd,
              loadingProduct: loadingProduct,
            ),
          ),
        ],
      );
    }
    final detailsPanel = Container(
      color: Colors.white,
      padding: layout.detailsPanelPadding,
      child: ProductDetailLoadingSkeleton(
        layout: layout,
        commerceSlot: loadingQuickAdd,
        loadingProduct: loadingProduct,
      ),
    );

    if (layout.isDesktop) {
      // Mirrors DesktopHeroBody. The sticky panel's initial offset is visible
      // even before the user scrolls; omitting it makes the desktop skeleton's
      // commerce stack start much higher than the loaded PDP.
      return LayoutBuilder(
        builder: (context, constraints) {
          final totalFlex = layout.heroImageFlex + layout.heroTextFlex;
          final leftWidth =
              constraints.maxWidth * (layout.heroImageFlex / totalFlex);
          final fallbackRightHeight = leftWidth / layout.heroAspectRatio;
          return StorefrontStickyPanels(
            leftFlex: layout.heroImageFlex,
            rightFlex: layout.heroTextFlex,
            fallbackRightHeight: fallbackRightHeight,
            topOffset: layout.stickyTopOffsetForViewport(
              MediaQuery.sizeOf(context).height,
            ),
            leftChild: imagePanel,
            rightChild: detailsPanel,
          );
        },
      );
    }

    // Mirrors SplitHeroBody. The tablet split layout is not sticky, so a
    // simple flex row is the matching loading geometry for that breakpoint.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: layout.heroImageFlex, child: imagePanel),
        Expanded(flex: layout.heroTextFlex, child: detailsPanel),
      ],
    );
  }
}

/// Wraps [PdpHeroPlaceholder] in the same scroll/section chrome the data
/// branch paints, so the loading and loaded layouts share one geometry.
Widget buildPdpLoadingHeroScaffoldBody({
  required String productId,
  required CatalogMedia listingMedia,
  required ProductDetailLayoutSpec layout,
  String? imageHeroTag,
  Widget? loadingQuickAdd,
  CatalogProduct? loadingProduct,
  Key? scrollKey,
}) {
  final placeholder = PdpHeroPlaceholder(
    productId: productId,
    imageHeroTag: imageHeroTag,
    listingMedia: listingMedia,
    layout: layout,
    loadingQuickAdd: loadingQuickAdd,
    loadingProduct: loadingProduct,
  );
  final heroSectionChild = layout.isWide
      ? StorefrontFullBleed(child: placeholder)
      : placeholder;
  return CustomScrollView(
    key: scrollKey,
    // Allow overscroll even when the skeleton is shorter than the viewport, so
    // the pull-to-hero-back drag is detectable during loading.
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverToBoxAdapter(
        child: StorefrontPageSection(
          maxWidth: layout.maxWidth,
          minHorizontalPadding: layout.horizontalPadding,
          padding: EdgeInsets.only(
            top: layout.heroTopPadding,
            bottom: layout.isMobile ? 40 : 56,
          ),
          child: heroSectionChild,
        ),
      ),
    ],
  );
}
