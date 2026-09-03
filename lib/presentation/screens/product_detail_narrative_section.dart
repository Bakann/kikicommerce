import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/price_utils.dart';
import '../../core/utils/string_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../l10n/l10n_extension.dart';
import '../providers/pending_media_provider.dart';
import 'product_detail_narrative_logic.dart';
import 'product_detail_layout_spec.dart';
import 'product_detail_price_block.dart';
import 'pdp/pdp_animated_heart_button.dart';
import '../widgets/image_carousel.dart';
import '../widgets/kiki_image.dart';
import '../widgets/product_size_dropdown.dart';
import '../widgets/storefront_layout.dart';

class NarrativePdpSection extends StatefulWidget {
  final CatalogProduct product;
  final CatalogPrice? defaultPrice;
  final double? originalPrice;
  final int? discount;
  final String symbol;
  final List<CatalogMedia> images;
  final ProductDetailLayoutSpec layout;
  final Map<String, NarrativeChapter> chaptersByMediaId;
  final Map<String, PendingMediaEntry> pendingMedia;
  final bool isEditMode;
  final Future<bool> Function(double value)? onSavePrice;
  final void Function(int currentIndex)? onPickPhoto;
  final void Function(int currentIndex)? onPickMedia;
  final void Function(int currentIndex)? onRemoveMedia;
  final void Function(int currentIndex, int targetIndex)? onMoveMedia;
  final void Function(int currentIndex)? onSetFirstMedia;
  final VoidCallback? onAddMedia;
  final String? scrollToMediaId;
  final ValueChanged<String>? onScrollToMediaHandled;
  final Future<bool> Function()? onAddToCart;
  final Widget? trailingContent;
  final Widget? topLeftOverlay;
  final void Function(CatalogMedia currentImage)? onOpenMainImageVisionModal;

  const NarrativePdpSection({
    super.key,
    required this.product,
    required this.defaultPrice,
    required this.originalPrice,
    required this.discount,
    required this.symbol,
    required this.images,
    required this.layout,
    required this.chaptersByMediaId,
    required this.pendingMedia,
    required this.isEditMode,
    this.onSavePrice,
    this.onPickPhoto,
    this.onPickMedia,
    this.onRemoveMedia,
    this.onMoveMedia,
    this.onSetFirstMedia,
    this.onAddMedia,
    this.scrollToMediaId,
    this.onScrollToMediaHandled,
    this.onAddToCart,
    this.trailingContent,
    this.topLeftOverlay,
    this.onOpenMainImageVisionModal,
  });

  @override
  State<NarrativePdpSection> createState() => _NarrativePdpSectionState();
}

class _NarrativePdpSectionState extends State<NarrativePdpSection> {
  late final PageController _pageController;
  late List<GlobalKey> _imageKeys;
  ScrollPosition? _scrollPosition;
  bool _indexSyncScheduled = false;
  // Held in a ValueNotifier so a scroll-driven index change only rebuilds the
  // story card + progress bar (via ValueListenableBuilder), not the whole
  // section — the image stack/carousel are index-independent.
  final ValueNotifier<int> _currentIndex = ValueNotifier<int>(0);

