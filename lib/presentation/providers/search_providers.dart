import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../application/catalog/product_search_repository.dart';
import '../../application/catalog/search_query.dart';

final searchResultsProvider =
    FutureProvider.family<SearchResultPage, SearchQuery>((ref, query) {
      final trimmed = query.query?.trim();
      if (trimmed == null || trimmed.isEmpty) {
        return const SearchResultPage.empty();
      }

      return ref.watch(searchProductsProvider).call(query);
    });

/// Live product-name suggestions for the search entry screen. `autoDispose` so
/// stale per-keystroke queries are released once the input moves on; callers
/// should debounce before passing the text in to avoid a request per keystroke.
final productNameSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, query) {
      final trimmed = query.trim();
      // Single-character inputs match almost everything — wait for a real prefix.
      if (trimmed.length < 2) {
        return Future<List<String>>.value(const <String>[]);
      }
      return ref
          .watch(productSearchRepositoryProvider)
          .suggestProductNames(trimmed);
    });
