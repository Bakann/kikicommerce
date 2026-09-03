import 'search_index_utils.dart';

/// Escapes a value for use inside a PocketBase filter string (double-quoted).
String escapeFilterValue(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}

/// Builds a PocketBase filter that matches all tokens in [query] against
/// [fieldName] using the `~` (LIKE) operator.
///
/// Multi-word queries are tokenized on whitespace and ANDed:
///   `"robe été"` → `fieldName ~ "robe" && fieldName ~ "ete"`
///
/// Returns `null` if [query] is null, empty, or contains no valid tokens.
String? buildSearchFilter({required String fieldName, required String? query}) {
  if (query == null || query.trim().isEmpty) return null;

  final tokens = normalizeForSearch(
    query,
  ).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  if (tokens.isEmpty) return null;

  return tokens
      .map((token) => '$fieldName ~ "${escapeFilterValue(token)}"')
      .join(' && ');
}

/// Combines multiple filter clauses with `&&`, ignoring nulls.
///
/// Returns `null` if all filters are null.
String? combineFilters(List<String?> filters) {
  final parts = filters.whereType<String>().toList();
  if (parts.isEmpty) return null;
  return parts.join(' && ');
}
