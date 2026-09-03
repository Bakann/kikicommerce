import '../../app/catalog_routes.dart';
import '../../app/locale_route_resolver.dart';

/// Hero tag for the category-tile → PLP transition. The source tile and the
/// destination PLP hero must compute the SAME tag; both derive it from the
/// category slug (the only identifier known synchronously on both sides — the
/// tile knows its href, the PLP route knows its `:categorySlug` path param).
String categoryPlpHeroTag(String slugKey) => 'category-plp-hero-$slugKey';

/// Derives the shared hero key from a CMS href. Returns null when [href] does
/// not point at a concrete category PLP, in which case the caller must fall
/// back to plain navigation with no Hero.
///
/// The key must equal the `heroSlugKey` the destination PLP receives (see
/// `StorefrontHomePage`), so it is the category slug:
/// - `/catalog/<slug>` → `<slug>`
/// - `/sport/<segment>/<slug>` → `<slug>` (sport themes reach their PLP through
///   the `/sport` route namespace, not `/catalog`)
/// - `/catalog?categoryId=<id>` → `id:<id>` (by-id route)
///
/// A bare `/catalog` or a `/sport/<segment>` landing has no category target and
/// returns null.
String? categoryPlpHeroKeyFromHref(String href) {
  final trimmed = href.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  final resolution = resolveLocaleRoute(uri);
  final segments = Uri.parse(resolution.routePath).pathSegments;

  // /sport/<segment>/<categorySlug> — the sport-theme category PLP.
  if (segments.length == 3 &&
      segments.first == 'sport' &&
      segments[2].isNotEmpty) {
    return segments[2];
  }

  // /catalog or /catalog/<slug> (and the /catalog?categoryId=<id> form).
  if (CatalogRoutes.isCategoryPlpLocation(trimmed)) {
    if (segments.length >= 2 && segments[1].isNotEmpty) {
      return segments[1];
    }
    final categoryId = uri.queryParameters['categoryId'];
    if (categoryId != null && categoryId.isNotEmpty) {
      return 'id:$categoryId';
    }
  }
  return null;
}
