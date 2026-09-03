import 'package:flutter/material.dart';

import '../../../application/cms/cms_models.dart';
import '../../../application/storefront/storefront_sport_segment.dart';
import '../../../domain/catalog/catalog_entities.dart';
import 'sections/category_tiles_section.dart';
import 'sections/collection_hero_section.dart';
import 'sections/discover_links_section.dart';
import 'sections/editorial_intro_section.dart';
import 'sections/editorial_story_section.dart';
import 'sections/brand_segment_section.dart';
import 'sections/category_banner_strip_section_host.dart';
import 'sections/category_split_tabs_section.dart';
import 'sections/featured_products_section.dart';
import 'sections/hero_campaign_section.dart';
import 'sections/horizontal_tile_carousel_section.dart';
import 'sections/mixed_product_grid_section.dart';
import 'sections/seo_text_section.dart';
import 'sections/service_cards_section.dart';

/// Maps a parsed [CmsSectionConfig] to its widget.
///
/// Unknown / unparseable sections render as [SizedBox.shrink] in the
/// storefront — never crashes the page (cf. plan §8 safe rendering).
/// In edit mode they render a visible diagnostic panel instead so admins
/// see what's broken rather than a silent gap.
Widget renderCmsSection(
  BuildContext context,
  CmsSectionConfig section, {
  String? routeCategoryId,
  CatalogCategory? routeCategory,
  bool isEditMode = false,
  bool enableProductHeroTransition = false,
  StorefrontSportSegment? activeSportSegment,
}) {
  return switch (section) {
    CmsHeroSection(:final data) => HeroCampaignSection(
      config: data,
      enableTextReveal: !isEditMode,
      textRevealId: section.record.id,
    ),
    CmsEditorialSection(:final data) => EditorialStorySection(config: data),
    CmsCategoryTilesSection(:final data) => CategoryTilesSection(
      config: data,
      enableTextReveal: !isEditMode,
      textRevealId: section.record.id,
    ),
    CmsFeaturedProductsSection(:final data) => FeaturedProductsSection(
      config: data,
      enableTextReveal: !isEditMode,
      textRevealId: section.record.id,
    ),
    CmsServiceCardsSection(:final data) => ServiceCardsSection(
      config: data,
      enableTextReveal: !isEditMode,
      textRevealId: section.record.id,
    ),
    CmsCollectionHeroSection(:final data) => CollectionHeroSection(
      config: data,
      enableTextReveal: !isEditMode,
      textRevealId: section.record.id,
    ),
    CmsEditorialIntroSection(:final data) => EditorialIntroSection(
      config: data,
      enableTextReveal: !isEditMode,
      textRevealId: section.record.id,
    ),
    CmsMixedProductGridSection(:final data) => MixedProductGridSection(
      config: data,
      routeCategoryId: routeCategoryId,
      routeCategory: routeCategory,
      enableProductHeroTransition: enableProductHeroTransition,
      enableTextReveal: !isEditMode,
      textRevealId: section.record.id,
    ),
    CmsSeoTextSection(:final data) => SeoTextSection(
      config: data,
      enableTextReveal: !isEditMode,
      textRevealId: section.record.id,
    ),
    CmsDiscoverLinksSection(:final data) => DiscoverLinksSection(
      config: data,
      enableTextReveal: !isEditMode,
      textRevealId: section.record.id,
    ),
    CmsHorizontalTileCarouselSection(:final data) =>
      HorizontalTileCarouselSection(config: data),
    CmsBrandSegmentSection(:final data) => BrandSegmentSection(config: data),
    CmsCategorySplitTabsSection(:final data) => CategorySplitTabsSection(
      config: data,
      activeSportSegment: activeSportSegment,
    ),
    CmsCategoryBannerStripSection(:final data) =>
      CategoryBannerStripSectionHost(config: data),
    CmsUnknownSection(:final parseError) =>
      isEditMode
          ? _CmsUnknownDiagnostic(section: section, parseError: parseError)
          : const SizedBox.shrink(),
  };
}

class _CmsUnknownDiagnostic extends StatelessWidget {
  final CmsUnknownSection section;
  final Object? parseError;

  const _CmsUnknownDiagnostic({
    required this.section,
    required this.parseError,
  });

  @override
  Widget build(BuildContext context) {
    final type =
        section.record.sectionType?.wireName ??
        (section.record.rawSectionType.isEmpty
            ? '(empty)'
            : section.record.rawSectionType);
    final hasParseError = parseError != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        border: Border.all(color: const Color(0xFFE3B872)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFF8C5B00),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasParseError
                      ? 'Section CMS en erreur'
                      : 'Type de section inconnu',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C3D00),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'sectionType: $type',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Color(0xFF5C3D00),
            ),
          ),
          if (hasParseError) ...[
            const SizedBox(height: 4),
            Text(
              parseError.toString(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFF5C3D00),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Cette section ne s\'affiche pas en storefront. Corrigez la config '
            'ou supprimez-la.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B4500)),
          ),
        ],
      ),
    );
  }
}
