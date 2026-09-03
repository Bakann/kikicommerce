import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/admin/admin_client.dart';
import 'package:kiki_commerce/admin/admin_import_service.dart';
import 'package:kiki_commerce/admin/services/admin_media_source_loader.dart';

void main() {
  group('CatalogCsvImportService', () {
    test('throws when CSV is empty', () async {
      final client = _RecordingAdminClient();
      final service = CatalogCsvImportService(
        client: client,
        mediaSourceLoader: _NoOpMediaSourceLoader(),
      );
      expect(() => service.importCatalogCsv(''), throwsA(isA<Exception>()));
    });

    test(
      'creates currency/unit/category/product/priceRow on a fresh store',
      () async {
        final client = _RecordingAdminClient();
        final service = CatalogCsvImportService(
          client: client,
          mediaSourceLoader: _NoOpMediaSourceLoader(),
        );

        final report = await service.importCatalogCsv(
          _csv(
            headers: [
              'currency_isocode',
              'currency_symbol',
              'currency_name',
              'currency_digits',
              'currency_is_active',
              'unit_code',
              'unit_name',
              'unit_symbol',
              'unit_is_active',
              'category_code',
              'category_name',
              'category_is_active',
              'product_code',
              'product_name',
              'product_is_active',
              'price',
              'price_is_active',
            ],
            rows: [
              [
                'EUR', '€', 'Euro', '2', 'true', //
                'unit', 'Unité', 'u.', 'true', //
                'shirts', 'Shirts', 'true', //
                'SKU-1', 'Widget', 'true', //
                '19.90', 'true',
              ],
            ],
          ),
        );

        expect(report.totalRows, 1);
        expect(report.errors, isEmpty);
        expect(report.createdByCollection['currencies'], 1);
        expect(report.createdByCollection['units'], 1);
        expect(report.createdByCollection['categories'], 1);
        expect(report.createdByCollection['products'], 1);
        expect(report.createdByCollection['priceRows'], 1);
        expect(report.createdByCollection['categoryProducts'], 1);

        final currencyCall = client.createCalls.firstWhere(
          (call) => call.collection == 'currencies',
        );
        expect(currencyCall.data['isocode'], 'EUR');
        expect(currencyCall.data['symbol'], '€');

        final productCall = client.createCalls.firstWhere(
          (call) => call.collection == 'products',
        );
        expect(productCall.data['code'], 'SKU-1');
        expect(
          productCall.data['searchIndex'],
          isNotEmpty,
          reason: 'product payload should include computed searchIndex',
        );

        final priceRowCall = client.createCalls.firstWhere(
          (call) => call.collection == 'priceRows',
        );
        expect(priceRowCall.data['product'], productCall.recordId);
        expect(priceRowCall.data['currency'], currencyCall.recordId);
        expect(priceRowCall.data['price'], 19.90);
      },
    );

    test('updates existing records instead of creating duplicates', () async {
      final client = _RecordingAdminClient();
      client.seedRecords('currencies', [
        {'id': 'cur1', 'isocode': 'EUR', 'symbol': '€', 'name': 'Euro'},
      ]);

      final service = CatalogCsvImportService(
        client: client,
        mediaSourceLoader: _NoOpMediaSourceLoader(),
      );

      final report = await service.importCatalogCsv(
        _csv(
          headers: [
            'currency_isocode',
            'currency_symbol',
            'currency_name',
            'currency_digits',
            'currency_is_active',
          ],
          rows: [
            ['EUR', '€', 'Euro', '2', 'true'],
          ],
        ),
      );

      expect(report.createdByCollection['currencies'] ?? 0, 0);
      expect(report.updatedByCollection['currencies'], 1);
      expect(
        client.createCalls
            .where((call) => call.collection == 'currencies')
            .toList(),
        isEmpty,
      );
      final update = client.updateCalls.firstWhere(
        (call) => call.collection == 'currencies',
      );
      expect(update.recordId, 'cur1');
    });

    test(
      'wires category parent relationship after creating both records',
      () async {
        final client = _RecordingAdminClient();
        final service = CatalogCsvImportService(
          client: client,
          mediaSourceLoader: _NoOpMediaSourceLoader(),
        );

        final report = await service.importCatalogCsv(
          _csv(
            headers: [
              'category_code',
              'category_name',
              'category_is_active',
              'category_parent_code',
            ],
            rows: [
              ['apparel', 'Apparel', 'true', ''],
              ['shirts', 'Shirts', 'true', 'apparel'],
            ],
          ),
        );

        expect(report.createdByCollection['categories'], 2);

        final parentCreate = client.createCalls.firstWhere(
          (call) => call.data['code'] == 'apparel',
        );
        final childCreate = client.createCalls.firstWhere(
          (call) => call.data['code'] == 'shirts',
        );

        final parentUpdate = client.updateCalls.firstWhere(
          (call) =>
              call.collection == 'categories' &&
              call.recordId == childCreate.recordId,
        );
        expect(parentUpdate.data['parent'], parentCreate.recordId);
      },
    );

    test('reports an error when category parent code is unknown', () async {
      final client = _RecordingAdminClient();
      final service = CatalogCsvImportService(
        client: client,
        mediaSourceLoader: _NoOpMediaSourceLoader(),
      );

      final report = await service.importCatalogCsv(
        _csv(
          headers: [
            'category_code',
            'category_name',
            'category_is_active',
            'category_parent_code',
          ],
          rows: [
            ['shirts', 'Shirts', 'true', 'ghost'],
          ],
        ),
      );

      expect(report.createdByCollection['categories'], 1);
      expect(
        report.errors.any(
          (error) =>
              error.contains('parent introuvable') && error.contains('ghost'),
        ),
        isTrue,
      );
    });

    test('reports invalid boolean cells without throwing', () async {
      final client = _RecordingAdminClient();
      final service = CatalogCsvImportService(
        client: client,
        mediaSourceLoader: _NoOpMediaSourceLoader(),
      );

      final report = await service.importCatalogCsv(
        _csv(
          headers: ['category_code', 'category_name', 'category_is_active'],
          rows: [
            ['shirts', 'Shirts', 'treu'],
          ],
        ),
      );

      expect(report.createdByCollection['categories'], 1);
      expect(
        report.errors.any(
          (error) =>
              error.contains('category_is_active') && error.contains('treu'),
        ),
        isTrue,
      );

      final categoryCall = client.createCalls.firstWhere(
        (call) => call.collection == 'categories',
      );
      expect(categoryCall.data['isActive'], isTrue);
    });
  });
}

