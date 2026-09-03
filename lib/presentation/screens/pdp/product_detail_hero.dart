import 'package:flutter/material.dart';

import '../../../domain/catalog/catalog_entities.dart';
import '../../l10n/l10n_extension.dart';
import '../../widgets/animations/text_reveal/text_reveal.dart';
import '../../providers/pending_media_provider.dart';
import '../../widgets/image_carousel.dart';
import '../../widgets/pdp_purchase_bar.dart';
import '../../widgets/product_size_dropdown.dart';
import '../../widgets/storefront_layout.dart';
import '../product_detail_layout_spec.dart';
import '../product_detail_narrative_section.dart';
import '../product_detail_price_block.dart';
import 'pdp_animated_heart_button.dart';
import 'product_detail_inline_editors.dart';
import 'product_detail_purchase.dart';
import 'product_detail_translations_sheet.dart';
import '../../widgets/holo_foil_overlay.dart';

class PdpHeroContext {
  final CatalogProduct product;
  final ProductDetailLayoutSpec layout;
  final Map<String, PendingMediaEntry> pendingMedia;
  final bool isEditMode;
  final List<CatalogMedia> allMedia;

  /// Wraps hero images with the holo-foil overlay when the product has a
  /// `product_foils` record (saved from the Foil studio). Disabled in edit
  /// mode; products without a foil render exactly as before.
  MediaOverlayBuilder? get mediaOverlayBuilder => isEditMode
      ? null
      : (media, fit, alignment, child) => HoloFoilOverlay(
          productId: product.id,
          media: media,
          fit: fit,
          alignment: alignment,
          child: child,
        );
  final CatalogPrice? defaultPrice;
  final double? originalPrice;
  final int? discount;
  final String symbol;
  final bool isNew;
  final bool hasVariantSelector;
  final Widget heroBreadcrumbOverlay;
  final Widget detailTabs;
  final GlobalKey? mobilePurchaseAnchorKey;
  final void Function(List<CatalogMedia> media, int index) onPickPhoto;
  final void Function(List<CatalogMedia> media, int index) onPickMedia;
  final void Function(List<CatalogMedia> media, int index) onRemoveMedia;
  final void Function(
    List<CatalogMedia> media,
    int currentIndex,
    int targetIndex,
  )
  onMoveMedia;
  final void Function(List<CatalogMedia> media, int index) onSetFirstMedia;
  final VoidCallback onAddMedia;
  final String? carouselScrollTargetMediaId;
  final ValueChanged<String> onCarouselScrollTargetHandled;
  final VoidCallback onEditTranslations;
  final Future<bool> Function(double value) onSavePrice;
  final Future<bool> Function() onAddToCart;
  final void Function(CatalogMedia currentImage)? onOpenVisionModal;
  final String? mainImageHeroTag;

  const PdpHeroContext({
    required this.product,
    required this.layout,
    required this.pendingMedia,
    required this.isEditMode,
    required this.allMedia,
    required this.defaultPrice,
    required this.originalPrice,
    required this.discount,
    required this.symbol,
    required this.isNew,
    required this.hasVariantSelector,
    required this.heroBreadcrumbOverlay,
    required this.detailTabs,
    required this.mobilePurchaseAnchorKey,
    required this.onPickPhoto,
    required this.onPickMedia,
    required this.onRemoveMedia,
    required this.onMoveMedia,
    required this.onSetFirstMedia,
    required this.onAddMedia,
    required this.carouselScrollTargetMediaId,
    required this.onCarouselScrollTargetHandled,
    required this.onEditTranslations,
    required this.onSavePrice,
    required this.onAddToCart,
    required this.onOpenVisionModal,
    required this.mainImageHeroTag,
  });

