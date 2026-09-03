import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/presentation/providers/media_library_provider.dart';

const _apiBaseUrl = 'https://api.example.test';
const _mediaBaseUrl = 'https://cdn.example.test/img';

void main() {
  group('mediaLibraryProvider', () {
    test('loads active medias and paginates through the controller', () async {
      final repository = _FakeAdminBackofficeRepository(
        pages: const {
          1: [
            {
              'id': 'media-1',
              'collectionId': 'medias',
              'file': 'one.jpg',
              'title': 'One',
              'isActive': true,
            },
          ],
          2: [
            {
              'id': 'media-2',
              'collectionId': 'medias',
              'file': 'two.jpg',
              'title': 'Two',
              'isActive': true,
            },
            {
              'id': 'inactive-media',
              'collectionId': 'medias',
              'file': 'hidden.jpg',
              'isActive': false,
            },
          ],
        },
      );
      final container = ProviderContainer(
        overrides: [
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final provider = mediaLibraryProvider(
        const MediaLibraryQuery(
          authToken: 'token',
          apiBaseUrl: _apiBaseUrl,
          mediaBaseUrl: _mediaBaseUrl,
          perPage: 1,
        ),
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      await container.read(provider.future);

      expect(container.read(provider).value?.items, hasLength(1));
      expect(container.read(provider).value?.items.first.id, 'media-1');
      expect(
        container.read(provider).value?.items.first.fileUrl,
        'https://cdn.example.test/img/api/files/medias/media-1/one.jpg',
      );
      expect(container.read(provider).value?.hasMore, isTrue);
      expect(repository.lastListBaseUrl, _apiBaseUrl);

      await controller.loadMore();

      final state = container.read(provider).value!;
      expect(state.items.map((media) => media.id), ['media-1', 'media-2']);
      expect(state.hasMore, isTrue);
    });

    test('defers loading until the search query is long enough', () async {
      final repository = _FakeAdminBackofficeRepository(
        pages: const {
          1: [
            {
              'id': 'media-1',
              'collectionId': 'medias',
              'file': 'one.jpg',
              'title': 'One',
              'isActive': true,
            },
          ],
        },
      );
      final container = ProviderContainer(
        overrides: [
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final deferredProvider = mediaLibraryProvider(
        const MediaLibraryQuery(
          authToken: 'token',
          apiBaseUrl: _apiBaseUrl,
          mediaBaseUrl: _mediaBaseUrl,
          perPage: 8,
          deferUntilSearch: true,
        ),
      );
      final deferredSubscription = container.listen(
        deferredProvider,
        (_, _) {},
      );
      addTearDown(deferredSubscription.close);

      await container.read(deferredProvider.future);

      final deferredState = container.read(deferredProvider).value!;
      expect(deferredState.isDeferred, isTrue);
      expect(deferredState.items, isEmpty);
      expect(repository.listCalls, 0);

      final activeProvider = mediaLibraryProvider(
        const MediaLibraryQuery(
          authToken: 'token',
          apiBaseUrl: _apiBaseUrl,
          mediaBaseUrl: _mediaBaseUrl,
          searchQuery: 'on',
          perPage: 8,
          deferUntilSearch: true,
        ),
      );
      final activeSubscription = container.listen(activeProvider, (_, _) {});
      addTearDown(activeSubscription.close);

      await container.read(activeProvider.future);

      final activeState = container.read(activeProvider).value!;
      expect(activeState.isDeferred, isFalse);
      expect(activeState.items.single.id, 'media-1');
      expect(repository.listCalls, 1);
      expect(repository.lastPerPage, 8);
      expect(repository.lastFilter, contains("title ~ 'on'"));
    });

    test('keeps previous data when refresh fails', () async {
      final repository = _FakeAdminBackofficeRepository(
        pages: const {
          1: [
            {
              'id': 'media-1',
              'collectionId': 'medias',
              'file': 'one.jpg',
              'title': 'One',
              'isActive': true,
            },
          ],
        },
      );
      final container = ProviderContainer(
        overrides: [
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final provider = mediaLibraryProvider(
        const MediaLibraryQuery(
          authToken: 'token',
          apiBaseUrl: _apiBaseUrl,
          mediaBaseUrl: _mediaBaseUrl,
        ),
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      await container.read(provider.future);

      repository.throwOnList = true;
      await controller.refresh();

      final state = container.read(provider).value!;
      expect(state.items.single.id, 'media-1');
      expect(state.actionError, contains('list failed'));
    });

    test('prepends uploaded media to current state', () async {
      final repository = _FakeAdminBackofficeRepository(pages: const {1: []});
      final container = ProviderContainer(
        overrides: [
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final provider = mediaLibraryProvider(
        const MediaLibraryQuery(
          authToken: 'token',
          apiBaseUrl: _apiBaseUrl,
          mediaBaseUrl: _mediaBaseUrl,
        ),
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      await container.read(provider.future);

      final uploaded = await controller.uploadFile(
        fileBytes: Uint8List.fromList(_onePixelPng),
        filename: 'new.png',
      );

      final state = container.read(provider).value!;
      if (uploaded == null) {
        fail(state.actionError ?? 'upload returned null without actionError');
      }
      expect(uploaded.id, 'uploaded-media');
      expect(
        uploaded.fileUrl,
        'https://cdn.example.test/img/api/files/medias/uploaded-media/new.png',
      );
      expect(state.items.single.id, 'uploaded-media');
      expect(repository.uploadedFilename, 'new.png');
      expect(repository.lastUploadBaseUrl, _apiBaseUrl);
    });
  });
}

const _onePixelPng = [
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  15,
  4,
  0,
  9,
  251,
  3,
  253,
  160,
  179,
  173,
  48,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

class _FakeAdminBackofficeRepository implements AdminBackofficeRepository {
  final Map<int, List<Map<String, dynamic>>> pages;
  bool throwOnList = false;
  String? uploadedFilename;
  int listCalls = 0;
  int? lastPerPage;
  String? lastFilter;
  String? lastListBaseUrl;
  String? lastUploadBaseUrl;

  _FakeAdminBackofficeRepository({required this.pages});

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
    lastListBaseUrl = baseUrl;
    lastPerPage = perPage;
    lastFilter = filter;

    if (throwOnList) {
      throw Exception('list failed');
    }

    return pages[page] ?? const [];
  }

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) async {
    lastUploadBaseUrl = baseUrl;
    uploadedFilename = filename;
    return {
      'id': 'uploaded-media',
      'collectionId': 'medias',
      'file': filename,
      'title': 'Uploaded',
      'isActive': true,
    };
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
}
