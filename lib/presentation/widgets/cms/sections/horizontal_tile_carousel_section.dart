import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/cms/cms_models.dart';
import '../../category_hero_tags.dart';
import '../../horizontal_parallax.dart';
import '../../kiki_image.dart';
import '../../product_hero_tags.dart';
import '../../storefront_layout.dart';
import '../category_tile_navigation.dart';
import '../cms_legacy_l10n.dart';

// Single source of truth for the tile image variant so the rendered image, the
// warmed shuttle URL and the carried hint all reference the exact same URL.
const String _carouselTileThumbSize = '800x800f';
const Color _carouselTilePlaceholderColor = Color(0xFFEDEAE3);

/// Nike-themed horizontal scroller of square tiles with a title above.
///
/// Reused for "En ce moment", "Choisis ton aventure", "Modèles iconiques",
/// "Nos marques" in the Nike landing. Title font and tile aspect ratio match
/// the reference screenshots; the carousel scrolls horizontally and reveals a
/// slice of the next tile so users discover the affordance.
class HorizontalTileCarouselSection extends StatelessWidget {
  final HorizontalTileCarouselConfig config;

  const HorizontalTileCarouselSection({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    if (config.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);
    final horizontalPadding = StorefrontLayout.nikeContentPaddingFor(width);
    final title = config.title?.trim();
    final displayTitle = title == null
        ? null
        : localizedLegacyCmsText(context, title);
    final isFeature = config.layout == 'feature';
    final isMomentSection = !isFeature && title == 'En ce moment';
    final isAdventureSection = !isFeature && title == 'Choisis ton aventure';

    final viewportWidth = width - (horizontalPadding * 2);
    // Show ~2 tiles + a preview of the third on mobile to invite swiping.
    final tileWidth = isMobile
        ? viewportWidth / (isMomentSection ? 2.24 : 2.04)
        : 280.0;
    final tileGap = isMobile ? 4.0 : 8.0;

    return Padding(
      padding: EdgeInsets.only(
        top: isFeature
            ? (isMobile ? 16 : 24)
            : (isMobile
                  ? (isMomentSection ? 8 : (isAdventureSection ? 74 : 30))
                  : 24),
        bottom: isFeature
            ? (isMobile ? 16 : 32)
            : (isMobile ? (isMomentSection ? 2 : 12) : 32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (displayTitle != null && displayTitle.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                isMobile ? (isFeature ? 18 : 26) : 20,
              ),
              child: Text(
                displayTitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: isMobile ? 24 : 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: const Color(0xFF111111),
                  height: 1.1,
                ),
              ),
            ),
          if (isFeature)
            _FeatureCarousel(
              items: config.items,
              width: width,
              horizontalPadding: horizontalPadding,
            )
          else
            SizedBox(
              height: tileWidth + 46, // tile + label below
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                itemCount: config.items.length,
                separatorBuilder: (_, _) => SizedBox(width: tileGap),
                itemBuilder: (context, index) =>
                    _CarouselTile(item: config.items[index], size: tileWidth),
              ),
            ),
        ],
      ),
    );
  }
}

/// Height of a feature card as a fraction of its width. Tuned to the
/// slightly-landscape proportions of the Nike "collection" cards.
const double _featureCardHeightFactor = 0.88;

/// `layout: 'feature'` — large swipeable cards with the label overlaid on the
/// image and a dot pager beneath. The active card is inset by the content
/// padding while its neighbours peek toward the screen edges to invite swiping.
class _FeatureCarousel extends StatefulWidget {
  final List<HorizontalTileItem> items;
  final double width;
  final double horizontalPadding;

  const _FeatureCarousel({
    required this.items,
    required this.width,
    required this.horizontalPadding,
  });

  @override
  State<_FeatureCarousel> createState() => _FeatureCarouselState();
}

