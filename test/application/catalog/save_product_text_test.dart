import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/admin/save_admin_record.dart';
import 'package:kiki_commerce/application/catalog/save_product_text.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

class _RecordingRepository implements AdminBackofficeRepository {
  String? updatedRecordId;
  Map<String, dynamic>? updatedData;
  bool shouldFail = false;

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    if (shouldFail) {
      throw StateError('backend down');
    }
    updatedRecordId = recordId;
    updatedData = data;
    return {'id': recordId, ...data};
  }

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async => throw UnimplementedError();

  @override
  Future<String> authenticateSuperuser({
    required String baseUrl,
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> listRecords({
    required String baseUrl,
    required String authToken,
    required String collection,
    String sort = '-created',
    int perPage = 500,
    int page = 1,
    String? filter,
  }) async => throw UnimplementedError();

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
  }) async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
  }) async => throw UnimplementedError();

  @override
  Future<CatalogImportReport> importCatalogCsv({
    required String baseUrl,
    required String authToken,
    required String csvContent,
  }) async => throw UnimplementedError();

  @override
  Future<CatalogExportResult> exportCatalogCsv({
    required String baseUrl,
    required String authToken,
  }) async => throw UnimplementedError();
}

CatalogProduct _product({
  String name = 'Sac Noisette',
  String? summary = '<p>Un joli sac.</p>',
  String code = 'SAC-001',
}) {
  return CatalogProduct(
    id: 'prod-1',
    code: code,
    name: name,
    summary: summary,
    gender: 'F',
    productType: 'bag',
    brand: 'Kiki',
  );
}

void main() {
  late _RecordingRepository repo;
  late SaveProductText useCase;

  setUp(() {
    repo = _RecordingRepository();
    useCase = SaveProductText(SaveAdminRecord(repo));
  });

  Future<SaveProductTextResult> invoke({
    CatalogProduct? product,
    String? name,
    String? summary,
  }) => useCase(
    baseUrl: 'https://pb.test',
    authToken: 'token',
    product: product ?? _product(),
    name: name,
    summary: summary,
  );

  test('returns noChange when nothing changed', () async {
    final result = await invoke(name: 'Sac Noisette', summary: 'Un joli sac.');
    expect(result, isA<SaveProductTextNoChange>());
    expect(repo.updatedRecordId, isNull);
  });

  test('saves when name changes and rebuilds searchIndex', () async {
    final result = await invoke(name: 'Nouveau nom');
    expect(result, isA<SaveProductTextSaved>());
    expect(repo.updatedRecordId, 'prod-1');
    expect(repo.updatedData!['name'], 'Nouveau nom');
    expect(repo.updatedData!.containsKey('summary'), isFalse);
    final searchIndex = repo.updatedData!['searchIndex'] as String;
    expect(searchIndex.toLowerCase(), contains('nouveau nom'));
  });

  test('saves when summary changes (after html stripping)', () async {
    final result = await invoke(summary: 'Un nouveau résumé');
    expect(result, isA<SaveProductTextSaved>());
    expect(repo.updatedData!['summary'], 'Un nouveau résumé');
    expect(repo.updatedData!.containsKey('name'), isFalse);
  });

  test('returns failure when repository throws', () async {
    repo.shouldFail = true;
    final result = await invoke(name: 'Nouveau nom');
    expect(result, isA<SaveProductTextFailure>());
    expect(
      (result as SaveProductTextFailure).error.toString(),
      contains('backend down'),
    );
  });

  test('buildProductSearchData merges overrides with product fallbacks', () {
    final product = _product(summary: '<b>joli</b>');
    final data = buildProductSearchData(
      product,
      name: 'Override',
      summary: 'Nettoyé',
    );
    expect(data['name'], 'Override');
    expect(data['summary'], 'Nettoyé');
    expect(data['code'], product.code);
    expect(data['brand'], product.brand);
  });

  test('buildProductSearchData strips HTML when using product summary', () {
    final product = _product(summary: '<p>html <b>strong</b></p>');
    final data = buildProductSearchData(product);
    expect(data['summary'], isNot(contains('<')));
    expect(data['summary'], contains('html'));
  });
}
