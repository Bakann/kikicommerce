import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/catalog/catalog_invalidations.dart';
import 'package:kiki_commerce/application/catalog/pdp_localized_text_editor.dart';

void main() {
  group('SavePdpLocalizedText', () {
    test('saves FR product and narrative chapter updates', () async {
      final repo = _RecordingAdminBackofficeRepository();
      final useCase = SavePdpLocalizedText(repo);

      final result = await useCase(
        baseUrl: 'http://pb.test',
        authToken: 'token',
        initial: _bundle(),
        locale: pdpBaseLocale,
        draft: const PdpLocalizedTextDraft(
          product: PdpLocalizedProductText(
            name: 'Gapy Style Deluxe',
            summary: 'Résumé FR',
            description: 'Description enrichie',
          ),
          chapters: [
            PdpLocalizedChapterText(
              chapterId: 'chapter-1',
              headline: 'Chapitre été',
              story: 'Story FR',
              ctaLabel: 'Voir',
            ),
          ],
        ),
      );

      expect(result, isA<SavePdpLocalizedTextSaved>());
      expect(repo.updatedCollections, ['products', 'narrativeChapters']);
      expect(repo.updatedRecordIds, ['prod-1', 'chapter-1']);
      expect(repo.updatedData.first['name'], 'Gapy Style Deluxe');
      expect(repo.updatedData.first['description'], 'Description enrichie');
      expect(
        repo.updatedData.first['searchIndex'],
        contains('gapy style deluxe'),
      );
      expect(repo.updatedData.last['headline'], 'Chapitre été');
    });

    test('creates EN product and chapter translations when missing', () async {
      final repo = _RecordingAdminBackofficeRepository();
      final useCase = SavePdpLocalizedText(repo);

      final result = await useCase(
        baseUrl: 'http://pb.test',
        authToken: 'token',
        initial: _bundle(),
        locale: pdpTranslationLocale,
        draft: const PdpLocalizedTextDraft(
          product: PdpLocalizedProductText(
            name: 'Gapy Style',
            summary: 'Summer-ready shirt',
            description: 'English description',
          ),
          chapters: [
            PdpLocalizedChapterText(
              chapterId: 'chapter-1',
              headline: 'Summer chapter',
              story: 'Story EN',
              ctaLabel: 'View',
            ),
          ],
        ),
      );

      expect(result, isA<SavePdpLocalizedTextSaved>());
      expect(repo.createdCollections, [
        'product_translations',
        'narrative_chapter_translations',
      ]);
      expect(repo.createdData.first, containsPair('product', 'prod-1'));
      expect(repo.createdData.first, containsPair('locale', 'en'));
      expect(repo.createdData.first, containsPair('name', 'Gapy Style'));
      expect(repo.createdData.last, containsPair('chapter', 'chapter-1'));
      expect(repo.createdData.last, containsPair('headline', 'Summer chapter'));
    });

    test(
      'updates product translation and deletes blank chapter translation',
      () async {
        final repo = _RecordingAdminBackofficeRepository();
        final useCase = SavePdpLocalizedText(repo);

        final result = await useCase(
          baseUrl: 'http://pb.test',
          authToken: 'token',
          initial: _bundle(
            productTranslationRecordId: 'ptr-1',
            chapterTranslationRecordId: 'ntr-1',
            translatedProduct: const PdpLocalizedProductText(
              name: 'Gapy',
              summary: 'Old EN',
              description: 'Old description',
            ),
            translatedChapter: const PdpLocalizedChapterText(
              chapterId: 'chapter-1',
              headline: 'Old chapter',
              story: 'Old story',
              ctaLabel: 'Old',
            ),
          ),
          locale: pdpTranslationLocale,
          draft: const PdpLocalizedTextDraft(
            product: PdpLocalizedProductText(
              name: 'Gapy',
              summary: 'New EN',
              description: 'Old description',
            ),
            chapters: [
              PdpLocalizedChapterText(chapterId: 'chapter-1', headline: ''),
            ],
          ),
        );

        expect(result, isA<SavePdpLocalizedTextSaved>());
        expect(repo.updatedCollections, ['product_translations']);
        expect(repo.updatedRecordIds, ['ptr-1']);
        expect(repo.updatedData.single, {'summary': 'New EN'});
        expect(repo.deletedCollections, ['narrative_chapter_translations']);
        expect(repo.deletedRecordIds, ['ntr-1']);
      },
    );

    test('rejects EN translation with summary but no product name', () async {
      final repo = _RecordingAdminBackofficeRepository();
      final useCase = SavePdpLocalizedText(repo);

      final result = await useCase(
        baseUrl: 'http://pb.test',
        authToken: 'token',
        initial: _bundle(),
        locale: pdpTranslationLocale,
        draft: const PdpLocalizedTextDraft(
          product: PdpLocalizedProductText(
            name: '',
            summary: 'Summary without name',
          ),
        ),
      );

      expect(result, isA<SavePdpLocalizedTextValidationFailure>());
      expect(repo.createdCollections, isEmpty);
      expect(repo.updatedCollections, isEmpty);
      expect(repo.deletedCollections, isEmpty);
    });

    test('rejects invalid FR chapter before mutating product', () async {
      final repo = _RecordingAdminBackofficeRepository();
      final useCase = SavePdpLocalizedText(repo);

      final result = await useCase(
        baseUrl: 'http://pb.test',
        authToken: 'token',
        initial: _bundle(),
        locale: pdpBaseLocale,
        draft: const PdpLocalizedTextDraft(
          product: PdpLocalizedProductText(
            name: 'Gapy Style Deluxe',
            summary: 'Résumé FR',
            description: 'Description FR',
          ),
          chapters: [
            PdpLocalizedChapterText(
              chapterId: 'chapter-1',
              headline: '',
              story: 'Story FR changée',
            ),
          ],
        ),
      );

      expect(result, isA<SavePdpLocalizedTextValidationFailure>());
      expect(repo.createdCollections, isEmpty);
      expect(repo.updatedCollections, isEmpty);
      expect(repo.deletedCollections, isEmpty);
    });

    test(
      'rejects invalid EN chapter before mutating product translation',
      () async {
        final repo = _RecordingAdminBackofficeRepository();
        final useCase = SavePdpLocalizedText(repo);

        final result = await useCase(
          baseUrl: 'http://pb.test',
          authToken: 'token',
          initial: _bundle(),
          locale: pdpTranslationLocale,
          draft: const PdpLocalizedTextDraft(
            product: PdpLocalizedProductText(
              name: 'Gapy Style',
              summary: 'English summary',
            ),
            chapters: [
              PdpLocalizedChapterText(
                chapterId: 'chapter-1',
                headline: '',
                story: 'Translated story without title',
              ),
            ],
          ),
        );

        expect(result, isA<SavePdpLocalizedTextValidationFailure>());
        expect(repo.createdCollections, isEmpty);
        expect(repo.updatedCollections, isEmpty);
        expect(repo.deletedCollections, isEmpty);
      },
    );
  });

  group('translation invalidations', () {
    test('product_translations invalidate the translated product surfaces', () {
      final targets = invalidationsForAdminSave(
        collection: 'product_translations',
        data: const {'product': 'prod-1'},
        recordId: 'ptr-1',
      );

      expect(targets, contains(const ProductDetailInvalidation('prod-1')));
      expect(targets, contains(const AllProductListsInvalidation()));
      expect(targets, contains(const AllSearchResultsInvalidation()));
      expect(targets, contains(const AllProductRoutesInvalidation()));
    });

    test(
      'chapter translations without a product relation invalidate all PDPs',
      () {
        // The realtime payload relates to `chapter`, never `product`, and its
        // `id` is the translation row — using it as a product id would target a
        // bogus key and leave the real PDP cache stale.
        final targets = invalidationsForAdminSave(
          collection: 'narrative_chapter_translations',
          data: const {'chapter': 'chapter-1', 'locale': 'en'},
          recordId: 'nctr-1',
        );

        expect(targets, contains(const AllProductDetailsInvalidation()));
        expect(
          targets,
          isNot(contains(const ProductDetailInvalidation('nctr-1'))),
        );
      },
    );

    test('chapter translations honour an explicit product relation', () {
      final targets = invalidationsForAdminSave(
        collection: 'narrative_chapter_translations',
        data: const {'chapter': 'chapter-1', 'product': 'prod-1'},
        recordId: 'nctr-1',
      );

      expect(targets, contains(const ProductDetailInvalidation('prod-1')));
    });
  });
}

