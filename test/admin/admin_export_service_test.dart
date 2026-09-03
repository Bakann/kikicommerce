import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/admin/admin_client.dart';
import 'package:kiki_commerce/admin/admin_export_service.dart';
import 'package:kiki_commerce/application/admin/catalog_csv_format.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('CatalogCsvExportService', () {
    test('exports one row with the expected header and media URLs', () async {
      final result = await _exportFromCollections(_baseCollections());
      final rows = CatalogCsvFormat.decode(result.csvContent);
      final row = _rowAsMap(rows, 1);

      expect(result.exportedRows, 1);
      expect(result.warnings, isEmpty);
      expect(rows.first, CatalogCsvFormat.headers);
      expect(row['category_code'], 'CAT-ROBES');
      expect(row['product_code'], 'PROD-ROBE-001');
      expect(row['product_slug'], 'robe-kiki-atelier');
      expect(
        row['thumbnail_source'],
        'https://example.com/api/files/medias/media-thumb/thumb.png',
      );
      expect(row['gallery_media_codes'], 'MED-GAL-1|MED-GAL-2');
      expect(
        row['gallery_media_sources'],
        'https://example.com/api/files/medias/media-g1/gallery-1.png|'
        'https://example.com/api/files/medias/media-g2/gallery-2.png',
      );
    });

    test('duplicates rows when a product has multiple price rows', () async {
      final collections = _baseCollections();
      collections['priceRows'] = [
        ...collections['priceRows']!,
        {
          'id': 'price-2',
          'product': 'prod-1',
          'currency': 'currency-eur',
          'unit': 'unit-pcs',
          'price': 79.9,
          'minqtd': 2,
          'net': false,
          'startTime': '2026-01-15T00:00:00Z',
          'endTime': '',
          'channel': 'store',
          'isDefault': false,
          'isActive': true,
        },
      ];

      final result = await _exportFromCollections(collections);
      final rows = CatalogCsvFormat.decode(result.csvContent);

      expect(result.exportedRows, 2);
      expect(_rowAsMap(rows, 1)['price_channel'], 'web');
      expect(_rowAsMap(rows, 2)['price_channel'], 'store');
    });

    test(
      'duplicates rows when a product belongs to multiple categories',
      () async {
        final collections = _baseCollections();
        collections['categories'] = [
          ...collections['categories']!,
          {
            'id': 'cat-2',
            'code': 'CAT-CEREMONIE',
            'name': 'Ceremonie',
            'description': 'Second category',
            'slug': 'ceremonie',
            'parent': '',
            'isActive': true,
          },
        ];
        collections['categoryProducts'] = [
          ...collections['categoryProducts']!,
          {
            'id': 'cp-2',
            'category': 'cat-2',
            'product': 'prod-1',
            'position': 20,
            'isPrimary': false,
            'isActive': true,
          },
        ];

        final result = await _exportFromCollections(collections);
        final rows = CatalogCsvFormat.decode(result.csvContent);

        expect(result.exportedRows, 2);
        expect(_rowAsMap(rows, 1)['category_code'], 'CAT-ROBES');
        expect(_rowAsMap(rows, 2)['category_code'], 'CAT-CEREMONIE');
      },
    );

    test('serializes gallery metadata with pipe separators', () async {
      final result = await _exportFromCollections(_baseCollections());
      final row = _rowAsMap(CatalogCsvFormat.decode(result.csvContent), 1);

      expect(row['gallery_media_titles'], 'Galerie Kiki 1|Galerie Kiki 2');
      expect(
        row['gallery_media_alt_texts'],
        'Vue galerie Kiki 1|Vue galerie Kiki 2',
      );
      expect(row['gallery_media_mime_types'], 'image/png|image/png');
      expect(row['gallery_media_is_active'], 'true|true');
    });

    test('skips non representable records and reports warnings', () async {
      final collections = _baseCollections();
      collections['categories'] = [
        ...collections['categories']!,
        {
          'id': 'cat-unused',
          'code': 'CAT-ORPHAN',
          'name': 'Orphan',
          'description': '',
          'slug': 'orphan',
          'parent': '',
          'isActive': true,
        },
      ];
      collections['products'] = [
        ...collections['products']!,
        {
          'id': 'prod-noprice',
          'code': 'PROD-NOPRICE',
          'name': 'Sans prix',
          'summary': '',
          'description': '',
          'ean': '',
          'gender': '',
          'productType': '',
          'brand': '',
          'isActive': true,
          'onlineDate': '',
          'offlineDate': '',
          'thumbnail': '',
          'picture': '',
          'galleryImages': const <String>[],
        },
      ];
      collections['categoryProducts'] = [
        {
          'id': 'cp-invalid',
          'category': 'cat-1',
          'product': 'prod-1',
          'position': 10,
          'isPrimary': true,
          'isActive': false,
        },
        {
          'id': 'cp-noprice',
          'category': 'cat-1',
          'product': 'prod-noprice',
          'position': 30,
          'isPrimary': false,
          'isActive': true,
        },
      ];
      collections['medias'] = [
        ...collections['medias']!,
        {
          'id': 'media-unused',
          'code': 'MED-UNUSED',
          'title': 'Unused',
          'altText': 'Unused',
          'mimeType': 'image/png',
          'file': 'unused.png',
          'isActive': true,
        },
      ];

      final result = await _exportFromCollections(collections);

      expect(result.exportedRows, 0);
      expect(
        result.warnings.any(
          (warning) => warning.contains('Catégorie CAT-ORPHAN ignorée'),
        ),
        isTrue,
      );
      expect(
        result.warnings.any(
          (warning) => warning.contains('Produit PROD-NOPRICE ignoré'),
        ),
        isTrue,
      );
      expect(
        result.warnings.any(
          (warning) => warning.contains(
            'category.isActive et categoryProducts.isActive divergent',
          ),
        ),
        isTrue,
      );
      expect(
        result.warnings.any(
          (warning) => warning.contains('Média MED-UNUSED ignoré'),
        ),
        isTrue,
      );
    });
  });
}

