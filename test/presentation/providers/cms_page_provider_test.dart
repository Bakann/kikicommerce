import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_invalidations.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/cms/cms_page_repository.dart';
import 'package:kiki_commerce/application/storefront/storefront_sport_segment.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/presentation/providers/catalog_invalidator_provider.dart';
import 'package:kiki_commerce/presentation/providers/cms_page_provider.dart';
import 'package:kiki_commerce/presentation/providers/content_locale_provider.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';

void main() {
  test(
    'homepageCmsProvider waits for active theme before fetching CMS',
    () async {
      final activeTheme = Completer<StorefrontActiveTheme>();
      final cmsRepository = _FakeCmsPageRepository();
      final container = ProviderContainer(
        overrides: [
          activeStorefrontThemeProvider.overrideWith(
            (ref) => activeTheme.future,
          ),
          cmsPageRepositoryProvider.overrideWithValue(cmsRepository),
        ],
      );
      addTearDown(container.dispose);

      final future = container.read(homepageCmsProvider.future);
      await Future<void>.delayed(Duration.zero);

      expect(cmsRepository.pageRequests, isEmpty);

      activeTheme.complete(
        const StorefrontActiveTheme(theme: StorefrontTheme.nike),
      );
      await future;

      expect(cmsRepository.pageRequests, ['homepage_nike:fr']);
    },
  );

  test('homepageCmsProvider resolves Dior and Nike page codes', () async {
    final cmsRepository = _FakeCmsPageRepository();
    final container = ProviderContainer(
      overrides: [
        activeStorefrontThemeProvider.overrideWith(
          (ref) async =>
              const StorefrontActiveTheme(theme: StorefrontTheme.dior),
        ),
        cmsPageRepositoryProvider.overrideWithValue(cmsRepository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homepageCmsProvider.future);
    expect(cmsRepository.pageRequests, ['homepage:fr']);
  });

  test('homepageCmsProvider uses preview theme without publishing', () async {
    final cmsRepository = _FakeCmsPageRepository();
    final container = ProviderContainer(
      overrides: [
        activeStorefrontThemeProvider.overrideWith(
          (ref) async =>
              const StorefrontActiveTheme(theme: StorefrontTheme.dior),
        ),
        editingStorefrontThemeProvider.overrideWith(
          (ref) => StorefrontTheme.nike,
        ),
        cmsPageRepositoryProvider.overrideWithValue(cmsRepository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homepageCmsProvider.future);

    expect(cmsRepository.pageRequests, ['homepage_nike:fr']);
  });

  test('homepageCmsProvider uses visitor theme override', () async {
    final cmsRepository = _FakeCmsPageRepository();
    final container = ProviderContainer(
      overrides: [
        activeStorefrontThemeProvider.overrideWith(
          (ref) async =>
              const StorefrontActiveTheme(theme: StorefrontTheme.dior),
        ),
        visitorStorefrontThemeOverrideProvider.overrideWith(
          (ref) async => StorefrontTheme.nike,
        ),
        cmsPageRepositoryProvider.overrideWithValue(cmsRepository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homepageCmsProvider.future);

    expect(cmsRepository.pageRequests, ['homepage_nike:fr']);
  });

  test('segment homepage forces Nike and falls back to Homme CMS', () async {
    final activeTheme = Completer<StorefrontActiveTheme>();
    final cmsRepository = _FakeCmsPageRepository(
      missingPageCodes: {'homepage_nike_femme'},
    );
    final container = ProviderContainer(
      overrides: [
        activeStorefrontThemeProvider.overrideWith((ref) => activeTheme.future),
        cmsPageRepositoryProvider.overrideWithValue(cmsRepository),
      ],
    );
    addTearDown(container.dispose);

    final resolution = await container.read(
      homepageCmsForSegmentProvider(StorefrontSportSegment.femme).future,
    );

    expect(cmsRepository.pageRequests, [
      'homepage_nike_femme:fr',
      'homepage_nike:fr',
    ]);
    expect(activeTheme.isCompleted, isFalse);
    expect(resolution.requestedCode, 'homepage_nike_femme');
    expect(resolution.resolvedCode, 'homepage_nike');
    expect(resolution.usedFallback, isTrue);
    expect(resolution.bundle?.page.code, 'homepage_nike');
  });

  test('segment homepage reports missing fallback distinctly', () async {
    final cmsRepository = _FakeCmsPageRepository(
      missingPageCodes: {'homepage_nike_enfant', 'homepage_nike'},
    );
    final container = ProviderContainer(
      overrides: [cmsPageRepositoryProvider.overrideWithValue(cmsRepository)],
    );
    addTearDown(container.dispose);

    final resolution = await container.read(
      homepageCmsForSegmentProvider(StorefrontSportSegment.enfant).future,
    );

    expect(cmsRepository.pageRequests, [
      'homepage_nike_enfant:fr',
      'homepage_nike:fr',
    ]);
    expect(resolution.bundle, isNull);
    expect(resolution.requestedCode, 'homepage_nike_enfant');
    expect(resolution.resolvedCode, isNull);
    // The fallback page is also missing, so nothing was actually resolved:
    // usedFallback must stay false so the edit-mode hint doesn't mislead.
    expect(resolution.usedFallback, isFalse);
  });

  test('homepageCmsForSegmentProvider uses the active content locale', () async {
    final cmsRepository = _FakeCmsPageRepository();
    final container = ProviderContainer(
      overrides: [
        cmsPageRepositoryProvider.overrideWithValue(cmsRepository),
        contentLocaleProvider.overrideWith(
          () => ContentLocaleController(seeded: 'en'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(
      homepageCmsForSegmentProvider(StorefrontSportSegment.femme).future,
    );

    // The active locale ('en') is what reaches the repository; the page exists
    // so no FR fallback is needed.
    expect(cmsRepository.pageRequests, ['homepage_nike_femme:en']);
  });

  test(
    'cmsPageProvider falls back to the default locale only when missing',
    () async {
      final cmsRepository = _FakeCmsPageRepository(
        missingPageKeys: {'homepage:en'},
      );
      final container = ProviderContainer(
        overrides: [cmsPageRepositoryProvider.overrideWithValue(cmsRepository)],
      );
      addTearDown(container.dispose);

      final bundle = await container.read(
        cmsPageProvider(
          const CmsPageRequest(code: 'homepage', locale: 'en'),
        ).future,
      );

      expect(cmsRepository.pageRequests, ['homepage:en', 'homepage:fr']);
      expect(bundle?.page.locale, 'fr');
    },
  );

  test('cmsPageProvider serves a repeat read from the cache', () async {
    final cmsRepository = _FakeCmsPageRepository();
    final container = ProviderContainer(
      overrides: [cmsPageRepositoryProvider.overrideWithValue(cmsRepository)],
    );
    addTearDown(container.dispose);

    const request = CmsPageRequest(code: 'homepage', locale: 'fr');
    await container.read(cmsPageProvider(request).future);

    // Drop the Riverpod provider state (as autodispose does between
    // navigations) WITHOUT touching the LocalReadCache, then re-read. The
    // CachedRemoteReader must serve the SWR cache instead of re-hitting
    // PocketBase — this is the whole point of routing CMS reads through it.
    container.invalidate(cmsPageProvider(request));
    await container.read(cmsPageProvider(request).future);

    expect(
      cmsRepository.pageRequests,
      ['homepage:fr'],
      reason: 'a fresh cache hit must not refetch the repository',
    );
  });

  test('CmsPagesInvalidation forces a fresh repository read', () async {
    final cmsRepository = _FakeCmsPageRepository();
    final container = ProviderContainer(
      overrides: [cmsPageRepositoryProvider.overrideWithValue(cmsRepository)],
    );
    addTearDown(container.dispose);

    const request = CmsPageRequest(code: 'homepage', locale: 'fr');
    await container.read(cmsPageProvider(request).future);
    expect(cmsRepository.pageRequests, ['homepage:fr']);

    const CatalogInvalidator().applyToContainer(container, const [
      CmsPagesInvalidation(),
    ]);

    await container.read(cmsPageProvider(request).future);
    // Teeth for the invalidation contract: CmsPagesInvalidation must sweep the
    // `cms:` cache prefix (not just the Riverpod providers), otherwise an admin
    // edit stays masked by the SWR cache and the repository is not re-read.
    expect(
      cmsRepository.pageRequests,
      ['homepage:fr', 'homepage:fr'],
      reason:
          'CMS reads must refetch the repository after CmsPagesInvalidation',
    );
  });

  test('cmsPageProvider propagates CMS failures without fallback', () async {
    final failure = StateError('cms failed');
    final cmsRepository = _FakeCmsPageRepository(
      failingPageCodes: {'homepage': failure},
    );
    final container = ProviderContainer(
      overrides: [cmsPageRepositoryProvider.overrideWithValue(cmsRepository)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(
        cmsPageProvider(
          const CmsPageRequest(code: 'homepage', locale: 'en'),
        ).future,
      ),
      throwsA(same(failure)),
    );
    expect(cmsRepository.pageRequests, ['homepage:en']);
  });
}

class _FakeCmsPageRepository implements CmsPageRepository {
  final Set<String> missingPageCodes;
  final Set<String> missingPageKeys;
  final Map<String, Object> failingPageCodes;
  final List<String> pageRequests = [];

  _FakeCmsPageRepository({
    this.missingPageCodes = const {},
    this.missingPageKeys = const {},
    this.failingPageCodes = const {},
  });

  @override
  Future<CmsPageLoadResult> fetchPage({
    required String code,
    required String locale,
  }) async {
    pageRequests.add('$code:$locale');
    final failure = failingPageCodes[code];
    if (failure != null) {
      return CmsPageFailure(failure, StackTrace.current);
    }
    if (missingPageCodes.contains(code) ||
        missingPageKeys.contains('$code:$locale')) {
      return const CmsPageMissing();
    }
    return CmsPageFound(
      CmsPageBundle(
        page: CmsPageRecord(
          id: 'page-$code',
          code: code,
          locale: locale,
          title: code,
          isActive: true,
        ),
        sections: const [],
      ),
    );
  }

  @override
  Future<CmsPageLoadResult> fetchPlpForCategory({
    required String categoryId,
    required String locale,
  }) {
    throw UnimplementedError();
  }
}
