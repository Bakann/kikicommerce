import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/catalog/catalog_invalidations.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/save_navigation_item.dart';
import 'package:kiki_commerce/presentation/providers/catalog_invalidator_provider.dart';
import 'package:kiki_commerce/presentation/providers/navigation_item_editor_controller.dart';

const _apiBaseUrl = 'https://api.example.test';

void main() {
  group('NavigationItemEditorController', () {
    test('saves a navigation item and invalidates the drawer', () async {
      final repository = _FakeAdminBackofficeRepository();
      final invalidator = _RecordingCatalogInvalidator();
      final container = ProviderContainer(
        overrides: [
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
          catalogInvalidatorProvider.overrideWithValue(invalidator),
        ],
      );
      addTearDown(container.dispose);

      final saved = await container
          .read(navigationItemEditorControllerProvider.notifier)
          .save(
            NavigationItemEditorSaveRequest(
              authToken: 'token',
              baseUrl: _apiBaseUrl,
              input: _input(label: 'Cadeaux'),
            ),
          );

      expect(saved, isTrue);
      expect(
        container.read(navigationItemEditorControllerProvider).hasError,
        isFalse,
      );
      expect(repository.createdCollection, 'navigation_items');
      expect(repository.createdData?['label'], 'Cadeaux');
      expect(invalidator.targets, const [DrawerNavigationInvalidation()]);
    });

    test('stores validation errors in AsyncValue', () async {
      final container = ProviderContainer(
        overrides: [
          adminBackofficeRepositoryProvider.overrideWithValue(
            _FakeAdminBackofficeRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final saved = await container
          .read(navigationItemEditorControllerProvider.notifier)
          .save(
            NavigationItemEditorSaveRequest(
              authToken: 'token',
              baseUrl: _apiBaseUrl,
              input: _input(
                itemType: DrawerNavigationItemType.category,
                categoryId: null,
              ),
            ),
          );

      final state = container.read(navigationItemEditorControllerProvider);
      expect(saved, isFalse);
      expect(state.hasError, isTrue);
      expect(state.error, isA<NavigationItemValidationException>());
    });
  });
}

SaveNavigationItemInput _input({
  String label = 'Menu',
  DrawerNavigationItemType itemType = DrawerNavigationItemType.page,
  String? categoryId = 'cat-1',
}) {
  return SaveNavigationItemInput(
    menuId: 'menu-1',
    position: 10,
    depth: 0,
    label: label,
    itemType: itemType,
    categoryId: categoryId,
    pageKey: itemType == DrawerNavigationItemType.page ? 'gifts' : null,
    placement: DrawerNavigationPlacement.nav,
    desktopTemplate: DrawerNavigationDesktopTemplate.listOnly,
    isActive: true,
    isHidden: false,
  );
}

class _RecordingCatalogInvalidator extends CatalogInvalidator {
  final targets = <CatalogInvalidationTarget>[];

  @override
  void apply(Ref ref, Iterable<CatalogInvalidationTarget> targets) {
    this.targets.addAll(targets);
  }
}

class _FakeAdminBackofficeRepository implements AdminBackofficeRepository {
  String? createdCollection;
  Map<String, dynamic>? createdData;

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    createdCollection = collection;
    createdData = data;
    return {'id': 'created', ...data};
  }

  @override
  Future<String> authenticateSuperuser({
    required String baseUrl,
    required String email,
    required String password,
  }) async => 'token';

  @override
  Future<void> deleteRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
  }) async {}

  @override
  Future<CatalogExportResult> exportCatalogCsv({
    required String baseUrl,
    required String authToken,
  }) async => CatalogExportResult(csvContent: '', exportedRows: 0);

  @override
  Future<CatalogImportReport> importCatalogCsv({
    required String baseUrl,
    required String authToken,
    required String csvContent,
  }) async => CatalogImportReport(totalRows: 0);

  @override
  Future<List<Map<String, dynamic>>> listRecords({
    required String baseUrl,
    required String authToken,
    required String collection,
    String sort = '-created',
    int perPage = 500,
    int page = 1,
    String? filter,
  }) async => const [];

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async => {'id': recordId, ...data};

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) async => {'id': 'media-1', 'file': filename};

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
  }) async => {'id': recordId ?? 'media-1', ...data};
}