Future<CatalogExportResult> _exportFromCollections(
  Map<String, List<Map<String, dynamic>>> collections,
) {
  final client = PocketBaseAdminClient(
    baseUrl: 'https://example.com',
    authToken: 'token',
    httpClient: MockClient((request) async {
      if (request.method != 'GET') {
        return http.Response('Unsupported method', 405);
      }

      final pathSegments = request.url.pathSegments;
      if (pathSegments.length < 4 || pathSegments[1] != 'collections') {
        return http.Response('Not found', 404);
      }

      final collection = pathSegments[2];
      final items = collections[collection] ?? const <Map<String, dynamic>>[];
      return http.Response(
        jsonEncode({'items': items}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  return CatalogCsvExportService(client: client).exportCatalogCsv();
}

Map<String, dynamic> _rowAsMap(List<List<dynamic>> rows, int rowIndex) {
  final headers = rows.first.cast<String>();
  final values = rows[rowIndex];
  return {
    for (var index = 0; index < headers.length; index += 1)
      headers[index]: (index < values.length ? values[index] : '').toString(),
  };
}

Map<String, List<Map<String, dynamic>>> _baseCollections() {
  return {
    'categories': [
      {
        'id': 'cat-1',
        'code': 'CAT-ROBES',
        'name': 'Robes Studio Kiki',
        'description': 'Collection capsule',
        'slug': 'robes-studio-kiki',
        'parent': '',
        'isActive': true,
      },
    ],
    'products': [
      {
        'id': 'prod-1',
        'code': 'PROD-ROBE-001',
        'name': 'Robe Kiki Atelier',
        'slug': 'robe-kiki-atelier',
        'summary': '<p>Résumé</p>',
        'description': '<p>Description</p>',
        'ean': '3760350100011',
        'gender': 'girl',
        'productType': 'Robe',
        'brand': 'Kiki Atelier',
        'isActive': true,
        'onlineDate': '2026-01-05T00:00:00Z',
        'offlineDate': '',
        'thumbnail': 'media-thumb',
        'picture': 'media-main',
        'galleryImages': ['container-1'],
      },
    ],
    'categoryProducts': [
      {
        'id': 'cp-1',
        'category': 'cat-1',
        'product': 'prod-1',
        'position': 10,
        'isPrimary': true,
        'isActive': true,
      },
    ],
    'priceRows': [
      {
        'id': 'price-1',
        'product': 'prod-1',
        'currency': 'currency-eur',
        'unit': 'unit-pcs',
        'price': 69.9,
        'minqtd': 1,
        'net': false,
        'startTime': '2026-01-05T00:00:00Z',
        'endTime': '',
        'channel': 'web',
        'isDefault': true,
        'isActive': true,
      },
    ],
    'currencies': [
      {
        'id': 'currency-eur',
        'isocode': 'EUR',
        'symbol': '€',
        'name': 'Euro',
        'digits': 2,
        'isActive': true,
      },
    ],
    'units': [
      {
        'id': 'unit-pcs',
        'code': 'PCS',
        'name': 'Pièce',
        'symbol': 'pc',
        'isActive': true,
      },
    ],
    'medias': [
      {
        'id': 'media-thumb',
        'code': 'MED-THUMB',
        'title': 'Miniature Robe Kiki',
        'altText': 'Miniature de la robe Kiki',
        'mimeType': 'image/png',
        'file': 'thumb.png',
        'isActive': true,
      },
      {
        'id': 'media-main',
        'code': 'MED-MAIN',
        'title': 'Image principale Robe Kiki',
        'altText': 'Image principale de la robe Kiki',
        'mimeType': 'image/png',
        'file': 'main.png',
        'isActive': true,
      },
      {
        'id': 'media-g1',
        'code': 'MED-GAL-1',
        'title': 'Galerie Kiki 1',
        'altText': 'Vue galerie Kiki 1',
        'mimeType': 'image/png',
        'file': 'gallery-1.png',
        'isActive': true,
      },
      {
        'id': 'media-g2',
        'code': 'MED-GAL-2',
        'title': 'Galerie Kiki 2',
        'altText': 'Vue galerie Kiki 2',
        'mimeType': 'image/png',
        'file': 'gallery-2.png',
        'isActive': true,
      },
    ],
    'mediaContainers': [
      {
        'id': 'container-1',
        'code': 'MC-ROBE-001',
        'name': 'Galerie Robe Kiki',
        'medias': ['media-g1', 'media-g2'],
        'isActive': true,
      },
    ],
  };
}