  bool get _usesDesktopImageStack =>
      widget.layout.isDesktop && !widget.isEditMode;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(keepPage: false);
    _imageKeys = _buildImageKeys();
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_handleScroll);
    _pageController.dispose();
    _currentIndex.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachScrollPosition();
    _scheduleIndexSync();
  }

  @override
  void didUpdateWidget(covariant NarrativePdpSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUsedDesktopImageStack =
        oldWidget.layout.isDesktop && !oldWidget.isEditMode;
    if (oldWidget.images.length != widget.images.length) {
      _imageKeys = _buildImageKeys();
      _currentIndex.value = widget.images.isEmpty
          ? 0
          : math.min(_currentIndex.value, widget.images.length - 1);
    }
    _attachScrollPosition();
    _scheduleIndexSync();
    if (oldUsedDesktopImageStack && !_usesDesktopImageStack) {
      _scheduleCarouselIndexSync();
    }
  }

  List<GlobalKey> _buildImageKeys() =>
      List<GlobalKey>.generate(widget.images.length, (_) => GlobalKey());

  void _attachScrollPosition() {
    final nextPosition = _usesDesktopImageStack
        ? Scrollable.maybeOf(context)?.position
        : null;
    if (_scrollPosition == nextPosition) {
      return;
    }
    _scrollPosition?.removeListener(_handleScroll);
    _scrollPosition = nextPosition;
    _scrollPosition?.addListener(_handleScroll);
  }

  void _handleScroll() {
    _scheduleIndexSync();
  }

  void _scheduleIndexSync() {
    if (!_usesDesktopImageStack || !mounted || _indexSyncScheduled) {
      return;
    }
    _indexSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _indexSyncScheduled = false;
      _syncCurrentIndexToVisibleImage();
    });
  }

  void _scheduleCarouselIndexSync() {
    if (!mounted || _usesDesktopImageStack || widget.images.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _usesDesktopImageStack || widget.images.isEmpty) {
        return;
      }
      final targetIndex = _currentIndex.value.clamp(
        0,
        widget.images.length - 1,
      );
      if (!_pageController.hasClients) {
        return;
      }
      final currentPage = _pageController.page ?? _pageController.initialPage;
      if ((currentPage - targetIndex).abs() < 0.01) {
        return;
      }
      _pageController.jumpToPage(targetIndex);
    });
  }

  void _syncCurrentIndexToVisibleImage() {
    if (!_usesDesktopImageStack || !mounted || widget.images.isEmpty) {
      return;
    }

    final viewportHeight = MediaQuery.sizeOf(context).height;
    final anchorY = math
        .min(viewportHeight * 0.36, viewportHeight - 120)
        .clamp(0.0, viewportHeight);

    NarrativeViewportSample? getSample(int index) {
      if (index < 0 || index >= _imageKeys.length) return null;
      final box =
          _imageKeys[index].currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      final top = box.localToGlobal(Offset.zero).dy;
      return NarrativeViewportSample(
        index: index,
        top: top,
        bottom: top + box.size.height,
      );
    }

    final samples = <NarrativeViewportSample>[];
    final activeIndex = _currentIndex.value;
    final currentSample = getSample(activeIndex);

    if (currentSample != null) {
      samples.add(currentSample);
      if (currentSample.bottom < anchorY) {
        // Scrolled down (image moved up). Check next images.
        for (int i = activeIndex + 1; i < _imageKeys.length; i++) {
          final sample = getSample(i);
          if (sample != null) {
            samples.add(sample);
            if (sample.bottom >= anchorY) break;
          }
        }
      } else if (currentSample.top > anchorY) {
        // Scrolled up (image moved down). Check previous images.
        for (int i = activeIndex - 1; i >= 0; i--) {
          final sample = getSample(i);
          if (sample != null) {
            samples.add(sample);
            if (sample.top <= anchorY) break;
          }
        }
      }
    } else {
      // Fallback: evaluate all if we lost the current
      for (int i = 0; i < _imageKeys.length; i++) {
        final sample = getSample(i);
        if (sample != null) {
          samples.add(sample);
        }
      }
    }

    if (samples.isEmpty) {
      return;
    }

    final nextIndex = resolveNarrativeActiveIndex(
      samples: samples,
      anchorY: anchorY,
    );
    if (nextIndex == _currentIndex.value) {
      return;
    }

    _currentIndex.value = nextIndex;
  }

  Future<void> _scrollToDesktopImage(int index) async {
    if (!_usesDesktopImageStack) {
      return;
    }

    final targetContext = _imageKeys[index].currentContext;
    final box = targetContext?.findRenderObject() as RenderBox?;
    final scrollPosition = _scrollPosition;
    if (box == null || !box.hasSize || scrollPosition == null) {
      return;
    }

    final desiredTop = 24.0;
    final topInViewport = box.localToGlobal(Offset.zero).dy;
    final targetPixels = scrollPosition.pixels + topInViewport - desiredTop;

    await scrollPosition.animateTo(
      targetPixels.clamp(
        scrollPosition.minScrollExtent,
        scrollPosition.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  double _estimateDesktopMediaColumnHeight(double availableWidth) {
    final totalFlex = widget.layout.heroImageFlex + widget.layout.heroTextFlex;
    final leftWidth =
        availableWidth * (widget.layout.heroImageFlex / totalFlex);
    final imageCount = _usesDesktopImageStack ? widget.images.length : 1;
    final panelPadding = widget.layout.imagePanelPadding.vertical;
    final imageHeight = leftWidth / widget.layout.heroAspectRatio;
    return panelPadding + (imageHeight * imageCount);
  }

  @override
  Widget build(BuildContext context) {
    final desktopImageStack = DesktopImageStack(
      images: widget.images,
      pendingMedia: widget.pendingMedia,
      itemKeys: _imageKeys,
      aspectRatio: widget.layout.heroAspectRatio,
      imageFit: BoxFit.cover,
      imageThumbSize: CatalogMedia.productDetailDesktopThumbSize,
      firstImageTopLeftOverlay: widget.topLeftOverlay,
      spacing: 0,
    );
    final carousel = ImageCarousel(
      controller: _pageController,
      images: widget.images,
      pendingMedia: widget.pendingMedia,
      aspectRatio: widget.layout.heroAspectRatio,
      imageFit: widget.layout.isMobile ? BoxFit.cover : BoxFit.contain,
      imageAlignment: widget.layout.isMobile
          ? Alignment.topCenter
          : Alignment.center,
      showThumbnailRail: false,
      showShoppingOverlays: false,
      showPageIndicators: false,
      mainImageThumbSize: widget.layout.isDesktop
          ? CatalogMedia.productDetailDesktopThumbSize
          : (widget.layout.isSplit
                ? CatalogMedia.productDetailTabletThumbSize
                : CatalogMedia.productDetailMobileThumbSize),
      thumbnailThumbSize: CatalogMedia.galleryThumbnailThumbSize,
      isEditMode: widget.isEditMode,
      onPickPhoto: widget.onPickPhoto,
      onPickMedia: widget.onPickMedia,
      onRemoveMedia: widget.onRemoveMedia,
      onMoveMedia: widget.onMoveMedia,
      onSetFirstMedia: widget.onSetFirstMedia,
      onAddMedia: widget.onAddMedia,
      scrollToMediaId: widget.scrollToMediaId,
      onScrollToMediaHandled: widget.onScrollToMediaHandled,
      onPageChanged: (index) => _currentIndex.value = index,
      topLeftOverlay: widget.topLeftOverlay,
      onOpenMainImageVisionModal: widget.onOpenMainImageVisionModal,
    );

    final storyCard = ValueListenableBuilder<int>(
      valueListenable: _currentIndex,
      builder: (context, index, _) => _NarrativeStoryCard(
        chapter: widget.chaptersByMediaId[widget.images[index].id]!,
        product: widget.product,
        currentMedia: widget.images[index],
        layout: widget.layout,
      ),
    );
    final progressBar = ValueListenableBuilder<int>(
      valueListenable: _currentIndex,
      builder: (context, index, _) => _NarrativeProgressBar(
        currentIndex: index,
        itemCount: widget.images.length,
        onTapIndex: (tappedIndex) => _usesDesktopImageStack
            ? _scrollToDesktopImage(tappedIndex)
            : _pageController.animateToPage(
                tappedIndex,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              ),
      ),
    );
    final summary = _CompactProductSummary(
      product: widget.product,
      defaultPrice: widget.defaultPrice,
      originalPrice: widget.originalPrice,
      discount: widget.discount,
      symbol: widget.symbol,
      layout: widget.layout,
      isEditMode: widget.isEditMode,
      showPurchaseCta: !widget.layout.isMobile,
      onSavePrice: widget.onSavePrice,
      onAddToCart: widget.onAddToCart,
    );
    final trailingContent = widget.trailingContent;
    Widget imagePanel(Widget child) => Container(
      color: productDetailImageSurfaceColor,
      child: Padding(padding: widget.layout.imagePanelPadding, child: child),
    );
    Widget detailsPanel(Widget child) => Container(
      color: Colors.white,
      padding: widget.layout.detailsPanelPadding,
      child: child,
    );

    if (widget.layout.isDesktop) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final desktopMediaHeight = _estimateDesktopMediaColumnHeight(
            constraints.maxWidth,
          );
          return StorefrontStickyPanels(
            leftFlex: widget.layout.heroImageFlex,
            rightFlex: widget.layout.heroTextFlex,
            fallbackRightHeight: desktopMediaHeight,
            topOffset: widget.layout.stickyTopOffsetForViewport(
              MediaQuery.sizeOf(context).height,
            ),
            leftChild: imagePanel(
              _usesDesktopImageStack ? desktopImageStack : carousel,
            ),
            rightChild: detailsPanel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  storyCard,
                  const SizedBox(height: 24),
                  progressBar,
                  const SizedBox(height: 28),
                  summary,
                  if (trailingContent != null) ...[
                    const SizedBox(height: 30),
                    trailingContent,
                  ],
                ],
              ),
            ),
          );
        },
      );
    }

    if (widget.layout.isSplit) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: widget.layout.heroImageFlex,
            child: imagePanel(carousel),
          ),
          Expanded(
            flex: widget.layout.heroTextFlex,
            child: detailsPanel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  storyCard,
                  const SizedBox(height: 22),
                  progressBar,
                  const SizedBox(height: 26),
                  summary,
                  if (trailingContent != null) ...[
                    const SizedBox(height: 28),
                    trailingContent,
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StorefrontFullBleed(child: imagePanel(carousel)),
        Padding(
          padding: widget.layout.detailsPanelPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              storyCard,
              const SizedBox(height: 18),
              progressBar,
              const SizedBox(height: 24),
              summary,
              if (trailingContent != null) ...[
                const SizedBox(height: 28),
                trailingContent,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrativeStoryCard extends StatelessWidget {
  final NarrativeChapter chapter;
  final CatalogProduct product;
  final CatalogMedia currentMedia;
  final ProductDetailLayoutSpec layout;

  const _NarrativeStoryCard({
    required this.chapter,
    required this.product,
    required this.currentMedia,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Container(
        key: ValueKey(chapter.id),
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: productDetailDividerColor)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.pdpChapterLabel(chapter.position),
              style: TextStyle(
                fontSize: 12,
                color: productDetailMutedTextColor,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              chapter.headline,
              style: GoogleFonts.notoSerif(
                fontSize: _headlineFontSize(context),
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2D2D2A),
                height: 1.12,
              ),
            ),
            if ((chapter.story ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                chapter.story!,
                style: TextStyle(
                  fontSize: layout.isDesktop ? 15 : 14,
                  height: 1.65,
                  color: const Color(0xFF676762),
                ),
              ),
            ],
            if (_showsCta) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => _handleCta(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2F2F2C),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                ),
                child: Text(
                  chapter.ctaLabel!,
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _showsCta =>
      (chapter.ctaLabel ?? '').trim().isNotEmpty &&
      chapter.ctaAction != NarrativeCtaAction.none;

  double _headlineFontSize(BuildContext context) {
    if (layout.isDesktop) return 26;
    if (layout.isSplit) return 22;
    return 20;
  }

  Future<void> _handleCta(BuildContext context) async {
    switch (chapter.ctaAction) {
      case NarrativeCtaAction.zoom:
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: KikiImage(
                imageUrl: currentMedia.originalUrl ?? currentMedia.url,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      case NarrativeCtaAction.sizeGuide:
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => _NarrativeSheet(
            title: context.l10n.pdpSizeGuideTitle,
            body: context.l10n.pdpSizeGuideBody,
          ),
        );
      case NarrativeCtaAction.materialDetail:
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => _NarrativeSheet(
            title: context.l10n.pdpMaterialDetailsTitle,
            body: stripHtml(product.summary ?? '').trim().isEmpty
                ? context.l10n.pdpMaterialDetailsEmpty
                : stripHtml(product.summary ?? ''),
          ),
        );
      case NarrativeCtaAction.none:
        break;
    }
  }
}

class _NarrativeSheet extends StatelessWidget {
  final String title;
  final String body;

  const _NarrativeSheet({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(body, style: const TextStyle(fontSize: 15, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

class _NarrativeProgressBar extends StatelessWidget {
  final int currentIndex;
  final int itemCount;
  final ValueChanged<int> onTapIndex;

  const _NarrativeProgressBar({
    required this.currentIndex,
    required this.itemCount,
    required this.onTapIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var index = 0; index < itemCount; index++) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => onTapIndex(index),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: index == currentIndex
                          ? const Color(0xFF2D2D2A)
                          : const Color(0xFFD7D4CE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              if (index < itemCount - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.pdpProgressCount(currentIndex + 1, itemCount),
          style: const TextStyle(
            fontSize: 12,
            color: productDetailMutedTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CompactProductSummary extends StatelessWidget {
  final CatalogProduct product;
  final CatalogPrice? defaultPrice;
  final double? originalPrice;
  final int? discount;
  final String symbol;
  final ProductDetailLayoutSpec layout;
  final bool isEditMode;
  final bool showPurchaseCta;
  final Future<bool> Function(double value)? onSavePrice;
  final Future<bool> Function()? onAddToCart;

  const _CompactProductSummary({
    required this.product,
    required this.defaultPrice,
    required this.originalPrice,
    required this.discount,
    required this.symbol,
    required this.layout,
    required this.isEditMode,
    required this.showPurchaseCta,
    this.onSavePrice,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = layout.isMobile;
    return Padding(
      padding: layout.summaryPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: layout.isDesktop ? 34 : 24,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2F2F2C),
                    height: isMobile ? 0.98 : 1.08,
                    letterSpacing: isMobile ? -0.15 : -0.35,
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              PdpAnimatedHeartButton(size: isMobile ? 22 : 20),
            ],
          ),
          if (product.productType?.trim().isNotEmpty ?? false) ...[
            SizedBox(height: isMobile ? 2 : 6),
            Text(
              product.productType!.trim(),
              style: TextStyle(
                fontSize: layout.subtitleFontSize,
                color: const Color(0xFF6F6F6B),
                height: 1.18,
              ),
            ),
          ],
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            context.l10n.pdpReference(product.code),
            style: TextStyle(
              fontSize: layout.referenceFontSize,
              color: productDetailMutedTextColor,
              height: 1.2,
            ),
          ),
          if (defaultPrice != null || isEditMode) ...[
            SizedBox(height: isMobile ? 14 : 16),
            ProductDetailPriceBlock(
              defaultPrice: defaultPrice,
              originalPrice: originalPrice,
              discount: discount,
              symbol: symbol,
              layout: layout,
              isEditMode: isEditMode,
              showStandaloneValue: defaultPrice != null || isEditMode,
              onSave: onSavePrice,
            ),
          ],
          SizedBox(height: isMobile ? 24 : 28),
          Text(
            context.l10n.pdpSelectYourSize,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Color(0xFF666661),
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
          if (showPurchaseCta && onAddToCart != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A2A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: const RoundedRectangleBorder(),
                ),
                onPressed: () async {
                  // No inline error UI here, so report failure via a SnackBar.
                  final ok = await onAddToCart!();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.l10n.pdpCartAddFailed)),
                    );
                  }
                },
                child: Row(
                  children: [
                    Expanded(child: Text(context.l10n.pdpAddToCart)),
                    if (defaultPrice != null)
                      Text(
                        formatPrice(defaultPrice!.price, symbol),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFF2F1EE),
              child: Text(
                context.l10n.pdpExpressCheckout,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9C9C98),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
