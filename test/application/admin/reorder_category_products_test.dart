import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/admin/reorder_category_products.dart';

void main() {
  group('ReorderCategoryProducts', () {
    test('moves the dragged product to the target slot', () {
      final items = [
        const CategoryProductOrderItem(relationId: 'cp_a', position: 10),
        const CategoryProductOrderItem(relationId: 'cp_b', position: 20),
        const CategoryProductOrderItem(relationId: 'cp_c', position: 30),
      ];

      final reordered = ReorderCategoryProducts.reorderedItems(
        items: items,
        draggedRelationId: 'cp_a',
        targetRelationId: 'cp_c',
      );

      expect(reordered.map((item) => item.relationId), [
        'cp_b',
        'cp_c',
        'cp_a',
      ]);
    });

    test('updates only records whose position changes', () async {
      final repository = _FakeAdminBackofficeRepository();
      final useCase = ReorderCategoryProducts(repository);

      await useCase(
        authToken: 'token',
        items: [
          const CategoryProductOrderItem(relationId: 'cp_a', position: 10),
          const CategoryProductOrderItem(relationId: 'cp_b', position: 20),
          const CategoryProductOrderItem(relationId: 'cp_c', position: 30),
        ],
        draggedRelationId: 'cp_a',
        targetRelationId: 'cp_c',
      );

      expect(repository.updateCalls.map((call) => call.recordId), [
        'cp_b',
        'cp_c',
        'cp_a',
      ]);
      expect(repository.updateCalls.map((call) => call.data['position']), [
        10,
        20,
        30,
      ]);
    });

    test('does not write when there is no reorder', () async {
      final repository = _FakeAdminBackofficeRepository();
      final useCase = ReorderCategoryProducts(repository);

      await useCase(
        authToken: 'token',
        items: [
          const CategoryProductOrderItem(relationId: 'cp_a', position: 30),
          const CategoryProductOrderItem(relationId: 'cp_b', position: 10),
        ],
        draggedRelationId: 'cp_a',
        targetRelationId: 'cp_a',
      );

      expect(repository.updateCalls, isEmpty);
    });
  });
}

class _UpdateCall {
  final String collection;
  final String recordId;
  final Map<String, dynamic> data;

  const _UpdateCall({
    required this.collection,
    required this.recordId,
    required this.data,
  });
}

class _FakeAdminBackofficeRepository implements AdminBackofficeRepository {
  final updateCalls = <_UpdateCall>[];

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    updateCalls.add(
      _UpdateCall(collection: collection, recordId: recordId, data: data),
    );
    return {'id': recordId, ...data};
  }

  @override
  Future<String> authenticateSuperuser({
    required String baseUrl,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CatalogExportResult> exportCatalogCsv({
    required String baseUrl,
    required String authToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CatalogImportReport> importCatalogCsv({
    required String baseUrl,
    required String authToken,
    required String csvContent,
  }) {
    throw UnimplementedError();
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
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) {
    throw UnimplementedError();
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
  }) {
    throw UnimplementedError();
  }
}