  _ProductSummaryPanel _summaryPanel({required bool showPurchaseCta}) {
    return _ProductSummaryPanel(
      product: product,
      defaultPrice: defaultPrice,
      originalPrice: originalPrice,
      discount: discount,
      symbol: symbol,
      isNew: isNew,
      hasVariantSelector: hasVariantSelector,
      layout: layout,
      showPurchaseCta: showPurchaseCta,
      mobilePurchaseAnchorKey: mobilePurchaseAnchorKey,
      isEditMode: isEditMode,
      onEditTranslations: onEditTranslations,
      onSavePrice: onSavePrice,
      onAddToCart: onAddToCart,
    );
  }
}

class _HeroImagePanel extends StatelessWidget {
  final PdpHeroContext heroContext;
  final Widget child;

  const _HeroImagePanel({required this.heroContext, required this.child});

  @override
  Widget build(BuildContext context) {
    // Pointer and tilt host for the holo-foil overlays. A loaded, matching
    // overlay registers itself before motion can start, so products without a
    // foil never touch the sensor or request permission.
    return HoloFoilPointerScope(
      enableMobileTilt: !heroContext.isEditMode,
      child: Container(
        color: productDetailImageSurfaceColor,
        child: Padding(
          padding: heroContext.layout.imagePanelPadding,
          child: child,
        ),
      ),
    );
  }
}

Widget _heroDetailsPanel({
  required ProductDetailLayoutSpec layout,
  required Widget child,
}) {
  return Container(
    color: Colors.white,
    padding: layout.detailsPanelPadding,
    child: child,
  );
}

class NarrativeHeroBody extends StatelessWidget {
  final PdpHeroContext heroContext;
  final List<CatalogMedia> narrativeMedia;
  final Map<String, NarrativeChapter> chaptersByMediaId;

  const NarrativeHeroBody({
    super.key,
    required this.heroContext,
    required this.narrativeMedia,
    required this.chaptersByMediaId,
  });

  @override
  Widget build(BuildContext context) {
    return NarrativePdpSection(
      product: heroContext.product,
      defaultPrice: heroContext.defaultPrice,
      symbol: heroContext.symbol,
      originalPrice: heroContext.originalPrice,
      discount: heroContext.discount,
      images: narrativeMedia,
      layout: heroContext.layout,
      chaptersByMediaId: chaptersByMediaId,
      pendingMedia: heroContext.pendingMedia,
      isEditMode: heroContext.isEditMode,
      onSavePrice: heroContext.onSavePrice,
      onPickPhoto: (index) => heroContext.onPickPhoto(narrativeMedia, index),
      onPickMedia: (index) => heroContext.onPickMedia(narrativeMedia, index),
      onRemoveMedia: (index) =>
          heroContext.onRemoveMedia(narrativeMedia, index),
      onMoveMedia: (currentIndex, targetIndex) =>
          heroContext.onMoveMedia(narrativeMedia, currentIndex, targetIndex),
      onSetFirstMedia: (index) =>
          heroContext.onSetFirstMedia(narrativeMedia, index),
      onAddMedia: heroContext.onAddMedia,
      scrollToMediaId: heroContext.carouselScrollTargetMediaId,
      onScrollToMediaHandled: heroContext.onCarouselScrollTargetHandled,
      onAddToCart: heroContext.onAddToCart,
      trailingContent: heroContext.detailTabs,
      topLeftOverlay: heroContext.heroBreadcrumbOverlay,
      onOpenMainImageVisionModal: heroContext.onOpenVisionModal,
    );
  }
}

class DesktopHeroBody extends StatelessWidget {
  final PdpHeroContext heroContext;

  const DesktopHeroBody({super.key, required this.heroContext});

  static double _estimateMediaColumnHeight({
    required double availableWidth,
    required ProductDetailLayoutSpec layout,
    required int imageCount,
    required double spacing,
  }) {
    final totalFlex = layout.heroImageFlex + layout.heroTextFlex;
    final leftWidth = availableWidth * (layout.heroImageFlex / totalFlex);
    final clampedCount = imageCount <= 0 ? 1 : imageCount;
    final panelPadding = layout.imagePanelPadding.vertical;
    final imageHeight = leftWidth / layout.heroAspectRatio;
    return panelPadding +
        (imageHeight * clampedCount) +
        (spacing * (clampedCount - 1));
  }

