import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/cms/cms_page_editor_repository.dart';
import 'package:kiki_commerce/application/cms/cms_page_repository.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/providers/storefront_shell_provider.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/screens/cms_product_list_page.dart';
import 'package:kiki_commerce/presentation/screens/product_list_page.dart';
import 'package:kiki_commerce/presentation/widgets/cms/cms_section_renderer.dart';
import 'package:kiki_commerce/presentation/widgets/cms/cms_sections_sidebar.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/collection_hero_section.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/mixed_product_grid_section.dart';
import 'package:kiki_commerce/presentation/widgets/product_hero_tags.dart';

import '../../support/l10n_harness.dart';

class _NullCmsRepository implements CmsPageRepository {
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
    return const CmsPageMissing();
  }
}

class _PlpCmsRepository implements CmsPageRepository {
  final CmsPageBundle bundle;

  const _PlpCmsRepository(this.bundle);

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
    return CmsPageFound(bundle);
  }
}

class _FakeCategoryRepository implements CategoryCatalogRepository {
  final CatalogCategory category;
  final Future<CatalogPageData> Function(String categoryId, int perPage)?
  loadProducts;

  const _FakeCategoryRepository(this.category, {this.loadProducts});

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async => [category];

  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async => category;

  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async {
    final loader = loadProducts;
    if (loader != null) {
      return loader(categoryId, perPage);
    }
    return CatalogPageData(
      page: page,
      perPage: perPage,
      totalItems: 0,
      totalPages: 0,
      categoryId: categoryId,
      categoryName: category.name,
      items: const [],
    );
  }

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async =>
      category;

  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String locale,
    required String categorySlug,
    required String productSlug,
  }) async {
    return null;
  }
}

class _RecordingEditorRepo implements CmsPageEditorRepository {
  final List<Map<String, dynamic>> calls = [];

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
      'code': code,
      'sourceCategoryId': sourceCategoryId,
    });
    return 'page1';
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
      'op': 'createSection',
      'pageId': pageId,
      'sectionType': sectionType,
      'position': position,
      'isActive': isActive,
    });
  }

  @override
  Future<void> deleteSection({
    required String authToken,
    required String sectionRecordId,
  }) async {}

  @override
  Future<void> updateSection({
    required String authToken,
    required String sectionRecordId,
    required Map<String, dynamic> patch,
  }) async {}
}

