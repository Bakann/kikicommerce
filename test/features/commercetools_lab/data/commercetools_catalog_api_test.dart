import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/error/app_exception.dart';
import 'package:kiki_commerce/features/commercetools_lab/data/commercetools_catalog_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('CommercetoolsCatalogApi.fetchProducts', () {
    test('parses items and hits /products?limit=20', () async {
      final requests = <http.Request>[];
      final api = CommercetoolsCatalogApi(
        client: MockClient((request) async {
          requests.add(request);
          return _jsonResponse({
            'items': [
              {
                'id': 'p1',
                'name': 'Bruno Chair',
                'slug': 'bruno-chair',
                'price': null,
              },
              {
                'id': 'p2',
                'name': 'Ben Pillow Cover',
                'price': {'centAmount': 1299, 'currencyCode': 'EUR'},
              },
            ],
          });
        }),
        baseUrl: 'https://proxy.example.dev',
      );

      final products = await api.fetchProducts();

      expect(products, hasLength(2));
      expect(products.first.name, 'Bruno Chair');
      expect(products.first.price, isNull);
      expect(products[1].price!.centAmount, 1299);

      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/products');
      expect(requests.single.url.queryParameters['limit'], '20');
    });

    test('normalizes a trailing slash in the base URL', () async {
      final requests = <http.Request>[];
      final api = CommercetoolsCatalogApi(
        client: MockClient((request) async {
          requests.add(request);
          return _jsonResponse({'items': []});
        }),
        baseUrl: 'https://proxy.example.dev/',
      );

      await api.fetchProducts();

      expect(
        requests.single.url.toString(),
        'https://proxy.example.dev/products?limit=20',
      );
    });

    test('throws ApiException on non-200', () async {
      final api = CommercetoolsCatalogApi(
        client: MockClient((_) async => http.Response('nope', 503)),
        baseUrl: 'https://proxy.example.dev',
      );

      expect(
        api.fetchProducts(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
      );
    });

    test('throws ApiException on malformed JSON', () async {
      final api = CommercetoolsCatalogApi(
        client: MockClient((_) async => http.Response('not json', 200)),
        baseUrl: 'https://proxy.example.dev',
      );

      expect(api.fetchProducts(), throwsA(isA<ApiException>()));
    });

    test('throws ApiException when items is not a List', () async {
      final api = CommercetoolsCatalogApi(
        client: MockClient((_) async => _jsonResponse({'items': 'oops'})),
        baseUrl: 'https://proxy.example.dev',
      );

      expect(api.fetchProducts(), throwsA(isA<ApiException>()));
    });

    test(
      'throws ApiException when items contains a non-object entry',
      () async {
        final api = CommercetoolsCatalogApi(
          client: MockClient(
            (_) async => _jsonResponse({
              'items': [
                {'id': 'p1'},
                'bad-item',
              ],
            }),
          ),
          baseUrl: 'https://proxy.example.dev',
        );

        expect(api.fetchProducts(), throwsA(isA<ApiException>()));
      },
    );

    test('throws ApiException for an invalid base URL', () async {
      final api = CommercetoolsCatalogApi(
        client: MockClient((_) async => _jsonResponse({'items': []})),
        baseUrl: 'not-a-url',
      );

      expect(api.fetchProducts(), throwsA(isA<ApiException>()));
    });

    test('throws when the base URL is empty', () async {
      final api = CommercetoolsCatalogApi(
        client: MockClient((_) async => _jsonResponse({'items': []})),
        baseUrl: '   ',
      );

      expect(api.fetchProducts(), throwsA(isA<ApiException>()));
    });
  });
}