  @override
  Widget build(BuildContext context) {
    final layout = heroContext.layout;
    final allMedia = heroContext.allMedia;
    final isEditMode = heroContext.isEditMode;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktopMediaHeight = _estimateMediaColumnHeight(
          availableWidth: constraints.maxWidth,
          layout: layout,
          imageCount: isEditMode ? 1 : allMedia.length,
          spacing: 0,
        );
        return StorefrontStickyPanels(
          leftFlex: layout.heroImageFlex,
          rightFlex: layout.heroTextFlex,
          fallbackRightHeight: desktopMediaHeight,
          topOffset: layout.stickyTopOffsetForViewport(
            MediaQuery.sizeOf(context).height,
          ),
          leftChild: _HeroImagePanel(
            heroContext: heroContext,
            child: isEditMode
                ? ImageCarousel(
                    images: allMedia,
                    pendingMedia: heroContext.pendingMedia,
                    aspectRatio: layout.heroAspectRatio,
                    imageFit: BoxFit.contain,
                    imageAlignment: Alignment.center,
                    showThumbnailRail: false,
                    showShoppingOverlays: false,
                    mainImageThumbSize:
                        CatalogMedia.productDetailDesktopThumbSize,
                    thumbnailThumbSize: CatalogMedia.galleryThumbnailThumbSize,
                    isEditMode: isEditMode,
                    onPickPhoto: (index) =>
                        heroContext.onPickPhoto(allMedia, index),
                    onPickMedia: (index) =>
                        heroContext.onPickMedia(allMedia, index),
                    onRemoveMedia: (index) =>
                        heroContext.onRemoveMedia(allMedia, index),
                    onMoveMedia: (currentIndex, targetIndex) => heroContext
                        .onMoveMedia(allMedia, currentIndex, targetIndex),
                    onSetFirstMedia: (index) =>
                        heroContext.onSetFirstMedia(allMedia, index),
                    onAddMedia: heroContext.onAddMedia,
                    scrollToMediaId: heroContext.carouselScrollTargetMediaId,
                    onScrollToMediaHandled:
                        heroContext.onCarouselScrollTargetHandled,
                    topLeftOverlay: heroContext.heroBreadcrumbOverlay,
                    onOpenMainImageVisionModal: heroContext.onOpenVisionModal,
                    mainImageHeroTag: heroContext.mainImageHeroTag,
                    mediaOverlayBuilder: heroContext.mediaOverlayBuilder,
                  )
                : DesktopImageStack(
                    images: allMedia,
                    pendingMedia: heroContext.pendingMedia,
                    aspectRatio: layout.heroAspectRatio,
                    imageFit: BoxFit.cover,
                    imageThumbSize: CatalogMedia.productDetailDesktopThumbSize,
                    spacing: 0,
                    firstImageTopLeftOverlay: heroContext.heroBreadcrumbOverlay,
                    mainImageHeroTag: heroContext.mainImageHeroTag,
                    mediaOverlayBuilder: heroContext.mediaOverlayBuilder,
                  ),
          ),
          rightChild: _heroDetailsPanel(
            layout: layout,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                heroContext._summaryPanel(showPurchaseCta: true),
                const SizedBox(height: 34),
                heroContext.detailTabs,
              ],
            ),
          ),
        );
      },
    );
  }
}

class SplitHeroBody extends StatelessWidget {
  final PdpHeroContext heroContext;

  const SplitHeroBody({super.key, required this.heroContext});

