import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/widgets/product_card.dart';

const _media = CatalogMedia(
  id: 'media-1',
  url: 'https://example.com/listing.jpg',
  previewUrl: 'https://example.com/listing-preview.jpg',
);

const _product = CatalogProduct(
  id: 'product-1',
  code: 'PRODUCT-1',
  name: 'Bruno Chair',
  picture: _media,
);

Widget _harness({required ProductCardOpenCallback onOpen}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 240,
          height: 480,
          child: ProductCard(
            product: _product,
            prices: const [],
            routeName: '/lab/commercetools-products/bruno-chair',
            enableHeroTransition: true,
            onOpen: onOpen,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping invokes onOpen with the card hero metadata instead of '
      'the default navigation', (tester) async {
    ProductCardOpenContext? captured;

    await tester.pumpWidget(
      _harness(
        onOpen: (openContext) async {
          captured = openContext;
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('product_card_product-1')));
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.product.id, 'product-1');
    expect(captured!.routeName, '/lab/commercetools-products/bruno-chair');
    // enableHeroTransition + a listing image that matches the primary media →
    // the card resolved an eligible Hero and a tag.
    expect(captured!.heroEligible, isTrue);
    expect(captured!.imageHeroTag, isNotNull);
    expect(captured!.heroListingMedia?.id, 'media-1');
  });
}