void main() {
  const category = CatalogCategory(
    id: 'cat1',
    code: 'CAT1',
    name: 'Cadeaux',
    slug: 'cadeaux',
  );

  testWidgets('falls back to ProductListPage when no CMS PLP exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cmsPageRepositoryProvider.overrideWithValue(_NullCmsRepository()),
          categoryCatalogRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(category),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
          home: const Scaffold(body: CmsProductListPage(category: category)),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Cadeaux'), findsWidgets);
    expect(find.text('Créer la PLP CMS'), findsNothing);
  });

  testWidgets('shows bootstrap sidebar in edit mode when no CMS PLP exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cmsPageRepositoryProvider.overrideWithValue(_NullCmsRepository()),
          categoryCatalogRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(category),
          ),
          editModeProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
          home: const Scaffold(body: CmsProductListPage(category: category)),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('PLP CMS'), findsOneWidget);
    expect(find.text('Créer la PLP CMS'), findsOneWidget);
    expect(find.text('Nouveau produit'), findsOneWidget);
  });

  testWidgets('bootstrap CTA creates PLP page and sections', (tester) async {
    final editorRepo = _RecordingEditorRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cmsPageRepositoryProvider.overrideWithValue(_NullCmsRepository()),
          cmsPageEditorRepositoryProvider.overrideWithValue(editorRepo),
          categoryCatalogRepositoryProvider.overrideWithValue(
            const _FakeCategoryRepository(category),
          ),
          adminAuthTokenProvider.overrideWith((ref) => 'tok-1'),
          editModeProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
          home: const Scaffold(body: CmsProductListPage(category: category)),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Créer la PLP CMS'));
    await tester.pump();
    await tester.pump();

    expect(editorRepo.calls, hasLength(6));
    expect(editorRepo.calls.first['op'], 'createPage');
    expect(editorRepo.calls.skip(1).map((c) => c['sectionType']), [
      'hero_campaign',
      'mixed_product_grid',
      'seo_text',
      'service_cards',
      'discover_links',
    ]);
  });

  group('mixed_product_grid loading UX', () {
    late Size previousPhysicalSize;
    late double previousDevicePixelRatio;

    void setDesktopSurface() {
      previousPhysicalSize = testerView.physicalSize;
      previousDevicePixelRatio = testerView.devicePixelRatio;
      testerView.physicalSize = const Size(1200, 900);
      testerView.devicePixelRatio = 1.0;
    }

    void restoreSurface() {
      testerView.physicalSize = previousPhysicalSize;
      testerView.devicePixelRatio = previousDevicePixelRatio;
    }

    testWidgets('renders scrollable skeleton while products are loading', (
      tester,
    ) async {
      final products = Completer<CatalogPageData>();
      setDesktopSurface();
      addTearDown(restoreSurface);

      await tester.pumpWidget(
        _buildCmsPlpHarness(
          category: category,
          bundle: _cmsPlpBundle(),
          productFuture: products.future,
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Cadeaux hero'), findsOneWidget);
      expect(find.text('Cadeaux'), findsWidgets);
      expect(
        find.byKey(const ValueKey('mixed-product-grid-skeleton')),
        findsOneWidget,
      );
      expect(_mainScrollExtent(tester), greaterThan(0));

      products.complete(_catalogPageData(category, 8));
      await tester.pumpAndSettle();
    });

    testWidgets('replaces skeleton with products after load', (tester) async {
      final products = Completer<CatalogPageData>();
      setDesktopSurface();
      addTearDown(restoreSurface);

      await tester.pumpWidget(
        _buildCmsPlpHarness(
          category: category,
          bundle: _cmsPlpBundle(),
          productFuture: products.future,
        ),
      );

      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('mixed-product-grid-skeleton')),
        findsOneWidget,
      );

      products.complete(_catalogPageData(category, 8));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mixed-product-grid-skeleton')),
        findsNothing,
      );
      expect(find.text('Product 1'), findsOneWidget);
      expect(find.text('Product 8'), findsOneWidget);
    });

    testWidgets('keeps scroll extent stable between skeleton and products', (
      tester,
    ) async {
      final products = Completer<CatalogPageData>();
      setDesktopSurface();
      addTearDown(restoreSurface);

      await tester.pumpWidget(
        _buildCmsPlpHarness(
          category: category,
          bundle: _cmsPlpBundle(),
          productFuture: products.future,
        ),
      );

      await tester.pump();
      await tester.pump();
      final loadingExtent = _mainScrollExtent(tester);

      products.complete(_catalogPageData(category, 8));
      await tester.pumpAndSettle();
      final loadedExtent = _mainScrollExtent(tester);

      expect((loadedExtent - loadingExtent).abs(), lessThan(120));
    });

    testWidgets(
      'hero first triggers immersive mode with computed height (non edit)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            cmsPageRepositoryProvider.overrideWithValue(
              _PlpCmsRepository(_cmsPlpHeroBundle()),
            ),
            categoryCatalogRepositoryProvider.overrideWithValue(
              _FakeCategoryRepository(
                category,
                loadProducts: (_, _) =>
                    Future.value(_catalogPageData(category, 4)),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        setDesktopSurface();
        addTearDown(restoreSurface);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              locale: const Locale('fr'),
              home: Scaffold(body: CmsProductListPage(category: category)),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        final state = container.read(storefrontShellProvider);
        expect(state.isImmersive, isTrue);
        expect(state.heroHeight, isNotNull);
        expect(state.heroHeight, greaterThan(0));
      },
    );

    testWidgets('edit mode forces normal shell even with hero first', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          cmsPageRepositoryProvider.overrideWithValue(
            _PlpCmsRepository(_cmsPlpHeroBundle()),
          ),
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryRepository(
              category,
              loadProducts: (_, _) =>
                  Future.value(_catalogPageData(category, 4)),
            ),
          ),
          editModeProvider.overrideWith((ref) => true),
          adminAuthTokenProvider.overrideWith((ref) => 'tok-1'),
        ],
      );
      addTearDown(container.dispose);
      setDesktopSurface();
      addTearDown(restoreSurface);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: const Locale('fr'),
            home: Scaffold(body: CmsProductListPage(category: category)),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final state = container.read(storefrontShellProvider);
      expect(state.isImmersive, isFalse);
      expect(state.heroHeight, isNull);
    });

    testWidgets('non-hero first section keeps shell normal', (tester) async {
      final container = ProviderContainer(
        overrides: [
          cmsPageRepositoryProvider.overrideWithValue(
            _PlpCmsRepository(_cmsPlpBundle()),
          ),
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryRepository(
              category,
              loadProducts: (_, _) =>
                  Future.value(_catalogPageData(category, 4)),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      setDesktopSurface();
      addTearDown(restoreSurface);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: const Locale('fr'),
            home: Scaffold(body: CmsProductListPage(category: category)),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      final state = container.read(storefrontShellProvider);
      expect(state.isImmersive, isFalse);
      expect(state.heroHeight, isNull);
    });

    testWidgets('shows a visible error state when products fail', (
      tester,
    ) async {
      final products = Completer<CatalogPageData>();
      setDesktopSurface();
      addTearDown(restoreSurface);

      await tester.pumpWidget(
        _buildCmsPlpHarness(
          category: category,
          bundle: _cmsPlpBundle(),
          productFuture: products.future,
        ),
      );

      await tester.pump();
      await tester.pump();
      products.completeError(Exception('boom'), StackTrace.current);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('Impossible de charger les produits pour le moment.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mixed-product-grid-skeleton')),
        findsNothing,
      );
    });
  });

  testWidgets(
    'toggling editMode preserves storefront section element identity',
    (tester) async {
      // Element identity test: when the user enters or leaves edit mode,
      // the storefront sections subtree must not be torn down. We probe
      // this by capturing the Element behind a CollectionHeroSection
      // before and after the toggle and asserting it is the same instance.
      final products = Completer<CatalogPageData>();

      await tester.pumpWidget(
        _buildCmsPlpHarness(
          category: category,
          bundle: _cmsPlpBundle(),
          productFuture: products.future,
        ),
      );
      await tester.pump();
      await tester.pump();

      final heroFinder = find.byType(CollectionHeroSection);
      expect(heroFinder, findsOneWidget);
      final beforeElement = tester.element(heroFinder);

      // Enter edit mode via the live provider container — this mimics the
      // FAB toggle without re-mounting the widget tree.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CmsProductListPage)),
      );
      container.read(editModeProvider.notifier).state = true;
      await tester.pump();
      await tester.pump();

      // Sidebar appears = chrome layer reacted to the toggle.
      expect(find.byType(CmsSectionsSidebar), findsOneWidget);

      final afterElement = tester.element(heroFinder);
      expect(afterElement, same(beforeElement));

      // Flip back to non-edit; element identity should still hold.
      container.read(editModeProvider.notifier).state = false;
      await tester.pump();
      await tester.pump();

      final afterToggleBackElement = tester.element(heroFinder);
      expect(afterToggleBackElement, same(beforeElement));
    },
  );

  group('sport apparence bypasses CMS PLP in public read', () {
    testWidgets(
      'Nike + public read renders the direct catalogue grid, not CMS sections',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cmsPageRepositoryProvider.overrideWithValue(
                _PlpCmsRepository(_cmsPlpBundle()),
              ),
              categoryCatalogRepositoryProvider.overrideWithValue(
                _FakeCategoryRepository(
                  category,
                  loadProducts: (_, _) =>
                      Future.value(_catalogPageData(category, 4)),
                ),
              ),
              editingStorefrontThemeProvider.overrideWith(
                (ref) => StorefrontTheme.nike,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              locale: const Locale('fr'),
              home: const Scaffold(
                body: CmsProductListPage(category: category),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        // Direct catalogue grid is mounted…
        expect(find.byType(ProductListPage), findsOneWidget);
        // …and the CMS hero section is NOT rendered.
        expect(find.byType(CollectionHeroSection), findsNothing);
        expect(find.text('Cadeaux hero'), findsNothing);
      },
    );

    testWidgets('Nike + edit mode keeps the CMS PLP accessible', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cmsPageRepositoryProvider.overrideWithValue(
              _PlpCmsRepository(_cmsPlpBundle()),
            ),
            categoryCatalogRepositoryProvider.overrideWithValue(
              _FakeCategoryRepository(
                category,
                loadProducts: (_, _) =>
                    Future.value(_catalogPageData(category, 4)),
              ),
            ),
            editingStorefrontThemeProvider.overrideWith(
              (ref) => StorefrontTheme.nike,
            ),
            editModeProvider.overrideWith((ref) => true),
            adminAuthTokenProvider.overrideWith((ref) => 'tok-1'),
          ],
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: const Locale('fr'),
            home: const Scaffold(body: CmsProductListPage(category: category)),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Edit mode is not bypassed: the CMS sections render so admins keep
      // full access to manage the CMS PLP even under the sport apparence.
      expect(find.byType(CollectionHeroSection), findsOneWidget);
    });

    testWidgets('Dior + public read keeps the CMS-composed PLP', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cmsPageRepositoryProvider.overrideWithValue(
              _PlpCmsRepository(_cmsPlpBundle()),
            ),
            categoryCatalogRepositoryProvider.overrideWithValue(
              _FakeCategoryRepository(
                category,
                loadProducts: (_, _) =>
                    Future.value(_catalogPageData(category, 4)),
              ),
            ),
            editingStorefrontThemeProvider.overrideWith(
              (ref) => StorefrontTheme.dior,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: const Locale('fr'),
            home: const Scaffold(body: CmsProductListPage(category: category)),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(CollectionHeroSection), findsOneWidget);
    });
  });

  group('product image Hero transition', () {
    testWidgets('catalogue PLP grid wraps the product image in a Hero', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildCmsPlpHarness(
          category: category,
          bundle: _cmsPlpBundle(),
          productFuture: Future.value(_catalogPageDataWithMedia(category, 4)),
        ),
      );
      await tester.pumpAndSettle();

      final heroFinder = find.byWidgetPredicate(
        (w) =>
            w is Hero &&
            w.tag ==
                productImageHeroTag(
                  'p1',
                  sourceScope: productListingHeroScope(categoryId: category.id),
                ),
      );
      expect(heroFinder, findsOneWidget);
    });

    testWidgets(
      'renderCmsSection default keeps the grid Hero-free (non-PLP surface)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              categoryCatalogRepositoryProvider.overrideWithValue(
                _FakeCategoryRepository(
                  category,
                  loadProducts: (_, _) =>
                      Future.value(_catalogPageDataWithMedia(category, 4)),
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: testLocalizationsDelegates,
              supportedLocales: testSupportedLocales,
              locale: const Locale('fr'),
              home: Scaffold(
                body: Builder(
                  builder: (context) => ListView(
                    children: [
                      renderCmsSection(
                        context,
                        _cmsPlpBundle().sections
                            .whereType<CmsMixedProductGridSection>()
                            .first,
                        routeCategoryId: category.id,
                        routeCategory: category,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MixedProductGridSection), findsOneWidget);
        expect(find.byType(Hero), findsNothing);
      },
    );
  });
}

