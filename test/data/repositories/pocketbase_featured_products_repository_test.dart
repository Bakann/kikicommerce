import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/data/api/pocketbase_client.dart';
import 'package:kiki_commerce/data/repositories/pocketbase_featured_products_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PocketBaseFeaturedProductsRepository', () {
    test('empty input returns empty without any network call', () async {
      final requests = <http.Request>[];
      final repo = PocketBaseFeaturedProductsRepository(
        client: PocketBaseClient(
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response('Not found', 404);
          }),
          baseUrl: 'https://example.test',
        ),
      );

      final result = await repo.getFeaturedProducts(const [], locale: 'fr');

      expect(result, isEmpty);
      expect(requests, isEmpty);
    });

    test(
      'returns products in requested order with one bulk query each',
      () async {
        final requests = <http.Request>[];
        final repo = PocketBaseFeaturedProductsRepository(
          client: PocketBaseClient(
            httpClient: MockClient((request) async {
              requests.add(request);
              if (request.url.path.endsWith('/products/records')) {
                // Returned out of order on purpose: the repository must
                // re-order the response back into the requested id order.
                return _jsonResponse(_productsPageJson(['p3', 'p1', 'p2']));
              }
              if (request.url.path.endsWith('/priceRows/records')) {
                return _jsonResponse(_pricesPageJson());
              }
              return http.Response('Not found', 404);
            }),
            baseUrl: 'https://example.test',
          ),
        );

        final result = await repo.getFeaturedProducts([
          'p1',
          'p2',
          'p3',
        ], locale: 'fr');

        expect(result.map((f) => f.product.id), ['p1', 'p2', 'p3']);

        // No N+1: exactly one products call and one priceRows call, both
        // bulk-filtered with `||` rather than one request per id.
        expect(
          requests.where((r) => r.url.path.endsWith('/products/records')),
          hasLength(1),
        );
        expect(
          requests.where((r) => r.url.path.endsWith('/priceRows/records')),
          hasLength(1),
        );

        final productsFilter = requests
            .firstWhere((r) => r.url.path.endsWith('/products/records'))
            .url
            .queryParameters['filter'];
        expect(productsFilter, contains('id="p1"'));
        expect(productsFilter, contains('id="p3"'));
        expect(productsFilter, contains('||'));
        expect(productsFilter, contains('isActive=true'));

        // p1 carries a price row; p2 has none.
        final p1 = result.firstWhere((f) => f.product.id == 'p1');
        expect(p1.prices, isNotEmpty);
        expect(p1.imageUrl, isNotNull);
        final p2 = result.firstWhere((f) => f.product.id == 'p2');
        expect(p2.prices, isEmpty);
      },
    );

    test('drops ids missing from the response', () async {
      final repo = PocketBaseFeaturedProductsRepository(
        client: PocketBaseClient(
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/products/records')) {
              return _jsonResponse(_productsPageJson(['p1'])); // p2 absent
            }
            if (request.url.path.endsWith('/priceRows/records')) {
              return _jsonResponse(_emptyPageJson());
            }
            return http.Response('Not found', 404);
          }),
          baseUrl: 'https://example.test',
        ),
      );

      final result = await repo.getFeaturedProducts(['p1', 'p2'], locale: 'fr');

      expect(result.map((f) => f.product.id), ['p1']);
    });

    test(
      'still returns tiles when the price query fails (best effort)',
      () async {
        final repo = PocketBaseFeaturedProductsRepository(
          client: PocketBaseClient(
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('/products/records')) {
                return _jsonResponse(_productsPageJson(['p1']));
              }
              if (request.url.path.endsWith('/priceRows/records')) {
                return http.Response('Forbidden', 403);
              }
              return http.Response('Not found', 404);
            }),
            baseUrl: 'https://example.test',
          ),
        );

        final result = await repo.getFeaturedProducts(['p1'], locale: 'fr');

        expect(result, hasLength(1));
        expect(result.single.prices, isEmpty);
      },
    );
  });
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _productsPageJson(List<String> ids) {
  return {
    'page': 1,
    'perPage': ids.length,
    'totalItems': ids.length,
    'totalPages': 1,
    'items': [for (final id in ids) _productJson(id)],
  };
}

Map<String, dynamic> _productJson(String id) {
  return {
    'id': id,
    'collectionId': 'products_collection',
    'collectionName': 'products',
    'code': 'CODE-$id',
    'name': 'Product $id',
    'slug': 'product-$id',
    'picture': 'media-$id',
    'thumbnail': '',
    'galleryImages': <String>[],
    'isActive': true,
    'expand': {
      'picture': {
        'id': 'media-$id',
        'collectionId': 'medias',
        'file': '$id.jpg',
      },
    },
  };
}

Map<String, dynamic> _pricesPageJson() {
  return {
    'page': 1,
    'perPage': 4,
    'totalItems': 1,
    'totalPages': 1,
    'items': [
      {
        'id': 'price-1',
        'product': 'p1',
        'currency': 'cur-eur',
        'price': 42.0,
        'isActive': true,
        'expand': {
          'currency': {'id': 'cur-eur', 'symbol': '€', 'isocode': 'EUR'},
        },
      },
    ],
  };
}

Map<String, dynamic> _emptyPageJson() {
  return {
    'page': 1,
    'perPage': 4,
    'totalItems': 0,
    'totalPages': 0,
    'items': <Map<String, dynamic>>[],
  };
}
