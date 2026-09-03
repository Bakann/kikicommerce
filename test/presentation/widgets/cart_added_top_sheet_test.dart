import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/widgets/cart_added_top_sheet.dart';

void main() {
  Future<void> openSheet(WidgetTester tester, {String? summary}) async {
    final product = CatalogProduct(
      id: 'p1',
      code: 'P-001',
      name: 'Produit de test',
      summary: summary,
    );
    const price = CatalogPrice(id: 'price-1', productId: 'p1', price: 99.0);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCartAddedTopSheet(
                  context: context,
                  product: product,
                  defaultPrice: price,
                  symbol: '€',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Size rowSize(WidgetTester tester) {
    final imageFinder = find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 140 && w.height == null,
    );
    expect(imageFinder, findsWidgets);
    final rowFinder = find.ancestor(
      of: imageFinder.first,
      matching: find.byType(Row),
    );
    return tester.getSize(rowFinder.first);
  }

  testWidgets('product row stays at 140 px tall with a short summary', (
    tester,
  ) async {
    await openSheet(tester, summary: 'Court');
    expect(rowSize(tester).height, 140.0);
  });

  testWidgets(
    'product row stays at 140 px tall with a long summary (no IntrinsicHeight stretch)',
    (tester) async {
      await openSheet(tester, summary: 'Lorem ipsum ' * 80);
      expect(rowSize(tester).height, 140.0);
    },
  );
}
