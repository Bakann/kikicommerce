import '../../core/utils/pocketbase_filter_utils.dart';
import '../../core/utils/search_index_utils.dart';
import '../admin/admin_backoffice_repository.dart';

const String pdpBaseLocale = 'fr';
const String pdpTranslationLocale = 'en';

class PdpLocalizedProductText {
  final String name;
  final String summary;
  final String description;

  const PdpLocalizedProductText({
    required this.name,
    this.summary = '',
    this.description = '',
  });

  bool get isBlank =>
      name.trim().isEmpty &&
      summary.trim().isEmpty &&
      description.trim().isEmpty;

  Map<String, dynamic> toProductPayload() {
    return {
      'name': name.trim(),
      'summary': summary.trim(),
      'description': description.trim(),
    };
  }
}

class PdpLocalizedChapterText {
  final String chapterId;
  final String headline;
  final String story;
  final String ctaLabel;

  const PdpLocalizedChapterText({
    required this.chapterId,
    required this.headline,
    this.story = '',
    this.ctaLabel = '',
  });

  bool get isBlank =>
      headline.trim().isEmpty &&
      story.trim().isEmpty &&
      ctaLabel.trim().isEmpty;

  Map<String, dynamic> toChapterPayload() {
    return {
      'headline': headline.trim(),
      'story': story.trim(),
      'ctaLabel': ctaLabel.trim(),
    };
  }
}

class PdpLocalizedChapterBundle {
  final String id;
  final int position;
  final PdpLocalizedChapterText base;
  final String? translationRecordId;
  final PdpLocalizedChapterText translation;

  const PdpLocalizedChapterBundle({
    required this.id,
    required this.position,
    required this.base,
    required this.translation,
    this.translationRecordId,
  });

  bool get hasTranslation => translationRecordId != null;
}

class PdpLocalizedTextBundle {
  final String productId;
  final Map<String, dynamic> baseProductRecord;
  final PdpLocalizedProductText baseProduct;
  final String? productTranslationRecordId;
  final PdpLocalizedProductText translationProduct;
  final List<PdpLocalizedChapterBundle> chapters;

  const PdpLocalizedTextBundle({
    required this.productId,
    required this.baseProductRecord,
    required this.baseProduct,
    required this.translationProduct,
    required this.chapters,
    this.productTranslationRecordId,
  });

  bool get hasProductTranslation => productTranslationRecordId != null;

  bool get hasAnyTranslation =>
      hasProductTranslation ||
      chapters.any((chapter) => chapter.hasTranslation);
}

class PdpLocalizedTextDraft {
  final PdpLocalizedProductText product;
  final List<PdpLocalizedChapterText> chapters;

  const PdpLocalizedTextDraft({
    required this.product,
    this.chapters = const [],
  });
}

sealed class SavePdpLocalizedTextResult {
  const SavePdpLocalizedTextResult();
}

class SavePdpLocalizedTextNoChange extends SavePdpLocalizedTextResult {
  const SavePdpLocalizedTextNoChange();
}

class SavePdpLocalizedTextSaved extends SavePdpLocalizedTextResult {
  const SavePdpLocalizedTextSaved();
}

class SavePdpLocalizedTextValidationFailure extends SavePdpLocalizedTextResult {
  final String message;

  const SavePdpLocalizedTextValidationFailure(this.message);
}

class SavePdpLocalizedTextFailure extends SavePdpLocalizedTextResult {
  final Object error;

  const SavePdpLocalizedTextFailure(this.error);
}

class LoadPdpLocalizedText {
  final AdminBackofficeRepository repository;

  const LoadPdpLocalizedText(this.repository);

  Future<PdpLocalizedTextBundle> call({
    required String baseUrl,
    required String authToken,
    required String productId,
    String locale = pdpTranslationLocale,
  }) async {
    final escapedProductId = escapeFilterValue(productId);
    final productRows = await repository.listRecords(
      baseUrl: baseUrl,
      authToken: authToken,
      collection: 'products',
      filter: 'id="$escapedProductId"',
      page: 1,
      perPage: 1,
    );
    if (productRows.isEmpty) {
      throw StateError('Produit introuvable: $productId');
    }

    final productRow = Map<String, dynamic>.from(productRows.first);
    final productTranslationRows = await repository.listRecords(
      baseUrl: baseUrl,
      authToken: authToken,
      collection: 'product_translations',
      filter:
          'product="$escapedProductId" && locale="${escapeFilterValue(locale)}"',
      page: 1,
      perPage: 1,
    );

    final chapterRows = await repository.listRecords(
      baseUrl: baseUrl,
      authToken: authToken,
      collection: 'narrativeChapters',
      filter: 'product="$escapedProductId" && isActive=true',
      sort: 'position',
      page: 1,
      perPage: 200,
    );

    final chapterTranslationRows = chapterRows.isEmpty
        ? const <Map<String, dynamic>>[]
        : await repository.listRecords(
            baseUrl: baseUrl,
            authToken: authToken,
            collection: 'narrative_chapter_translations',
            filter:
                '(${chapterRows.map((row) => 'chapter="${escapeFilterValue(_id(row))}"').join(' || ')})'
                ' && locale="${escapeFilterValue(locale)}"',
            page: 1,
            perPage: chapterRows.length,
          );
    final chapterTranslationByChapterId = {
      for (final row in chapterTranslationRows)
        _relationId(row['chapter']): row,
    };

    final productTranslation = productTranslationRows.isEmpty
        ? null
        : productTranslationRows.first;
    return PdpLocalizedTextBundle(
      productId: productId,
      baseProductRecord: productRow,
      baseProduct: _productTextFromProduct(productRow),
      productTranslationRecordId: productTranslation == null
          ? null
          : _id(productTranslation),
      translationProduct: productTranslation == null
          ? const PdpLocalizedProductText(name: '')
          : _productTextFromTranslation(productTranslation),
      chapters: [
        for (final row in chapterRows)
          _chapterBundle(row, chapterTranslationByChapterId[_id(row)]),
      ],
    );
  }
}

