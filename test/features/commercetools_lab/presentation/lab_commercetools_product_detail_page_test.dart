import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/features/commercetools_lab/data/commercetools_catalog_adapter.dart';
import 'package:kiki_commerce/features/commercetools_lab/data/commercetools_catalog_product.dart';
import 'package:kiki_commerce/features/commercetools_lab/navigation/commercetools_product_detail_navigation.dart';
import 'package:kiki_commerce/features/commercetools_lab/presentation/commercetools_lab_providers.dart';
import 'package:kiki_commerce/features/commercetools_lab/presentation/lab_commercetools_product_detail_page.dart';

import '../../../support/l10n_harness.dart';

const _source = CommercetoolsCatalogProduct(
  id: 'ct-id-1',
  key: 'bruno-chair',
  slug: 'bruno-chair',
  name: 'Bruno Chair',
  description: 'A comfortable chair.',
  price: CommercetoolsCatalogPrice(centAmount: 7999, currencyCode: 'EUR'),
);

final _item = CommercetoolsCatalogAdapter.toListingItem(_source);

Widget _surface(Widget page) {
  return MaterialApp(
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: testSupportedLocales,
    locale: const Locale('fr'),
    home: Scaffold(
      body: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: page,
      ),
    ),
  );
}

void main() {
  testWidgets('renders the product from the route hint', (tester) async {
    final hint = CommercetoolsProductDetailRouteHint(
      listingItem: CommercetoolsCatalogAdapter.toListingItem(_source),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: _surface(
          LabCommercetoolsProductDetailPage(
            routeKey: 'bruno-chair',
            hint: hint,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Bruno Chair'), findsWidgets);
    expect(find.text('Produit introuvable.'), findsNothing);
  });

  testWidgets('resolves the product from the provider on deep link', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          commercetoolsListingItemByRouteKeyProvider.overrideWith(
            (ref, routeKey) async => routeKey == 'bruno-chair' ? _item : null,
          ),
        ],
        child: _surface(
          const LabCommercetoolsProductDetailPage(routeKey: 'bruno-chair'),
        ),
      ),
    );
    await tester.pump(); // resolve the future

    expect(find.text('Bruno Chair'), findsWidgets);
  });

  testWidgets('shows a not-found message when the route key is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          commercetoolsListingItemByRouteKeyProvider.overrideWith(
            (ref, routeKey) async => null,
          ),
        ],
        child: _surface(
          const LabCommercetoolsProductDetailPage(routeKey: 'missing'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Produit introuvable.'), findsOneWidget);
  });

  testWidgets('shows a loading indicator while the product loads', (
    tester,
  ) async {
    final completer = Completer<CatalogListingItem?>();
    addTearDown(() => completer.complete(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          commercetoolsListingItemByRouteKeyProvider.overrideWith(
            (ref, routeKey) => completer.future,
          ),
        ],
        child: _surface(
          const LabCommercetoolsProductDetailPage(routeKey: 'bruno-chair'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
