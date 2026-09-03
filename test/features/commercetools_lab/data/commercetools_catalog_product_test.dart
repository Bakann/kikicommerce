import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/features/commercetools_lab/data/commercetools_catalog_product.dart';

void main() {
  group('CommercetoolsCatalogProduct.fromJson', () {
    test('parses an item with price: null', () {
      final product = CommercetoolsCatalogProduct.fromJson({
        'id': 'd2748de5-a89d-4f76-8a51-80d418198f90',
        'key': 'bruno-chair',
        'slug': 'bruno-chair',
        'name': 'Bruno Chair',
        'description': 'A chair.',
        'imageUrl': 'https://example.com/Bruno_Chair-1.1.jpeg',
        'price': null,
      });

      expect(product.id, 'd2748de5-a89d-4f76-8a51-80d418198f90');
      expect(product.key, 'bruno-chair');
      expect(product.slug, 'bruno-chair');
      expect(product.name, 'Bruno Chair');
      expect(product.imageUrl, 'https://example.com/Bruno_Chair-1.1.jpeg');
      expect(product.price, isNull);
    });

    test('parses an item with a full price object', () {
      final product = CommercetoolsCatalogProduct.fromJson({
        'id': 'p1',
        'name': 'Ben Pillow Cover',
        'price': {'centAmount': 1299, 'currencyCode': 'EUR'},
      });

      expect(product.price, isNotNull);
      expect(product.price!.centAmount, 1299);
      expect(product.price!.currencyCode, 'EUR');
    });

    test('parses an item missing optional fields without throwing', () {
      final product = CommercetoolsCatalogProduct.fromJson({'id': 'only-id'});

      expect(product.id, 'only-id');
      expect(product.key, isNull);
      expect(product.slug, isNull);
      expect(product.name, isNull);
      expect(product.description, isNull);
      expect(product.imageUrl, isNull);
      expect(product.price, isNull);
    });
  });
}
