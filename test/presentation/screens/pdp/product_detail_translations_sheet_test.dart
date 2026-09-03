import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/catalog/pdp_localized_text_editor.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_translations_sheet.dart';

void main() {
  testWidgets('opens on active EN locale and shows fallback state', (
    WidgetTester tester,
  ) async {
    final repo = _RecordingAdminBackofficeRepository();

    await _pumpSheet(tester, repo, initialLocale: pdpTranslationLocale);

    expect(find.text('Traductions PDP'), findsOneWidget);
    expect(find.text('Utilise le FR'), findsOneWidget);
    expect(_currentName(tester), isEmpty);
  });

  testWidgets('tabs keep local edits when switching locale', (
    WidgetTester tester,
  ) async {
    final repo = _RecordingAdminBackofficeRepository();

    await _pumpSheet(tester, repo, initialLocale: pdpBaseLocale);

    await tester.enterText(_nameField(), 'Nom FR brouillon');
    await tester.pump();
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    await tester.enterText(_nameField(), 'Name EN draft');
    await tester.pump();
    await tester.tap(find.text('FR'));
    await tester.pumpAndSettle();

    expect(_currentName(tester), 'Nom FR brouillon');

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(_currentName(tester), 'Name EN draft');
  });

  testWidgets('saving EN creates a product translation when missing', (
    WidgetTester tester,
  ) async {
    final repo = _RecordingAdminBackofficeRepository();

    await _pumpSheet(tester, repo, initialLocale: pdpTranslationLocale);

    await tester.enterText(_nameField(), 'Summer Bag');
    await tester.pump();

    expect(find.text('Modifié non enregistré'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repo.createdCollections, ['product_translations']);
    expect(repo.createdData.single, containsPair('product', 'prod-1'));
    expect(repo.createdData.single, containsPair('locale', 'en'));
    expect(repo.createdData.single, containsPair('name', 'Summer Bag'));
  });

  testWidgets('copy from FR prefills missing EN product fields', (
    WidgetTester tester,
  ) async {
    final repo = _RecordingAdminBackofficeRepository();

    await _pumpSheet(tester, repo, initialLocale: pdpTranslationLocale);

    await tester.tap(find.text('Copier depuis FR'));
    await tester.pump();

    expect(_currentName(tester), 'Sac Totoro Nuage');
    expect(find.text('Modifié non enregistré'), findsOneWidget);
  });

  testWidgets('clearing EN deletes the product translation', (
    WidgetTester tester,
  ) async {
    final repo = _RecordingAdminBackofficeRepository(
      productTranslations: const [
        {
          'id': 'ptr-1',
          'product': 'prod-1',
          'locale': 'en',
          'name': 'Summer Bag',
          'summary': 'A sunny bag.',
          'description': 'English description.',
        },
      ],
    );

    await _pumpSheet(tester, repo, initialLocale: pdpTranslationLocale);

    expect(find.text('Publié'), findsOneWidget);
    expect(_currentName(tester), 'Summer Bag');

    await tester.tap(find.text('Supprimer la traduction EN'));
    await tester.pump();

    expect(find.text('Modifié non enregistré'), findsOneWidget);
    expect(_currentName(tester), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repo.deletedCollections, ['product_translations']);
    expect(repo.deletedRecordIds, ['ptr-1']);
  });

  testWidgets('saving persists edits from both tabs, not just the active one', (
    WidgetTester tester,
  ) async {
    final repo = _RecordingAdminBackofficeRepository();

    await _pumpSheet(tester, repo, initialLocale: pdpBaseLocale);

    // Edit the FR base, switch to EN, edit EN, then save while EN is active.
    await tester.enterText(_nameField(), 'Nom FR révisé');
    await tester.pump();

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    await tester.enterText(_nameField(), 'Revised EN name');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pump();
    await tester.pumpAndSettle();

    // FR went through products.updateRecord and is not silently dropped …
    expect(repo.updatedCollections, contains('products'));
    expect(repo.updatedData.single, containsPair('name', 'Nom FR révisé'));
    // … while EN created its product translation in the same save.
    expect(repo.createdCollections, ['product_translations']);
    expect(repo.createdData.single, containsPair('name', 'Revised EN name'));
  });
}

Future<void> _pumpSheet(
  WidgetTester tester,
  _RecordingAdminBackofficeRepository repo, {
  required String initialLocale,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminBackofficeRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: PdpTranslationsEditorSheet(
            productId: 'prod-1',
            authToken: 'token',
            initialLocale: initialLocale,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _nameField() => find.widgetWithText(TextField, 'Nom produit *');

String _currentName(WidgetTester tester) {
  return tester.widget<TextField>(_nameField()).controller?.text ?? '';
}

class _RecordingAdminBackofficeRepository implements AdminBackofficeRepository {
  final createdCollections = <String>[];
  final updatedCollections = <String>[];
  final deletedCollections = <String>[];
  final createdData = <Map<String, dynamic>>[];
  final updatedData = <Map<String, dynamic>>[];
  final deletedRecordIds = <String>[];
  final recordsByCollection = <String, List<Map<String, dynamic>>>{};

  _RecordingAdminBackofficeRepository({
    List<Map<String, dynamic>> productTranslations = const [],
  }) {
    recordsByCollection['products'] = [
      {
        'id': 'prod-1',
        'code': 'PROD-1',
        'name': 'Sac Totoro Nuage',
        'slug': 'sac-totoro-nuage',
        'summary': 'Un sac pour les jours de pluie.',
        'description': 'Description FR.',
      },
    ];
    recordsByCollection['product_translations'] = productTranslations
        .map(Map<String, dynamic>.from)
        .toList();
    recordsByCollection['narrativeChapters'] = [];
    recordsByCollection['narrative_chapter_translations'] = [];
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
  }) async {
    return (recordsByCollection[collection] ?? const [])
        .map(Map<String, dynamic>.from)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    createdCollections.add(collection);
    createdData.add(Map<String, dynamic>.from(data));
    return {'id': 'created-${createdCollections.length}', ...data};
  }

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    updatedCollections.add(collection);
    updatedData.add(Map<String, dynamic>.from(data));
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
  }) async => data;

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) async => const {};

  @override
  Future<void> deleteRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
  }) async {
    deletedCollections.add(collection);
    deletedRecordIds.add(recordId);
  }

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
