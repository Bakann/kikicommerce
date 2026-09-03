import 'dart:typed_data';

import '../../application/admin/admin_backoffice_repository.dart';
import '../../application/admin/catalog_export_result.dart';
import '../../application/admin/catalog_import_report.dart';
import '../admin_client.dart';
import '../admin_export_service.dart';
import '../admin_import_service.dart';
import '../services/admin_media_source_loader.dart';

class PocketBaseAdminBackofficeRepository implements AdminBackofficeRepository {
  final AdminMediaSourceLoader mediaSourceLoader;

  const PocketBaseAdminBackofficeRepository({
    this.mediaSourceLoader = const AdminMediaSourceLoader(),
  });

  @override
  Future<String> authenticateSuperuser({
    required String baseUrl,
    required String email,
    required String password,
  }) {
    final client = PocketBaseAdminClient(baseUrl: baseUrl);
    return client.authenticateSuperuser(email: email, password: password);
  }

  @override
  Future<List<Map<String, dynamic>>> listRecords({
    required String baseUrl,
    required String authToken,
    required String collection,
    String sort = '-created',
    int perPage = 500,
    int page = 1,
    String? filter,
  }) {
    final client = _client(baseUrl: baseUrl, authToken: authToken);
    return client.listRecords(
      collection,
      sort: sort,
      perPage: perPage,
      page: page,
      filter: filter,
    );
  }

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) {
    return _client(
      baseUrl: baseUrl,
      authToken: authToken,
    ).createRecord(collection, data);
  }

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) {
    return _client(
      baseUrl: baseUrl,
      authToken: authToken,
    ).updateRecord(collection, recordId, data);
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
    final payload = mediaSource == null
        ? null
        : await mediaSourceLoader.load(
            mediaSource,
            fallbackFilename: fallbackFilename,
            mimeType: mimeType,
          );

    if (recordId == null && payload == null) {
      throw Exception(
        'La création d’un média requiert une source asset:// ou http(s)://.',
      );
    }

    return _client(
      baseUrl: baseUrl,
      authToken: authToken,
    ).upsertMultipartRecord(
      collection: collection,
      recordId: recordId,
      data: data,
      fileBytes: payload?.bytes,
      filename: payload?.filename,
      mimeType: mimeType,
    );
  }

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) {
    final baseName = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;
    return _client(
      baseUrl: baseUrl,
      authToken: authToken,
    ).upsertMultipartRecord(
      collection: 'medias',
      data: {'code': baseName, 'title': baseName, 'isActive': true},
      fileBytes: fileBytes,
      filename: filename,
      mimeType: mimeType,
    );
  }

  @override
  Future<void> deleteRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
  }) {
    return _client(
      baseUrl: baseUrl,
      authToken: authToken,
    ).deleteRecord(collection, recordId);
  }

  @override
  Future<CatalogImportReport> importCatalogCsv({
    required String baseUrl,
    required String authToken,
    required String csvContent,
  }) {
    return CatalogCsvImportService(
      client: _client(baseUrl: baseUrl, authToken: authToken),
      mediaSourceLoader: mediaSourceLoader,
    ).importCatalogCsv(csvContent);
  }

  @override
  Future<CatalogExportResult> exportCatalogCsv({
    required String baseUrl,
    required String authToken,
  }) {
    return CatalogCsvExportService(
      client: _client(baseUrl: baseUrl, authToken: authToken),
    ).exportCatalogCsv();
  }

  PocketBaseAdminClient _client({
    required String baseUrl,
    required String authToken,
  }) {
    return PocketBaseAdminClient(baseUrl: baseUrl, authToken: authToken);
  }
}
