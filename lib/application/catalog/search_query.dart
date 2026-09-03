/// Sort options for product search results.
enum SearchSort {
  newest,
  nameAsc,
  nameDesc;

  String toPocketBaseSort() => switch (this) {
    SearchSort.newest => '-created',
    SearchSort.nameAsc => 'name',
    SearchSort.nameDesc => '-name',
  };

  // UI labels are resolved at the render site (see `searchSortLabel` in
  // search_results_page.dart) so this enum stays free of localized strings.

  static SearchSort fromName(String? name) {
    if (name == null) return SearchSort.newest;
    return SearchSort.values.where((s) => s.name == name).firstOrNull ??
        SearchSort.newest;
  }
}

/// Immutable search query — used as key for FutureProvider.family.
/// Dart records provide structural equality for free.
typedef SearchQuery = ({String? query, SearchSort sort, int page, int perPage});

const SearchQuery defaultSearchQuery = (
  query: null,
  sort: SearchSort.newest,
  page: 1,
  perPage: 20,
);

SearchQuery searchQueryFromUri(Uri uri) {
  final params = uri.queryParameters;
  return (
    query: params['q'],
    sort: SearchSort.fromName(params['sort']),
    page: int.tryParse(params['page'] ?? '') ?? 1,
    perPage: int.tryParse(params['perPage'] ?? '') ?? 20,
  );
}

Map<String, String> searchQueryToParams(SearchQuery query) {
  return {
    if (query.query != null && query.query!.isNotEmpty) 'q': query.query!,
    if (query.sort != SearchSort.newest) 'sort': query.sort.name,
    if (query.page > 1) 'page': '${query.page}',
    if (query.perPage != 20) 'perPage': '${query.perPage}',
  };
}
