import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../providers/pending_media_provider.dart';
import 'kiki_image.dart';
import 'pdp_water_ripple_image.dart';
import 'product_hero_tags.dart';

const imageCarouselProductImageEditorSemanticsLabel =
    "Ouvrir l'éditeur de l'image produit";
const imageCarouselProductImageEditorSemanticsIdentifier =
    'product-image-editor-trigger';
const imageCarouselAddImageSemanticsLabel =
    'Ajouter une image au carousel produit';
const imageCarouselAddImageSemanticsIdentifier =
    'product-image-carousel-add-trigger';
const imageCarouselRemoveImageSemanticsLabel =
    'Supprimer cette image du carousel produit';
const imageCarouselRemoveImageSemanticsIdentifier =
    'product-image-carousel-remove-trigger';
const imageCarouselSetFirstImageSemanticsLabel =
    'Afficher cette image en premier sur la PDP';
const imageCarouselSetFirstImageSemanticsIdentifier =
    'product-image-carousel-set-first-trigger';

// Background used at Hero landing so the destination keeps painting the
// already-warm listing variant while the larger PDP-thumb variant loads and
// fades in. A plain CachedNetworkImage placeholder is not enough: it is removed
// during the fade, which can briefly reveal the empty image surface.
Widget _landingPlaceholder(
  CatalogMedia media,
  BoxFit fit,
  Alignment alignment,
) {
  return Image(
    image: NetworkImage(media.listingUrl),
    fit: fit,
    alignment: alignment,
    gaplessPlayback: true,
    // Match the Hero shuttle and KikiImage default so shuttle →
    // placeholder → real image stays visually continuous.
    filterQuality: FilterQuality.medium,
    // errorBuilder keeps the widget tree valid in widget tests where
    // the binding returns HTTP 400 for NetworkImage, and degrades
    // gracefully in production if the warm path missed (rare).
    errorBuilder: (_, _, _) => const SizedBox.expand(),
  );
}

class _HeroLandingImage extends StatelessWidget {
  final CatalogMedia media;
  final BoxFit fit;
  final Alignment alignment;
  final Widget child;

  const _HeroLandingImage({
    required this.media,
    required this.fit,
    required this.alignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // One-shot ripple entry animation when the loaded hero image lands. Lives
    // here (not on the loading placeholder) so it plays on every PDP open —
    // cache HIT or MISS. _HeroLandingImage is only mounted for the index-0 main
    // image (see resolvedMainImageHeroTag), so this never ripples gallery pages.
    //
    // The per-frame shader snapshot is heaviest on the full-bleed mobile hero,
    // so phone-class devices get a shorter, lighter pulse. Reduced-motion
    // remains the only condition that disables the effect entirely.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final isPhone = mediaSize.shortestSide < 600;
    final hasImageBackButton = mediaSize.width <= 600;
    return LayoutBuilder(
      builder: (context, constraints) {
        final origin = hasImageBackButton
            ? pdpWaterRippleBackButtonOrigin(context, constraints.biggest)
            : kPdpWaterRippleDefaultOrigin;
        return PdpWaterRipple(
          enabled: !reduceMotion,
          origin: origin,
          duration: isPhone
              ? const Duration(milliseconds: 650)
              : const Duration(milliseconds: 1000),
          intensity: isPhone ? 0.60 : 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _landingPlaceholder(media, fit, alignment),
              ),
              Positioned.fill(child: child),
            ],
          ),
        );
      },
    );
  }
}

/// Optional decorator around each catalog image (e.g. the PDP holo
/// overlay). Receives the media plus the fit/alignment the image is
/// rendered with, so the decoration can align to the displayed pixels.
typedef MediaOverlayBuilder =
    Widget Function(
      CatalogMedia media,
      BoxFit fit,
      Alignment alignment,
      Widget child,
    );

class DesktopImageStack extends StatelessWidget {
  final List<CatalogMedia> images;
  final Map<String, PendingMediaEntry> pendingMedia;
  final List<GlobalKey>? itemKeys;
  final double aspectRatio;
  final BoxFit imageFit;
  final String? imageThumbSize;
  final Widget? firstImageTopLeftOverlay;
  final double spacing;
  final String? mainImageHeroTag;
  final MediaOverlayBuilder? mediaOverlayBuilder;

