import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/catalog/product_search_repository.dart';
import 'package:kiki_commerce/application/catalog/search_query.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/l10n/app_localizations.dart';
import 'package:kiki_commerce/presentation/providers/search_providers.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/screens/search_results_page.dart';

const _query = (query: 'xyz', sort: SearchSort.newest, page: 1, perPage: 20);

Future<void> _pumpSearch(WidgetTester tester, Locale locale) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchResultsProvider(
          _query,
        ).overrideWith((ref) => const SearchResultPage.empty()),
        effectiveStorefrontThemeAsyncProvider.overrideWithValue(
          const AsyncValue.data(StorefrontTheme.nike),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const Scaffold(body: SearchResultsPage(query: _query)),
      ),
    ),
  );
}

void main() {
  testWidgets('empty results render in French', (tester) async {
    await _pumpSearch(tester, const Locale('fr'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun résultat pour "xyz".'), findsOneWidget);
  });

  testWidgets('empty results render in English', (tester) async {
    await _pumpSearch(tester, const Locale('en'));
    await tester.pumpAndSettle();

    expect(find.text('No results for "xyz".'), findsOneWidget);
  });
}
