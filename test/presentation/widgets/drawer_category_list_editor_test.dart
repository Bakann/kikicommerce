import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/category_providers.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/widgets/drawer/drawer_category_list_editor.dart';

void main() {
  testWidgets('disclosure opens category children instead of rename dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drawerCategoriesProvider.overrideWith(
            (ref) async => const [
              CatalogCategory(
                id: 'homme',
                code: 'HOMME',
                name: 'Homme',
                slug: 'homme',
              ),
              CatalogCategory(
                id: 'chaussures',
                code: 'CHAUSSURES',
                name: 'Chaussures',
                slug: 'chaussures',
                parentId: 'homme',
              ),
              CatalogCategory(
                id: 'vetements',
                code: 'VETEMENTS',
                name: 'Vêtements',
                slug: 'vetements',
                parentId: 'homme',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DrawerCategoryListEditor()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Homme'), findsOneWidget);
    expect(find.text('Chaussures'), findsNothing);

    await tester.tap(find.byTooltip('Voir les sous-catégories'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier la catégorie'), findsNothing);
    expect(find.text('Chaussures'), findsOneWidget);
    expect(find.text('Vêtements'), findsOneWidget);
    expect(find.text('Homme'), findsOneWidget);
  });

  testWidgets('empty category can be opened to create its first child', (
    tester,
  ) async {
    final adminRepository = _RecordingAdminBackofficeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuthTokenProvider.overrideWith((ref) => 'token'),
          adminBackofficeRepositoryProvider.overrideWithValue(adminRepository),
          drawerNavigationRepositoryProvider.overrideWithValue(
            const _FallbackDrawerNavigationRepository(),
          ),
          drawerCategoriesProvider.overrideWith(
            (ref) async => const [
              CatalogCategory(
                id: 'homme',
                code: 'HOMME',
                name: 'Homme',
                slug: 'homme',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DrawerCategoryListEditor()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voir les sous-catégories'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Aucune sous-catégorie'), findsOneWidget);
    expect(find.text('Nouvelle sous-catégorie'), findsOneWidget);

    await tester.tap(find.text('Nouvelle sous-catégorie'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Chaussures');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
    await tester.pumpAndSettle();

    expect(adminRepository.createCalls, hasLength(1));
    final call = adminRepository.createCalls.single;
    expect(call.collection, 'categories');
    expect(call.data['name'], 'Chaussures');
    expect(call.data['parent'], 'homme');
  });
}

class _FallbackDrawerNavigationRepository
    implements DrawerNavigationRepository {
  const _FallbackDrawerNavigationRepository();

  @override
  Future<DrawerNavigationLoadResult> fetchMainDrawer({
    required String locale,
    bool includeHidden = false,
  }) async {
    return const DrawerNavigationLoadResult.fallback(
      fallbackReason: DrawerNavigationFallbackReason.menuMissing,
    );
  }
}

class _CreateCall {
  final String collection;
  final Map<String, dynamic> data;

  const _CreateCall({required this.collection, required this.data});
}

class _RecordingAdminBackofficeRepository implements AdminBackofficeRepository {
  final List<_CreateCall> createCalls = [];

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    createCalls.add(_CreateCall(collection: collection, data: Map.of(data)));
    return {'id': 'created-${createCalls.length}', ...data};
  }

  @override
  Future<String> authenticateSuperuser({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CatalogExportResult> exportCatalogCsv({
    required String baseUrl,
    required String authToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CatalogImportReport> importCatalogCsv({
    required String baseUrl,
    required String authToken,
    required String csvContent,
  }) async {
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
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) async {
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
  }) async {
    throw UnimplementedError();
  }
}