Widget _buildCmsPlpHarness({
  required CatalogCategory category,
  required CmsPageBundle bundle,
  required Future<CatalogPageData> productFuture,
}) {
  return ProviderScope(
    overrides: [
      cmsPageRepositoryProvider.overrideWithValue(_PlpCmsRepository(bundle)),
      categoryCatalogRepositoryProvider.overrideWithValue(
        _FakeCategoryRepository(
          category,
          loadProducts: (_, _) => productFuture,
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(body: CmsProductListPage(category: category)),
    ),
  );
}

CmsPageBundle _cmsPlpBundle() {
  return CmsPageBundle(
    page: const CmsPageRecord(
      id: 'page1',
      code: 'plp-cadeaux',
      locale: 'fr',
      title: 'Cadeaux',
      isActive: true,
      pageType: CmsPageType.plp,
      sourceCategoryId: 'cat1',
    ),
    sections: [
      CmsCollectionHeroSection(
        _sectionRecord(
          id: 'hero',
          sectionType: CmsSectionType.collectionHero,
          position: 0,
        ),
        const CollectionHeroConfig(
          title: 'Cadeaux hero',
          intro: 'Une selection de cadeaux.',
          desktopLayout: 'centered',
          mobileLayout: 'textOnly',
        ),
      ),
      CmsMixedProductGridSection(
        _sectionRecord(
          id: 'grid',
          sectionType: CmsSectionType.mixedProductGrid,
          position: 1,
        ),
        const MixedProductGridConfig(
          source: GridSourceConfig(limit: 8),
          columnsMobile: 2,
          columnsTablet: 3,
          columnsDesktop: 4,
        ),
      ),
    ],
  );
}

CmsPageBundle _cmsPlpHeroBundle() {
  return CmsPageBundle(
    page: const CmsPageRecord(
      id: 'page1',
      code: 'plp-cadeaux',
      locale: 'fr',
      title: 'Cadeaux',
      isActive: true,
      pageType: CmsPageType.plp,
      sourceCategoryId: 'cat1',
    ),
    sections: [
      CmsHeroSection(
        _sectionRecord(
          id: 'hero',
          sectionType: CmsSectionType.heroCampaign,
          position: 0,
        ),
        const HeroCampaignConfig(title: 'Cadeaux hero campaign'),
      ),
      CmsMixedProductGridSection(
        _sectionRecord(
          id: 'grid',
          sectionType: CmsSectionType.mixedProductGrid,
          position: 1,
        ),
        const MixedProductGridConfig(
          source: GridSourceConfig(limit: 8),
          columnsMobile: 2,
          columnsTablet: 3,
          columnsDesktop: 4,
        ),
      ),
    ],
  );
}

CmsSectionRecord _sectionRecord({
  required String id,
  required CmsSectionType sectionType,
  required int position,
}) {
  return CmsSectionRecord(
    id: id,
    pageId: 'page1',
    sectionId: id,
    sectionType: sectionType,
    rawSectionType: sectionType.wireName,
    position: position,
    isActive: true,
    config: const {},
  );
}

CatalogPageData _catalogPageData(CatalogCategory category, int count) {
  return CatalogPageData(
    page: 1,
    perPage: count,
    totalItems: count,
    totalPages: 1,
    categoryId: category.id,
    categoryName: category.name,
    items: [
      for (var i = 1; i <= count; i++)
        CatalogListingItem(
          id: 'cp$i',
          categoryId: category.id,
          productId: 'p$i',
          productRouteSlug: 'product-$i',
          position: i * 10,
          category: category,
          product: CatalogProduct(id: 'p$i', code: 'P$i', name: 'Product $i'),
          prices: [
            CatalogPrice(
              id: 'price$i',
              productId: 'p$i',
              price: (10 + i).toDouble(),
              currencySymbol: 'EUR',
            ),
          ],
        ),
    ],
  );
}

CatalogPageData _catalogPageDataWithMedia(CatalogCategory category, int count) {
  return CatalogPageData(
    page: 1,
    perPage: count,
    totalItems: count,
    totalPages: 1,
    categoryId: category.id,
    categoryName: category.name,
    items: [
      for (var i = 1; i <= count; i++)
        CatalogListingItem(
          id: 'cp$i',
          categoryId: category.id,
          productId: 'p$i',
          productRouteSlug: 'product-$i',
          position: i * 10,
          category: category,
          product: CatalogProduct(
            id: 'p$i',
            code: 'P$i',
            name: 'Product $i',
            picture: CatalogMedia(
              id: 'media-$i',
              url: 'https://example.com/p$i.jpg',
              previewUrl: 'https://example.com/p$i-preview.jpg',
            ),
          ),
          prices: [
            CatalogPrice(
              id: 'price$i',
              productId: 'p$i',
              price: (10 + i).toDouble(),
              currencySymbol: 'EUR',
            ),
          ],
        ),
    ],
  );
}

double _mainScrollExtent(WidgetTester tester) {
  return tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .map((state) => state.position.maxScrollExtent)
      .fold<double>(0, (max, value) => value > max ? value : max);
}

TestFlutterView get testerView =>
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