String _csv({required List<String> headers, required List<List<String>> rows}) {
  final buffer = StringBuffer()..writeln(headers.join(';'));
  for (final row in rows) {
    buffer.writeln(row.join(';'));
  }
  return buffer.toString();
}

class _NoOpMediaSourceLoader implements AdminMediaSourceLoader {
  @override
  Future<ResolvedAdminMediaSource?> load(
    String source, {
    required String fallbackFilename,
    String? mimeType,
  }) async {
    return null;
  }

  @override
  String filenameFromSource(
    String source, {
    required String fallbackFilename,
    String? mimeType,
  }) => fallbackFilename;
}

class _CreateCall {
  final String collection;
  final Map<String, dynamic> data;
  final String recordId;

  _CreateCall({
    required this.collection,
    required this.data,
    required this.recordId,
  });
}

class _UpdateCall {
  final String collection;
  final String recordId;
  final Map<String, dynamic> data;

  _UpdateCall({
    required this.collection,
    required this.recordId,
    required this.data,
  });
}

class _DeleteCall {
  final String collection;
  final String recordId;

  _DeleteCall({required this.collection, required this.recordId});
}

class _UpsertMultipartCall {
  final String collection;
  final String? recordId;
  final Map<String, dynamic> data;
  final String? filename;

  _UpsertMultipartCall({
    required this.collection,
    required this.recordId,
    required this.data,
    required this.filename,
  });
}

class _RecordingAdminClient extends PocketBaseAdminClient {
  _RecordingAdminClient() : super(baseUrl: 'http://fake');

