import 'dart:convert';

/// Centralised, deterministic cache-key builder for Kiki Commerce reads.
///
/// All builders apply the same canonicalisation rules:
/// - filter map keys are sorted alphabetically
/// - `null` values are dropped
/// - empty strings are dropped
/// - empty lists are dropped
/// - list values are sorted (stable, by string form) so `[red, blue]` and
///   `[blue, red]` produce the same key
/// - locale and currency are included in business keys
/// - optional segments (e.g. `customerSegment`) are only included when non-null
///   and non-empty
class KikiCacheKeys {
  KikiCacheKeys._();

  static String drawer({
    required String locale,
    required String currency,
    required String menuCode,
  }) {
    return _join('drawer', [
      'locale=$locale',
      'currency=$currency',
      'menu=$menuCode',
    ]);
  }

  static String homepage({required String locale, required String currency}) {
    return _join('homepage', ['locale=$locale', 'currency=$currency']);
  }

  static String cmsPage({
    required String locale,
    required String currency,
    required String pageCode,
  }) {
    return _join('cms', [
      'locale=$locale',
      'currency=$currency',
      'page=$pageCode',
    ]);
  }

  /// CMS PLP page read, keyed by category id. Shares the `cms:` prefix with
  /// [cmsPage] so a single prefix sweep invalidates every CMS read at once
  /// (see CmsPagesInvalidation).
  static String cmsPlp({
    required String locale,
    required String currency,
    required String categoryId,
  }) {
    return _join('cms', [
      'locale=$locale',
      'currency=$currency',
      'plp=$categoryId',
    ]);
  }

  static String categories({required String locale, required String currency}) {
    return _join('categories', ['locale=$locale', 'currency=$currency']);
  }

  /// Variant of [categories] for the drawer's category tree, parameterised
  /// by `includeHidden` because the response shape changes between
  /// edit-mode (admin sees hidden items) and storefront mode.
  static String drawerCategories({
    required String locale,
    required String currency,
    required bool includeHidden,
  }) {
    return _join('drawerCategories', [
      'locale=$locale',
      'currency=$currency',
      'visibility=${includeHidden ? 'all' : 'visible'}',
    ]);
  }

  static String defaultCategory({
    required String locale,
    required String currency,
  }) {
    return _join('defaultCategory', ['locale=$locale', 'currency=$currency']);
  }

  static String categoryBySlug({
    required String locale,
    required String currency,
    required String slug,
  }) {
    return _join('categoryBySlug', [
      'locale=$locale',
      'currency=$currency',
      'slug=$slug',
    ]);
  }

  static String plp({
    required String locale,
    required String currency,
    required String categorySlug,
    String? sort,
    Map<String, Object?> filters = const {},
    String? customerSegment,
  }) {
    final segments = <String>[
      'locale=$locale',
      'currency=$currency',
      'category=$categorySlug',
    ];
    if (sort != null && sort.isNotEmpty) {
      segments.add('sort=$sort');
    }
    if (customerSegment != null && customerSegment.isNotEmpty) {
      segments.add('segment=$customerSegment');
    }
    final canonicalisedFilters = _canonicaliseFilters(filters);
    if (canonicalisedFilters.isNotEmpty) {
      segments.add('filters=${jsonEncode(canonicalisedFilters)}');
    }
    return _join('plp', segments);
  }

  static String product({
    required String locale,
    required String currency,
    required String productId,
  }) {
    return _join('product', [
      'locale=$locale',
      'currency=$currency',
      'id=$productId',
    ]);
  }

  static String mediaMetadata({required String mediaId}) {
    return _join('mediaMeta', ['id=$mediaId']);
  }

  /// Holo foil overlay ingredients saved by the Foil studio for one product
  /// (`product_foils` collection). Locale/currency-independent.
  static String productFoil({required String productId}) {
    return _join('productFoil', ['id=$productId']);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static String _join(String resourceType, List<String> segments) {
    return '$resourceType:${segments.join('|')}';
  }

  /// Returns a sorted, value-cleaned representation of [filters] suitable for
  /// hashing into a cache key. Returns an empty map when nothing is left.
  static Map<String, Object> _canonicaliseFilters(
    Map<String, Object?> filters,
  ) {
    final result = <String, Object>{};
    final sortedKeys = filters.keys.toList()..sort();
    for (final key in sortedKeys) {
      final value = filters[key];
      final cleaned = _cleanValue(value);
      if (cleaned == null) continue;
      result[key] = cleaned;
    }
    return result;
  }

  /// Recursively cleans a filter value:
  /// - null → dropped
  /// - empty string → dropped
  /// - empty list → dropped
  /// - list → cleaned, then sorted by stringified form
  /// - map → keys sorted, values cleaned, dropped if empty
  static Object? _cleanValue(Object? value) {
    if (value == null) return null;
    if (value is String) {
      if (value.isEmpty) return null;
      return value;
    }
    if (value is List) {
      final cleaned = <Object>[];
      for (final item in value) {
        final cleanedItem = _cleanValue(item);
        if (cleanedItem != null) cleaned.add(cleanedItem);
      }
      if (cleaned.isEmpty) return null;
      cleaned.sort((a, b) => a.toString().compareTo(b.toString()));
      return cleaned;
    }
    if (value is Map) {
      final asMap = value.map((k, v) => MapEntry(k.toString(), v as Object?));
      final cleaned = _canonicaliseFilters(asMap);
      if (cleaned.isEmpty) return null;
      return cleaned;
    }
    return value;
  }
}
