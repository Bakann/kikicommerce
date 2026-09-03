import '../../domain/catalog/catalog_entities.dart';
import 'plp_fallback_routing.dart';

/// Resolves the destination of a PLP "back" action when there is no Navigator
/// history to pop.
///
/// The resolution is ordered by reliability:
///   1. **Business parent** — the current category's [CatalogCategory.parentId]
///      looked up among the available categories. This is real catalog data,
///      so it wins over anything derived from the URL. The current category is
///      taken from the feed when present, or resolved from `currentCategoryId`
///      among the available categories (so empty PLPs still resolve a parent).
///   2. **URL-only fallback** — [PlpFallbackRouting.urlOnlyFallbackParentLocation],
///      which merely strips the last path segment. A last resort, not a real
///      parent resolution.
///   3. **Catalog base** — when neither of the above yields a location.
///
/// Business resolution only applies inside the flat `/catalog` namespace, where
/// a category's canonical page is `/catalog/<slug>`. Sport routes are
/// segment-driven (`/sport/<segment>/<category>/…`): walking up the URL segment
/// tree is the intended behaviour there, so they deliberately stay on the
/// URL-only fallback path.
final class PlpParentRouting {
  const PlpParentRouting._();

  static String resolveParentLocation({
    required Uri currentUri,
    required String catalogBaseLocation,
    CatalogCategory? currentCategory,
    String? currentCategoryId,
    List<CatalogCategory> availableCategories = const [],
    Set<String> preservedQueryKeys =
        PlpFallbackRouting.defaultPlpParentQueryKeys,
  }) {
    final businessParent = _businessParentLocation(
      currentUri: currentUri,
      catalogBaseLocation: catalogBaseLocation,
      currentCategory: currentCategory,
      currentCategoryId: currentCategoryId,
      availableCategories: availableCategories,
      preservedQueryKeys: preservedQueryKeys,
    );
    if (businessParent != null) {
      return businessParent;
    }

    return PlpFallbackRouting.urlOnlyFallbackParentLocation(
          currentUri,
          preservedQueryKeys: preservedQueryKeys,
        ) ??
        catalogBaseLocation;
  }

  /// The parent category page resolved from catalog data, or `null` when no
  /// reliable business parent exists for [currentUri].
  static String? _businessParentLocation({
    required Uri currentUri,
    required String catalogBaseLocation,
    required CatalogCategory? currentCategory,
    required String? currentCategoryId,
    required List<CatalogCategory> availableCategories,
    required Set<String> preservedQueryKeys,
  }) {
    // The feed exposes the current category (cheaply, from any product item),
    // but an empty category has no item to derive it from. Fall back to a
    // lookup of [currentCategoryId] among the available categories so the
    // business parent still resolves for empty PLPs (e.g. just-created ones).
    final category =
        currentCategory ?? _findCurrent(availableCategories, currentCategoryId);
    final parentId = category?.parentId;
    if (parentId == null || parentId.isEmpty) {
      return null;
    }

    // The flat catalog namespace can be multi-segment (e.g. `/shop/catalog`):
    // the parent page keeps the whole base prefix and appends the parent slug.
    final baseSegments = Uri.parse(catalogBaseLocation).pathSegments;
    if (baseSegments.isEmpty ||
        !_startsWith(currentUri.pathSegments, baseSegments)) {
      return null;
    }

    final parent = _findById(availableCategories, parentId);
    final parentSlug = parent?.slug?.trim();
    if (parentSlug == null || parentSlug.isEmpty) {
      return null;
    }

    final queryParameters = PlpFallbackRouting.portableParentQueryParameters(
      currentUri,
      preservedQueryKeys,
    );
    final parentSegments = [
      ...baseSegments,
      parentSlug,
    ].map(Uri.encodeComponent).join('/');
    return Uri(
      path: '/$parentSegments',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
  }

  /// Whether [segments] begins with every segment of [prefix], in order.
  static bool _startsWith(List<String> segments, List<String> prefix) {
    if (segments.length < prefix.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (segments[i] != prefix[i]) {
        return false;
      }
    }
    return true;
  }

  /// The current category resolved by id (then slug) among [categories].
  static CatalogCategory? _findCurrent(
    List<CatalogCategory> categories,
    String? categoryIdOrSlug,
  ) {
    if (categoryIdOrSlug == null || categoryIdOrSlug.isEmpty) {
      return null;
    }
    for (final category in categories) {
      if (category.id == categoryIdOrSlug) {
        return category;
      }
    }
    for (final category in categories) {
      if (category.slug == categoryIdOrSlug) {
        return category;
      }
    }
    return null;
  }

  static CatalogCategory? _findById(
    List<CatalogCategory> categories,
    String id,
  ) {
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }
}