class SavePdpLocalizedText {
  final AdminBackofficeRepository repository;

  const SavePdpLocalizedText(this.repository);

  Future<SavePdpLocalizedTextResult> call({
    required String baseUrl,
    required String authToken,
    required PdpLocalizedTextBundle initial,
    required String locale,
    required PdpLocalizedTextDraft draft,
  }) async {
    try {
      if (locale == pdpBaseLocale) {
        return await _saveBase(
          baseUrl: baseUrl,
          authToken: authToken,
          initial: initial,
          draft: draft,
        );
      }
      return await _saveTranslation(
        baseUrl: baseUrl,
        authToken: authToken,
        initial: initial,
        draft: draft,
        locale: locale,
      );
    } catch (error) {
      return SavePdpLocalizedTextFailure(error);
    }
  }

  Future<SavePdpLocalizedTextResult> _saveBase({
    required String baseUrl,
    required String authToken,
    required PdpLocalizedTextBundle initial,
    required PdpLocalizedTextDraft draft,
  }) async {
    if (draft.product.name.trim().isEmpty) {
      return const SavePdpLocalizedTextValidationFailure(
        'Le nom du produit FR est requis.',
      );
    }

    final initialChapters = {for (final c in initial.chapters) c.id: c};
    for (final chapterDraft in draft.chapters) {
      if (!initialChapters.containsKey(chapterDraft.chapterId)) continue;
      if (chapterDraft.headline.trim().isEmpty) {
        return const SavePdpLocalizedTextValidationFailure(
          'Chaque chapitre FR doit conserver un titre.',
        );
      }
    }

    var changed = false;
    final productUpdates = _changedProductPayload(
      initial.baseProduct,
      draft.product,
    );
    if (productUpdates.isNotEmpty) {
      final mergedProduct = {...initial.baseProductRecord, ...productUpdates};
      productUpdates['searchIndex'] = buildProductSearchIndex(mergedProduct);
      await repository.updateRecord(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: 'products',
        recordId: initial.productId,
        data: productUpdates,
      );
      changed = true;
    }

    for (final chapterDraft in draft.chapters) {
      final initialChapter = initialChapters[chapterDraft.chapterId];
      if (initialChapter == null) continue;
      final updates = _changedChapterPayload(initialChapter.base, chapterDraft);
      if (updates.isEmpty) continue;
      await repository.updateRecord(
        baseUrl: baseUrl,
        authToken: authToken,
        collection: 'narrativeChapters',
        recordId: chapterDraft.chapterId,
        data: updates,
      );
      changed = true;
    }

    return changed
        ? const SavePdpLocalizedTextSaved()
        : const SavePdpLocalizedTextNoChange();
  }

