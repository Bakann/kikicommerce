import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/assign_product_media.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';

void main() {
  group('AssignProductMedia', () {
    test('PATCHes the product record with the given media id', () async {
      final repository = _FakeAdminBackofficeRepository();
      final useCase = AssignProductMedia(repository);

      await useCase.call(
        authToken: 'test-token',
        productId: 'product-1',
        mediaId: 'media-42',
      );

      expect(repository.updateCalls, 1);
      expect(repository.lastUpdateCollection, 'products');
      expect(repository.lastUpdateRecordId, 'product-1');
      expect(repository.lastUpdateData, {'picture': 'media-42'});
    });
  });
}

class _FakeAdminBackofficeRepository implements AdminBackofficeRepository {
  int updateCalls = 0;
  String? lastUpdateCollection;
  String? lastUpdateRecordId;
  Map<String, dynamic>? lastUpdateData;

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    updateCalls += 1;
    lastUpdateCollection = collection;
    lastUpdateRecordId = recordId;
    lastUpdateData = data;
    return data;
  }

  @override
  Future<String> authenticateSuperuser({
    required String baseUrl,
    required String email,
    required String password,
  }) async => 'token';

  @override
  Future<List<Map<String, dynamic>>> listRecords({
    required String baseUrl,
    required String authToken,
    required String collection,
    String sort = '-created',
    int perPage = 500,
    int page = 1,
    String? filter,
  }) async => [];

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async => data;

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
  }) async => data;

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) async => {'id': 'new-media', 'file': filename};

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
  }) async => CatalogImportReport(totalRows: 0);

  @override
  Future<CatalogExportResult> exportCatalogCsv({
    required String baseUrl,
    required String authToken,
  }) async => CatalogExportResult(csvContent: '', exportedRows: 0);
}
