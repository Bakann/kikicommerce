import '../application/catalog/search_query.dart';
import '../application/storefront/storefront_sport_segment.dart';
import '../core/utils/slug_utils.dart';
import '../domain/catalog/catalog_entities.dart';
import 'locale_route_resolver.dart';

final class CatalogRoutes {
  static const String home = '/';
  static const String admin = '/admin';
  static const String search = '/search';
  static const String story = '/story';
  static const String sportBase = '/sport';
  static const String catalogBase = '/catalog';
  static const String productBase = '/product';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String checkoutAccess = '/checkout/access';
  static const String checkoutGuestAddress = '/checkout/guest/address';

  /// Whether [location] points at a catalog category PLP (`/catalog` or
  /// `/catalog/...`, with or without a query) or the sport-flow PLP route
  /// (`/sport/<segment>/<slug>`). Used by navigation entry points (drawer, CMS
  /// links) to decide whether to push — so the PLP back arrow returns to the
  /// page the link was tapped from — rather than replace.
  static bool isCategoryPlpLocation(String location) {
    final uri = Uri.tryParse(location.trim());
    if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return false;
    final path = resolveLocaleRoute(uri).routePath;
    if (path == catalogBase || path.startsWith('$catalogBase/')) {
      return true;
    }

    final segments = Uri(path: path).pathSegments;
    return segments.length == 3 &&
        segments.first == 'sport' &&
        StorefrontSportSegment.tryParse(segments[1]) != null &&
        segments[2].isNotEmpty;
  }

  static String localizedLocation(String location, {required String locale}) {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.hasScheme || uri.host.isNotEmpty) {
      return location;
    }
    return localizedUriFor(uri, locale: locale).toString();
  }

  /// Experimental commercetools catalog lab page. Surfaced as a "Démo
  /// commercetools" link at the bottom of the drawer; a technical demo, not
  /// the official catalog.
  static const String labCommercetoolsProducts = '/lab/commercetools-products';

  /// Detail route for a commercetools lab product. [routeKey] may be a slug,
  /// key, or id (matched in that order by the lab repository). Isolated from
  /// the PocketBase PDP — see `LabCommercetoolsProductDetailPage`.
  static String labCommercetoolsProductByRouteKey(String routeKey) {
    return '$labCommercetoolsProducts/${Uri.encodeComponent(routeKey)}';
  }

  static String checkoutAccessLocation({String? email}) {
    final trimmedEmail = email?.trim();
    if (trimmedEmail == null || trimmedEmail.isEmpty) {
      return checkoutAccess;
    }
    return '$checkoutAccess?email=${Uri.encodeQueryComponent(trimmedEmail)}';
  }

  static String checkoutGuestAddressLocation({required String email}) {
    return '$checkoutGuestAddress?email=${Uri.encodeQueryComponent(email.trim())}';
  }

  static String searchUrl({
    required String query,
    SearchSort? sort,
    int? page,
  }) {
    final params = searchQueryToParams((
      query: query,
      sort: sort ?? SearchSort.newest,
      page: page ?? 1,
      perPage: 20,
    ));
    if (params.isEmpty) return search;
    final qs = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return '$search?$qs';
  }

  static String categoryBySlug(String slug) {
    return '$catalogBase/${Uri.encodeComponent(slug)}';
  }

  static String sportSegmentLocation(StorefrontSportSegment segment) {
    return '$sportBase/${Uri.encodeComponent(segment.wireName)}';
  }

  static String sportCategoryLocation({
    required StorefrontSportSegment segment,
    required String categorySlug,
  }) {
    return '$sportBase/'
        '${Uri.encodeComponent(segment.wireName)}/'
        '${Uri.encodeComponent(categorySlug)}';
  }

  static String sportProductLocation({
    required StorefrontSportSegment segment,
    required String categorySlug,
    required String productSlug,
  }) {
    return '$sportBase/'
        '${Uri.encodeComponent(segment.wireName)}/'
        '${Uri.encodeComponent(categorySlug)}/'
        '${Uri.encodeComponent(productSlug)}';
  }

  static String categoryById(String categoryId) {
    return '$catalogBase?categoryId=${Uri.encodeQueryComponent(categoryId)}';
  }

  static String productById(String productId) {
    return '$productBase?productId=${Uri.encodeQueryComponent(productId)}';
  }

  static String pageKeyLocation(String pageKey) {
    final normalized = pageKey.trim().toLowerCase();
    return switch (normalized) {
      '' => home,
      'home' => home,
      'search' => search,
      'admin' => admin,
      // Future-proofing: lets a managed drawer `page` item point at the
      // commercetools lab without being rewritten into a `/catalog/...` slug.
      'lab_commercetools_products' => labCommercetoolsProducts,
      'commercetools_lab' => labCommercetoolsProducts,
      _ => categoryBySlug(normalized.replaceAll('_', '-')),
    };
  }

  static String productBySlugs({
    required String categorySlug,
    required String productSlug,
  }) {
    return '$catalogBase/'
        '${Uri.encodeComponent(categorySlug)}/'
        '${Uri.encodeComponent(productSlug)}';
  }

  static String categoryLocation(CatalogCategory category) {
    final slug = category.slug?.trim();
    if (slug != null && slug.isNotEmpty) {
      return categoryBySlug(slug);
    }

    return categoryById(category.id);
  }

  static String productLocation({
    required CatalogCategory? category,
    required CatalogProduct product,
    String? productSlug,
    Iterable<CatalogProduct> siblingProducts = const [],
  }) {
    final categorySlug = category?.slug?.trim();
    if (categorySlug == null || categorySlug.isEmpty) {
      return productById(product.id);
    }

    final resolvedProductSlug = productSlug?.trim();

    return productBySlugs(
      categorySlug: categorySlug,
      productSlug: resolvedProductSlug != null && resolvedProductSlug.isNotEmpty
          ? resolvedProductSlug
          : canonicalProductSlug(
              product: product,
              siblingProducts: siblingProducts,
            ),
    );
  }
}
