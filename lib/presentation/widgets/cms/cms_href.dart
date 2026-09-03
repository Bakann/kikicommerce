import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/catalog_routes.dart';
import 'sport_context_cms_href.dart';

/// Resolves a CMS-stored href. Internal hrefs (starting with `/`) navigate via
/// GoRouter. External hrefs (`http://`, `https://`) are no-ops in V1 — wire
/// `url_launcher` here when external links are needed.
void launchCmsHref(BuildContext context, String href) {
  final h = href.trim();
  if (h.isEmpty) return;
  if (h.startsWith('http://') || h.startsWith('https://')) {
    return;
  }
  final target = CatalogRoutes.localizedLocation(
    sportContextualCmsHref(context, h),
    locale: Localizations.localeOf(context).languageCode,
  );
  // Preserve history for catalog PLP destinations (e.g. a landing carousel tile
  // linking to /catalog/...): the PLP back arrow then returns to the page the
  // link was tapped from instead of walking up the catalog hierarchy. Other
  // internal links (home, sport tabs, search) keep replace semantics.
  if (CatalogRoutes.isCategoryPlpLocation(target)) {
    context.push(target);
  } else {
    context.go(target);
  }
}
