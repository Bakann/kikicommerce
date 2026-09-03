import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/catalog/search_query.dart';
import 'package:kiki_commerce/data/api/pocketbase_client.dart';
import 'package:kiki_commerce/data/repositories/search_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PocketBaseSearchRepository', () {
    test(
      'search request expands picture and thumbnail without galleryImages',
      () async {
        final requests = <http.Request>[];
        final repository = PocketBaseSearchRepository(
          client: PocketBaseClient(
            httpClient: MockClient((request) async {
              requests.add(request);

              if (request.url.path.endsWith('/products/records')) {
                return _jsonResponse(_productsPageJson());
              }

              if (request.url.path.endsWith('/priceRows/records')) {
                return _jsonResponse(_emptyPageJson(perPage: 200));
              }

              return http.Response('Not found', 404);
            }),
            baseUrl: 'https://example.test',
          ),
        );

        final page = await repository.searchProducts((
          query: 'produit',
          sort: SearchSort.newest,
          page: 1,
          perPage: 20,
        ));

        expect(page.items, hasLength(1));

        final productsRequest = requests.firstWhere(
          (request) => request.url.path.endsWith('/products/records'),
        );
        final expand = productsRequest.url.queryParameters['expand'];
        expect(expand, 'picture,thumbnail');
        expect(expand, isNot(contains('galleryImages')));
        expect(
          requests.where(
            (request) => request.url.path.endsWith('/mediaContainers/records'),
          ),
          isEmpty,
        );
      },
    );

    test(
      'loads gallery fallback only when a result product has no media',
      () async {
        final requests = <http.Request>[];
        final repository = PocketBaseSearchRepository(
          client: PocketBaseClient(
            httpClient: MockClient((request) async {
              requests.add(request);

              if (request.url.path.endsWith('/products/records')) {
                return _jsonResponse(_productsPageJsonWithoutMedia());
              }

              if (request.url.path.endsWith('/mediaContainers/records')) {
                return _jsonResponse(_mediaContainersPageJson());
              }

              if (request.url.path.endsWith('/priceRows/records')) {
                return _jsonResponse(_emptyPageJson(perPage: 200));
              }

              return http.Response('Not found', 404);
            }),
            baseUrl: 'https://example.test',
          ),
        );

        final page = await repository.searchProducts((
          query: 'produit',
          sort: SearchSort.newest,
          page: 1,
          perPage: 20,
        ));

        expect(page.items, hasLength(1));
        expect(page.items.single.product.picture, isNull);
        expect(page.items.single.product.thumbnail, isNull);
        expect(page.items.single.product.gallery, hasLength(1));
        expect(
          page.items.single.product.listingMedia!.url,
          'https://kiki-commerce.pockethost.io/api/files/medias/media-gallery/gallery.jpg',
        );

        final productsRequest = requests.firstWhere(
          (request) => request.url.path.endsWith('/products/records'),
        );
        expect(
          productsRequest.url.queryParameters['expand'],
          'picture,thumbnail',
        );

        final mediaContainersRequest = requests.firstWhere(
          (request) => request.url.path.endsWith('/mediaContainers/records'),
        );
        expect(mediaContainersRequest.url.queryParameters['expand'], 'medias');
        expect(
          mediaContainersRequest.url.queryParameters['filter'],
          contains('gallery-1'),
        );
      },
    );

    test(
      'suggestProductNames returns distinct names via a light fields query',
      () async {
        final requests = <http.Request>[];
        final repository = PocketBaseSearchRepository(
          client: PocketBaseClient(
            httpClient: MockClient((request) async {
              requests.add(request);
              if (request.url.path.endsWith('/products/records')) {
                return _jsonResponse(
                  _namesPageJson(['Air Max', 'Air Max', 'Air Force']),
                );
              }
              return http.Response('Not found', 404);
            }),
            baseUrl: 'https://example.test',
          ),
        );

        final names = await repository.suggestProductNames('air', limit: 8);

        // De-duped (case-insensitive), order preserved.
        expect(names, ['Air Max', 'Air Force']);

        final request = requests.single;
        expect(request.url.path.endsWith('/products/records'), isTrue);
        expect(request.url.queryParameters['fields'], 'name');
        expect(request.url.queryParameters['expand'], isNull);
        // No price/gallery fan-out for the lightweight autocomplete path.
        expect(
          requests.where((r) => r.url.path.endsWith('/priceRows/records')),
          isEmpty,
        );
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

Map<String, dynamic> _productsPageJson() {
  return {
    'page': 1,
    'perPage': 20,
    'totalItems': 1,
    'totalPages': 1,
    'items': [
      {
        'id': 'prod-1',
        'collectionId': 'products_collection',
        'collectionName': 'products',
        'code': 'PROD-1',
        'name': 'Produit',
        'slug': 'produit',
        'picture': 'media-1',
        'thumbnail': 'media-2',
        'galleryImages': ['gallery-1'],
        'isActive': true,
        'expand': {
          'picture': {
            'id': 'media-1',
            'collectionId': 'medias',
            'file': 'produit.jpg',
          },
          'thumbnail': {
            'id': 'media-2',
            'collectionId': 'medias',
            'file': 'produit-thumb.jpg',
          },
        },
      },
    ],
  };
}

Map<String, dynamic> _productsPageJsonWithoutMedia() {
  return {
    'page': 1,
    'perPage': 20,
    'totalItems': 1,
    'totalPages': 1,
    'items': [
      {
        'id': 'prod-1',
        'collectionId': 'products_collection',
        'collectionName': 'products',
        'code': 'PROD-1',
        'name': 'Produit',
        'slug': 'produit',
        'picture': '',
        'thumbnail': '',
        'galleryImages': ['gallery-1'],
        'isActive': true,
        'expand': <String, dynamic>{},
      },
    ],
  };
}

Map<String, dynamic> _mediaContainersPageJson() {
  return {
    'page': 1,
    'perPage': 1,
    'totalItems': 1,
    'totalPages': 1,
    'items': [
      {
        'id': 'gallery-1',
        'collectionId': 'mediaContainers_collection',
        'medias': ['media-gallery'],
        'isActive': true,
        'expand': {
          'medias': [
            {
              'id': 'media-gallery',
              'collectionId': 'medias',
              'file': 'gallery.jpg',
            },
          ],
        },
      },
    ],
  };
}

Map<String, dynamic> _namesPageJson(List<String> names) {
  return {
    'page': 1,
    'perPage': names.length,
    'totalItems': names.length,
    'totalPages': 1,
    'items': [
      for (final name in names) {'name': name},
    ],
  };
}

Map<String, dynamic> _emptyPageJson({int perPage = 20}) {
  return {
    'page': 1,
    'perPage': perPage,
    'totalItems': 0,
    'totalPages': 0,
    'items': <Map<String, dynamic>>[],
  };
}
