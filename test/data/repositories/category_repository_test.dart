import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/data/api/pocketbase_client.dart';
import 'package:kiki_commerce/data/repositories/category_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PocketBaseCategoryRepository', () {
    test(
      'PLP request expands picture and thumbnail without galleryImages',
      () async {
        final requests = <http.Request>[];
        final repository = PocketBaseCategoryRepository(
          client: PocketBaseClient(
            httpClient: MockClient((request) async {
              requests.add(request);

              if (request.url.path.endsWith('/categoryProducts/records')) {
                return _jsonResponse(_categoryProductsPageJson());
              }

              if (request.url.path.endsWith('/priceRows/records')) {
                return _jsonResponse(_emptyPageJson(perPage: 200));
              }

              return http.Response('Not found', 404);
            }),
            baseUrl: 'https://example.test',
          ),
        );

        final page = await repository.getCategoryProducts(
          'cat-1',
          locale: 'fr',
        );

        expect(page.items, hasLength(1));
        expect(page.items.single.product.listingMedia, isNotNull);

        final categoryProductsRequest = requests.firstWhere(
          (request) => request.url.path.endsWith('/categoryProducts/records'),
        );
        final expand = categoryProductsRequest.url.queryParameters['expand'];
        expect(expand, 'category,product,product.picture,product.thumbnail');
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
      'loads gallery fallback only when a listing product has no media',
      () async {
        final requests = <http.Request>[];
        final repository = PocketBaseCategoryRepository(
          client: PocketBaseClient(
            httpClient: MockClient((request) async {
              requests.add(request);

              if (request.url.path.endsWith('/categoryProducts/records')) {
                return _jsonResponse(_categoryProductsPageJsonWithoutMedia());
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

        final page = await repository.getCategoryProducts(
          'cat-1',
          locale: 'fr',
        );

        expect(page.items, hasLength(1));
        expect(page.items.single.product.picture, isNull);
        expect(page.items.single.product.thumbnail, isNull);
        expect(page.items.single.product.gallery, hasLength(1));
        expect(
          page.items.single.product.listingMedia!.url,
          'https://kiki-commerce.pockethost.io/api/files/medias/media-gallery/gallery.jpg',
        );

        final categoryProductsRequest = requests.firstWhere(
          (request) => request.url.path.endsWith('/categoryProducts/records'),
        );
        expect(
          categoryProductsRequest.url.queryParameters['expand'],
          'category,product,product.picture,product.thumbnail',
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
  });
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _categoryProductsPageJson() {
  return {
    'page': 1,
    'perPage': 20,
    'totalItems': 1,
    'totalPages': 1,
    'items': [
      {
        'id': 'cp-1',
        'category': 'cat-1',
        'product': 'prod-1',
        'position': 10,
        'isActive': true,
        'expand': {
          'category': {
            'id': 'cat-1',
            'collectionId': 'categories_collection',
            'code': 'CAT',
            'name': 'Catégorie',
            'slug': 'categorie',
            'isActive': true,
          },
          'product': {
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
        },
      },
    ],
  };
}

Map<String, dynamic> _categoryProductsPageJsonWithoutMedia() {
  return {
    'page': 1,
    'perPage': 20,
    'totalItems': 1,
    'totalPages': 1,
    'items': [
      {
        'id': 'cp-1',
        'category': 'cat-1',
        'product': 'prod-1',
        'position': 10,
        'isActive': true,
        'expand': {
          'category': {
            'id': 'cat-1',
            'collectionId': 'categories_collection',
            'code': 'CAT',
            'name': 'Catégorie',
            'slug': 'categorie',
            'isActive': true,
          },
          'product': {
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
        },
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

Map<String, dynamic> _emptyPageJson({int perPage = 20}) {
  return {
    'page': 1,
    'perPage': perPage,
    'totalItems': 0,
    'totalPages': 0,
    'items': <Map<String, dynamic>>[],
  };
}
