import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../application/catalog/catalog_invalidations.dart';
import '../../application/cms/cms_models.dart';
import '../../application/cms/cms_page_repository.dart';
import '../../core/utils/slug_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../widgets/cms/cms_section_defaults.dart';
import 'catalog_invalidator_provider.dart';
import 'cms_page_provider.dart';
import 'edit_mode_provider.dart';

class CmsAuthRequiredException implements Exception {
  const CmsAuthRequiredException();

  @override
  String toString() =>
      'CmsAuthRequiredException: an admin auth token is required.';
}

class CmsMutationInProgressException implements Exception {
  const CmsMutationInProgressException();

  @override
  String toString() =>
      'CmsMutationInProgressException: a CMS mutation is already running.';
}

final cmsPageEditorControllerProvider =
    AsyncNotifierProvider<CmsPageEditorController, void>(
      CmsPageEditorController.new,
    );

class CmsPageEditorController extends AsyncNotifier<void> {
  bool _mutationInFlight = false;

  @override
  void build() {}

  String _requireToken() {
    final token = ref.read(adminAuthTokenProvider);
    if (token == null || token.isEmpty) {
      throw const CmsAuthRequiredException();
    }
    return token;
  }

  Future<String> bootstrapPlpForCategory(CatalogCategory category) async {
    return _runMutation((token) async {
      final existing = await ref
          .read(cmsPageRepositoryProvider)
          .fetchPlpForCategory(
            categoryId: category.id,
            locale: defaultCmsLocale,
          );
      switch (existing) {
        case CmsPageFound(:final bundle):
          return bundle.page.id;
        case CmsPageMissing():
          break;
        case CmsPageFailure(:final error, :final stackTrace):
          Error.throwWithStackTrace(error, stackTrace);
      }

      final pageId = await ref
          .read(cmsPageEditorRepositoryProvider)
          .createPlpPage(
            authToken: token,
            code: _plpCodeForCategory(category),
            locale: defaultCmsLocale,
            title: category.name,
            sourceCategoryId: category.id,
            seoTitle: category.name,
            seoDescription: category.description,
          );
      if (pageId.isEmpty) {
        throw StateError('PLP page created but id missing from response.');
      }

      final repository = ref.read(cmsPageEditorRepositoryProvider);
      for (final draft in _plpBootstrapSections) {
        final config = <String, dynamic>{
          ...defaultConfigFor(draft.type),
          ...?draft.configOverride,
        };
        await repository.createSection(
          authToken: token,
          pageId: pageId,
          sectionId: draft.sectionId,
          sectionType: draft.type.wireName,
          position: draft.position,
          isActive: draft.isActive,
          config: _cloneJsonMap(config),
        );
      }

      return pageId;
    });
  }

  Future<void> createSection({
    required String pageId,
    required String sectionId,
    required CmsSectionType type,
    required int position,
    required Map<String, dynamic> config,
    bool isActive = true,
  }) async {
    return _runMutation((token) async {
      await ref
          .read(cmsPageEditorRepositoryProvider)
          .createSection(
            authToken: token,
            pageId: pageId,
            sectionId: sectionId,
            sectionType: type.wireName,
            position: position,
            isActive: isActive,
            config: config,
          );
    });
  }

  Future<void> updateSectionConfig({
    required String sectionRecordId,
    required Map<String, dynamic> config,
  }) async {
    return _patch(sectionRecordId, {'config': config});
  }

  Future<void> renameSection({
    required String sectionRecordId,
    required String sectionId,
  }) async {
    return _patch(sectionRecordId, {'sectionId': sectionId});
  }

  Future<void> duplicateSection({
    required CmsSectionRecord section,
    required String sectionId,
    required int position,
  }) async {
    final type = section.sectionType;
    if (type == null) {
      throw StateError(
        'Cannot duplicate unknown CMS section type: ${section.rawSectionType}',
      );
    }
    return createSection(
      pageId: section.pageId,
      sectionId: sectionId,
      type: type,
      position: position,
      isActive: section.isActive,
      config: _cloneJsonMap(section.config),
    );
  }

  Future<void> setSectionActive({
    required String sectionRecordId,
    required bool isActive,
  }) async {
    return _patch(sectionRecordId, {'isActive': isActive});
  }

  Future<void> setSectionPosition({
    required String sectionRecordId,
    required int position,
  }) async {
    return _patch(sectionRecordId, {'position': position});
  }

