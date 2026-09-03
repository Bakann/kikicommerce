import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/catalog/catalog_invalidations.dart';
import 'package:kiki_commerce/presentation/providers/admin_backoffice_controller.dart';
import 'package:kiki_commerce/presentation/providers/catalog_invalidator_provider.dart';

void main() {
  group('AdminBackofficeController', () {
    test('authenticate with explicit token loads collections', () async {
      final repository = _FakeAdminBackofficeRepository(
        recordsByCollection: {
          'categories': [
            {'id': 'cat-1', 'name': 'Robes'},
          ],
        },
      );
      final container = ProviderContainer(
        overrides: [
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(adminBackofficeControllerProvider.notifier)
          .authenticate(
            baseUrl: 'https://example.com',
            tokenInput: 'token-123',
            email: '',
            password: '',
          );

      final state = container.read(adminBackofficeControllerProvider);
      expect(repository.authenticateCalls, 0);
      expect(state.sessionToken, 'token-123');
      expect(state.recordsByCollection['categories'], hasLength(1));
      expect(state.statusMessage, 'Collections synchronisées avec PocketBase.');
      expect(state.errorMessage, isNull);
    });

    test('authenticate with credentials uses repository token', () async {
      final repository = _FakeAdminBackofficeRepository();
      final container = ProviderContainer(
        overrides: [
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(adminBackofficeControllerProvider.notifier)
          .authenticate(
            baseUrl: 'https://example.com',
            tokenInput: '',
            email: 'admin@example.com',
            password: 'secret',
          );

      final state = container.read(adminBackofficeControllerProvider);
      expect(repository.authenticateCalls, 1);
      expect(state.sessionToken, 'super-token');
    });

    test(
      'importCatalog stores formatted summary and refreshes records',
      () async {
        final report = CatalogImportReport(totalRows: 3)
          ..markCreated('products');
        final repository = _FakeAdminBackofficeRepository(
          importReport: report,
          recordsByCollection: {
            'products': [
              {'id': 'prod-1', 'name': 'Robe Kiki'},
            ],
          },
        );
        final invalidator = _RecordingCatalogInvalidator();
        final container = ProviderContainer(
          overrides: [
            adminBackofficeRepositoryProvider.overrideWithValue(repository),
            catalogInvalidatorProvider.overrideWithValue(invalidator),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(adminBackofficeControllerProvider.notifier)
            .importCatalog(
              baseUrl: 'https://example.com',
              authToken: 'token-123',
              csvContent: 'csv-content',
            );

        final state = container.read(adminBackofficeControllerProvider);
        expect(repository.importCalls, 1);
        expect(state.isImporting, isFalse);
        expect(state.recordsByCollection['products'], hasLength(1));
        expect(state.statusMessage, contains('Lignes traitées: 3'));
        expect(
          state.statusMessage,
          contains('Products: 1 créé(s), 0 mis à jour'),
        );
        expect(
          invalidator.targets,
          containsAll(const [
            AllProductDetailsInvalidation(),
            AllProductListsInvalidation(),
            AllSearchResultsInvalidation(),
            AllProductRoutesInvalidation(),
            DrawerNavigationInvalidation(),
          ]),
        );
      },
    );

    test('exportCatalog stores summary and returns the result', () async {
      final repository = _FakeAdminBackofficeRepository(
        exportResult: CatalogExportResult(
          csvContent: 'csv-content',
          exportedRows: 2,
          warnings: const ['warning'],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(adminBackofficeControllerProvider.notifier)
          .exportCatalog(
            baseUrl: 'https://example.com',
            authToken: 'token-123',
          );

      final state = container.read(adminBackofficeControllerProvider);
      expect(repository.exportCalls, 1);
      expect(result?.csvContent, 'csv-content');
      expect(state.isExporting, isFalse);
      expect(state.statusMessage, contains('CSV exporté: 2 ligne(s).'));
      expect(state.statusMessage, contains('1 avertissement(s).'));
    });

    test('clearSession removes token and keeps a status message', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        adminBackofficeControllerProvider.notifier,
      );
      notifier.showStatus('Avant');
      container
          .read(adminBackofficeControllerProvider.notifier)
          .state = container
          .read(adminBackofficeControllerProvider)
          .copyWith(sessionToken: 'token-123');

      notifier.clearSession();

      final state = container.read(adminBackofficeControllerProvider);
      expect(state.sessionToken, isNull);
      expect(state.statusMessage, 'Session admin effacée.');
    });
  });
}

class _RecordingCatalogInvalidator extends CatalogInvalidator {
  final targets = <CatalogInvalidationTarget>[];

  @override
  void apply(Ref ref, Iterable<CatalogInvalidationTarget> targets) {
    this.targets.addAll(targets);
  }
}

class _FakeAdminBackofficeRepository implements AdminBackofficeRepository {
  final Map<String, List<Map<String, dynamic>>> recordsByCollection;
  final CatalogImportReport importReport;
  final CatalogExportResult exportResult;

  int authenticateCalls = 0;
  int importCalls = 0;
  int exportCalls = 0;

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
  }) async {
    authenticateCalls += 1;
    return 'super-token';
  }

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async => {'id': 'created', ...data};

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
  Future<List<Map<String, dynamic>>> listRecords({
    required String baseUrl,
    required String authToken,
    required String collection,
    String sort = '-created',
    int perPage = 500,
    int page = 1,
    String? filter,
  }) async => recordsByCollection[collection] ?? const [];

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async => {'id': recordId, ...data};

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
  }) async => {'id': recordId ?? 'media-created', ...data};

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) async => {'id': 'uploaded-media', 'file': filename};
}
