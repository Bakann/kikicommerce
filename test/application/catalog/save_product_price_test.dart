import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/admin/save_admin_record.dart';
import 'package:kiki_commerce/application/catalog/save_product_price.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

class _RecordingRepository implements AdminBackofficeRepository {
  String? updatedCollection;
  String? updatedRecordId;
  Map<String, dynamic>? updatedData;
  String? createdCollection;
  Map<String, dynamic>? createdData;
  bool shouldFail = false;
  List<Map<String, dynamic>> currencies = const [
    {'id': 'currency-eur', 'isocode': 'EUR', 'symbol': '€', 'isActive': true},
  ];

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
    updatedCollection = collection;
    updatedRecordId = recordId;
    updatedData = Map<String, dynamic>.from(data);
    return {'id': recordId, ...data};
  }

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    if (shouldFail) {
      throw StateError('backend down');
    }
    createdCollection = collection;
    createdData = Map<String, dynamic>.from(data);
    return {'id': 'created-1', ...data};
  }

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
  }) async {
    if (collection == 'currencies') {
      return currencies.map(Map<String, dynamic>.from).toList();
    }
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

void main() {
  late _RecordingRepository repo;
  late SaveProductPrice useCase;

  const priceRow = CatalogPrice(
    id: 'price-1',
    productId: 'prod-1',
    price: 39,
    isDefault: true,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );

  setUp(() {
    repo = _RecordingRepository();
    useCase = SaveProductPrice(SaveAdminRecord(repo), repo);
  });

  Future<SaveProductPriceResult> invoke(
    double value, {
    CatalogPrice? currentPriceRow = priceRow,
  }) => useCase(
    baseUrl: 'https://pb.test',
    authToken: 'token',
    productId: 'prod-1',
    priceRow: currentPriceRow,
    price: value,
  );

  test('returns noChange when normalized price stays identical', () async {
    final result = await invoke(39.0001);
    expect(result, isA<SaveProductPriceNoChange>());
    expect(repo.updatedRecordId, isNull);
  });

  test('updates the active price row with a rounded decimal value', () async {
    final result = await invoke(49.995);
    expect(result, isA<SaveProductPriceSaved>());
    expect(repo.updatedCollection, 'priceRows');
    expect(repo.updatedRecordId, 'price-1');
    expect(repo.updatedData, {'price': 49.99});
  });

  test(
    'creates a price row when the product has no active price yet',
    () async {
      final result = await invoke(49.9, currentPriceRow: null);
      expect(result, isA<SaveProductPriceSaved>());
      expect(repo.createdCollection, 'priceRows');
      expect(repo.createdData, {
        'product': 'prod-1',
        'currency': 'currency-eur',
        'price': 49.9,
        'isDefault': true,
        'isActive': true,
      });
    },
  );

  test('returns failure when repository throws', () async {
    repo.shouldFail = true;
    final result = await invoke(59.9);
    expect(result, isA<SaveProductPriceFailure>());
    expect(
      (result as SaveProductPriceFailure).error.toString(),
      contains('backend down'),
    );
  });

  test('normalizeProductPrice keeps two decimals', () {
    expect(normalizeProductPrice(12), 12);
    expect(normalizeProductPrice(12.3456), 12.35);
  });

  test('isSameProductPrice compares normalized values', () {
    expect(isSameProductPrice(39, 39.0001), isTrue);
    expect(isSameProductPrice(39, 39.02), isFalse);
  });
}
