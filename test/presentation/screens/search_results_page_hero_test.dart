import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/catalog/product_search_repository.dart';
import 'package:kiki_commerce/application/catalog/search_query.dart';
import 'package:kiki_commerce/application/storefront/storefront_plp_profile.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/l10n/app_localizations.dart';
import 'package:kiki_commerce/presentation/providers/search_providers.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/screens/search_results_page.dart';
import 'package:kiki_commerce/presentation/widgets/product_card.dart';

const _query = (query: 'air', sort: SearchSort.newest, page: 1, perPage: 20);

void main() {
  testWidgets(
    'search results reuse the PLP product card (hero transition + theme presentation)',
    (tester) async {
      const product = CatalogProduct(id: 'p1', code: 'P1', name: 'Air Max');
      const page = SearchResultPage(
        page: 1,
        perPage: 20,
        totalItems: 1,
        totalPages: 1,
        items: [SearchResultItem(product: product, prices: [])],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchResultsProvider(_query).overrideWith((ref) => page),
            // Nike apparence → sport PLP presentation.
            effectiveStorefrontThemeAsyncProvider.overrideWithValue(
              const AsyncValue.data(StorefrontTheme.nike),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('fr'),
            home: const Scaffold(body: SearchResultsPage(query: _query)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = tester.widget<ProductCard>(find.byType(ProductCard));
      expect(card.enableHeroTransition, isTrue);
      expect(card.presentation, ProductCardPresentation.sportPerformance);
    },
  );
}
