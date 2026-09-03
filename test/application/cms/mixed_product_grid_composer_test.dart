import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/cms/mixed_product_grid_composer.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

void main() {
  group('MixedProductGridComposer', () {
    test('places inserts after N catalog products', () {
      final config = MixedProductGridConfig.fromJson({
        'schemaVersion': 1,
        'inserts': [
          {
            'type': 'category_tile',
            'slotPosition': 2,
            'title': 'Accessoires',
            'href': '/catalog/accessoires',
          },
        ],
      });

      final out = MixedProductGridComposer.compose(
        products: [_item('p1', 1), _item('p2', 2), _item('p3', 3)],
        config: config,
        activeSort: 'manual',
        now: DateTime.utc(2026),
      );

      expect(_productId(out[0]), 'p1');
      expect(_productId(out[1]), 'p2');
      expect(out[2], isA<MixedGridInsertItem>());
      expect(_productId(out[3]), 'p3');
    });

    test('excluded product wins over pinned product', () {
      final config = MixedProductGridConfig.fromJson({
        'schemaVersion': 1,
        'excludedProductIds': ['p2'],
        'pinnedProducts': [
          {'productId': 'p2', 'slotPosition': 0},
        ],
      });

      final out = MixedProductGridComposer.compose(
        products: [_item('p1', 1), _item('p2', 2)],
        config: config,
        activeSort: 'manual',
        now: DateTime.utc(2026),
      );

      expect(out.whereType<MixedGridProductItem>(), hasLength(1));
      expect(_productId(out.single), 'p1');
    });

    test('pins are active only in manual sort', () {
      final config = MixedProductGridConfig.fromJson({
        'schemaVersion': 1,
        'pinnedProducts': [
          {'productId': 'p3', 'slotPosition': 0},
        ],
      });
      final products = [
        _item('p1', 1, onlineDate: DateTime.utc(2026, 3)),
        _item('p2', 2, onlineDate: DateTime.utc(2026, 2)),
        _item('p3', 3, onlineDate: DateTime.utc(2026, 1)),
      ];

      final manual = MixedProductGridComposer.compose(
        products: products,
        config: config,
        activeSort: 'manual',
        now: DateTime.utc(2026, 4),
      );
      final newest = MixedProductGridComposer.compose(
        products: products,
        config: config,
        activeSort: 'newest',
        now: DateTime.utc(2026, 4),
      );

      expect(_productId(manual.first), 'p3');
      expect(_productId(newest.first), 'p1');
    });

    test('insert collision with pin is pushed to next product position', () {
      final config = MixedProductGridConfig.fromJson({
        'schemaVersion': 1,
        'pinnedProducts': [
          {'productId': 'p2', 'slotPosition': 0},
        ],
        'inserts': [
          {
            'type': 'category_tile',
            'slotPosition': 0,
            'title': 'Accessoires',
            'href': '/catalog/accessoires',
          },
        ],
      });

      final out = MixedProductGridComposer.compose(
        products: [_item('p1', 1), _item('p2', 2)],
        config: config,
        activeSort: 'manual',
        now: DateTime.utc(2026),
      );

      expect(_productId(out[0]), 'p2');
      expect(out[1], isA<MixedGridInsertItem>());
      expect(_productId(out[2]), 'p1');
    });

    test('unknown inserts are ignored', () {
      final config = MixedProductGridConfig.fromJson({
        'schemaVersion': 1,
        'inserts': [
          {'type': 'unknown_tile', 'slotPosition': 0},
        ],
      });

      final out = MixedProductGridComposer.compose(
        products: [_item('p1', 1)],
        config: config,
        activeSort: 'manual',
        now: DateTime.utc(2026),
      );

      expect(out, hasLength(1));
      expect(out.single, isA<MixedGridProductItem>());
    });

    test('legacy default placeholder insert is ignored', () {
      final config = MixedProductGridConfig.fromJson({
        'schemaVersion': 1,
        'inserts': [
          {
            'type': 'category_tile',
            'slotPosition': 1,
            'displaySize': 'small',
            'title': 'Nouvelle insertion',
            'href': '/catalog',
            'imageMobile': null,
            'imageDesktop': null,
          },
        ],
      });

      final out = MixedProductGridComposer.compose(
        products: [_item('p1', 1), _item('p2', 2)],
        config: config,
        activeSort: 'manual',
        now: DateTime.utc(2026),
      );

      expect(out, hasLength(2));
      expect(out, everyElement(isA<MixedGridProductItem>()));
    });
  });
}

CatalogListingItem _item(
  String id,
  int position, {
  DateTime? onlineDate,
  double price = 10,
}) {
  return CatalogListingItem(
    id: 'cp_$id',
    categoryId: 'cat1',
    productId: id,
    product: CatalogProduct(
      id: id,
      code: id.toUpperCase(),
      name: 'Product $id',
      onlineDate: onlineDate,
    ),
    position: position,
    category: const CatalogCategory(
      id: 'cat1',
      code: 'CAT1',
      name: 'Catégorie',
      slug: 'categorie',
    ),
    prices: [CatalogPrice(id: 'price_$id', productId: id, price: price)],
  );
}

String? _productId(MixedGridItem item) {
  return switch (item) {
    MixedGridProductItem(:final listingItem) => listingItem.productId,
    MixedGridInsertItem() => null,
  };
}
