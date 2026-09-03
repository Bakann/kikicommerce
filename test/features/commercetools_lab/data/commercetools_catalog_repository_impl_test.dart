import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/features/commercetools_lab/data/commercetools_catalog_api.dart';
import 'package:kiki_commerce/features/commercetools_lab/data/commercetools_catalog_repository_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

CommercetoolsCatalogRepositoryImpl _repo(MockClient client) {
  return CommercetoolsCatalogRepositoryImpl(
    api: CommercetoolsCatalogApi(
      client: client,
      baseUrl: 'https://proxy.example.dev',
    ),
  );
}

void main() {
  group('CommercetoolsCatalogRepositoryImpl', () {
    test('getProducts maps Worker products to CatalogListingItems', () async {
      final repo = _repo(
        MockClient(
          (_) async => _json({
            'items': [
              {
                'id': 'p1',
                'slug': 'bruno-chair',
                'name': 'Bruno Chair',
                'price': {'centAmount': 7999, 'currencyCode': 'EUR'},
              },
            ],
          }),
        ),
      );

      final items = await repo.getProducts();

      expect(items, hasLength(1));
      expect(items.single.product.name, 'Bruno Chair');
      expect(items.single.prices.single.price, 79.99);
    });

    test('getProductByRouteKey matches slug, then key, then id', () async {
      final repo = _repo(
        MockClient(
          (_) async => _json({
            'items': [
              {'id': 'id-1', 'slug': 'slug-1', 'key': 'key-1', 'name': 'A'},
              {'id': 'shared', 'slug': 'other', 'key': 'shared', 'name': 'B'},
            ],
          }),
        ),
      );

      // Only product B carries the key 'shared'; resolved via the key scan.
      final byKey = await repo.getProductByRouteKey('shared');
      expect(byKey?.product.name, 'B');

      final bySlug = await repo.getProductByRouteKey('slug-1');
      expect(bySlug?.product.name, 'A');

      final byId = await repo.getProductByRouteKey('id-1');
      expect(byId?.product.name, 'A');
    });

    test('getProductByRouteKey prefers slug over key on collision', () async {
      final repo = _repo(
        MockClient(
          (_) async => _json({
            'items': [
              {'id': 'b', 'key': 'x', 'name': 'KeyMatch'},
              {'id': 'a', 'slug': 'x', 'name': 'SlugMatch'},
            ],
          }),
        ),
      );

      final match = await repo.getProductByRouteKey('x');
      expect(match?.product.name, 'SlugMatch');
    });

    test('getProductByRouteKey returns null when nothing matches', () async {
      final repo = _repo(
        MockClient(
          (_) async => _json({
            'items': [
              {'id': 'p1', 'slug': 'bruno-chair', 'name': 'Bruno Chair'},
            ],
          }),
        ),
      );

      expect(await repo.getProductByRouteKey('missing'), isNull);
    });
  });
}