  const DesktopImageStack({
    super.key,
    required this.images,
    required this.pendingMedia,
    this.itemKeys,
    this.aspectRatio = 1.08,
    this.imageFit = BoxFit.contain,
    this.imageThumbSize,
    this.firstImageTopLeftOverlay,
    this.spacing = 0,
    this.mainImageHeroTag,
    this.mediaOverlayBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.image, size: 64)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int index = 0; index < images.length; index++) ...[
          RepaintBoundary(
            child: KeyedSubtree(
              key: itemKeys != null && index < itemKeys!.length
                  ? itemKeys![index]
                  : ValueKey('desktop_image_${images[index].id}'),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildStackImage(index)),
                    if (index == 0 && firstImageTopLeftOverlay != null)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: firstImageTopLeftOverlay!,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (index < images.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }

  Widget _buildStackImage(int index) {
    final media = images[index];
    final imageUrl = imageThumbSize == null
        ? media.previewUrl
        : media.thumbUrl(imageThumbSize!);
    final resolvedFit = imageFit == BoxFit.contain ? BoxFit.fitWidth : imageFit;
    final isHeroChild = index == 0 && mainImageHeroTag != null;
    Widget image = KikiImage(
      imageUrl: imageUrl,
      imageBytes: pendingMedia[media.id]?.bytes,
      fit: resolvedFit,
      filterQuality: FilterQuality.medium,
      placeholder: isHeroChild ? const SizedBox.expand() : null,
    );
    image =
        mediaOverlayBuilder?.call(
          media,
          resolvedFit,
          Alignment.center,
          image,
        ) ??
        image;

    if (!isHeroChild) {
      return image;
    }

    return Hero(
      tag: mainImageHeroTag!,
      flightShuttleBuilder: productImageHeroFlightShuttleBuilder(
        imageUrl: media.listingUrl,
        fit: BoxFit.cover,
      ),
      child: _HeroLandingImage(
        media: media,
        fit: resolvedFit,
        alignment: Alignment.center,
        child: image,
      ),
    );
  }
}

class ImageCarousel extends StatefulWidget {
  final List<CatalogMedia> images;
  final Map<String, PendingMediaEntry> pendingMedia;
  final bool isEditMode;
  final void Function(int currentIndex)? onPickPhoto;
  final void Function(int currentIndex)? onPickMedia;
  final void Function(int currentIndex)? onRemoveMedia;
  final void Function(int currentIndex, int targetIndex)? onMoveMedia;
  final void Function(int currentIndex)? onSetFirstMedia;
  final VoidCallback? onAddMedia;
  final double aspectRatio;
  final BoxFit imageFit;
  final bool showThumbnailRail;
  final bool showShoppingOverlays;
  final bool showPageIndicators;
  final String? mainImageThumbSize;
  final String? thumbnailThumbSize;
  final PageController? controller;
  final ValueChanged<int>? onPageChanged;
  final String? scrollToMediaId;
  final ValueChanged<String>? onScrollToMediaHandled;
  final Widget? topLeftOverlay;
  final Alignment imageAlignment;
  final void Function(CatalogMedia currentImage)? onOpenMainImageVisionModal;
  final String? mainImageHeroTag;
  final MediaOverlayBuilder? mediaOverlayBuilder;

  const ImageCarousel({
    super.key,
    required this.images,
    required this.pendingMedia,
    this.isEditMode = false,
    this.onPickPhoto,
    this.onPickMedia,
    this.onRemoveMedia,
    this.onMoveMedia,
    this.onSetFirstMedia,
    this.onAddMedia,
    this.aspectRatio = 0.85,
    this.imageFit = BoxFit.cover,
    this.showThumbnailRail = false,
    this.showShoppingOverlays = true,
    this.showPageIndicators = true,
    this.mainImageThumbSize,
    this.thumbnailThumbSize,
    this.controller,
    this.onPageChanged,
    this.scrollToMediaId,
    this.onScrollToMediaHandled,
    this.topLeftOverlay,
    this.imageAlignment = Alignment.center,
    this.onOpenMainImageVisionModal,
    this.mainImageHeroTag,
    this.mediaOverlayBuilder,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  // The carousel often lives inside a PDP CustomScrollView keyed for vertical
  // scroll restoration. If this PageController participates in PageStorage, it
  // can accidentally restore that vertical offset as a horizontal page offset
  // when the loading skeleton swaps to the real PDP.
  final PageController _internalController = PageController(keepPage: false);
  int _currentPage = 0;
  bool _scrollToMediaScheduled = false;

  PageController get _controller => widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.controller?.initialPage ?? 0;
    _scheduleScrollToRequestedMedia();
  }

  @override
  void didUpdateWidget(covariant ImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.images.isEmpty) {
      _currentPage = 0;
    } else if (_currentPage >= widget.images.length) {
      _currentPage = widget.images.length - 1;
    }

    if (widget.scrollToMediaId != oldWidget.scrollToMediaId ||
        !_hasSameImageIds(oldWidget.images, widget.images)) {
      _scheduleScrollToRequestedMedia();
    }
  }

  ImageProvider<Object> _imageProviderFor(
    CatalogMedia media, {
    String? thumbSize,
  }) {
    final pendingEntry = widget.pendingMedia[media.id];
    if (pendingEntry != null) {
      return MemoryImage(pendingEntry.bytes);
    }

    final imageUrl = thumbSize == null
        ? media.previewUrl
        : media.thumbUrl(thumbSize);
    return CachedNetworkImageProvider(imageUrl);
  }

  Widget _buildCatalogImage(
    CatalogMedia media, {
    required BoxFit fit,
    double? width,
    double? height,
    String? thumbSize,
    Alignment alignment = Alignment.center,
    Widget? errorFallback,
    Widget? placeholder,
  }) {
    return KikiImage(
      imageUrl: thumbSize == null
          ? media.previewUrl
          : media.thumbUrl(thumbSize),
      imageBytes: widget.pendingMedia[media.id]?.bytes,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      errorWidget: errorFallback,
      placeholder: placeholder,
    );
  }

  Widget _buildPageIndicators(int currentPage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.images.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: index == currentPage ? 18 : 10,
          height: 1.5,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: index == currentPage
                ? const Color(0xFF2C2C2A)
                : const Color(0xFFD5D3CE),
          ),
        ),
      ),
    );
  }

  // "Liquid reveal" transition, applying the principles of the liquid_swipe
  // package (Apache-2.0, Sahdeep Singh) on top of the existing PageView rather
  // than replacing it — the carousel keeps its Hero, water ripple, dots,
  // thumbnail rail and animateToPage.
  //
  // liquid_swipe's defining trait is that pages do NOT slide: the current page
  // stays put while the next one is uncovered by a single, smooth, spring-eased
  // liquid lobe. We honour that by using the PageView purely as the scroll /
  // gesture / snapping engine and pinning every visible page to the viewport
  // (cancelling PageView's own horizontal translation with a Transform), so the
  // only motion is the lobe. The page arriving from the right is clipped with a
  // growing lobe and painted over the settled page beneath it.
  //
  // Bounded to the at-most-two pages adjacent to the live scroll position;
  // settled and off-screen pages paint untouched, and reduced motion disables
  // the effect entirely. The viewport width comes from the scroll metrics (no
  // geometry read, no LayoutBuilder) so the index-0 Hero is still exposed
  // synchronously on the first build.
  Widget _buildLiquidRevealPage({required int index, required Widget child}) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        if (!_controller.hasClients || !_controller.position.haveDimensions) {
          return child!;
        }
        final page = _controller.page ?? _currentPage.toDouble();
        final relative = index - page;
        // Settled or off-screen: paint straight through, no pin and no clip.
        if (relative.abs() < 0.0001 || relative.abs() >= 1.0) {
          return child!;
        }
        final width = _controller.position.viewportDimension;
        // relative > 0 → the page coming in from the right: reveal it with the
        // growing lobe on top. relative < 0 → the page we are leaving: it sits
        // full underneath.
        final revealed = relative > 0
            ? ClipPath(
                clipBehavior: Clip.antiAlias,
                clipper: _LiquidRevealClipper(progress: 1.0 - relative),
                child: child,
              )
            : child!;
        return Transform.translate(
          offset: Offset(-relative * width, 0),
          child: revealed,
        );
      },
    );
  }

  @override
  void dispose() {
    _internalController.dispose();
    super.dispose();
  }

  bool _hasSameImageIds(List<CatalogMedia> previous, List<CatalogMedia> next) {
    if (previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index += 1) {
      if (previous[index].id != next[index].id) {
        return false;
      }
    }
    return true;
  }

  void _scheduleScrollToRequestedMedia() {
    if (_scrollToMediaScheduled) {
      return;
    }
    _scrollToMediaScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToMediaScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(_scrollToRequestedMedia());
    });
  }

  Future<void> _scrollToRequestedMedia() async {
    final targetMediaId = widget.scrollToMediaId;
    if (targetMediaId == null || targetMediaId.isEmpty) {
      return;
    }

    final targetIndex = widget.images.indexWhere(
      (media) => media.id == targetMediaId,
    );
    if (targetIndex < 0) {
      return;
    }

    if (_currentPage != targetIndex) {
      setState(() => _currentPage = targetIndex);
    }

    if (!_controller.hasClients) {
      widget.onPageChanged?.call(targetIndex);
      widget.onScrollToMediaHandled?.call(targetMediaId);
      return;
    }

    try {
      await _controller.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      if (_controller.hasClients) {
        _controller.jumpToPage(targetIndex);
      }
    }

    if (!mounted || widget.scrollToMediaId != targetMediaId) {
      return;
    }
    widget.onScrollToMediaHandled?.call(targetMediaId);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          children: [
            Container(
              color: Colors.grey.shade200,
              child: const Center(child: Icon(Icons.image, size: 64)),
            ),
            if (widget.topLeftOverlay != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: widget.topLeftOverlay!,
              ),
            if (widget.isEditMode &&
                (widget.onAddMedia != null || widget.onPickMedia != null))
              Positioned.fill(
                child: Center(
                  child: GestureDetector(
                    onTap:
                        widget.onAddMedia ??
                        (widget.onPickMedia == null
                            ? null
                            : () => widget.onPickMedia!(0)),
                    child: Tooltip(
                      message: 'Ajouter une image',
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_library_outlined,
                          color: kNavyBlue,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final currentPage = _currentPage < widget.images.length
        ? _currentPage
        : widget.images.length - 1;
    final shouldShowPageIndicators =
        widget.images.length > 1 &&
        !widget.showThumbnailRail &&
        widget.showPageIndicators;
    final shouldOverlayPageIndicators =
        shouldShowPageIndicators && !widget.showShoppingOverlays;
    Widget buildCarouselPage(int index) {
      final media = widget.images[index];
      final isHeroChild = index == 0 && widget.mainImageHeroTag != null;
      Widget image = _buildCatalogImage(
        media,
        fit: widget.imageFit,
        alignment: widget.imageAlignment,
        width: double.infinity,
        thumbSize: widget.mainImageThumbSize,
        placeholder: isHeroChild ? const SizedBox.expand() : null,
      );
      image =
          widget.mediaOverlayBuilder?.call(
            media,
            widget.imageFit,
            widget.imageAlignment,
            image,
          ) ??
          image;
      if (!isHeroChild) {
        return image;
      }
      return Hero(
        tag: widget.mainImageHeroTag!,
        flightShuttleBuilder: productImageHeroFlightShuttleBuilder(
          imageUrl: media.listingUrl,
          fit: BoxFit.cover,
        ),
        child: _HeroLandingImage(
          media: media,
          fit: widget.imageFit,
          alignment: widget.imageAlignment,
          child: image,
        ),
      );
    }

    final pageView = widget.mainImageHeroTag == null
        ? PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              widget.onPageChanged?.call(index);
            },
            itemBuilder: (context, index) => _buildLiquidRevealPage(
              index: index,
              child: buildCarouselPage(index),
            ),
          )
        : PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              widget.onPageChanged?.call(index);
            },
            // A tagged carousel must expose its index-0 Hero during the
            // destination route's first build; PageView.builder can create the
            // child too late for the initial Hero scan on mobile. Do not
            // "optimize" this back to PageView.builder — it breaks the Hero.
            // The children list is O(N) lightweight widget configs, but the
            // viewport still mounts pages lazily (measured: only the visible
            // page's KikiImage builds/decodes at first paint), so this does not
            // eagerly fetch/decode offscreen gallery images.
            children: [
              for (var index = 0; index < widget.images.length; index++)
                _buildLiquidRevealPage(
                  index: index,
                  child: buildCarouselPage(index),
                ),
            ],
          );

    final mainVisual = AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        children: [
          pageView,
          if (widget.topLeftOverlay != null)
            Positioned(
              top: widget.showShoppingOverlays ? 16 : 34,
              left: widget.showShoppingOverlays ? 16 : 24,
              right: widget.showShoppingOverlays ? 84 : 16,
              child: widget.topLeftOverlay!,
            ),
          if (widget.showShoppingOverlays)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border,
                  color: kNavyBlue,
                  size: 24,
                ),
              ),
            ),
          if (widget.showShoppingOverlays)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'COMPLÉTEZ VOTRE LOOK',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          if (widget.showShoppingOverlays)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: kNavyBlue,
                  size: 24,
                ),
              ),
            ),
          if (widget.isEditMode)
            Positioned.fill(
              child: Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Semantics(
                      container: true,
                      button: true,
                      enabled: true,
                      label: imageCarouselProductImageEditorSemanticsLabel,
                      hint: "Ouvre le recadrage de l'image affichée",
                      identifier:
                          imageCarouselProductImageEditorSemanticsIdentifier,
                      onTap: () => widget.onPickPhoto?.call(currentPage),
                      child: GestureDetector(
                        excludeFromSemantics: true,
                        onTap: () => widget.onPickPhoto?.call(currentPage),
                        child: Tooltip(
                          message: 'Recadrer cette image',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.crop,
                              color: kNavyBlue,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.onPickMedia != null) ...[
                      GestureDetector(
                        onTap: () => widget.onPickMedia!(currentPage),
                        child: Tooltip(
                          message: 'Choisir une autre image',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.photo_library_outlined,
                              color: kNavyBlue,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (widget.onAddMedia != null)
                      Semantics(
                        container: true,
                        button: true,
                        enabled: true,
                        label: imageCarouselAddImageSemanticsLabel,
                        hint: 'Ajoute une image à la galerie du produit',
                        identifier: imageCarouselAddImageSemanticsIdentifier,
                        onTap: widget.onAddMedia,
                        child: GestureDetector(
                          excludeFromSemantics: true,
                          onTap: widget.onAddMedia,
                          child: Tooltip(
                            message: 'Ajouter au carousel',
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: kNavyBlue,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.onSetFirstMedia != null &&
                        widget.images.length > 1 &&
                        currentPage > 0)
                      Semantics(
                        container: true,
                        button: true,
                        enabled: true,
                        label: imageCarouselSetFirstImageSemanticsLabel,
                        hint: 'Place l’image affichée en première position',
                        identifier:
                            imageCarouselSetFirstImageSemanticsIdentifier,
                        onTap: () => widget.onSetFirstMedia!(currentPage),
                        child: GestureDetector(
                          excludeFromSemantics: true,
                          onTap: () => widget.onSetFirstMedia!(currentPage),
                          child: Tooltip(
                            message: 'Afficher en premier',
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.vertical_align_top,
                                color: kNavyBlue,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.onMoveMedia != null &&
                        widget.images.length > 1 &&
                        currentPage > 0)
                      GestureDetector(
                        onTap: () =>
                            widget.onMoveMedia!(currentPage, currentPage - 1),
                        child: Tooltip(
                          message: 'Déplacer avant',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: kNavyBlue,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    if (widget.onMoveMedia != null &&
                        widget.images.length > 1 &&
                        currentPage < widget.images.length - 1)
                      GestureDetector(
                        onTap: () =>
                            widget.onMoveMedia!(currentPage, currentPage + 1),
                        child: Tooltip(
                          message: 'Déplacer après',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: kNavyBlue,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    if (widget.onRemoveMedia != null)
                      Semantics(
                        container: true,
                        button: true,
                        enabled: true,
                        label: imageCarouselRemoveImageSemanticsLabel,
                        hint:
                            'Retire l’image affichée de la galerie du produit',
                        identifier: imageCarouselRemoveImageSemanticsIdentifier,
                        onTap: () => widget.onRemoveMedia!(currentPage),
                        child: GestureDetector(
                          excludeFromSemantics: true,
                          onTap: () => widget.onRemoveMedia!(currentPage),
                          child: Tooltip(
                            message: 'Supprimer du carousel',
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.delete_outline,
                                color: kNavyBlue,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.onOpenMainImageVisionModal != null) ...[
                      GestureDetector(
                        onTap: () => widget.onOpenMainImageVisionModal!(
                          widget.images[currentPage],
                        ),
                        child: Tooltip(
                          message: 'Ouvrir l’image en grand',
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.open_in_full,
                              color: kNavyBlue,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (shouldOverlayPageIndicators)
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: _buildPageIndicators(currentPage),
            ),
        ],
      ),
    );

    final carousel = widget.showThumbnailRail && widget.images.length > 1
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Column(
                  children: [
                    for (
                      int index = 0;
                      index < widget.images.length;
                      index++
                    ) ...[
                      _CarouselThumbnail(
                        imageProvider: _imageProviderFor(
                          widget.images[index],
                          thumbSize: widget.thumbnailThumbSize,
                        ),
                        isSelected: index == _currentPage,
                        onTap: () => _controller.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                      ),
                      if (index < widget.images.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: mainVisual),
            ],
          )
        : mainVisual;

    return Column(
      children: [
        carousel,
        if (shouldShowPageIndicators && widget.showShoppingOverlays)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _buildPageIndicators(currentPage),
          ),
      ],
    );
  }
}

/// Clips a page so it is revealed from the right edge behind a single smooth
/// "liquid" lobe — the wave-reveal principle of the liquid_swipe package
/// (Apache-2.0, Sahdeep Singh), reimplemented for a PageView-driven carousel.
///
/// [progress] is 0 (a thin sliver at the right edge) → 1 (fully revealed). The
/// lobe is one organic teardrop, not a repeating ripple: its reach grows over
/// the first 40% of the gesture, then settles with a damped spring so the edge
/// reads as liquid rather than mechanical.
class _LiquidRevealClipper extends CustomClipper<Path> {
  final double progress;

  const _LiquidRevealClipper({required this.progress});

  /// Vertical centre of the lobe, 0 (top) … 1 (bottom). Fixed for now; if the
  /// lobe should follow the finger this becomes a per-frame input again.
  static const double _verReveal = 0.5;

  // Damped-spring constants mirroring liquid_swipe's waveHorRadiusF: a quick
  // reach followed by an elastic settle.
  static const double _springBoundary = 0.4;
  static const double _maxReachFactor = 0.70; // of the page width
  static const double _maxHalfHeightFactor = 0.46; // of the page height
  static const double _minHalfHeightFactor = 0.10;

  @override
  Path getClip(Size size) {
    final p = progress.clamp(0.0, 1.0);
    final width = size.width;
    final height = size.height;

    // The straight "water line": everything to its right is the revealed page.
    final baseX = width * (1.0 - p);
    final horRadius = _horRadius(p, width);
    final vertRadius = _vertRadius(p, height);
    final cy = (height * _verReveal).clamp(vertRadius, height - vertRadius);
    // Circle-approximation handle length for a rounded, full lobe.
    final handle = vertRadius * 0.5523;

    final path = Path()
      ..moveTo(width, 0)
      ..lineTo(width, height)
      ..lineTo(baseX, height)
      ..lineTo(baseX, cy + vertRadius)
      // Bow out to the lobe tip (baseX - horRadius, cy) and back, two mirrored
      // cubics forming one smooth teardrop.
      ..cubicTo(
        baseX,
        cy + vertRadius - handle,
        baseX - horRadius,
        cy + handle,
        baseX - horRadius,
        cy,
      )
      ..cubicTo(
        baseX - horRadius,
        cy - handle,
        baseX,
        cy - vertRadius + handle,
        baseX,
        cy - vertRadius,
      )
      ..lineTo(baseX, 0)
      ..close();
    return path;
  }

  double _horRadius(double p, double width) {
    if (p <= 0 || p >= 1) return 0;
    final maxReach = width * _maxReachFactor;
    if (p <= _springBoundary) return maxReach * (p / _springBoundary);
    final t = (p - _springBoundary) / (1.0 - _springBoundary);
    // Damped harmonic oscillator (r=40, m=9.8, k=50), as in liquid_swipe.
    const beta = 40 / (2 * 9.8);
    const omega0Sq = (50 / 9.8) * (50 / 9.8);
    final omega = math.sqrt(-beta * beta + omega0Sq);
    return maxReach * math.exp(-beta * t) * math.cos(omega * t);
  }

  double _vertRadius(double p, double height) {
    final maxHalf = height * _maxHalfHeightFactor;
    final minHalf = height * _minHalfHeightFactor;
    if (p >= _springBoundary) return maxHalf;
    return minHalf + (maxHalf - minHalf) * (p / _springBoundary);
  }

  @override
  bool shouldReclip(_LiquidRevealClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}

class _CarouselThumbnail extends StatelessWidget {
  final ImageProvider<Object> imageProvider;
  final bool isSelected;
  final VoidCallback onTap;

  const _CarouselThumbnail({
    required this.imageProvider,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 74,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? kNavyBlue : const Color(0xFFD9DEE6),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image(
              image: imageProvider,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_outlined),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