  Future<void> moveSection({
    required List<CmsSectionConfig> sections,
    required String sectionRecordId,
    required int targetIndex,
  }) async {
    if (targetIndex < 0 || targetIndex >= sections.length) return;

    final currentIndex = sections.indexWhere(
      (section) => section.record.id == sectionRecordId,
    );
    if (currentIndex < 0 || currentIndex == targetIndex) return;

    final reordered = [...sections];
    final moved = reordered.removeAt(currentIndex);
    reordered.insert(targetIndex, moved);

    final updates = <_SectionPositionPatch>[];
    for (var index = 0; index < reordered.length; index++) {
      final record = reordered[index].record;
      if (record.position != index) {
        updates.add(
          _SectionPositionPatch(sectionRecordId: record.id, position: index),
        );
      }
    }
    if (updates.isEmpty) return;

    return _runMutation((token) async {
      final repository = ref.read(cmsPageEditorRepositoryProvider);
      await Future.wait<void>([
        for (final update in updates)
          repository.updateSection(
            authToken: token,
            sectionRecordId: update.sectionRecordId,
            patch: {'position': update.position},
          ),
      ]);
    });
  }

  Future<void> deleteSection({required String sectionRecordId}) async {
    return _runMutation((token) async {
      await ref
          .read(cmsPageEditorRepositoryProvider)
          .deleteSection(authToken: token, sectionRecordId: sectionRecordId);
    });
  }

  Future<void> _patch(
    String sectionRecordId,
    Map<String, dynamic> patch,
  ) async {
    return _runMutation((token) async {
      await ref
          .read(cmsPageEditorRepositoryProvider)
          .updateSection(
            authToken: token,
            sectionRecordId: sectionRecordId,
            patch: patch,
          );
    });
  }

  Future<T> _runMutation<T>(
    Future<T> Function(String authToken) mutation,
  ) async {
    if (_mutationInFlight) {
      throw const CmsMutationInProgressException();
    }
    _mutationInFlight = true;
    state = const AsyncValue.loading();
    try {
      final token = _requireToken();
      final result = await mutation(token);
      _invalidatePages();
      state = const AsyncValue.data(null);
      return result;
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
      rethrow;
    } finally {
      _mutationInFlight = false;
    }
  }

  void _invalidatePages() {
    // Route through the canonical invalidator so the `cms:` cache/dedup sweep
    // and the Riverpod provider invalidations stay in lock-step. Without the
    // cache sweep, edits would be masked by the SWR cache for the TTL window.
    ref.read(catalogInvalidatorProvider).apply(ref, const [
      CmsPagesInvalidation(),
    ]);
  }

  Map<String, dynamic> _cloneJsonMap(Map<String, dynamic> source) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);
  }

  String _plpCodeForCategory(CatalogCategory category) {
    final source = category.slug?.trim().isNotEmpty == true
        ? category.slug
        : (category.code.trim().isNotEmpty ? category.code : category.name);
    final slug = slugify(source, fallback: category.id).replaceAll('-', '_');
    final code = 'plp_$slug';
    return code.length <= 64 ? code : code.substring(0, 64);
  }
}

class _SectionPositionPatch {
  final String sectionRecordId;
  final int position;

  const _SectionPositionPatch({
    required this.sectionRecordId,
    required this.position,
  });
}

class _PlpBootstrapSectionDraft {
  final CmsSectionType type;
  final String sectionId;
  final int position;
  final bool isActive;

  /// Merged over [defaultConfigFor] when the section is created. Used to make
  /// the PLP hero a full-bleed 1:1 image hero by default.
  final Map<String, dynamic>? configOverride;

  const _PlpBootstrapSectionDraft({
    required this.type,
    required this.sectionId,
    required this.position,
    required this.isActive,
    this.configOverride,
  });
}

const List<_PlpBootstrapSectionDraft> _plpBootstrapSections = [
  _PlpBootstrapSectionDraft(
    type: CmsSectionType.heroCampaign,
    sectionId: 'hero',
    position: 0,
    isActive: true,
    // Full-bleed 1:1, image-first (no overlay copy) — the category PLP hero
    // the storefront flies the tapped tile into. The admin can add a title later.
    configOverride: {'heightMode': 'square', 'title': '', 'primaryCta': null},
  ),
  _PlpBootstrapSectionDraft(
    type: CmsSectionType.mixedProductGrid,
    sectionId: 'mixed-product-grid',
    position: 1,
    isActive: true,
  ),
  _PlpBootstrapSectionDraft(
    type: CmsSectionType.seoText,
    sectionId: 'seo-text',
    position: 2,
    isActive: false,
  ),
  _PlpBootstrapSectionDraft(
    type: CmsSectionType.serviceCards,
    sectionId: 'service-cards',
    position: 3,
    isActive: false,
  ),
  _PlpBootstrapSectionDraft(
    type: CmsSectionType.discoverLinks,
    sectionId: 'discover-links',
    position: 4,
    isActive: false,
  ),
];
