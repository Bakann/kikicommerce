import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/navigation/drawer_editorial_tiles.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/core/constants.dart';
import 'package:kiki_commerce/presentation/providers/category_providers.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/providers/navigation_providers.dart';
import 'package:kiki_commerce/presentation/providers/product_providers.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/screens/product_list_page.dart';
import 'package:kiki_commerce/presentation/widgets/drawer/managed_drawer_widgets.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_category_drawer.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_managed_navigation_drawer.dart';

import '../../support/l10n_harness.dart';

void main() {
  void setMobileSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
  }

  void setDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
  }

  void resetSurface(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  Widget buildHarness({
    DrawerNavigationLoadResult? result,
    DrawerNavigationRepository? repository,
    String? currentCategoryId,
    bool isEditMode = false,
    AdminBackofficeRepository? adminRepository,
    CategoryCatalogRepository? categoryRepository,
  }) {
    return ProviderScope(
      overrides: [
        drawerNavigationRepositoryProvider.overrideWithValue(
          repository ?? _FakeDrawerNavigationRepository(result!),
        ),
        categoryCatalogRepositoryProvider.overrideWithValue(
          categoryRepository ?? const _FakeCategoryCatalogRepository(),
        ),
        if (isEditMode) editModeProvider.overrideWith((ref) => true),
        if (isEditMode)
          adminAuthTokenProvider.overrideWith((ref) => 'test-token'),
        if (adminRepository != null)
          adminBackofficeRepositoryProvider.overrideWithValue(adminRepository),
      ],
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(
          drawer: StorefrontCategoryDrawer(
            currentCategoryId: currentCategoryId,
          ),
          body: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
      ),
    );
  }

  test('drawer providers exclude hidden records outside edit mode', () async {
    final navigationRepository = _RecordingDrawerNavigationRepository(
      _buildManagedDrawerResult(),
    );
    final categoryRepository = _RecordingCategoryCatalogRepository();
    final container = ProviderContainer(
      overrides: [
        drawerNavigationRepositoryProvider.overrideWithValue(
          navigationRepository,
        ),
        categoryCatalogRepositoryProvider.overrideWithValue(categoryRepository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(mainDrawerNavigationProvider.future);
    await container.read(drawerCategoriesProvider.future);

    expect(navigationRepository.includeHiddenCalls, [false]);
    expect(categoryRepository.includeHiddenCalls, [false]);
  });

  test('drawer providers include hidden records in edit mode', () async {
    final navigationRepository = _RecordingDrawerNavigationRepository(
      _buildManagedDrawerResult(),
    );
    final categoryRepository = _RecordingCategoryCatalogRepository();
    final container = ProviderContainer(
      overrides: [
        drawerNavigationRepositoryProvider.overrideWithValue(
          navigationRepository,
        ),
        categoryCatalogRepositoryProvider.overrideWithValue(categoryRepository),
        editModeProvider.overrideWith((ref) => true),
      ],
    );
    addTearDown(container.dispose);

    await container.read(mainDrawerNavigationProvider.future);
    await container.read(drawerCategoriesProvider.future);

    expect(navigationRepository.includeHiddenCalls, [true]);
    expect(categoryRepository.includeHiddenCalls, [true]);
  });

  testWidgets('mobile drawer opens second level and injects Voir tout', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    addTearDown(() => resetSurface(tester));

    await tester.pumpWidget(
      buildHarness(
        result: _buildManagedDrawerResult(),
        currentCategoryId: 'cat-her',
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Voir tout'), findsOneWidget);
    expect(find.text('Découvrez les cadeaux'), findsOneWidget);
    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('Cadeaux pour elle'), findsWidgets);
    expect(tester.getSize(find.byType(Drawer)).width, closeTo(374, 1));
  });

  testWidgets('drawer close waits for X collapse before dismissing', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    addTearDown(() => resetSurface(tester));

    await tester.pumpWidget(buildHarness(result: _buildManagedDrawerResult()));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);

    await tester.tap(find.text('Fermer'));
    await tester.pump(const Duration(milliseconds: 419));

    expect(find.byType(Drawer), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('desktop drawer exposes nav and promo content from main_drawer', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));

    await tester.pumpWidget(
      buildHarness(
        result: _buildManagedDrawerResult(),
        currentCategoryId: 'cat-her',
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Cadeaux'), findsWidgets);
    expect(find.text('Découvrez les cadeaux'), findsOneWidget);
    expect(find.text('Cadeaux pour elle'), findsWidgets);
    expect(find.text('Cadeaux pour lui'), findsWidgets);
    expectTextStyle(tester, 'Cadeaux', fontWeight: FontWeight.w500);
    expectTextStyle(
      tester,
      'Découvrez les cadeaux',
      fontWeight: FontWeight.w400,
    );
    expectTextStyle(tester, 'Highlights', fontWeight: FontWeight.w500);
    expect(tester.getSize(find.byType(Drawer)).width, greaterThan(900));
  });

  testWidgets('live drawer can be forced to the category tree', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));

    await tester.pumpWidget(
      buildHarness(
        result: _buildManagedDrawerResult(displayMode: 'categories'),
        currentCategoryId: 'cat-home',
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Maison'), findsOneWidget);
    expect(find.text('Cuisine'), findsOneWidget);
    expect(find.text('Nouvelle catégorie'), findsNothing);
    expect(find.text('Découvrez les cadeaux'), findsNothing);
    expectTextStyle(tester, 'Maison', fontWeight: FontWeight.w500);
    expectTextStyle(tester, 'Cuisine', fontWeight: FontWeight.w400);
    expect(tester.getSize(find.byType(Drawer)).width, closeTo(411.594, 0.001));
  });

  testWidgets('mobile category drawer animates drill and back level changes', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    addTearDown(() => resetSurface(tester));

    await tester.pumpWidget(
      buildHarness(
        result: _buildManagedDrawerResult(displayMode: 'categories'),
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Maison'), findsOneWidget);
    expect(find.text('Cuisine'), findsOneWidget);
    expect(find.text('Lampes'), findsNothing);

    await tester.tap(find.text('Maison'));
    await tester.pump();

    expect(find.text('Lampes'), findsOneWidget);
    expect(find.text('Cuisine'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Lampes'), findsOneWidget);
    expect(find.text('Cuisine'), findsNothing);

    await tester.tap(find.text('Maison'));
    await tester.pump();

    expect(find.text('Lampes'), findsOneWidget);
    expect(find.text('Cuisine'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Lampes'), findsNothing);
    expect(find.text('Cuisine'), findsOneWidget);
  });

  testWidgets(
    'desktop drawer shows root promo media when there are no promo children',
    (WidgetTester tester) async {
      setDesktopSurface(tester);
      addTearDown(() => resetSurface(tester));

      await tester.pumpWidget(
        buildHarness(
          result: _buildManagedDrawerResultWithRootPromoOnly(),
          currentCategoryId: 'cat-vogue',
        ),
      );

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Mode femme'), findsWidgets);
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(tester.getSize(find.byType(Drawer)).width, greaterThan(900));
    },
  );

  testWidgets('desktop drawer renders editorial tiles before legacy promo', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));

    await tester.pumpWidget(
      buildHarness(
        result: _buildManagedDrawerResultWithRootPromoAndEditorialTiles(),
        currentCategoryId: 'cat-vogue',
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Tuile éditoriale'), findsOneWidget);
    expect(find.text('Mode femme'), findsWidgets);
    expect(tester.getSize(find.byType(Drawer)).width, greaterThan(900));
  });

  testWidgets('empty editorial tiles fall back to legacy promo media', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));

    await tester.pumpWidget(
      buildHarness(
        result: _buildManagedDrawerResultWithEmptyEditorialTiles(),
        currentCategoryId: 'cat-vogue',
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Tuile éditoriale'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.getSize(find.byType(Drawer)).width, greaterThan(900));
  });

  testWidgets(
    'edit dialog opens when selected promo media is absent from loaded options',
    (WidgetTester tester) async {
      setDesktopSurface(tester);
      addTearDown(() => resetSurface(tester));

      final adminRepository = _RecordingAdminBackofficeRepository();

      await tester.pumpWidget(
        buildHarness(
          result: _buildManagedDrawerResultWithRootPromoOnly(),
          isEditMode: true,
          adminRepository: adminRepository,
        ),
      );

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Modifier').first);
      await tester.pumpAndSettle();

      expect(find.text('Modifier l’entrée'), findsOneWidget);
      expect(find.text('media-vogue'), findsOneWidget);
    },
  );

  testWidgets('editorial tiles dialog patches only config', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));

    final adminRepository = _RecordingAdminBackofficeRepository();

    await tester.pumpWidget(
      buildHarness(
        result: _buildManagedDrawerResultWithRootPromoAndEditorialTiles(),
        isEditMode: true,
        adminRepository: adminRepository,
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Modifier').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Éditer les tiles'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));

    expect(adminRepository.updatedCollection, 'navigation_items');
    expect(adminRepository.updatedRecordId, 'root-vogue');
    expect(adminRepository.updatedData?.keys, ['config']);
    final config = adminRepository.updatedData?['config'] as Map;
    expect(config['futureKey'], {'enabled': true});
    final editorialTiles = config[drawerEditorialTilesConfigKey] as Map;
    expect(
      (editorialTiles['items'] as List).first['title'],
      'Tuile éditoriale',
    );
  });

  testWidgets('new root appears after save without a full page reload', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));

    final adminRepository = _RecordingAdminBackofficeRepository();
    final repository = _SequencedDrawerNavigationRepository([
      _buildManagedDrawerResultWithRootPromoOnly(),
      _buildManagedDrawerResultWithRootPromoOnly(),
      _buildManagedDrawerResultWithTwoRoots(),
    ]);

    await tester.pumpWidget(
      buildHarness(
        repository: repository,
        isEditMode: true,
        adminRepository: adminRepository,
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nouvelle entrée'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Mode homme');
    await tester.enterText(find.byType(TextFormField).at(1), 'mode_homme');
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(adminRepository.createdCollection, 'navigation_items');
    expect(repository.callCount, greaterThanOrEqualTo(3));
    expect(find.text('Mode homme'), findsWidgets);
  });

  testWidgets(
    'edit mode exposes drawer bootstrap when main_drawer is missing',
    (WidgetTester tester) async {
      setDesktopSurface(tester);
      addTearDown(() => resetSurface(tester));

      final adminRepository = _RecordingAdminBackofficeRepository();

      await tester.pumpWidget(
        buildHarness(
          result: const DrawerNavigationLoadResult.fallback(
            fallbackReason: DrawerNavigationFallbackReason.menuMissing,
          ),
          isEditMode: true,
          adminRepository: adminRepository,
        ),
      );

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Drawer géré'), findsOneWidget);
      expect(find.text('Créer le drawer géré'), findsOneWidget);

      await tester.tap(find.text('Créer le drawer géré'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(adminRepository.createdCollection, 'navigation_menus');
      expect(adminRepository.createdData?['code'], 'main_drawer');
      expect(find.text('Nouvelle entrée'), findsOneWidget);
    },
  );

  testWidgets('edit mode refreshes managed navigation when the drawer opens', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));

    final repository = _SequencedDrawerNavigationRepository([
      const DrawerNavigationLoadResult.fallback(
        fallbackReason: DrawerNavigationFallbackReason.menuMissing,
      ),
      _buildManagedDrawerResult(),
    ]);

    await tester.pumpWidget(
      buildHarness(
        repository: repository,
        isEditMode: true,
        currentCategoryId: 'cat-her',
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(repository.callCount, greaterThanOrEqualTo(2));
    expect(find.text('Créer le drawer géré'), findsNothing);
    expect(find.text('Découvrez les cadeaux'), findsOneWidget);
    expect(find.text('Cadeaux pour elle'), findsWidgets);
  });

  testWidgets(
    'edit mode switches between navigation and category admin scopes',
    (WidgetTester tester) async {
      setDesktopSurface(tester);
      addTearDown(() => resetSurface(tester));
      final adminRepository = _RecordingAdminBackofficeRepository();

      await tester.pumpWidget(
        buildHarness(
          result: _buildManagedDrawerResult(),
          isEditMode: true,
          currentCategoryId: 'cat-home',
          adminRepository: adminRepository,
        ),
      );

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Navigation'), findsOneWidget);
      expect(find.text('Catégories'), findsOneWidget);
      expect(find.text('Nouvelle entrée'), findsOneWidget);

      await tester.tap(find.text('Catégories'));
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle catégorie'), findsOneWidget);
      expect(find.text('Maison'), findsOneWidget);
      expect(find.text('Cuisine'), findsOneWidget);
      expect(find.byTooltip('Actions catégorie'), findsWidgets);
      expect(find.text('Nouvelle entrée'), findsNothing);
      expect(adminRepository.updatedCollection, 'navigation_menus');
      expect(adminRepository.updatedData?['displayMode'], 'categories');

      await tester.tap(find.text('Navigation'));
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle entrée'), findsOneWidget);
      expect(find.text('Nouvelle catégorie'), findsNothing);
      expect(adminRepository.updatedData?['displayMode'], 'drawer');
    },
  );

  testWidgets('edit mode can hide and move navigation items', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));
    final adminRepository = _RecordingAdminBackofficeRepository();

    await tester.pumpWidget(
      buildHarness(
        result: _buildManagedDrawerResultWithTwoRoots(),
        isEditMode: true,
        adminRepository: adminRepository,
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    final navigationHandles = find.byIcon(Icons.drag_indicator);
    expect(navigationHandles, findsNWidgets(2));

    final firstHandleCenter = tester.getCenter(navigationHandles.at(0));
    final secondHandleCenter = tester.getCenter(navigationHandles.at(1));
    final gesture = await tester.startGesture(secondHandleCenter);
    await tester.pump();
    await gesture.moveTo(firstHandleCenter);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      adminRepository.updateCalls
          .where((call) => call.collection == 'navigation_items')
          .map((call) => (call.recordId, call.data['position'])),
      containsAll([('root-men', 10), ('root-vogue', 20)]),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actions navigation').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masquer').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(adminRepository.updatedCollection, 'navigation_items');
    expect(adminRepository.updatedRecordId, 'root-vogue');
    expect(adminRepository.updatedData?['isHidden'], true);
  });

  testWidgets('edit mode can restore hidden navigation items', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));
    final adminRepository = _RecordingAdminBackofficeRepository();

    await tester.pumpWidget(
      buildHarness(
        result: _buildManagedDrawerResultWithTwoRoots(secondRootHidden: true),
        isEditMode: true,
        adminRepository: adminRepository,
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Masqué'), findsOneWidget);
    expectTextStyle(tester, 'Masqué', fontWeight: FontWeight.w600);

    await tester.tap(find.byTooltip('Actions navigation').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réafficher'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(adminRepository.updatedCollection, 'navigation_items');
    expect(adminRepository.updatedRecordId, 'root-men');
    expect(adminRepository.updatedData?['isHidden'], false);
  });

  testWidgets('category drawer can hide and move categories', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));
    final adminRepository = _RecordingAdminBackofficeRepository();

    await tester.pumpWidget(
      buildHarness(
        result: _buildManagedDrawerResult(displayMode: 'categories'),
        isEditMode: true,
        adminRepository: adminRepository,
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catégories'));
    await tester.pumpAndSettle();

    final categoryHandles = find.byIcon(Icons.drag_indicator);
    expect(categoryHandles, findsNWidgets(2));

    final firstHandleCenter = tester.getCenter(categoryHandles.at(0));
    final secondHandleCenter = tester.getCenter(categoryHandles.at(1));
    final gesture = await tester.startGesture(secondHandleCenter);
    await tester.pump();
    await gesture.moveTo(firstHandleCenter);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(
      adminRepository.updateCalls
          .where((call) => call.collection == 'categories')
          .map((call) => (call.recordId, call.data['position'])),
      containsAll([('cat-kitchen', 10), ('cat-home', 20)]),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actions catégorie').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masquer').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(adminRepository.updatedCollection, 'categories');
    expect(adminRepository.updatedRecordId, 'cat-home');
    expect(adminRepository.updatedData?['isHidden'], true);
  });

  testWidgets('edit mode can restore hidden drawer categories', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));
    final adminRepository = _RecordingAdminBackofficeRepository();
    const categoryRepository = _FakeCategoryCatalogRepository([
      CatalogCategory(
        id: 'cat-home',
        code: 'HOME',
        name: 'Maison',
        slug: 'maison',
      ),
      CatalogCategory(
        id: 'cat-kitchen',
        code: 'KITCHEN',
        name: 'Cuisine',
        slug: 'cuisine',
        isHidden: true,
      ),
    ]);

    await tester.pumpWidget(
      buildHarness(
        result: _buildManagedDrawerResult(displayMode: 'categories'),
        isEditMode: true,
        adminRepository: adminRepository,
        categoryRepository: categoryRepository,
      ),
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catégories'));
    await tester.pumpAndSettle();

    expect(find.text('Masqué'), findsOneWidget);
    expectTextStyle(tester, 'Cuisine', fontWeight: FontWeight.w400);
    expectTextStyle(tester, 'Masqué', fontWeight: FontWeight.w600);

    await tester.tap(find.byTooltip('Actions catégorie').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réafficher'));
    await tester.pump();

    expect(adminRepository.updatedCollection, 'categories');
    expect(adminRepository.updatedRecordId, 'cat-kitchen');
    expect(adminRepository.updatedData?['isHidden'], false);
  });

  testWidgets(
    'desktop drawer: repeated hovers on the same root only fire setState once',
    (WidgetTester tester) async {
      setDesktopSurface(tester);
      addTearDown(() => resetSurface(tester));

      final result = _buildManagedDrawerResultWithTwoRoots();
      var activeRootChangedCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: const Locale('fr'),
            home: Scaffold(
              body: StorefrontManagedNavigationDrawerContent(
                menu: result.menu!,
                normalized: result.normalized!,
                debugOnActiveRootChanged: () => activeRootChangedCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the first root tile ("Cadeaux") and a neutral position outside it.
      final firstTile = find.byType(ManagedDrawerTile).first;
      final insideFirst = tester.getCenter(firstTile);
      const outside = Offset(2000, 2000);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: outside);
      addTearDown(gesture.removePointer);

      // First enter — guard does not trigger because no prior root resolution.
      await gesture.moveTo(insideFirst);
      await tester.pump();
      expect(activeRootChangedCount, 1);

      // Four more enters on the same tile (leave + re-enter each iteration).
      for (var i = 0; i < 4; i++) {
        await gesture.moveTo(outside);
        await tester.pump();
        await gesture.moveTo(insideFirst);
        await tester.pump();
      }

      // Guard collapses redundant hovers: still exactly one notification.
      expect(activeRootChangedCount, 1);
    },
  );

  group('drawer category navigation preserves history', () {
    DrawerNavigationItemData itemOf({
      required DrawerNavigationItemType type,
      CatalogCategory? category,
      String? categoryId,
      String? pageKey,
      String? productId,
      String? url,
    }) {
      return DrawerNavigationItemData(
        id: 'item',
        menuId: 'menu',
        position: 0,
        label: 'Item',
        itemType: type,
        placement: DrawerNavigationPlacement.nav,
        isActive: true,
        isHidden: false,
        category: category,
        categoryId: categoryId,
        pageKey: pageKey,
        productId: productId,
        url: url,
      );
    }

    test('only catalog PLP destinations ask to preserve history', () {
      const category = CatalogCategory(
        id: 'cat-shirts',
        code: 'SHIRTS',
        name: 'Shirts',
        slug: 'shirts',
      );

      // Category item -> /catalog/<slug>: push.
      expect(
        resolveAction(
          itemOf(
            type: DrawerNavigationItemType.category,
            category: category,
            categoryId: 'cat-shirts',
          ),
        ).preserveHistory,
        isTrue,
      );
      // Page item whose pageKey resolves to a category PLP (the real-world
      // "Toutes les chaussures" case): also push.
      expect(
        resolveAction(
          itemOf(
            type: DrawerNavigationItemType.page,
            pageKey: 'homme-chaussures-toutes-les-chaussures',
          ),
        ).preserveHistory,
        isTrue,
      );
      // Technical page destinations keep `go` semantics.
      expect(
        resolveAction(
          itemOf(type: DrawerNavigationItemType.page, pageKey: 'home'),
        ).preserveHistory,
        isFalse,
      );
      expect(
        resolveAction(
          itemOf(type: DrawerNavigationItemType.page, pageKey: 'search'),
        ).preserveHistory,
        isFalse,
      );
      expect(
        resolveAction(
          itemOf(type: DrawerNavigationItemType.product, productId: 'p1'),
        ).preserveHistory,
        isFalse,
      );
      expect(
        resolveAction(
          itemOf(
            type: DrawerNavigationItemType.external,
            url: 'https://x.test',
          ),
        ).preserveHistory,
        isFalse,
      );
    });

    testWidgets('drawer category tap pushes, so PLP back returns to page A', (
      WidgetTester tester,
    ) async {
      setMobileSurface(tester);
      addTearDown(() => resetSurface(tester));

      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (context, state) => Scaffold(
              drawer: const StorefrontCategoryDrawer(),
              body: Builder(
                builder: (ctx) => Column(
                  children: [
                    const Text('Start Page'),
                    IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The PLP lives inside a ShellRoute while /start does not, mirroring
          // the real app (MainShell wraps /catalog/...). This is what makes
          // Navigator.of(context).canPop() insufficient: the pushed PLP sits in
          // the shell's inner navigator, so back must consult go_router.
          ShellRoute(
            builder: (context, state, child) => child,
            routes: [
              // Witness route: if back fell through to PlpParentRouting (the
              // bug), the URL fallback would land here instead of page A.
              GoRoute(
                path: CatalogRoutes.catalogBase,
                builder: (context, state) =>
                    const Scaffold(body: Text('Catalog Root')),
              ),
              GoRoute(
                path: '${CatalogRoutes.catalogBase}/:slug',
                builder: (context, state) => Scaffold(
                  body: ProductListPage(
                    categoryId: state.pathParameters['slug']!,
                  ),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            drawerNavigationRepositoryProvider.overrideWithValue(
              _FakeDrawerNavigationRepository(
                _buildSinglePageCategoryRootResult(),
              ),
            ),
            categoryCatalogRepositoryProvider.overrideWithValue(
              const _FakeCategoryCatalogRepository(),
            ),
            effectiveStorefrontThemeAsyncProvider.overrideWithValue(
              const AsyncValue.data(StorefrontTheme.nike),
            ),
            plpProvider('shirts').overrideWith(
              (ref) async => const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 1,
                categoryId: 'shirts',
                categoryName: 'Shirts',
                items: [],
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: const Locale('fr'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Start Page'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Tap the category in the drawer: it pushes the PLP onto the stack.
      // (go_router `push` keeps the location at /start, so we assert on the
      // rendered PLP, matching the sport header tests.)
      expect(find.byType(ManagedDrawerTile), findsOneWidget);
      await tester.tap(find.byType(ManagedDrawerTile));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // The PLP back arrow now pops back to page A instead of walking up the
      // catalog hierarchy or falling back to /catalog (which would render the
      // witness "Catalog Root").
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Start Page'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.text('Catalog Root'), findsNothing);
    });
  });
}

void expectTextStyle(
  WidgetTester tester,
  String text, {
  required FontWeight fontWeight,
}) {
  final styles = tester
      .widgetList<Text>(find.text(text))
      .map((widget) => widget.style)
      .whereType<TextStyle>();

  expect(
    styles.any(
      (style) =>
          style.fontFamily == kDrawerFontFamily &&
          style.fontWeight == fontWeight,
    ),
    isTrue,
    reason:
        'Expected "$text" to render with $kDrawerFontFamily and $fontWeight.',
  );
}

DrawerNavigationLoadResult _buildSinglePageCategoryRootResult() {
  const menu = DrawerNavigationMenuData(
    id: 'menu-1',
    name: 'Main drawer',
    code: 'main_drawer',
    displayMode: 'drawer',
    isActive: true,
  );
  // Reproduces the real "Toutes les chaussures" entry: a `page` item whose
  // pageKey resolves to a `/catalog/<slug>` PLP (not a `category` item).
  const root = DrawerNavigationNode(
    item: DrawerNavigationItemData(
      id: 'root-shirts',
      menuId: 'menu-1',
      position: 10,
      label: 'Shirts',
      itemType: DrawerNavigationItemType.page,
      pageKey: 'shirts',
      placement: DrawerNavigationPlacement.nav,
      isActive: true,
      isHidden: false,
    ),
  );

  return DrawerNavigationLoadResult.success(
    menu: menu,
    normalized: const DrawerNavigationNormalizedResult.usable(roots: [root]),
  );
}

DrawerNavigationLoadResult _buildManagedDrawerResult({
  String displayMode = 'drawer',
}) {
  final menu = DrawerNavigationMenuData(
    id: 'menu-1',
    name: 'Main drawer',
    code: 'main_drawer',
    displayMode: displayMode,
    isActive: true,
  );
  const categoryHer = CatalogCategory(
    id: 'cat-her',
    code: 'CAT-HER',
    name: 'Cadeaux pour elle',
    slug: 'cadeaux-pour-elle',
  );
  const categoryHim = CatalogCategory(
    id: 'cat-him',
    code: 'CAT-HIM',
    name: 'Cadeaux pour lui',
    slug: 'cadeaux-pour-lui',
  );
  const mediaHer = CatalogMedia(
    id: 'media-her',
    url: 'https://example.com/her.jpg',
    previewUrl: 'https://example.com/her-preview.jpg',
  );
  const mediaHim = CatalogMedia(
    id: 'media-him',
    url: 'https://example.com/him.jpg',
    previewUrl: 'https://example.com/him-preview.jpg',
  );

  const root = DrawerNavigationNode(
    item: DrawerNavigationItemData(
      id: 'root-1',
      menuId: 'menu-1',
      position: 10,
      label: 'Cadeaux',
      itemType: DrawerNavigationItemType.page,
      pageKey: 'gifts',
      placement: DrawerNavigationPlacement.nav,
      desktopDrawerTemplate: DrawerNavigationDesktopTemplate.promoGrid2x2,
      isActive: true,
      isHidden: false,
    ),
    children: [
      DrawerNavigationNode(
        item: DrawerNavigationItemData(
          id: 'child-nav',
          menuId: 'menu-1',
          parentId: 'root-1',
          position: 10,
          label: 'Découvrez les cadeaux',
          itemType: DrawerNavigationItemType.page,
          pageKey: 'gifts_discover',
          placement: DrawerNavigationPlacement.nav,
          isActive: true,
          isHidden: false,
        ),
      ),
      DrawerNavigationNode(
        item: DrawerNavigationItemData(
          id: 'child-promo-her',
          menuId: 'menu-1',
          parentId: 'root-1',
          position: 20,
          label: 'Cadeaux pour elle',
          itemType: DrawerNavigationItemType.category,
          categoryId: 'cat-her',
          placement: DrawerNavigationPlacement.promo,
          isActive: true,
          isHidden: false,
          category: categoryHer,
          promoMedia: mediaHer,
          promoMediaId: 'media-her',
        ),
      ),
      DrawerNavigationNode(
        item: DrawerNavigationItemData(
          id: 'child-promo-him',
          menuId: 'menu-1',
          parentId: 'root-1',
          position: 30,
          label: 'Cadeaux pour lui',
          itemType: DrawerNavigationItemType.category,
          categoryId: 'cat-him',
          placement: DrawerNavigationPlacement.promo,
          isActive: true,
          isHidden: false,
          category: categoryHim,
          promoMedia: mediaHim,
          promoMediaId: 'media-him',
        ),
      ),
    ],
  );

  return DrawerNavigationLoadResult.success(
    menu: menu,
    normalized: const DrawerNavigationNormalizedResult.usable(roots: [root]),
  );
}

DrawerNavigationLoadResult _buildManagedDrawerResultWithRootPromoOnly() {
  const menu = DrawerNavigationMenuData(
    id: 'menu-1',
    name: 'Main drawer',
    code: 'main_drawer',
    displayMode: 'drawer',
    isActive: true,
  );
  const category = CatalogCategory(
    id: 'cat-vogue',
    code: 'VOGUE',
    name: 'vogue',
    slug: 'vogue',
  );
  const media = CatalogMedia(
    id: 'media-vogue',
    url: 'https://example.com/vogue.jpg',
    previewUrl: 'https://example.com/vogue-preview.jpg',
  );

  const root = DrawerNavigationNode(
    item: DrawerNavigationItemData(
      id: 'root-vogue',
      menuId: 'menu-1',
      position: 10,
      label: 'Mode femme',
      itemType: DrawerNavigationItemType.category,
      categoryId: 'cat-vogue',
      placement: DrawerNavigationPlacement.nav,
      desktopDrawerTemplate: DrawerNavigationDesktopTemplate.heroSingle,
      isActive: true,
      isHidden: false,
      category: category,
      promoMedia: media,
      promoMediaId: 'media-vogue',
    ),
  );

  return const DrawerNavigationLoadResult.success(
    menu: menu,
    normalized: DrawerNavigationNormalizedResult.usable(roots: [root]),
  );
}

DrawerNavigationLoadResult
_buildManagedDrawerResultWithRootPromoAndEditorialTiles() {
  const menu = DrawerNavigationMenuData(
    id: 'menu-1',
    name: 'Main drawer',
    code: 'main_drawer',
    displayMode: 'drawer',
    isActive: true,
  );
  const category = CatalogCategory(
    id: 'cat-vogue',
    code: 'VOGUE',
    name: 'vogue',
    slug: 'vogue',
  );
  const media = CatalogMedia(
    id: 'media-vogue',
    url: 'https://example.com/vogue.jpg',
    previewUrl: 'https://example.com/vogue-preview.jpg',
  );
  final config = _editorialTilesConfig(
    items: [_editorialTile('Tuile éditoriale')],
  );

  final root = DrawerNavigationNode(
    item: DrawerNavigationItemData(
      id: 'root-vogue',
      menuId: 'menu-1',
      position: 10,
      label: 'Mode femme',
      itemType: DrawerNavigationItemType.category,
      categoryId: 'cat-vogue',
      placement: DrawerNavigationPlacement.nav,
      desktopDrawerTemplate: DrawerNavigationDesktopTemplate.heroSingle,
      isActive: true,
      isHidden: false,
      category: category,
      promoMedia: media,
      promoMediaId: 'media-vogue',
      config: {
        drawerEditorialTilesConfigKey: config,
        'futureKey': {'enabled': true},
      },
      editorialTiles: DrawerEditorialTilesConfig.fromJson(config),
    ),
  );

  return DrawerNavigationLoadResult.success(
    menu: menu,
    normalized: DrawerNavigationNormalizedResult.usable(roots: [root]),
  );
}

DrawerNavigationLoadResult _buildManagedDrawerResultWithEmptyEditorialTiles() {
  const menu = DrawerNavigationMenuData(
    id: 'menu-1',
    name: 'Main drawer',
    code: 'main_drawer',
    displayMode: 'drawer',
    isActive: true,
  );
  const category = CatalogCategory(
    id: 'cat-vogue',
    code: 'VOGUE',
    name: 'vogue',
    slug: 'vogue',
  );
  const media = CatalogMedia(
    id: 'media-vogue',
    url: 'https://example.com/vogue.jpg',
    previewUrl: 'https://example.com/vogue-preview.jpg',
  );
  const config = {
    'type': drawerEditorialTilesType,
    'layout': {'mode': 'auto', 'forced': null},
    'items': [],
  };

  const root = DrawerNavigationNode(
    item: DrawerNavigationItemData(
      id: 'root-vogue',
      menuId: 'menu-1',
      position: 10,
      label: 'Mode femme',
      itemType: DrawerNavigationItemType.category,
      categoryId: 'cat-vogue',
      placement: DrawerNavigationPlacement.nav,
      desktopDrawerTemplate: DrawerNavigationDesktopTemplate.heroSingle,
      isActive: true,
      isHidden: false,
      category: category,
      promoMedia: media,
      promoMediaId: 'media-vogue',
      config: {drawerEditorialTilesConfigKey: config},
    ),
  );

  return const DrawerNavigationLoadResult.success(
    menu: menu,
    normalized: DrawerNavigationNormalizedResult.usable(roots: [root]),
  );
}

DrawerNavigationLoadResult _buildManagedDrawerResultWithTwoRoots({
  bool secondRootHidden = false,
}) {
  const menu = DrawerNavigationMenuData(
    id: 'menu-1',
    name: 'Main drawer',
    code: 'main_drawer',
    displayMode: 'drawer',
    isActive: true,
  );
  const categoryVogue = CatalogCategory(
    id: 'cat-vogue',
    code: 'VOGUE',
    name: 'vogue',
    slug: 'vogue',
  );
  const categoryMen = CatalogCategory(
    id: 'cat-men',
    code: 'MEN',
    name: 'homme',
    slug: 'homme',
  );
  const media = CatalogMedia(
    id: 'media-vogue',
    url: 'https://example.com/vogue.jpg',
    previewUrl: 'https://example.com/vogue-preview.jpg',
  );

  final roots = [
    const DrawerNavigationNode(
      item: DrawerNavigationItemData(
        id: 'root-vogue',
        menuId: 'menu-1',
        position: 10,
        label: 'Mode femme',
        itemType: DrawerNavigationItemType.category,
        categoryId: 'cat-vogue',
        placement: DrawerNavigationPlacement.nav,
        desktopDrawerTemplate: DrawerNavigationDesktopTemplate.heroSingle,
        isActive: true,
        isHidden: false,
        category: categoryVogue,
        promoMedia: media,
        promoMediaId: 'media-vogue',
      ),
    ),
    DrawerNavigationNode(
      item: DrawerNavigationItemData(
        id: 'root-men',
        menuId: 'menu-1',
        position: 20,
        label: 'Mode homme',
        itemType: DrawerNavigationItemType.category,
        categoryId: 'cat-men',
        placement: DrawerNavigationPlacement.nav,
        desktopDrawerTemplate: DrawerNavigationDesktopTemplate.heroSingle,
        isActive: true,
        isHidden: secondRootHidden,
        category: categoryMen,
      ),
    ),
  ];

  return DrawerNavigationLoadResult.success(
    menu: menu,
    normalized: DrawerNavigationNormalizedResult.usable(roots: roots),
  );
}

class _FakeDrawerNavigationRepository implements DrawerNavigationRepository {
  final DrawerNavigationLoadResult result;

  const _FakeDrawerNavigationRepository(this.result);

  @override
  Future<DrawerNavigationLoadResult> fetchMainDrawer({
    required String locale,
    bool includeHidden = false,
  }) async => result;
}

class _RecordingDrawerNavigationRepository
    implements DrawerNavigationRepository {
  final DrawerNavigationLoadResult result;
  final includeHiddenCalls = <bool>[];

  _RecordingDrawerNavigationRepository(this.result);

  @override
  Future<DrawerNavigationLoadResult> fetchMainDrawer({
    required String locale,
    bool includeHidden = false,
  }) async {
    includeHiddenCalls.add(includeHidden);
    return result;
  }
}

class _FakeCategoryCatalogRepository implements CategoryCatalogRepository {
  static const _categories = [
    CatalogCategory(
      id: 'cat-home',
      code: 'HOME',
      name: 'Maison',
      slug: 'maison',
    ),
    CatalogCategory(
      id: 'cat-lamps',
      code: 'LAMPS',
      name: 'Lampes',
      slug: 'lampes',
      parentId: 'cat-home',
    ),
    CatalogCategory(
      id: 'cat-kitchen',
      code: 'KITCHEN',
      name: 'Cuisine',
      slug: 'cuisine',
    ),
  ];

  final List<CatalogCategory> categories;

  const _FakeCategoryCatalogRepository([this.categories = _categories]);

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async => categories;

  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async {
    for (final category in categories) {
      if (category.slug == slug) {
        return category;
      }
    }
    return null;
  }

  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async {
    return CatalogPageData(
      page: page,
      perPage: perPage,
      totalItems: 0,
      totalPages: 0,
      categoryId: categoryId,
      items: const [],
    );
  }

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async =>
      categories.isEmpty ? null : categories.first;

  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String locale,
    required String categorySlug,
    required String productSlug,
  }) async => null;
}

class _RecordingCategoryCatalogRepository
    extends _FakeCategoryCatalogRepository {
  final includeHiddenCalls = <bool>[];

  _RecordingCategoryCatalogRepository();

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async {
    includeHiddenCalls.add(includeHidden);
    return super.getActiveCategories(
      includeHidden: includeHidden,
      locale: locale,
    );
  }
}

class _SequencedDrawerNavigationRepository
    implements DrawerNavigationRepository {
  final List<DrawerNavigationLoadResult> results;
  int callCount = 0;

  _SequencedDrawerNavigationRepository(this.results);

  @override
  Future<DrawerNavigationLoadResult> fetchMainDrawer({
    required String locale,
    bool includeHidden = false,
  }) async {
    final index = callCount < results.length ? callCount : results.length - 1;
    callCount += 1;
    return results[index];
  }
}

Map<String, dynamic> _editorialTilesConfig({
  required List<Map<String, dynamic>> items,
}) {
  return {
    'type': drawerEditorialTilesType,
    'layout': {'mode': 'auto', 'forced': null},
    'items': items,
  };
}

Map<String, dynamic> _editorialTile(String title) {
  return {
    'title': title,
    'link': '/editorial/$title',
    'media': {
      'recordId': 'media-editorial',
      'collectionId': 'medias',
      'filename': 'editorial.webp',
      'alt': title,
    },
    'isActive': true,
  };
}

class _RecordingAdminBackofficeRepository implements AdminBackofficeRepository {
  String? createdCollection;
  Map<String, dynamic>? createdData;
  String? updatedCollection;
  String? updatedRecordId;
  Map<String, dynamic>? updatedData;
  final updateCalls = <_AdminUpdateCall>[];

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
    createdCollection = collection;
    createdData = Map<String, dynamic>.from(data);
    return {'id': 'menu-1', ...data};
  }

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    updatedCollection = collection;
    updatedRecordId = recordId;
    updatedData = Map<String, dynamic>.from(data);
    updateCalls.add(
      _AdminUpdateCall(
        collection: collection,
        recordId: recordId,
        data: Map<String, dynamic>.from(data),
      ),
    );
    return data;
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
  }) async => <String, dynamic>{};

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

class _AdminUpdateCall {
  final String collection;
  final String recordId;
  final Map<String, dynamic> data;

  const _AdminUpdateCall({
    required this.collection,
    required this.recordId,
    required this.data,
  });
}
