import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/error/app_exception.dart';
import 'package:kiki_commerce/data/api/pocketbase_client.dart';
import 'package:kiki_commerce/data/repositories/product_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PocketBaseProductRepository', () {
    test('returns product detail when secondary requests time out', () async {
      final requests = <http.Request>[];
      final repository = _repositoryWithClient(
        MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/products/records/prod-1')) {
            return _jsonResponse(_productJson());
          }

          if (request.url.path.contains('/priceRows/records') ||
              request.url.path.contains('/narrativeChapters/records')) {
            await Future<void>.delayed(const Duration(seconds: 1));
            return _jsonResponse(_emptyPageJson());
          }

          return http.Response('Not found', 404);
        }),
        secondaryTimeout: const Duration(milliseconds: 10),
      );

      final detail = await repository.getProductDetail('prod-1', locale: 'fr');

      expect(detail.product.id, 'prod-1');
      expect(detail.product.name, 'Sac vert');
      expect(detail.prices, isEmpty);
      expect(detail.chapters, isEmpty);

      final productRequest = requests.firstWhere(
        (request) => request.url.path.endsWith('/products/records/prod-1'),
      );
      expect(
        productRequest.url.queryParameters['expand'],
        'picture,thumbnail,galleryImages,galleryImages.medias',
      );
    });

    test('fails fast when the required product request times out', () async {
      final repository = _repositoryWithClient(
        MockClient((request) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          return _jsonResponse(_productJson());
        }),
        productTimeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        repository.getProductDetail('prod-1', locale: 'fr'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}

PocketBaseProductRepository _repositoryWithClient(
  http.Client httpClient, {
  Duration productTimeout = const Duration(seconds: 8),
  Duration secondaryTimeout = const Duration(seconds: 3),
}) {
  return PocketBaseProductRepository(
    client: PocketBaseClient(
      httpClient: httpClient,
      baseUrl: 'https://example.test',
    ),
    productTimeout: productTimeout,
    secondaryTimeout: secondaryTimeout,
  );
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _productJson() {
  return {
    'id': 'prod-1',
    'collectionId': 'products_collection',
    'collectionName': 'products',
    'code': 'BAG-1',
    'name': 'Sac vert',
    'slug': 'sac-vert',
    'isActive': true,
    'galleryImages': <String>[],
  };
}

Map<String, dynamic> _emptyPageJson() {
  return {
    'page': 1,
    'perPage': 50,
    'totalItems': 0,
    'totalPages': 0,
    'items': <Map<String, dynamic>>[],
  };
}
