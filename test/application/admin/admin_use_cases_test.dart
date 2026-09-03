import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_models.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/admin/export_catalog_csv.dart';
import 'package:kiki_commerce/application/admin/import_catalog_csv.dart';
import 'package:kiki_commerce/application/admin/load_admin_collections.dart';
import 'package:kiki_commerce/application/admin/save_admin_record.dart';

void main() {
  group('Admin use cases', () {
    test('LoadAdminCollections aggregates all requested collections', () async {
      final repository = _FakeAdminBackofficeRepository(
        recordsByCollection: {
          'categories': [
            {'id': 'cat-1', 'name': 'Robes'},
          ],
          'products': [
            {'id': 'prod-1', 'name': 'Robe Kiki'},
          ],
        },
      );

      final result = await LoadAdminCollections(repository)(
        baseUrl: 'https://example.com',
        authToken: 'token',
        collections: const [
          AdminCollectionLoadRequest(name: 'categories', sort: 'name'),
          AdminCollectionLoadRequest(name: 'products', sort: 'name'),
        ],
      );

      expect(result['categories'], hasLength(1));
      expect(result['products'], hasLength(1));
      expect(repository.listedCollections, ['categories', 'products']);
    });

    test('SaveAdminRecord creates a new regular record', () async {
      final repository = _FakeAdminBackofficeRepository();

      await SaveAdminRecord(repository)(
        baseUrl: 'https://example.com',
        authToken: 'token',
        collection: 'products',
        data: const {'code': 'PROD-1'},
      );

      expect(repository.createCalls, 1);
      expect(repository.updateCalls, 0);
      expect(repository.mediaUpsertCalls, 0);
      expect(repository.lastCollection, 'products');
    });

    test('SaveAdminRecord updates an existing regular record', () async {
      final repository = _FakeAdminBackofficeRepository();

      await SaveAdminRecord(repository)(
        baseUrl: 'https://example.com',
        authToken: 'token',
        collection: 'products',
        recordId: 'prod-1',
        data: const {'code': 'PROD-1'},
      );

      expect(repository.createCalls, 0);
      expect(repository.updateCalls, 1);
      expect(repository.mediaUpsertCalls, 0);
      expect(repository.lastRecordId, 'prod-1');
    });

    test('SaveAdminRecord routes medias to multipart upsert', () async {
      final repository = _FakeAdminBackofficeRepository();

      await SaveAdminRecord(repository)(
        baseUrl: 'https://example.com',
        authToken: 'token',
        collection: 'medias',
        data: const {'code': 'MEDIA-1'},
        mediaSource: 'asset://assets/image.png',
        fallbackFilename: 'MEDIA-1',
        mimeType: 'image/png',
      );

      expect(repository.createCalls, 0);
      expect(repository.updateCalls, 0);
      expect(repository.mediaUpsertCalls, 1);
      expect(repository.lastMediaSource, 'asset://assets/image.png');
      expect(repository.lastFallbackFilename, 'MEDIA-1');
    });

    test('ImportCatalogCsv delegates to repository', () async {
      final report = CatalogImportReport(totalRows: 3)..markCreated('products');
      final repository = _FakeAdminBackofficeRepository(importReport: report);

      final result = await ImportCatalogCsv(repository)(
        baseUrl: 'https://example.com',
        authToken: 'token',
        csvContent: 'csv-content',
      );

      expect(result.totalRows, 3);
      expect(repository.importCalls, 1);
      expect(repository.lastImportedCsv, 'csv-content');
    });

    test('ExportCatalogCsv delegates to repository', () async {
      final exportResult = CatalogExportResult(
        csvContent: 'csv-content',
        exportedRows: 2,
        warnings: const ['warn'],
      );
      final repository = _FakeAdminBackofficeRepository(
        exportResult: exportResult,
      );

      final result = await ExportCatalogCsv(repository)(
        baseUrl: 'https://example.com',
        authToken: 'token',
      );

      expect(result.csvContent, 'csv-content');
      expect(result.exportedRows, 2);
      expect(repository.exportCalls, 1);
    });
  });
}

class _FakeAdminBackofficeRepository implements AdminBackofficeRepository {
  final Map<String, List<Map<String, dynamic>>> recordsByCollection;
  final CatalogImportReport importReport;
  final CatalogExportResult exportResult;

  int createCalls = 0;
  int updateCalls = 0;
  int mediaUpsertCalls = 0;
  int importCalls = 0;
  int exportCalls = 0;
  String? lastCollection;
  String? lastRecordId;
  String? lastMediaSource;
  String? lastFallbackFilename;
  String? lastImportedCsv;
  final List<String> listedCollections = [];

  _FakeAdminBackofficeRepository({
    Map<String, List<Map<String, dynamic>>>? recordsByCollection,
    CatalogImportReport? importReport,
    CatalogExportResult? exportResult,
  }) : recordsByCollection = recordsByCollection ?? const {},
       importReport = importReport ?? CatalogImportReport(totalRows: 0),
       exportResult =
           exportResult ?? CatalogExportResult(csvContent: '', exportedRows: 0);

  @override
  Future<String> authenticateSuperuser({
    required String baseUrl,
    required String email,
    required String password,
  }) async => 'super-token';

  @override
  Future<List<Map<String, dynamic>>> listRecords({
    required String baseUrl,
    required String authToken,
    required String collection,
    String sort = '-created',
    int perPage = 500,
    int page = 1,
    String? filter,
  }) async {
    listedCollections.add(collection);
    return recordsByCollection[collection] ?? const [];
  }

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    createCalls += 1;
    lastCollection = collection;
    return {'id': 'created', ...data};
  }

  @override
  Future<void> deleteRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
  }) async {}

  @override
  Future<CatalogImportReport> importCatalogCsv({
    required String baseUrl,
    required String authToken,
    required String csvContent,
  }) async {
    importCalls += 1;
    lastImportedCsv = csvContent;
    return importReport;
  }

  @override
  Future<CatalogExportResult> exportCatalogCsv({
    required String baseUrl,
    required String authToken,
  }) async {
    exportCalls += 1;
    return exportResult;
  }

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    updateCalls += 1;
    lastCollection = collection;
    lastRecordId = recordId;
    return {'id': recordId, ...data};
  }

  @override
  Future<Map<String, dynamic>> upsertMediaRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    String? recordId,
    required Map<String, dynamic> data,
    String? mediaSource,
    required String fallbackFilename,
    String? mimeType,
  }) async {
    mediaUpsertCalls += 1;
    lastCollection = collection;
    lastRecordId = recordId;
    lastMediaSource = mediaSource;
    lastFallbackFilename = fallbackFilename;
    return {'id': recordId ?? 'media-created', ...data};
  }

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) async {
    return {'id': 'uploaded-media', 'file': filename};
  }
}
