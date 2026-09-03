import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../application/cms/cms_models.dart';
import '../../category_hero_tags.dart';
import '../../kiki_image.dart';
import '../../product_hero_tags.dart';
import '../../storefront_layout.dart';
import '../category_tile_navigation.dart';
import '../cms_text_reveal.dart';

// Single source of truth for the tile image variant so the rendered image, the
// warmed shuttle URL and the carried hint all reference the exact same URL
// (required for the synchronous first-frame paint on web).
const String _tileThumbSize = '800x800f';
const Color _tilePlaceholderColor = Color(0xFFEDEAE3);

class CategoryTilesSection extends StatelessWidget {
  final CategoryTilesConfig config;
  final bool enableTextReveal;
  final String? textRevealId;

  const CategoryTilesSection({
    super.key,
    required this.config,
    this.enableTextReveal = true,
    this.textRevealId,
  });

  @override
  Widget build(BuildContext context) {
    if (config.tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = StorefrontLayout.isDesktop(width);
    final isTablet = StorefrontLayout.isTabletOnly(width);
    final isMobile = !isDesktop && !isTablet;

    final columns = isMobile ? config.columnsMobile : config.columnsDesktop;
    final spacing = isMobile ? 12.0 : 20.0;

    final horizontalPadding = StorefrontLayout.outerPaddingFor(width);

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        isMobile ? 48 : 80,
        horizontalPadding,
        isMobile ? 48 : 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: CmsRevealGroup(
            key: textRevealId == null
                ? null
                : ValueKey('cms-category-tiles-text-reveal-$textRevealId'),
            trigger: CmsRevealTrigger.viewport,
            enabled: enableTextReveal,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (config.title != null)
                CmsRevealText(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      config.title!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: isMobile ? 26 : 34,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              if (config.subtitle != null)
                CmsRevealText(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: Text(
                      config.subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6F6F6F),
                      ),
                    ),
                  ),
                ),
              if (config.title == null && config.subtitle == null)
                const SizedBox(height: 4)
              else if (config.subtitle == null)
                const SizedBox(height: 24),
              CmsRevealText(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: config.tiles.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemBuilder: (context, index) =>
                      _Tile(item: config.tiles[index], isMobile: isMobile),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  final CategoryTileItem item;
  final bool isMobile;

  const _Tile({required this.item, required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = item.media;
    final tileImageUrl = (media != null && media.isUsable)
        ? media.thumbUrl(size: _tileThumbSize)
        : null;
    final heroKey = categoryPlpHeroKeyFromHref(item.href);

    Widget imageLayer = ClipRect(child: _TileImage(media: item.media));
    // Only PLP-bound tiles with a usable image fly; the tag is shared with the
    // destination PLP hero via the slug key. See category_hero_tags.dart for
    // the one-Hero-per-slug-per-route authoring constraint.
    if (heroKey != null && tileImageUrl != null) {
      imageLayer = Hero(
        tag: categoryPlpHeroTag(heroKey),
        flightShuttleBuilder: imageHeroFlightShuttleBuilder(
          imageUrl: tileImageUrl,
          fit: BoxFit.cover,
          color: _tilePlaceholderColor,
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
      child: Stack(
        children: [
          Positioned.fill(child: imageLayer),
          // Subtle bottom gradient to ensure text readability on light images.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.5, 0.75, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: isMobile ? 20 : 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.eyebrow != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      item.eyebrow!.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white, width: 1.0),
                    ),
                  ),
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      return Container(color: _tilePlaceholderColor);
    }
    return KikiImage(
      imageUrl: media!.thumbUrl(size: _tileThumbSize),
      fit: BoxFit.cover,
      placeholder: Container(color: _tilePlaceholderColor),
      errorWidget: Container(color: _tilePlaceholderColor),
    );
  }
}
