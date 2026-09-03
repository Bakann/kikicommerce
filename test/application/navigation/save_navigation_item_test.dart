import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/admin/save_admin_record.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/save_navigation_item.dart';

class _RecordingRepository implements AdminBackofficeRepository {
  String? createdCollection;
  Map<String, dynamic>? createdData;
  String? updatedCollection;
  String? updatedRecordId;
  Map<String, dynamic>? updatedData;

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    createdCollection = collection;
    createdData = data;
    return {'id': 'new-id', ...data};
  }

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    updatedCollection = collection;
    updatedRecordId = recordId;
    updatedData = data;
    return {'id': recordId, ...data};
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

SaveNavigationItemInput _input({
  String label = 'Cadeaux',
  DrawerNavigationItemType itemType = DrawerNavigationItemType.category,
  String? categoryId = 'cat-1',
  String? productId,
  String? pageKey,
  String? url,
  String? promoMediaId,
  DrawerNavigationPlacement placement = DrawerNavigationPlacement.nav,
  DrawerNavigationDesktopTemplate desktopTemplate =
      DrawerNavigationDesktopTemplate.listOnly,
  int depth = 0,
  int position = 10,
  String? parentId,
  String? recordId,
  bool isActive = true,
  bool isHidden = false,
  Map<String, dynamic> config = const {},
}) {
  return SaveNavigationItemInput(
    menuId: 'menu-1',
    parentId: parentId,
    position: position,
    depth: depth,
    label: label,
    itemType: itemType,
    categoryId: categoryId,
    productId: productId,
    pageKey: pageKey,
    url: url,
    promoMediaId: promoMediaId,
    placement: placement,
    desktopTemplate: desktopTemplate,
    isActive: isActive,
    isHidden: isHidden,
    config: config,
    recordId: recordId,
  );
}

void main() {
  group('SaveNavigationItem validation', () {
    late _RecordingRepository repo;
    late SaveNavigationItem useCase;

    setUp(() {
      repo = _RecordingRepository();
      useCase = SaveNavigationItem(SaveAdminRecord(repo));
    });

    Future<void> invoke(SaveNavigationItemInput input) =>
        useCase(baseUrl: 'https://pb.test', authToken: 'token', input: input);

    test('throws when label is blank', () async {
      expect(
        () => invoke(_input(label: '   ')),
        throwsA(isA<NavigationItemValidationException>()),
      );
    });

    test('throws when itemType=category without categoryId', () async {
      expect(
        () => invoke(
          _input(itemType: DrawerNavigationItemType.category, categoryId: null),
        ),
        throwsA(isA<NavigationItemValidationException>()),
      );
    });

    test('throws when itemType=product without productId', () async {
      expect(
        () => invoke(
          _input(
            itemType: DrawerNavigationItemType.product,
            categoryId: null,
            productId: '',
          ),
        ),
        throwsA(isA<NavigationItemValidationException>()),
      );
    });

    test('throws when itemType=page without pageKey or url', () async {
      expect(
        () => invoke(
          _input(
            itemType: DrawerNavigationItemType.page,
            categoryId: null,
            pageKey: '   ',
            url: '',
          ),
        ),
        throwsA(isA<NavigationItemValidationException>()),
      );
    });

    test('throws when itemType=external without url', () async {
      expect(
        () => invoke(
          _input(
            itemType: DrawerNavigationItemType.external,
            categoryId: null,
            url: '',
          ),
        ),
        throwsA(isA<NavigationItemValidationException>()),
      );
    });

    test('throws when itemType=unknown', () async {
      expect(
        () => invoke(
          _input(itemType: DrawerNavigationItemType.unknown, categoryId: null),
        ),
        throwsA(isA<NavigationItemValidationException>()),
      );
    });

    test('throws when placement=promo without promoMediaId', () async {
      expect(
        () => invoke(
          _input(
            placement: DrawerNavigationPlacement.promo,
            promoMediaId: null,
          ),
        ),
        throwsA(isA<NavigationItemValidationException>()),
      );
    });

    test('itemType=page accepts pageKey only', () async {
      await invoke(
        _input(
          itemType: DrawerNavigationItemType.page,
          categoryId: null,
          pageKey: 'gifts',
        ),
      );
      expect(repo.createdCollection, 'navigation_items');
    });

    test('itemType=page accepts url only', () async {
      await invoke(
        _input(
          itemType: DrawerNavigationItemType.page,
          categoryId: null,
          url: 'https://example.com',
        ),
      );
      expect(repo.createdCollection, 'navigation_items');
    });
  });

  group('SaveNavigationItem payload', () {
    late _RecordingRepository repo;
    late SaveNavigationItem useCase;

    setUp(() {
      repo = _RecordingRepository();
      useCase = SaveNavigationItem(SaveAdminRecord(repo));
    });

    Future<void> invoke(SaveNavigationItemInput input) =>
        useCase(baseUrl: 'https://pb.test', authToken: 'token', input: input);

    test('creates a new record when recordId is null', () async {
      await invoke(_input(label: '  Cadeaux  '));
      expect(repo.createdCollection, 'navigation_items');
      expect(repo.updatedRecordId, isNull);
      expect(repo.createdData!['label'], 'Cadeaux');
      expect(repo.createdData!['itemType'], 'category');
      expect(repo.createdData!['category'], 'cat-1');
      expect(repo.createdData!['product'], isNull);
      expect(repo.createdData!['placement'], 'nav');
      expect(repo.createdData!['desktopDrawerTemplate'], 'list_only');
      expect(repo.createdData!['isActive'], true);
      expect(repo.createdData!['menu'], 'menu-1');
      expect(repo.createdData!['config'], isEmpty);
    });

    test('updates existing record when recordId provided', () async {
      await invoke(_input(recordId: 'rec-42'));
      expect(repo.updatedRecordId, 'rec-42');
      expect(repo.createdCollection, isNull);
    });

    test('omits desktopDrawerTemplate for depth>0', () async {
      await invoke(
        _input(
          depth: 1,
          parentId: 'root-1',
          desktopTemplate: DrawerNavigationDesktopTemplate.heroSingle,
        ),
      );
      expect(repo.createdData!['desktopDrawerTemplate'], isNull);
    });

    test('maps desktop templates to wire values at depth 0', () async {
      const templates = {
        DrawerNavigationDesktopTemplate.listOnly: 'list_only',
        DrawerNavigationDesktopTemplate.heroSingle: 'hero_single',
        DrawerNavigationDesktopTemplate.promoGrid2x2: 'promo_grid_2x2',
        DrawerNavigationDesktopTemplate.promoStack2: 'promo_stack_2',
      };
      for (final entry in templates.entries) {
        expect(desktopTemplateWireValue(entry.key), entry.value);
      }
    });

    test('clears non-matching target fields', () async {
      await invoke(
        _input(
          itemType: DrawerNavigationItemType.external,
          categoryId: 'should-be-dropped',
          productId: 'should-be-dropped',
          pageKey: 'should-be-dropped',
          url: 'https://example.com',
        ),
      );
      expect(repo.createdData!['category'], isNull);
      expect(repo.createdData!['product'], isNull);
      expect(repo.createdData!['pageKey'], isNull);
      expect(repo.createdData!['url'], 'https://example.com');
    });

    test('preserves unknown config keys in payload', () async {
      await invoke(
        _input(
          config: {
            'editorialTiles': {'items': []},
            'futureKey': {'enabled': true},
          },
        ),
      );

      expect(repo.createdData!['config'], {
        'editorialTiles': {'items': []},
        'futureKey': {'enabled': true},
      });
    });
  });
}
