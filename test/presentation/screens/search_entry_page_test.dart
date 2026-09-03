import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/application/catalog/product_search_repository.dart';
import 'package:kiki_commerce/application/catalog/search_query.dart';
import 'package:kiki_commerce/l10n/app_localizations.dart';
import 'package:kiki_commerce/presentation/screens/search_entry_page.dart';
import 'package:go_router/go_router.dart';

class _FakeSearchRepository implements ProductSearchRepository {
  @override
  Future<SearchResultPage> searchProducts(SearchQuery query) async =>
      const SearchResultPage.empty();

  @override
  Future<List<String>> suggestProductNames(
    String query, {
    int limit = 8,
  }) async => const ['Air Max', 'Air Force'];
}

Widget _searchStub(Uri uri) {
  final query = searchQueryFromUri(uri).query?.trim() ?? '';
  return Scaffold(
    body: query.isEmpty ? const SearchEntryPage() : Text('Results: $query'),
  );
}

Future<void> _pumpSearch(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: CatalogRoutes.search,
    routes: [
      for (final path in const ['/search', '/fr/search', '/en/search'])
        GoRoute(path: path, builder: (_, state) => _searchStub(state.uri)),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        productSearchRepositoryProvider.overrideWithValue(
          _FakeSearchRepository(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('typing shows live suggestions, tap runs the search', (
    tester,
  ) async {
    await _pumpSearch(tester);

    await tester.enterText(
      find.byKey(const ValueKey('search-entry-field')),
      'air',
    );
    // Debounce window then provider resolution.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Meilleures suggestions'), findsOneWidget);
    expect(find.text('Air Max', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Air Max', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('Results: Air Max'), findsOneWidget);
  });

  testWidgets('single-character input shows no suggestions', (tester) async {
    await _pumpSearch(tester);

    await tester.enterText(
      find.byKey(const ValueKey('search-entry-field')),
      'a',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Meilleures suggestions'), findsNothing);
  });
}
