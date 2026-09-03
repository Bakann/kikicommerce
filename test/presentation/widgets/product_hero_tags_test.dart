import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/product_hero_tags.dart';

void main() {
  test('productImageHeroTag returns a stable product-scoped tag', () {
    expect(productImageHeroTag('prod-1'), 'product-image-hero-prod-1');
    expect(productImageHeroTag('prod-1'), productImageHeroTag('prod-1'));
    expect(productImageHeroTag('prod-2'), isNot(productImageHeroTag('prod-1')));
  });

  test('productImageHeroTag includes the source scope when provided so PLP and '
      'PDP-cross-sell surfaces produce distinct tags for the same product', () {
    final plpScope = productListingHeroScope(categoryId: 'cat-1');
    final crossSellScope = productPdpCrossSellHeroScope(
      currentProductId: 'prod-B',
      currentMainImageHeroTag: productImageHeroTag(
        'prod-B',
        sourceScope: plpScope,
      ),
    );

    final plpTagForA = productImageHeroTag('prod-A', sourceScope: plpScope);
    final crossSellTagForA = productImageHeroTag(
      'prod-A',
      sourceScope: crossSellScope,
    );

    expect(plpTagForA, isNot(crossSellTagForA));
    expect(plpTagForA, isNot(productImageHeroTag('prod-A')));
    expect(plpTagForA, contains('plp-cat-1'));
    expect(crossSellTagForA, contains('pdp-cross-sell'));
  });

  test(
    'productListingHeroScope falls back to a stable scope when categoryId is '
    'missing',
    () {
      expect(productListingHeroScope(categoryId: null), 'plp-catalog');
      expect(productListingHeroScope(categoryId: ''), 'plp-catalog');
      expect(productListingHeroScope(categoryId: 'cat-9'), 'plp-cat-9');
    },
  );

  test('productPdpCrossSellHeroScope is parameterized by the current PDP main '
      'hero tag so cross-sells from two PDPs of the same category produce '
      'distinct scopes', () {
    final scopeFromPdpB = productPdpCrossSellHeroScope(
      currentProductId: 'prod-B',
      currentMainImageHeroTag: 'product-image-hero-plp-cat-1-prod-B',
    );
    final scopeFromPdpC = productPdpCrossSellHeroScope(
      currentProductId: 'prod-C',
      currentMainImageHeroTag: 'product-image-hero-plp-cat-1-prod-C',
    );

    expect(scopeFromPdpB, isNot(scopeFromPdpC));
  });
}
