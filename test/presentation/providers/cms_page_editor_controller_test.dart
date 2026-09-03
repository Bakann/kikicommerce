import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/cms/cms_page_editor_repository.dart';
import 'package:kiki_commerce/application/cms/cms_page_repository.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/cms_page_editor_controller.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';

class _RecordingRepo implements CmsPageEditorRepository {
  final List<Map<String, dynamic>> calls = [];
  final Completer<void>? updateBlocker;

  _RecordingRepo({this.updateBlocker});

  @override
  Future<String> createPlpPage({
    required String authToken,
    required String code,
    required String locale,
    required String title,
    required String sourceCategoryId,
    String? seoTitle,
    String? seoDescription,
  }) async {
    calls.add({
      'op': 'createPage',
      'authToken': authToken,
      'code': code,
      'locale': locale,
      'title': title,
      'sourceCategoryId': sourceCategoryId,
      'seoTitle': seoTitle,
      'seoDescription': seoDescription,
    });
    return 'page-plp-1';
  }

  @override
  Future<void> createSection({
    required String authToken,
    required String pageId,
    required String sectionId,
    required String sectionType,
    required int position,
    required bool isActive,
    required Map<String, dynamic> config,
  }) async {
    calls.add({
      'op': 'create',
      'authToken': authToken,
      'pageId': pageId,
      'sectionId': sectionId,
      'sectionType': sectionType,
      'position': position,
      'isActive': isActive,
      'config': config,
    });
  }

  @override
  Future<void> updateSection({
    required String authToken,
    required String sectionRecordId,
    required Map<String, dynamic> patch,
  }) async {
    calls.add({
      'op': 'update',
      'authToken': authToken,
      'sectionRecordId': sectionRecordId,
      'patch': patch,
    });
    await updateBlocker?.future;
  }

  @override
  Future<void> deleteSection({
    required String authToken,
    required String sectionRecordId,
  }) async {
    calls.add({
      'op': 'delete',
      'authToken': authToken,
      'sectionRecordId': sectionRecordId,
    });
  }
}

class _CmsReadRepo implements CmsPageRepository {
  final CmsPageBundle? plp;
  final Object? plpFailure;

  const _CmsReadRepo({this.plp, this.plpFailure});

  @override
  Future<CmsPageLoadResult> fetchPage({
    required String code,
    required String locale,
  }) async {
    return const CmsPageMissing();
  }

  @override
  Future<CmsPageLoadResult> fetchPlpForCategory({
    required String categoryId,
    required String locale,
  }) async {
    final failure = plpFailure;
    if (failure != null) {
      return CmsPageFailure(failure, StackTrace.current);
    }
    final bundle = plp;
    if (bundle == null) return const CmsPageMissing();
    return CmsPageFound(bundle);
  }
}

CmsSectionConfig _cmsSection({
  required String id,
  required int position,
  CmsSectionType type = CmsSectionType.horizontalTileCarousel,
}) {
  return parseCmsSection(
    CmsSectionRecord(
      id: id,
      pageId: 'page1',
      sectionId: id,
      sectionType: type,
      rawSectionType: type.wireName,
      position: position,
      isActive: true,
      config: const {},
    ),
  );
}

ProviderContainer _makeContainer({
  required _RecordingRepo repo,
  String? token,
  CmsPageRepository cmsReadRepo = const _CmsReadRepo(),
}) {
  return ProviderContainer(
    overrides: [
      cmsPageEditorRepositoryProvider.overrideWithValue(repo),
      cmsPageRepositoryProvider.overrideWithValue(cmsReadRepo),
      adminAuthTokenProvider.overrideWith((ref) => token),
    ],
  );
}

