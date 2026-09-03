import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/features/commercetools_lab/data/commercetools_catalog_adapter.dart';
import 'package:kiki_commerce/features/commercetools_lab/data/commercetools_catalog_product.dart';

void main() {
  group('CommercetoolsCatalogAdapter', () {
    test('maps a full product to a listing item with a price in units', () {
      const source = CommercetoolsCatalogProduct(
        id: 'abc',
        key: 'bruno-chair',
        slug: 'bruno-chair',
        name: 'Bruno Chair',
        description: 'A chair.',
        imageUrl: 'https://example.com/Bruno_Chair-1.1.jpeg',
        price: CommercetoolsCatalogPrice(centAmount: 7999, currencyCode: 'EUR'),
      );

      final item = CommercetoolsCatalogAdapter.toListingItem(source);

      expect(item.productId, 'abc');
      expect(item.product.name, 'Bruno Chair');
      expect(item.product.code, 'bruno-chair');
      expect(item.product.picture, isNotNull);
      expect(item.product.picture!.url, source.imageUrl);

      expect(item.prices, hasLength(1));
      final price = item.prices.single;
      expect(price.price, 79.99); // centAmount / 100
      expect(price.currencyCode, 'EUR');
      expect(price.currencySymbol, '€');
    });

    test('yields no prices when the source price is null', () {
      const source = CommercetoolsCatalogProduct(id: 'abc', name: 'No price');

      final item = CommercetoolsCatalogAdapter.toListingItem(source);

      expect(item.prices, isEmpty);
    });

    test('has no media when imageUrl is null or empty', () {
      const source = CommercetoolsCatalogProduct(id: 'abc', imageUrl: '');

      final product = CommercetoolsCatalogAdapter.toCatalogProduct(source);

      expect(product.picture, isNull);
    });

    test('falls back to key/slug/id for the name', () {
      const source = CommercetoolsCatalogProduct(id: 'abc', key: 'the-key');

      final product = CommercetoolsCatalogAdapter.toCatalogProduct(source);

      expect(product.name, 'the-key');
    });

    // The Worker now returns weserv-resized image URLs. CatalogMedia.listingUrl
    // still appends the PocketBase-style `&thumb=600x800f`; this guard documents
    // that the resize survives that append (weserv treats the extra `thumb` as a
    // no-op). Accepted lab compromise — external media should eventually avoid
    // thumbUrl/listingUrl mutation via source-aware CatalogMedia handling.
    test('weserv imageUrl stays resized through CatalogMedia.listingUrl', () {
      const weserv =
          'https://images.weserv.nl/?url=https%3A%2F%2Fstorage.googleapis.com%2Fx.jpeg&w=600&q=75&output=webp';
      const source = CommercetoolsCatalogProduct(
        id: 'abc',
        name: 'Resized',
        imageUrl: weserv,
      );

      final listingUrl = CommercetoolsCatalogAdapter.toCatalogProduct(
        source,
      ).picture!.listingUrl;

      final uri = Uri.parse(listingUrl);
      expect(uri.host, 'images.weserv.nl');
      expect(uri.queryParameters['w'], '600');
      expect(uri.queryParameters['q'], '75');
      expect(uri.queryParameters['output'], 'webp');
      // The legacy PocketBase-style thumb is still appended (no-op on weserv).
      expect(uri.queryParameters['thumb'], '600x800f');
    });
  });
}
