import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/catalog_routes.dart';
import '../../navigation/product_detail_navigation.dart';
import '../../providers/category_plp_hero_provider.dart';
import '../category_hero_tags.dart';
import 'cms_href.dart';
import 'sport_context_cms_href.dart';

/// Opens a category PLP from a tapped tile with a Hero transition mirroring the
/// PLP→PDP flight: stash the tile image as a transient hint, warm it into the
/// Skia image cache, then push the PLP route. The destination PLP hero reads
/// the hint by the same slug key and wears the matching Hero tag.
///
/// Falls back to plain [launchCmsHref] for any href that is not a category PLP
/// (external links, home, search…) — those keep their existing behaviour with
/// no Hero.
Future<void> openCategoryPlpFromTile(
  BuildContext context,
  WidgetRef ref, {
  required String href,
  required String? tileImageUrl,
}) async {
  final slugKey = categoryPlpHeroKeyFromHref(href);
  if (slugKey == null || tileImageUrl == null || tileImageUrl.isEmpty) {
    launchCmsHref(context, href);
    return;
  }

  ref.read(categoryPlpHeroShuttleProvider(slugKey).notifier).state =
      CategoryPlpHeroShuttle(imageUrl: tileImageUrl);

  await warmProductHeroShuttleImage(context, tileImageUrl);
  if (!context.mounted) return;

  final navigationHref = sportContextualCmsHref(context, href);
  // Preserve the catalog-PLP `push` semantics of launchCmsHref so the PLP back
  // arrow returns to the page the tile was tapped from.
  context.push(
    CatalogRoutes.localizedLocation(
      navigationHref.trim(),
      locale: Localizations.localeOf(context).languageCode,
    ),
  );
}