void main() {
  test(
    'createSection forwards every field and uses the active token',
    () async {
      final repo = _RecordingRepo();
      final container = _makeContainer(repo: repo, token: 'tok-1');
      addTearDown(container.dispose);

      await container
          .read(cmsPageEditorControllerProvider.notifier)
          .createSection(
            pageId: 'p1',
            sectionId: 'hero-1',
            type: CmsSectionType.heroCampaign,
            position: 0,
            config: {'title': 'X'},
          );

      expect(repo.calls, hasLength(1));
      final call = repo.calls.single;
      expect(call['op'], 'create');
      expect(call['authToken'], 'tok-1');
      expect(call['pageId'], 'p1');
      expect(call['sectionId'], 'hero-1');
      expect(call['sectionType'], 'hero_campaign');
      expect(call['position'], 0);
      expect(call['isActive'], true);
      expect(call['config'], {'title': 'X'});
    },
  );

  test('updateSectionConfig sends a config-only patch', () async {
    final repo = _RecordingRepo();
    final container = _makeContainer(repo: repo, token: 'tok-1');
    addTearDown(container.dispose);

    await container
        .read(cmsPageEditorControllerProvider.notifier)
        .updateSectionConfig(
          sectionRecordId: 'rec1',
          config: {'title': 'Updated'},
        );

    final call = repo.calls.single;
    expect(call['op'], 'update');
    expect(call['sectionRecordId'], 'rec1');
    expect(call['patch'], {
      'config': {'title': 'Updated'},
    });
  });

  test('renameSection sends a sectionId-only patch', () async {
    final repo = _RecordingRepo();
    final container = _makeContainer(repo: repo, token: 'tok-1');
    addTearDown(container.dispose);

    await container
        .read(cmsPageEditorControllerProvider.notifier)
        .renameSection(sectionRecordId: 'rec1', sectionId: 'hero-main');

    final call = repo.calls.single;
    expect(call['op'], 'update');
    expect(call['sectionRecordId'], 'rec1');
    expect(call['patch'], {'sectionId': 'hero-main'});
  });

  test('duplicateSection creates a copied section payload', () async {
    final repo = _RecordingRepo();
    final container = _makeContainer(repo: repo, token: 'tok-1');
    addTearDown(container.dispose);

    final config = {
      'title': 'Services',
      'cards': [
        {'title': 'Livraison', 'href': '/shipping'},
      ],
    };
    final section = CmsSectionRecord(
      id: 'rec1',
      pageId: 'page1',
      sectionId: 'services',
      sectionType: CmsSectionType.serviceCards,
      rawSectionType: 'service_cards',
      position: 2,
      isActive: false,
      config: config,
    );

    await container
        .read(cmsPageEditorControllerProvider.notifier)
        .duplicateSection(
          section: section,
          sectionId: 'services-copy',
          position: 9,
        );

    final call = repo.calls.single;
    expect(call['op'], 'create');
    expect(call['pageId'], 'page1');
    expect(call['sectionId'], 'services-copy');
    expect(call['sectionType'], 'service_cards');
    expect(call['position'], 9);
    expect(call['isActive'], false);
    expect(call['config'], config);
    expect(identical(call['config'], config), isFalse);
  });

  test(
    'setSectionActive and setSectionPosition send single-field patches',
    () async {
      final repo = _RecordingRepo();
      final container = _makeContainer(repo: repo, token: 'tok-1');
      addTearDown(container.dispose);

      final controller = container.read(
        cmsPageEditorControllerProvider.notifier,
      );
      await controller.setSectionActive(sectionRecordId: 'r', isActive: false);
      await controller.setSectionPosition(sectionRecordId: 'r', position: 7);

      expect(repo.calls.length, 2);
      expect(repo.calls[0]['patch'], {'isActive': false});
      expect(repo.calls[1]['patch'], {'position': 7});
    },
  );

  test(
    'moveSection normalizes positions so duplicate positions can move',
    () async {
      final repo = _RecordingRepo();
      final container = _makeContainer(repo: repo, token: 'tok-1');
      addTearDown(container.dispose);

      await container
          .read(cmsPageEditorControllerProvider.notifier)
          .moveSection(
            sections: [
              _cmsSection(id: 'brand', position: 0),
              _cmsSection(id: 'moment', position: 1),
              _cmsSection(id: 'tabs', position: 1),
              _cmsSection(id: 'banners', position: 2),
              _cmsSection(id: 'releases', position: 4),
            ],
            sectionRecordId: 'tabs',
            targetIndex: 1,
          );

      expect(repo.calls, hasLength(2));
      expect(repo.calls[0]['op'], 'update');
      expect(repo.calls[0]['sectionRecordId'], 'moment');
      expect(repo.calls[0]['patch'], {'position': 2});
      expect(repo.calls[1]['op'], 'update');
      expect(repo.calls[1]['sectionRecordId'], 'banners');
      expect(repo.calls[1]['patch'], {'position': 3});
    },
  );

  test('rejects concurrent CMS mutations while one is pending', () async {
    final blocker = Completer<void>();
    final repo = _RecordingRepo(updateBlocker: blocker);
    final container = _makeContainer(repo: repo, token: 'tok-1');
    addTearDown(container.dispose);

    final controller = container.read(cmsPageEditorControllerProvider.notifier);
    final firstMutation = controller.setSectionActive(
      sectionRecordId: 'rec1',
      isActive: false,
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(cmsPageEditorControllerProvider).isLoading, isTrue);
    expect(repo.calls, hasLength(1));

    await expectLater(
      controller.renameSection(sectionRecordId: 'rec2', sectionId: 'next'),
      throwsA(isA<CmsMutationInProgressException>()),
    );
    expect(repo.calls, hasLength(1));

    blocker.complete();
    await firstMutation;

    expect(container.read(cmsPageEditorControllerProvider).isLoading, isFalse);
  });

  test('deleteSection forwards the record id and token', () async {
    final repo = _RecordingRepo();
    final container = _makeContainer(repo: repo, token: 'tok-1');
    addTearDown(container.dispose);

    await container
        .read(cmsPageEditorControllerProvider.notifier)
        .deleteSection(sectionRecordId: 'rec1');

    final call = repo.calls.single;
    expect(call['op'], 'delete');
    expect(call['sectionRecordId'], 'rec1');
    expect(call['authToken'], 'tok-1');
  });

  test('throws CmsAuthRequiredException when no token is available', () async {
    final repo = _RecordingRepo();
    final container = _makeContainer(repo: repo, token: null);
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(cmsPageEditorControllerProvider.notifier)
          .deleteSection(sectionRecordId: 'rec'),
      throwsA(isA<CmsAuthRequiredException>()),
    );
    expect(repo.calls, isEmpty);
  });

  test('bootstrapPlpForCategory creates a page and default sections', () async {
    final repo = _RecordingRepo();
    final container = _makeContainer(repo: repo, token: 'tok-1');
    addTearDown(container.dispose);

    await container
        .read(cmsPageEditorControllerProvider.notifier)
        .bootstrapPlpForCategory(
          const CatalogCategory(
            id: 'cat1',
            code: 'GIFTS_WOMEN',
            name: 'Cadeaux femme',
            slug: 'cadeaux-femme',
            description: 'Sélection cadeaux',
          ),
        );

    expect(repo.calls, hasLength(6));
    expect(repo.calls.first['op'], 'createPage');
    expect(repo.calls.first['code'], 'plp_cadeaux_femme');
    expect(repo.calls.first['sourceCategoryId'], 'cat1');
    final sectionTypes = repo.calls.skip(1).map((call) => call['sectionType']);
    expect(sectionTypes, [
      'hero_campaign',
      'mixed_product_grid',
      'seo_text',
      'service_cards',
      'discover_links',
    ]);
    expect(repo.calls[1]['isActive'], isTrue);
    expect(repo.calls[2]['isActive'], isTrue);
    expect(repo.calls[3]['isActive'], isFalse);
    // The PLP hero is a full-bleed 1:1 image hero (image-first by default).
    final heroConfig = repo.calls[1]['config'] as Map<String, dynamic>;
    expect(heroConfig['heightMode'], 'square');
    expect(heroConfig['title'], '');
    expect(heroConfig['primaryCta'], isNull);
  });

  test(
    'bootstrapPlpForCategory does not create duplicates when PLP exists',
    () async {
      final repo = _RecordingRepo();
      final existing = CmsPageBundle(
        page: const CmsPageRecord(
          id: 'existing-page',
          code: 'plp_existing',
          locale: 'fr',
          title: 'Existing',
          isActive: true,
          pageType: CmsPageType.plp,
          sourceCategoryId: 'cat1',
        ),
        sections: const [],
      );
      final container = _makeContainer(
        repo: repo,
        token: 'tok-1',
        cmsReadRepo: _CmsReadRepo(plp: existing),
      );
      addTearDown(container.dispose);

      final pageId = await container
          .read(cmsPageEditorControllerProvider.notifier)
          .bootstrapPlpForCategory(
            const CatalogCategory(id: 'cat1', code: 'CAT1', name: 'Existing'),
          );

      expect(pageId, 'existing-page');
      expect(repo.calls, isEmpty);
    },
  );

  test('bootstrapPlpForCategory surfaces CMS read failures', () async {
    final repo = _RecordingRepo();
    final failure = StateError('cms read failed');
    final container = _makeContainer(
      repo: repo,
      token: 'tok-1',
      cmsReadRepo: _CmsReadRepo(plpFailure: failure),
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(cmsPageEditorControllerProvider.notifier)
          .bootstrapPlpForCategory(
            const CatalogCategory(id: 'cat1', code: 'CAT1', name: 'Existing'),
          ),
      throwsA(same(failure)),
    );

    expect(repo.calls, isEmpty);
    expect(
      container.read(cmsPageEditorControllerProvider).error,
      same(failure),
    );
  });
}
