import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/presentation/widgets/media_picker_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaPickerModal', () {
    void setLargeSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
    }

    void resetSurface(WidgetTester tester) {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }

    testWidgets('opens with current image without loading the library', (
      tester,
    ) async {
      setLargeSurface(tester);
      addTearDown(() => resetSurface(tester));

      final repository = _FakeAdminBackofficeRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminBackofficeRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await MediaPickerModal.show(
                    context,
                    authToken: 'token',
                    currentMediaId: 'media-current',
                    initialSelection: const MediaPickerInitialSelection(
                      mediaId: 'media-current',
                      previewUrl: 'https://example.test/current.jpg',
                      title: 'Current photo',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open the picker
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Modal should be visible
      expect(find.text('Choisir une image'), findsOneWidget);
      expect(find.text('Image actuelle'), findsOneWidget);
      expect(find.text('Current photo'), findsOneWidget);
      expect(repository.listCalls, 0);

      final selectButton = find.widgetWithText(ElevatedButton, 'Sélectionner');
      expect(tester.widget<ElevatedButton>(selectButton).onPressed, isNull);
    });

    testWidgets('waits for at least two search characters before loading', (
      tester,
    ) async {
      setLargeSurface(tester);
      addTearDown(() => resetSurface(tester));

      final repository = _FakeAdminBackofficeRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminBackofficeRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    MediaPickerModal.show(context, authToken: 'token'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(repository.listCalls, 0);

      await tester.enterText(find.byType(TextField), 'p');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repository.listCalls, 0);

      await tester.enterText(find.byType(TextField), 'ph');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(repository.listCalls, 1);
      expect(repository.lastPerPage, 8);
      expect(repository.lastFilter, contains("title ~ 'ph'"));
      expect(find.byTooltip('Photo 1'), findsOneWidget);
    });

    testWidgets('selects one search result', (tester) async {
      setLargeSurface(tester);
      addTearDown(() => resetSurface(tester));

      final repository = _FakeAdminBackofficeRepository();
      MediaPickerResult? result;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminBackofficeRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await MediaPickerModal.show(
                    context,
                    authToken: 'token',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ph');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Photo 1'));
      // The InkWell has both onTap and onDoubleTap, so Flutter waits ~300ms
      // for a potential second tap before firing onTap.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final selectButton = find.widgetWithText(ElevatedButton, 'Sélectionner');
      await tester.tap(selectButton);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.mediaId, 'media-1');
    });

    testWidgets('cancel returns null', (tester) async {
      setLargeSurface(tester);
      addTearDown(() => resetSurface(tester));

      final repository = _FakeAdminBackofficeRepository();
      MediaPickerResult? result;
      bool dialogReturned = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminBackofficeRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await MediaPickerModal.show(
                    context,
                    authToken: 'token',
                  );
                  dialogReturned = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(dialogReturned, isTrue);
      expect(result, isNull);
    });

    testWidgets('select button disabled when no media selected', (
      tester,
    ) async {
      setLargeSurface(tester);
      addTearDown(() => resetSurface(tester));

      final repository = _FakeAdminBackofficeRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminBackofficeRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    MediaPickerModal.show(context, authToken: 'token'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final selectButton = find.widgetWithText(ElevatedButton, 'Sélectionner');
      expect(tester.widget<ElevatedButton>(selectButton).onPressed, isNull);
    });
  });
}

class _FakeAdminBackofficeRepository implements AdminBackofficeRepository {
  int listCalls = 0;
  int? lastPerPage;
  String? lastFilter;

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
    listCalls++;
    lastPerPage = perPage;
    lastFilter = filter;

    return [
      {
        'id': 'media-1',
        'collectionId': 'col1',
        'file': 'photo1.jpg',
        'title': 'Photo 1',
        'code': 'photo1',
        'altText': 'A photo',
        'mimeType': 'image/jpeg',
        'isActive': true,
      },
      {
        'id': 'media-2',
        'collectionId': 'col1',
        'file': 'photo2.jpg',
        'title': 'Photo 2',
        'code': 'photo2',
        'isActive': true,
      },
    ];
  }

  @override
  Future<String> authenticateSuperuser({
    required String baseUrl,
    required String email,
    required String password,
  }) async => 'token';

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async => data;

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
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
  }) async => {'id': 'new-media', 'collectionId': 'col1', 'file': filename};

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