PdpLocalizedTextBundle _bundle({
  String? productTranslationRecordId,
  String? chapterTranslationRecordId,
  PdpLocalizedProductText translatedProduct = const PdpLocalizedProductText(
    name: '',
  ),
  PdpLocalizedChapterText translatedChapter = const PdpLocalizedChapterText(
    chapterId: 'chapter-1',
    headline: '',
  ),
}) {
  return PdpLocalizedTextBundle(
    productId: 'prod-1',
    baseProductRecord: const {
      'id': 'prod-1',
      'code': 'GAPY-STYLE',
      'name': 'Gapy Style',
      'slug': 'gapy-style',
      'summary': 'Résumé FR',
      'description': 'Description FR',
    },
    baseProduct: const PdpLocalizedProductText(
      name: 'Gapy Style',
      summary: 'Résumé FR',
      description: 'Description FR',
    ),
    productTranslationRecordId: productTranslationRecordId,
    translationProduct: translatedProduct,
    chapters: [
      PdpLocalizedChapterBundle(
        id: 'chapter-1',
        position: 0,
        base: const PdpLocalizedChapterText(
          chapterId: 'chapter-1',
          headline: 'Chapitre',
          story: 'Story FR',
          ctaLabel: 'Voir',
        ),
        translationRecordId: chapterTranslationRecordId,
        translation: translatedChapter,
      ),
    ],
  );
}

class _RecordingAdminBackofficeRepository implements AdminBackofficeRepository {
  final createdCollections = <String>[];
  final updatedCollections = <String>[];
  final deletedCollections = <String>[];
  final createdData = <Map<String, dynamic>>[];
  final updatedData = <Map<String, dynamic>>[];
  final updatedRecordIds = <String>[];
  final deletedRecordIds = <String>[];

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
  }) async => const [];

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
    updatedRecordIds.add(recordId);
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
