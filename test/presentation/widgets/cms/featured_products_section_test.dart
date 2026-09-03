import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/cms/featured_products_repository.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/featured_products_section.dart';

class _StubFeaturedProductsRepository implements FeaturedProductsRepository {
  final List<FeaturedProductData> data;

  const _StubFeaturedProductsRepository(this.data);

  @override
  Future<List<FeaturedProductData>> getFeaturedProducts(
    List<String> productIds, {
    required String locale,
  }) async {
    return data
        .where((d) => productIds.contains(d.product.id))
        .toList(growable: false);
  }
}

FeaturedProductData _fake(String id) {
  return FeaturedProductData(
    product: CatalogProduct(id: id, code: 'C-$id', name: 'Product $id'),
    prices: [CatalogPrice(id: 'price-$id', productId: id, price: 10.0)],
    imageUrl: null,
  );
}

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    required List<String> productIds,
    required String layout,
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          featuredProductsRepositoryProvider.overrideWithValue(
            _StubFeaturedProductsRepository(
              productIds.map(_fake).toList(growable: false),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeaturedProductsSection(
                config: FeaturedProductsConfig(
                  title: 'En vedette',
                  productIds: productIds,
                  layout: layout,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('does not use a GridView (no shrinkWrap layout pass)', (
    tester,
  ) async {
    await pumpSection(
      tester,
      productIds: const ['a', 'b', 'c', 'd'],
      layout: 'grid4',
      size: const Size(1440, 900),
    );
    expect(find.byType(GridView), findsNothing);
    for (final id in const ['a', 'b', 'c', 'd']) {
      expect(find.text('Product $id'), findsOneWidget);
    }
  });

  testWidgets('desktop grid4: 4 products on the same row', (tester) async {
    await pumpSection(
      tester,
      productIds: const ['a', 'b', 'c', 'd'],
      layout: 'grid4',
      size: const Size(1440, 900),
    );
    final ys = const [
      'a',
      'b',
      'c',
      'd',
    ].map((id) => tester.getTopLeft(find.text('Product $id')).dy).toList();
    expect(ys.toSet().length, 1);
  });

  testWidgets('mobile: 2 columns, second row keeps phantom alignment', (
    tester,
  ) async {
    // 3 products / 2 mobile columns → 2 rows, last row has 1 product + 1 phantom.
    await pumpSection(
      tester,
      productIds: const ['a', 'b', 'c'],
      layout: 'grid4',
      size: const Size(390, 1200),
    );
    for (final id in const ['a', 'b', 'c']) {
      expect(find.text('Product $id'), findsOneWidget);
    }
    final yA = tester.getTopLeft(find.text('Product a')).dy;
    final yB = tester.getTopLeft(find.text('Product b')).dy;
    final yC = tester.getTopLeft(find.text('Product c')).dy;
    expect(yA, yB, reason: 'first row has a and b');
    expect(yC, greaterThan(yA), reason: 'c falls onto the second row');
  });
}