  @override
  Widget build(BuildContext context) {
    final layout = heroContext.layout;
    final allMedia = heroContext.allMedia;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: layout.heroImageFlex,
          child: _HeroImagePanel(
            heroContext: heroContext,
            child: ImageCarousel(
              images: allMedia,
              pendingMedia: heroContext.pendingMedia,
              aspectRatio: layout.heroAspectRatio,
              imageFit: BoxFit.contain,
              imageAlignment: Alignment.center,
              showThumbnailRail: false,
              showShoppingOverlays: false,
              mainImageThumbSize: CatalogMedia.productDetailTabletThumbSize,
              thumbnailThumbSize: CatalogMedia.galleryThumbnailThumbSize,
              isEditMode: heroContext.isEditMode,
              onPickPhoto: (index) => heroContext.onPickPhoto(allMedia, index),
              onPickMedia: (index) => heroContext.onPickMedia(allMedia, index),
              onRemoveMedia: (index) =>
                  heroContext.onRemoveMedia(allMedia, index),
              onMoveMedia: (currentIndex, targetIndex) =>
                  heroContext.onMoveMedia(allMedia, currentIndex, targetIndex),
              onSetFirstMedia: (index) =>
                  heroContext.onSetFirstMedia(allMedia, index),
              onAddMedia: heroContext.onAddMedia,
              scrollToMediaId: heroContext.carouselScrollTargetMediaId,
              onScrollToMediaHandled: heroContext.onCarouselScrollTargetHandled,
              topLeftOverlay: heroContext.heroBreadcrumbOverlay,
              onOpenMainImageVisionModal: heroContext.onOpenVisionModal,
              mainImageHeroTag: heroContext.mainImageHeroTag,
              mediaOverlayBuilder: heroContext.mediaOverlayBuilder,
            ),
          ),
        ),
        Expanded(
          flex: layout.heroTextFlex,
          child: _heroDetailsPanel(
            layout: layout,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heroContext._summaryPanel(showPurchaseCta: true),
                const SizedBox(height: 30),
                heroContext.detailTabs,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MobileHeroBody extends StatelessWidget {
  final PdpHeroContext heroContext;

  const MobileHeroBody({super.key, required this.heroContext});

  @override
  Widget build(BuildContext context) {
    final layout = heroContext.layout;
    final allMedia = heroContext.allMedia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StorefrontFullBleed(
          child: _HeroImagePanel(
            heroContext: heroContext,
            child: ImageCarousel(
              images: allMedia,
              pendingMedia: heroContext.pendingMedia,
              aspectRatio: layout.heroAspectRatio,
              imageFit: BoxFit.contain,
              imageAlignment: Alignment.center,
              showShoppingOverlays: false,
              mainImageThumbSize: CatalogMedia.productDetailMobileThumbSize,
              isEditMode: heroContext.isEditMode,
              onPickPhoto: (index) => heroContext.onPickPhoto(allMedia, index),
              onPickMedia: (index) => heroContext.onPickMedia(allMedia, index),
              onRemoveMedia: (index) =>
                  heroContext.onRemoveMedia(allMedia, index),
              onMoveMedia: (currentIndex, targetIndex) =>
                  heroContext.onMoveMedia(allMedia, currentIndex, targetIndex),
              onSetFirstMedia: (index) =>
                  heroContext.onSetFirstMedia(allMedia, index),
              onAddMedia: heroContext.onAddMedia,
              scrollToMediaId: heroContext.carouselScrollTargetMediaId,
              onScrollToMediaHandled: heroContext.onCarouselScrollTargetHandled,
              topLeftOverlay: heroContext.heroBreadcrumbOverlay,
              onOpenMainImageVisionModal: heroContext.onOpenVisionModal,
              mainImageHeroTag: heroContext.mainImageHeroTag,
              mediaOverlayBuilder: heroContext.mediaOverlayBuilder,
            ),
          ),
        ),
        Padding(
          padding: layout.detailsPanelPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heroContext._summaryPanel(showPurchaseCta: false),
              const SizedBox(height: 28),
              heroContext.detailTabs,
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductSummaryPanel extends StatelessWidget {
  final CatalogProduct product;
  final CatalogPrice? defaultPrice;
  final double? originalPrice;
  final int? discount;
  final String symbol;
  final bool isNew;
  final bool hasVariantSelector;
  final ProductDetailLayoutSpec layout;
  final bool showPurchaseCta;
  final GlobalKey? mobilePurchaseAnchorKey;
  final bool isEditMode;
  final VoidCallback? onEditTranslations;
  final Future<bool> Function(double value)? onSavePrice;
  final Future<bool> Function()? onAddToCart;

  const _ProductSummaryPanel({
    required this.product,
    required this.defaultPrice,
    required this.originalPrice,
    required this.discount,
    required this.symbol,
    required this.isNew,
    required this.hasVariantSelector,
    required this.layout,
    required this.showPurchaseCta,
    required this.mobilePurchaseAnchorKey,
    required this.isEditMode,
    this.onEditTranslations,
    this.onSavePrice,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = layout.isMobile;
    final useNoVariantMobileCommerce = isMobile && !hasVariantSelector;
    final subtitle = _subtitleText;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNew)
          Text(
            'Nouveauté',
            style: TextStyle(
              fontSize: layout.referenceFontSize,
              fontWeight: FontWeight.w400,
              color: productDetailMutedTextColor,
            ),
          ),
        if (isNew) SizedBox(height: isMobile ? 10 : 18),
        _ProductSummaryTextReveal(
          product: product,
          subtitle: subtitle,
          layout: layout,
          isEditMode: isEditMode,
          onEditTranslations: onEditTranslations,
        ),
        if (isEditMode ||
            (!useNoVariantMobileCommerce &&
                !showPurchaseCta &&
                defaultPrice != null &&
                mobilePurchaseAnchorKey == null) ||
            (!useNoVariantMobileCommerce &&
                defaultPrice != null &&
                (originalPrice != null || discount != null))) ...[
          SizedBox(height: isMobile ? 14 : 18),
          ProductDetailPriceBlock(
            defaultPrice: defaultPrice,
            originalPrice: originalPrice,
            discount: discount,
            symbol: symbol,
            layout: layout,
            isEditMode: isEditMode,
            showStandaloneValue:
                !showPurchaseCta ||
                mobilePurchaseAnchorKey == null ||
                originalPrice != null ||
                discount != null ||
                isEditMode,
            onSave: onSavePrice,
          ),
        ],
        if (hasVariantSelector) ...[
          SizedBox(height: isMobile ? 24 : 28),
          Text(
            context.l10n.pdpSelectYourSize,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: const Color(0xFF666661),
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: isMobile ? 8 : 10),
          const ProductSizeDropdown(),
          SizedBox(height: isMobile ? 9 : 10),
          Text(
            context.l10n.pdpSizeGuideLink,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Color(0xFF595956),
              decoration: TextDecoration.underline,
            ),
          ),
          if (mobilePurchaseAnchorKey != null) ...[
            SizedBox(height: isMobile ? 20 : 24),
            MobilePurchaseAnchor(
              key: mobilePurchaseAnchorKey,
              child: PdpPurchaseBar(
                defaultPrice: defaultPrice,
                symbol: symbol,
                onAddToCart: onAddToCart ?? () async => false,
                includeSafeArea: false,
                height: kMobilePurchaseBarHeight,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ],
        if (useNoVariantMobileCommerce) ...[
          const SizedBox(height: 30),
          NoVariantMobileCommerceSection(
            defaultPrice: defaultPrice,
            symbol: symbol,
            onAddToCart: onAddToCart,
            purchaseAnchorKey: mobilePurchaseAnchorKey,
          ),
        ] else if (showPurchaseCta) ...[
          SizedBox(height: isMobile ? 20 : 46),
          if (layout.isDesktop) ...[
            const PdpPaymentBadges(compact: true),
            const SizedBox(height: 14),
          ],
          HeroPurchaseButton(
            defaultPrice: defaultPrice,
            symbol: symbol,
            onPressed: onAddToCart,
          ),
          SizedBox(height: layout.isDesktop ? 14 : 12),
          if (layout.isDesktop) ...[
            const BoutiqueReservationButton(),
            const SizedBox(height: 22),
            const DesktopPurchaseServices(),
            const SizedBox(height: 46),
          ] else
            const ExpressPurchaseHint(),
        ],
      ],
    );

    return Padding(padding: layout.summaryPadding, child: content);
  }

  String? get _subtitleText {
    final brand = product.brand?.trim();
    final productType = product.productType?.trim();
    if (brand != null && brand.isNotEmpty) {
      return productType != null && productType.isNotEmpty
          ? '$productType • $brand'
          : brand;
    }
    if (productType != null && productType.isNotEmpty) {
      return productType;
    }
    return null;
  }
}

class _ProductSummaryTextReveal extends StatelessWidget {
  final CatalogProduct product;
  final String? subtitle;
  final ProductDetailLayoutSpec layout;
  final bool isEditMode;
  final VoidCallback? onEditTranslations;

  const _ProductSummaryTextReveal({
    required this.product,
    required this.subtitle,
    required this.layout,
    required this.isEditMode,
    required this.onEditTranslations,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = layout.isMobile;
    final favoriteSize = isMobile ? 22.0 : 20.0;
    const favoriteTapSize = PdpAnimatedHeartButton.minTapSize;
    final favoriteTop = isMobile ? 2.0 : 4.0;
    final titleRightPadding = favoriteTapSize;
    final slug = product.slug?.trim();
    final slugOrCode = slug != null && slug.isNotEmpty
        ? slug
        : product.code.trim();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        TextRevealGroup(
          key: ValueKey('pdp-summary-text-${product.id}-$slugOrCode'),
          trigger: TextRevealTrigger.mount,
          enabled: !isEditMode,
          duration: const Duration(milliseconds: 600),
          stagger: const Duration(milliseconds: 80),
          translateY: 16,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextRevealItem(
              child: Padding(
                padding: EdgeInsets.only(right: titleRightPadding),
                child: EditableProductName(
                  name: product.name,
                  isEditMode: false,
                  layout: layout,
                ),
              ),
            ),
            if (isEditMode && onEditTranslations != null) ...[
              const SizedBox(height: 10),
              TextRevealItem(
                child: EditActionButton(
                  label: 'Traductions',
                  semanticsLabel: kPdpTranslationsEditorSemanticsLabel,
                  semanticsIdentifier:
                      kPdpTranslationsEditorSemanticsIdentifier,
                  onPressed: onEditTranslations!,
                ),
              ),
            ],
            if (layout.isDesktop) ...[
              const SizedBox(height: 8),
              TextRevealItem(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null)
                      Expanded(
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: layout.subtitleFontSize,
                            color: const Color(0xFF6F6F6B),
                            height: 1.24,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 18),
                    Text(
                      context.l10n.pdpReference(product.code),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: layout.referenceFontSize,
                        color: productDetailMutedTextColor,
                        height: 1.24,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (subtitle != null) ...[
                SizedBox(height: isMobile ? 2 : 6),
                TextRevealItem(
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: layout.subtitleFontSize,
                      color: const Color(0xFF6F6F6B),
                      height: 1.18,
                    ),
                  ),
                ),
              ],
              SizedBox(height: isMobile ? 2 : 4),
              TextRevealItem(
                child: Text(
                  context.l10n.pdpReference(product.code),
                  style: TextStyle(
                    fontSize: layout.referenceFontSize,
                    color: productDetailMutedTextColor,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
        Positioned(
          top: favoriteTop - (favoriteTapSize - favoriteSize) / 2,
          right: -(favoriteTapSize - favoriteSize) / 2,
          child: PdpAnimatedHeartButton(size: favoriteSize),
        ),
      ],
    );
  }
}
