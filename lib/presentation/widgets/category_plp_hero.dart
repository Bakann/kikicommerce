import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/cms/cms_models.dart';
import '../../application/cms/cms_page_repository.dart';
import '../providers/category_plp_hero_provider.dart';
import '../providers/cms_page_provider.dart';
import '../providers/content_locale_provider.dart';
import 'category_hero_tags.dart';
import 'cms/sections/hero_campaign_section.dart';
import 'product_hero_tags.dart';

/// Square (1:1) hero at the top of a category PLP. Destination of the
/// category-tile → PLP Hero flight (mirrors the PLP→PDP transition):
///
/// - The flight's first frame paints the carried tile image (read from
///   [categoryPlpHeroShuttleProvider] by the shared [slugKey]) synchronously,
///   because the destination resolves async.
/// - Once the PLP's configured hero image resolves (the first `hero_campaign`
///   section of the category's CMS PLP), it crossfades over the tile image.
///
/// Renders nothing when neither image is available (no flight target, no
/// permanent hero). Authoring constraint: at most one Hero per [slugKey] per
/// route (see category_hero_tags.dart).
const Color _heroPlaceholderColor = Color(0xFFEDEAE3);
const String _configuredHeroThumbSize = '1080x1080f';

class CategoryPlpHero extends ConsumerWidget {
  final String slugKey;

  /// Null while the destination category is still resolving (the route-level
  /// loading placeholder): the hero then paints the carried tile image only, so
  /// it exists on the destination's first frame and catches the inbound flight.
  /// Once the category is known, the configured PLP image is read and crossfaded.
  final String? categoryId;

  /// Whether this widget should read the category's configured CMS PLP hero.
  /// Sport PLPs pass false on the public path: their incoming tile image is
  /// enough for the Hero flight and avoids a non-critical CMS read during PLP
  /// startup.
  final bool loadConfiguredHero;

  const CategoryPlpHero({
    super.key,
    required this.slugKey,
    required this.categoryId,
    this.loadConfiguredHero = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hint = ref.watch(categoryPlpHeroShuttleProvider(slugKey));
    final categoryId = this.categoryId;
    // The configured PLP hero is the first hero_campaign of the category's CMS
    // PLP. Rendering that exact section here (in 'square' mode) keeps the
    // storefront hero pixel-identical to what the admin edits — WYSIWYG.
    final locale = ref.watch(contentLocaleProvider);
    final heroConfig = categoryId == null || !loadConfiguredHero
        ? null
        : ref.watch(
            cmsPlpProvider(
              CmsPlpRequest(categoryId: categoryId, locale: locale),
            ).select(_firstHeroCampaignConfig),
          );

    final tileUrl = hint?.imageUrl;
    final configuredUrl = heroConfig == null
        ? null
        : _heroConfigImageUrl(heroConfig);
    // Flight shuttle: prefer the warmed tile image, fall back to the configured
    // image (e.g. a direct URL visit with no inbound flight).
    final shuttleUrl = tileUrl ?? configuredUrl;

    // Nothing configured and nothing carried → no hero, no flight target.
    if (heroConfig == null && shuttleUrl == null) {
      return const SizedBox.shrink();
    }

    final Widget heroChild = heroConfig != null
        ? HeroCampaignSection(
            config: heroConfig,
            backgroundFallbackImageUrl: tileUrl,
          )
        : AspectRatio(
            aspectRatio: 1,
            child: Image(
              image: NetworkImage(tileUrl!),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          );

    return Hero(
      tag: categoryPlpHeroTag(slugKey),
      flightShuttleBuilder: imageHeroFlightShuttleBuilder(
        imageUrl: shuttleUrl ?? '',
        fit: BoxFit.cover,
        color: _heroPlaceholderColor,
      ),
      child: heroChild,
    );
  }
}

/// First `hero_campaign` config of the resolved CMS PLP bundle (the PLP hero),
/// or null while loading, on error, or when the page has no hero section.
HeroCampaignConfig? _firstHeroCampaignConfig(AsyncValue<CmsPageBundle?> async) {
  final bundle = async.value;
  if (bundle == null) return null;
  for (final section in bundle.sections) {
    if (section is CmsHeroSection) return section.data;
  }
  return null;
}

/// Hero image URL (1:1 variant) used for the flight shuttle / fallback paint.
String? _heroConfigImageUrl(HeroCampaignConfig config) {
  final media = config.mediaDesktop ?? config.mediaMobile;
  if (media != null && media.isUsable) {
    return media.thumbUrl(size: _configuredHeroThumbSize);
  }
  return null;
}