  final List<_CreateCall> createCalls = [];
  final List<_UpdateCall> updateCalls = [];
  final List<_DeleteCall> deleteCalls = [];
  final List<_UpsertMultipartCall> upsertMultipartCalls = [];
  final Map<String, List<Map<String, dynamic>>> _existing = {};
  int _idCounter = 0;

  void seedRecords(String collection, List<Map<String, dynamic>> records) {
    _existing[collection] = records;
  }

  String _nextId(String prefix) {
    _idCounter += 1;
    return '${prefix}_$_idCounter';
  }

  @override
  Future<PocketBaseCollectionSchema> getCollectionSchema(
    String collection,
  ) async {
    return _permissiveSchemaFor(collection);
  }

  @override
  Future<List<Map<String, dynamic>>> listRecords(
    String collection, {
    String sort = '-created',
    int perPage = 200,
    int page = 1,
    String? filter,
  }) async {
    return _existing[collection] ?? const [];
  }

  @override
  Future<Map<String, dynamic>> createRecord(
    String collection,
    Map<String, dynamic> data,
  ) async {
    final id = _nextId(collection);
    createCalls.add(
      _CreateCall(collection: collection, data: data, recordId: id),
    );
    final record = <String, dynamic>{...data, 'id': id};
    _existing.putIfAbsent(collection, () => []).add(record);
    return record;
  }

  @override
  Future<Map<String, dynamic>> updateRecord(
    String collection,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    updateCalls.add(
      _UpdateCall(collection: collection, recordId: recordId, data: data),
    );
    return <String, dynamic>{...data, 'id': recordId};
  }

  @override
  Future<void> deleteRecord(String collection, String recordId) async {
    deleteCalls.add(_DeleteCall(collection: collection, recordId: recordId));
  }

  @override
  Future<Map<String, dynamic>> upsertMultipartRecord({
    required String collection,
    String? recordId,
    required Map<String, dynamic> data,
    String fileField = 'file',
    Uint8List? fileBytes,
    String? filename,
    String? mimeType,
    List<PocketBaseMultipartFile> extraFiles = const [],
  }) async {
    upsertMultipartCalls.add(
      _UpsertMultipartCall(
        collection: collection,
        recordId: recordId,
        data: data,
        filename: filename,
      ),
    );
    final resolvedId = recordId ?? _nextId(collection);
    return <String, dynamic>{...data, 'id': resolvedId};
  }
}

PocketBaseCollectionSchema _permissiveSchemaFor(String collection) {
  return PocketBaseCollectionSchema(
    name: collection,
    fieldsByName: {
      for (final name
          in _knownFieldsByCollection[collection] ?? const <String>[])
        name: PocketBaseFieldSchema(
          name: name,
          type: 'text',
          required: false,
          maxSelect: null,
          values: const [],
        ),
    },
  );
}

const Map<String, List<String>> _knownFieldsByCollection = {
  'currencies': ['isocode', 'symbol', 'name', 'digits', 'isActive'],
  'units': ['code', 'name', 'symbol', 'isActive'],
  'categories': ['code', 'name', 'description', 'slug', 'isActive', 'parent'],
  'medias': ['code', 'title', 'altText', 'mimeType', 'isActive'],
  'mediaContainers': ['code', 'name', 'medias', 'isActive'],
  'products': [
    'code',
    'name',
    'slug',
    'summary',
    'description',
    'ean',
    'gender',
    'productType',
    'brand',
    'isActive',
    'onlineDate',
    'offlineDate',
    'picture',
    'thumbnail',
    'galleryImages',
  ],
  'categoryProducts': [
    'category',
    'product',
    'position',
    'isPrimary',
    'isActive',
  ],
  'priceRows': [
    'product',
    'currency',
    'unit',
    'price',
    'minqtd',
    'net',
    'startTime',
    'endTime',
    'channel',
    'isDefault',
    'isActive',
  ],
  'narrativeChapters': [
    'product',
    'media',
    'position',
    'headline',
    'story',
    'ctaLabel',
    'ctaAction',
    'isActive',
  ],
};
