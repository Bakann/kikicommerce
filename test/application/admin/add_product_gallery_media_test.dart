import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/add_product_gallery_media.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';

void main() {
  group('AddProductGalleryMedia', () {
    test('appends media to the existing gallery container', () async {
      final repository = _FakeAdminBackofficeRepository(
        product: const {
          'id': 'product-1',
          'code': 'PROD-1',
          'name': 'Robe Kiki',
          'galleryImages': ['container-1'],
        },
        mediaContainer: const {
          'id': 'container-1',
          'medias': ['media-old'],
        },
      );
      final useCase = AddProductGalleryMedia(repository);

      await useCase.call(
        authToken: 'test-token',
        productId: 'product-1',
        mediaId: 'media-new',
      );

      expect(repository.createCalls, isEmpty);
      expect(repository.updateCalls, hasLength(1));
      expect(repository.updateCalls.single.collection, 'mediaContainers');
      expect(repository.updateCalls.single.recordId, 'container-1');
      expect(repository.updateCalls.single.data, {
        'medias': ['media-old', 'media-new'],
      });
    });

    test('creates and links a gallery container when missing', () async {
      final repository = _FakeAdminBackofficeRepository(
        product: const {
          'id': 'product-1',
          'code': 'PROD-1',
          'name': 'Robe Kiki',
          'galleryImages': <String>[],
        },
      );
      final useCase = AddProductGalleryMedia(repository);

      await useCase.call(
        authToken: 'test-token',
        productId: 'product-1',
        mediaId: 'media-new',
      );

      expect(repository.createCalls, hasLength(1));
      expect(repository.createCalls.single.collection, 'mediaContainers');
      expect(repository.createCalls.single.data, {
        'code': 'prod-1-gallery',
        'name': 'Galerie Robe Kiki',
        'medias': ['media-new'],
        'isActive': true,
      });
      expect(repository.updateCalls, hasLength(1));
      expect(repository.updateCalls.single.collection, 'products');
      expect(repository.updateCalls.single.recordId, 'product-1');
      expect(repository.updateCalls.single.data, {
        'galleryImages': ['container-new'],
      });
    });

    test(
      'does not duplicate a media already present in the container',
      () async {
        final repository = _FakeAdminBackofficeRepository(
          product: const {
            'id': 'product-1',
            'code': 'PROD-1',
            'name': 'Robe Kiki',
            'galleryImages': ['container-1'],
          },
          mediaContainer: const {
            'id': 'container-1',
            'medias': ['media-new'],
          },
        );
        final useCase = AddProductGalleryMedia(repository);

        await useCase.call(
          authToken: 'test-token',
          productId: 'product-1',
          mediaId: 'media-new',
        );

        expect(repository.createCalls, isEmpty);
        expect(repository.updateCalls, isEmpty);
      },
    );
  });

  group('ReplaceProductGalleryMedia', () {
    test('replaces media in the existing gallery container', () async {
      final repository = _FakeAdminBackofficeRepository(
        product: const {
          'id': 'product-1',
          'code': 'PROD-1',
          'name': 'Robe Kiki',
          'galleryImages': ['container-1'],
        },
        mediaContainer: const {
          'id': 'container-1',
          'medias': ['media-old', 'media-other'],
        },
      );
      final useCase = ReplaceProductGalleryMedia(repository);

      await useCase.call(
        authToken: 'test-token',
        productId: 'product-1',
        currentMediaId: 'media-old',
        replacementMediaId: 'media-new',
      );

      expect(repository.updateCalls, hasLength(1));
      expect(repository.updateCalls.single.collection, 'mediaContainers');
      expect(repository.updateCalls.single.recordId, 'container-1');
      expect(repository.updateCalls.single.data, {
        'medias': ['media-new', 'media-other'],
      });
    });

    test('deduplicates when replacement media already exists', () async {
      final repository = _FakeAdminBackofficeRepository(
        product: const {
          'id': 'product-1',
          'code': 'PROD-1',
          'name': 'Robe Kiki',
          'galleryImages': ['container-1'],
        },
        mediaContainer: const {
          'id': 'container-1',
          'medias': ['media-old', 'media-new'],
        },
      );
      final useCase = ReplaceProductGalleryMedia(repository);

      await useCase.call(
        authToken: 'test-token',
        productId: 'product-1',
        currentMediaId: 'media-old',
        replacementMediaId: 'media-new',
      );

      expect(repository.updateCalls.single.data, {
        'medias': ['media-new'],
      });
    });
  });

  group('RemoveProductGalleryMedia', () {
    test('removes media from the existing gallery container', () async {
      final repository = _FakeAdminBackofficeRepository(
        product: const {
          'id': 'product-1',
          'code': 'PROD-1',
          'name': 'Robe Kiki',
          'galleryImages': ['container-1'],
        },
        mediaContainer: const {
          'id': 'container-1',
          'medias': ['media-old', 'media-remove', 'media-other'],
        },
      );
      final useCase = RemoveProductGalleryMedia(repository);

      await useCase.call(
        authToken: 'test-token',
        productId: 'product-1',
        mediaId: 'media-remove',
      );

      expect(repository.updateCalls, hasLength(1));
      expect(repository.updateCalls.single.collection, 'mediaContainers');
      expect(repository.updateCalls.single.recordId, 'container-1');
      expect(repository.updateCalls.single.data, {
        'medias': ['media-old', 'media-other'],
      });
    });

    test('throws when media is not part of the gallery', () async {
      final repository = _FakeAdminBackofficeRepository(
        product: const {
          'id': 'product-1',
          'code': 'PROD-1',
          'name': 'Robe Kiki',
          'galleryImages': ['container-1'],
        },
        mediaContainer: const {
          'id': 'container-1',
          'medias': ['media-old'],
        },
      );
      final useCase = RemoveProductGalleryMedia(repository);

      await expectLater(
        useCase.call(
          authToken: 'test-token',
          productId: 'product-1',
          mediaId: 'media-missing',
        ),
        throwsStateError,
      );
      expect(repository.updateCalls, isEmpty);
    });
  });

  group('MoveProductGalleryMedia', () {
    test('moves media to the next gallery position', () async {
      final repository = _FakeAdminBackofficeRepository(
        product: const {
          'id': 'product-1',
          'code': 'PROD-1',
          'name': 'Robe Kiki',
          'galleryImages': ['container-1'],
        },
        mediaContainer: const {
          'id': 'container-1',
          'medias': ['media-1', 'media-2', 'media-3'],
        },
      );
      final useCase = MoveProductGalleryMedia(repository);

      await useCase.call(
        authToken: 'test-token',
        productId: 'product-1',
        mediaId: 'media-2',
        direction: ProductGalleryMoveDirection.next,
      );

      expect(repository.updateCalls.single.collection, 'mediaContainers');
      expect(repository.updateCalls.single.recordId, 'container-1');
      expect(repository.updateCalls.single.data, {
        'medias': ['media-1', 'media-3', 'media-2'],
      });
    });
  });

  group('SetProductPrimaryMedia', () {
    test(
      'promotes gallery media and keeps previous picture in gallery',
      () async {
        final repository = _FakeAdminBackofficeRepository(
          product: const {
            'id': 'product-1',
            'code': 'PROD-1',
            'name': 'Robe Kiki',
            'picture': 'media-picture',
            'galleryImages': ['container-1'],
          },
          mediaContainer: const {
            'id': 'container-1',
            'medias': ['media-1', 'media-promoted', 'media-3'],
          },
        );
        final useCase = SetProductPrimaryMedia(repository);

        await useCase.call(
          authToken: 'test-token',
          productId: 'product-1',
          mediaId: 'media-promoted',
        );

        expect(repository.updateCalls, hasLength(2));
        expect(repository.updateCalls.first.collection, 'mediaContainers');
        expect(repository.updateCalls.first.data, {
          'medias': ['media-picture', 'media-1', 'media-3'],
        });
        expect(repository.updateCalls.last.collection, 'products');
        expect(repository.updateCalls.last.recordId, 'product-1');
        expect(repository.updateCalls.last.data, {'picture': 'media-promoted'});
      },
    );
  });
}

class _FakeAdminBackofficeRepository implements AdminBackofficeRepository {
  final Map<String, dynamic> product;
  final Map<String, dynamic>? mediaContainer;
  final createCalls = <_RepositoryWriteCall>[];
  final updateCalls = <_RepositoryWriteCall>[];

  _FakeAdminBackofficeRepository({required this.product, this.mediaContainer});

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
    return switch (collection) {
      'products' => [product],
      'mediaContainers' => [?mediaContainer],
      _ => const [],
    };
  }

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    createCalls.add(_RepositoryWriteCall(collection: collection, data: data));
    return {'id': 'container-new', ...data};
  }

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    updateCalls.add(
      _RepositoryWriteCall(
        collection: collection,
        recordId: recordId,
        data: data,
      ),
    );
    return {'id': recordId, ...data};
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
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) async => {'id': 'new-media', 'file': filename};

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

class _RepositoryWriteCall {
  final String collection;
  final String? recordId;
  final Map<String, dynamic> data;

  const _RepositoryWriteCall({
    required this.collection,
    this.recordId,
    required this.data,
  });
}