  Future<SavePdpLocalizedTextResult> _saveTranslation({
    required String baseUrl,
    required String authToken,
    required PdpLocalizedTextBundle initial,
    required PdpLocalizedTextDraft draft,
    required String locale,
  }) async {
    final initialChapters = {for (final c in initial.chapters) c.id: c};
    final productDraft = draft.product;
    if (!productDraft.isBlank && productDraft.name.trim().isEmpty) {
      return const SavePdpLocalizedTextValidationFailure(
        'Le nom du produit EN est requis quand une traduction existe.',
      );
    }
    for (final chapterDraft in draft.chapters) {
      if (!initialChapters.containsKey(chapterDraft.chapterId)) continue;
      if (!chapterDraft.isBlank && chapterDraft.headline.trim().isEmpty) {
        return const SavePdpLocalizedTextValidationFailure(
          'Chaque chapitre EN traduit doit avoir un titre.',
        );
      }
    }

    var changed = false;
    if (productDraft.isBlank) {
      final recordId = initial.productTranslationRecordId;
      if (recordId != null) {
        await repository.deleteRecord(
          baseUrl: baseUrl,
          authToken: authToken,
          collection: 'product_translations',
          recordId: recordId,
        );
        changed = true;
      }
    } else {
      final payload = productDraft.toProductPayload()
        ..addAll({'product': initial.productId, 'locale': locale});
      final recordId = initial.productTranslationRecordId;
      if (recordId == null) {
        await repository.createRecord(
          baseUrl: baseUrl,
          authToken: authToken,
          collection: 'product_translations',
          data: payload,
        );
        changed = true;
      } else {
        final updates = _changedProductPayload(
          initial.translationProduct,
          productDraft,
        );
        if (updates.isNotEmpty) {
          await repository.updateRecord(
            baseUrl: baseUrl,
            authToken: authToken,
            collection: 'product_translations',
            recordId: recordId,
            data: updates,
          );
          changed = true;
        }
      }
    }

    for (final chapterDraft in draft.chapters) {
      final initialChapter = initialChapters[chapterDraft.chapterId];
      if (initialChapter == null) continue;
      final recordId = initialChapter.translationRecordId;
      if (chapterDraft.isBlank) {
        if (recordId != null) {
          await repository.deleteRecord(
            baseUrl: baseUrl,
            authToken: authToken,
            collection: 'narrative_chapter_translations',
            recordId: recordId,
          );
          changed = true;
        }
        continue;
      }
      final payload = chapterDraft.toChapterPayload()
        ..addAll({'chapter': chapterDraft.chapterId, 'locale': locale});
      if (recordId == null) {
        await repository.createRecord(
          baseUrl: baseUrl,
          authToken: authToken,
          collection: 'narrative_chapter_translations',
          data: payload,
        );
        changed = true;
      } else {
        final updates = _changedChapterPayload(
          initialChapter.translation,
          chapterDraft,
        );
        if (updates.isNotEmpty) {
          await repository.updateRecord(
            baseUrl: baseUrl,
            authToken: authToken,
            collection: 'narrative_chapter_translations',
            recordId: recordId,
            data: updates,
          );
          changed = true;
        }
      }
    }

    return changed
        ? const SavePdpLocalizedTextSaved()
        : const SavePdpLocalizedTextNoChange();
  }
}

PdpLocalizedProductText _productTextFromProduct(Map<String, dynamic> row) {
  return PdpLocalizedProductText(
    name: _string(row['name']),
    summary: _string(row['summary']),
    description: _string(row['description']),
  );
}

PdpLocalizedProductText _productTextFromTranslation(Map<String, dynamic> row) {
  return PdpLocalizedProductText(
    name: _string(row['name']),
    summary: _string(row['summary']),
    description: _string(row['description']),
  );
}

PdpLocalizedChapterBundle _chapterBundle(
  Map<String, dynamic> chapter,
  Map<String, dynamic>? translation,
) {
  final id = _id(chapter);
  return PdpLocalizedChapterBundle(
    id: id,
    position: (chapter['position'] as num?)?.toInt() ?? 0,
    base: PdpLocalizedChapterText(
      chapterId: id,
      headline: _string(chapter['headline']),
      story: _string(chapter['story']),
      ctaLabel: _string(chapter['ctaLabel']),
    ),
    translationRecordId: translation == null ? null : _id(translation),
    translation: translation == null
        ? PdpLocalizedChapterText(chapterId: id, headline: '')
        : PdpLocalizedChapterText(
            chapterId: id,
            headline: _string(translation['headline']),
            story: _string(translation['story']),
            ctaLabel: _string(translation['ctaLabel']),
          ),
  );
}

Map<String, dynamic> _changedProductPayload(
  PdpLocalizedProductText before,
  PdpLocalizedProductText after,
) {
  return {
    if (after.name.trim() != before.name.trim()) 'name': after.name.trim(),
    if (after.summary.trim() != before.summary.trim())
      'summary': after.summary.trim(),
    if (after.description.trim() != before.description.trim())
      'description': after.description.trim(),
  };
}

Map<String, dynamic> _changedChapterPayload(
  PdpLocalizedChapterText before,
  PdpLocalizedChapterText after,
) {
  return {
    if (after.headline.trim() != before.headline.trim())
      'headline': after.headline.trim(),
    if (after.story.trim() != before.story.trim()) 'story': after.story.trim(),
    if (after.ctaLabel.trim() != before.ctaLabel.trim())
      'ctaLabel': after.ctaLabel.trim(),
  };
}

String _id(Map<String, dynamic> row) => _string(row['id']);

String _string(Object? value) => value is String ? value : '';

String _relationId(Object? value) {
  if (value is String) return value;
  if (value is List && value.isNotEmpty) return value.first?.toString() ?? '';
  return '';
}
