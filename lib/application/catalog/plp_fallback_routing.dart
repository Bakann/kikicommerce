/// URL-only fallback routing for PLP back actions without Navigator history.
///
/// This helper intentionally does not resolve catalog hierarchy. It only
/// derives a parent-looking route from the current URL by removing the last
/// path segment. Real catalog parent navigation should come from category data
/// or breadcrumbs when that information is available.
final class PlpFallbackRouting {
  static const Set<String> defaultPlpParentQueryKeys = {'sort', 'view'};

  const PlpFallbackRouting._();

  static String? urlOnlyFallbackParentLocation(
    Uri uri, {
    Set<String> preservedQueryKeys = defaultPlpParentQueryKeys,
  }) {
    final segments = uri.pathSegments;
    if (segments.length <= 1) {
      return null;
    }

    final encodedParentSegments = segments
        .take(segments.length - 1)
        .map(Uri.encodeComponent)
        .join('/');
    final queryParameters = portableParentQueryParameters(
      uri,
      preservedQueryKeys,
    );

    return Uri(
      path: '/$encodedParentSegments',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
  }

  /// The subset of [uri]'s query parameters that are safe to carry up to a
  /// parent PLP. Only [preservedQueryKeys] survive; category-specific filters
  /// (size, surface, …) are intentionally dropped. Shared with
  /// `PlpParentRouting` so business and URL-only parents agree on the rules.
  static Map<String, Object> portableParentQueryParameters(
    Uri uri, [
    Set<String> preservedQueryKeys = defaultPlpParentQueryKeys,
  ]) {
    final queryParameters = <String, Object>{};
    for (final key in preservedQueryKeys) {
      final values = uri.queryParametersAll[key];
      if (values == null || values.isEmpty) {
        continue;
      }
      queryParameters[key] = values.length == 1 ? values.single : values;
    }
    return queryParameters;
  }
}
