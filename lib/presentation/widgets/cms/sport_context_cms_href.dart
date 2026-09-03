import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../app/catalog_routes.dart';
import '../../../app/locale_route_resolver.dart';
import '../../../application/storefront/storefront_sport_segment.dart';

/// Keeps category CMS links inside the active sport flow.
///
/// CMS records store generic category targets as `/catalog/<slug>`. When those
/// links are tapped from `/sport/<segment>` or `/sport/<segment>/<slug>`, the
/// same PLP must open as `/sport/<segment>/<slug>` so GoRouter keeps the
/// existing [SportFlowShell] and its single bottom nav instance mounted.
String sportContextualCmsHref(BuildContext context, String href) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return trimmed;

  final categorySlug = _catalogSlugFromHref(trimmed);
  if (categorySlug == null) return trimmed;

  final segment = _currentSportSegment(context);
  if (segment == null) return trimmed;

  final sourceUri = Uri.tryParse(trimmed);
  if (sourceUri == null) return trimmed;

  return Uri(
    path: CatalogRoutes.sportCategoryLocation(
      segment: segment,
      categorySlug: categorySlug,
    ),
    queryParameters: sourceUri.queryParametersAll.isEmpty
        ? null
        : sourceUri.queryParametersAll,
    fragment: sourceUri.fragment.isEmpty ? null : sourceUri.fragment,
  ).toString();
}

String? _catalogSlugFromHref(String href) {
  final uri = Uri.tryParse(href);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return null;

  final routePath = resolveLocaleRoute(uri).routePath;
  final segments = Uri(path: routePath).pathSegments;
  if (segments.length == 2 &&
      segments.first == 'catalog' &&
      segments[1].isNotEmpty) {
    return segments[1];
  }
  return null;
}

StorefrontSportSegment? _currentSportSegment(BuildContext context) {
  final Uri currentUri;
  try {
    currentUri = GoRouterState.of(context).uri;
  } catch (_) {
    return null;
  }

  final routePath = resolveLocaleRoute(currentUri).routePath;
  final segments = Uri(path: routePath).pathSegments;
  if ((segments.length != 2 && segments.length != 3) ||
      segments.first != 'sport') {
    return null;
  }
  return StorefrontSportSegment.tryParse(segments[1]);
}