class _FeatureCarouselState extends State<_FeatureCarousel> {
  late PageController _controller;
  late double _viewportFraction;
  final ValueNotifier<int> _page = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _viewportFraction = _resolveViewportFraction();
    _controller = PageController(viewportFraction: _viewportFraction);
  }

  double _resolveViewportFraction() {
    // Keep the card close to the content margin with only a small peek, so it
    // reads as full-width (like the Nike reference) rather than a narrow inset
    // card. Each side inset is horizontalPadding + peek + the page margin below.
    const peek = 2.0;
    final fraction =
        (widget.width - 2 * (widget.horizontalPadding + peek)) / widget.width;
    return fraction.clamp(0.5, 1.0);
  }

  @override
  void didUpdateWidget(covariant _FeatureCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // viewportFraction is fixed at construction, so rebuild the controller when
    // a resize (e.g. orientation / web window) changes the target inset.
    final next = _resolveViewportFraction();
    if (next != _viewportFraction) {
      final page = _controller.hasClients
          ? (_controller.page?.round() ?? _page.value)
          : _page.value;
      _viewportFraction = next;
      _controller.dispose();
      _controller = PageController(
        viewportFraction: _viewportFraction,
        initialPage: page,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slotWidth = _viewportFraction * widget.width;
    // Each page child carries a small horizontal margin so peeked neighbours
    // don't touch the active card (2 * 4 = 8).
    final cardWidth = slotWidth - 8;
    final cardHeight = cardWidth * _featureCardHeightFactor;
    final showDots = widget.items.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: cardHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (index) => _page.value = index,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _FeatureCard(item: widget.items[index]),
            ),
          ),
        ),
        if (showDots) ...[
          const SizedBox(height: 14),
          Center(
            child: ValueListenableBuilder<int>(
              valueListenable: _page,
              builder: (context, current, _) => _FeatureDots(
                count: widget.items.length,
                activeIndex: current,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeatureCard extends ConsumerWidget {
  final HorizontalTileItem item;

  const _FeatureCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = item.media;
    final tileImageUrl = (media != null && media.isUsable)
        ? media.thumbUrl(size: _carouselTileThumbSize)
        : null;
    final heroKey = categoryPlpHeroKeyFromHref(item.href);

    Widget imageLayer = _TileImage(media: item.media);
    // Horizontal parallax: pan the image as the card swipes across the
    // viewport. Sits inside the Hero so the flight shuttle is unaffected.
    imageLayer = HorizontalParallax(
      scrollable: Scrollable.of(context),
      // Square sources in a landscape card have no horizontal slack, so the
      // image is zoomed slightly to create the pan room. Kept low (1.15) so the
      // extra crop on the subject stays subtle.
      overscan: 1.15,
      child: imageLayer,
    );
    // Mirrors the tile Hero contract (one shared slug-key tag per route).
    if (heroKey != null && tileImageUrl != null) {
      imageLayer = Hero(
        tag: categoryPlpHeroTag(heroKey),
        flightShuttleBuilder: imageHeroFlightShuttleBuilder(
          imageUrl: tileImageUrl,
          fit: BoxFit.cover,
          color: _carouselTilePlaceholderColor,
        ),
        child: imageLayer,
      );
    }

    return InkWell(
      onTap: () => openCategoryPlpFromTile(
        context,
        ref,
        href: item.href,
        tileImageUrl: tileImageUrl,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageLayer,
            // Bottom scrim so the overlaid title stays legible over any image.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x99000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  localizedLegacyCmsText(context, item.label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureDots extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _FeatureDots({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F0EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: EdgeInsets.only(right: i == count - 1 ? 0 : 8),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == activeIndex
                      ? const Color(0xFF111111)
                      : const Color(0xFFC4C2BB),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CarouselTile extends ConsumerWidget {
  final HorizontalTileItem item;
  final double size;

  const _CarouselTile({required this.item, required this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = item.media;
    final tileImageUrl = (media != null && media.isUsable)
        ? media.thumbUrl(size: _carouselTileThumbSize)
        : null;
    final heroKey = categoryPlpHeroKeyFromHref(item.href);

    Widget imageLayer = _TileImage(media: item.media);
    // Only PLP-bound tiles with a usable image fly (shared slug-key tag). See
    // category_hero_tags.dart for the one-Hero-per-slug-per-route constraint.
    if (heroKey != null && tileImageUrl != null) {
      imageLayer = Hero(
        tag: categoryPlpHeroTag(heroKey),
        flightShuttleBuilder: imageHeroFlightShuttleBuilder(
          imageUrl: tileImageUrl,
          fit: BoxFit.cover,
          color: _carouselTilePlaceholderColor,
        ),
        child: imageLayer,
      );
    }

    return SizedBox(
      width: size,
      child: InkWell(
        onTap: () => openCategoryPlpFromTile(
          context,
          ref,
          href: item.href,
          tileImageUrl: tileImageUrl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: size, height: size, child: imageLayer),
            ),
            const SizedBox(height: 10),
            Text(
              localizedLegacyCmsText(context, item.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111111),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileImage extends StatelessWidget {
  final CmsMediaRef? media;

  const _TileImage({required this.media});

  @override
  Widget build(BuildContext context) {
    if (media == null || !media!.isUsable) {
      return Container(color: _carouselTilePlaceholderColor);
    }
    return KikiImage(
      imageUrl: media!.thumbUrl(size: _carouselTileThumbSize),
      fit: BoxFit.cover,
      placeholder: Container(color: _carouselTilePlaceholderColor),
      errorWidget: Container(color: _carouselTilePlaceholderColor),
    );
  }
}
