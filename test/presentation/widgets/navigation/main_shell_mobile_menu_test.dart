import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/application/storefront/storefront_brand_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_navigation_settings.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/main_shell.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/mobile_fullscreen_menu_overlay.dart';

import '../../../support/l10n_harness.dart';

void main() {
  testWidgets('mobile drawer setting opens the classic drawer', (tester) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(tester, MobileMenuStyle.drawer);

    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pumpAndSettle();

    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    expect(scaffold.isDrawerOpen, isTrue);
    expect(find.byKey(MobileFullscreenMenuOverlay.overlayKey), findsNothing);
  });

  testWidgets('mobile fullscreenReveal setting opens the overlay', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(tester, MobileMenuStyle.fullscreenReveal);

    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump(const Duration(milliseconds: 300));

    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    expect(scaffold.isDrawerOpen, isFalse);
    expect(find.byKey(MobileFullscreenMenuOverlay.overlayKey), findsOneWidget);
  });

  testWidgets(
    'mobile fullscreenReveal navigation keeps panel mounted during circular reveal',
    (tester) async {
      await _setViewport(tester, const Size(390, 800));
      await _pumpShell(tester, MobileMenuStyle.fullscreenReveal);

      await tester.pump();
      await tester.tap(find.byTooltip('Ouvrir le menu'));
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byKey(MobileFullscreenMenuOverlay.panelKey), findsOneWidget);
      expect(
        find.byKey(MobileFullscreenMenuOverlay.overlayKey),
        findsOneWidget,
      );
      expect(_panelHeight(tester), greaterThan(0));
    },
  );

  testWidgets('mobile fullscreenReveal menu stores tapped icon origin', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(tester, MobileMenuStyle.fullscreenReveal);

    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump();

    final overlay = tester.widget<MobileFullscreenMenuOverlay>(
      find.byType(MobileFullscreenMenuOverlay),
    );
    expect(overlay.mode, MobileFullscreenMenuMode.navigation);
    expect(overlay.revealOriginGlobal, isNotNull);
    expect(overlay.revealOriginGlobal!.dx, lessThan(390 / 2));
  });

  testWidgets('mobile fullscreenReveal search opens premium search overlay', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(tester, MobileMenuStyle.fullscreenReveal);

    await tester.pump();
    await tester.tap(find.byTooltip('Recherche'));
    await tester.pump(const Duration(milliseconds: 300));

    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    expect(scaffold.isDrawerOpen, isFalse);
    expect(find.byKey(MobileFullscreenMenuOverlay.overlayKey), findsOneWidget);
    expect(
      find.byKey(MobileFullscreenMenuOverlay.searchFieldKey),
      findsOneWidget,
    );
    expect(find.byTooltip('Fermer le menu'), findsOneWidget);
  });

  testWidgets('mobile fullscreenReveal search stores tapped icon origin', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(tester, MobileMenuStyle.fullscreenReveal);

    await tester.pump();
    await tester.tap(find.byTooltip('Recherche'));
    await tester.pump();

    final overlay = tester.widget<MobileFullscreenMenuOverlay>(
      find.byType(MobileFullscreenMenuOverlay),
    );
    expect(overlay.mode, MobileFullscreenMenuMode.search);
    expect(overlay.revealOriginGlobal, isNotNull);
    expect(overlay.revealOriginGlobal!.dx, lessThan(390 / 2));
  });

  testWidgets(
    'mobile fullscreenReveal search keeps panel mounted during circular reveal',
    (tester) async {
      await _setViewport(tester, const Size(390, 800));
      await _pumpShell(tester, MobileMenuStyle.fullscreenReveal);

      await tester.pump();
      await tester.tap(find.byTooltip('Recherche'));
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byKey(MobileFullscreenMenuOverlay.panelKey), findsOneWidget);
      expect(
        find.byKey(MobileFullscreenMenuOverlay.overlayKey),
        findsOneWidget,
      );
      expect(
        find.byKey(MobileFullscreenMenuOverlay.searchFieldKey),
        findsOneWidget,
      );
      expect(_panelHeight(tester), greaterThan(0));
    },
  );

  testWidgets('mobile fullscreenReveal navigation close resets panel height', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(tester, MobileMenuStyle.fullscreenReveal);

    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Fermer le menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_panelHeight(tester), 0);
  });

  testWidgets('mobile fullscreenReveal search close keeps navigation hidden', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(tester, MobileMenuStyle.fullscreenReveal);

    await tester.pump();
    await tester.tap(find.byTooltip('Recherche'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Fermer le menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    expect(scaffold.isDrawerOpen, isFalse);
    expect(
      tester.getSize(find.byKey(MobileFullscreenMenuOverlay.panelKey)).height,
      0,
    );
    expect(find.byKey(MobileFullscreenMenuOverlay.contentKey), findsNothing);
  });

  testWidgets(
    'mobile fullscreenReveal reduced motion opens navigation instantly',
    (tester) async {
      await _setViewport(tester, const Size(390, 800));
      await _pumpShell(
        tester,
        MobileMenuStyle.fullscreenReveal,
        disableAnimations: true,
      );

      await tester.pump();
      await tester.tap(find.byTooltip('Ouvrir le menu'));
      await tester.pump();

      expect(_panelHeight(tester), greaterThan(700));
      expect(
        find.byKey(MobileFullscreenMenuOverlay.contentKey),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Fermer le menu'));
      await tester.pump();

      expect(_panelHeight(tester), 0);
    },
  );

  testWidgets('mobile fullscreenReveal reduced motion opens search instantly', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(
      tester,
      MobileMenuStyle.fullscreenReveal,
      disableAnimations: true,
    );

    await tester.pump();
    await tester.tap(find.byTooltip('Recherche'));
    await tester.pump();

    expect(_panelHeight(tester), greaterThan(700));
    expect(
      find.byKey(MobileFullscreenMenuOverlay.searchFieldKey),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Fermer le menu'));
    await tester.pump();

    expect(_panelHeight(tester), 0);
    expect(find.byKey(MobileFullscreenMenuOverlay.contentKey), findsNothing);
  });

  testWidgets('desktop fullscreenReveal setting falls back to classic drawer', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1180, 900));
    await _pumpShell(tester, MobileMenuStyle.fullscreenReveal);

    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pumpAndSettle();

    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    expect(scaffold.isDrawerOpen, isTrue);
    expect(find.byKey(MobileFullscreenMenuOverlay.overlayKey), findsNothing);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

double _panelHeight(WidgetTester tester) =>
    tester.getSize(find.byKey(MobileFullscreenMenuOverlay.panelKey)).height;

Future<void> _pumpShell(
  WidgetTester tester,
  MobileMenuStyle style, {
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        storefrontBrandSettingsProvider.overrideWith(
          (ref) async => const StorefrontBrandSettings(
            id: 'settings-id',
            title: 'Atelier Kiki',
            href: '/',
          ),
        ),
        storefrontNavigationSettingsProvider.overrideWith(
          (ref) async => StorefrontNavigationSettings(mobileMenuStyle: style),
        ),
        drawerNavigationRepositoryProvider.overrideWithValue(
          const _FallbackDrawerNavigationRepository(),
        ),
        categoryCatalogRepositoryProvider.overrideWithValue(
          const _EmptyCategoryRepository(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        locale: const Locale('fr'),
        builder: (context, child) {
          if (!disableAnimations) {
            return child!;
          }
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          );
        },
        home: const MainShell(
          routeKey: '/catalog',
          child: SizedBox(height: 1200),
        ),
      ),
    ),
  );
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

class _EmptyCategoryRepository implements CategoryCatalogRepository {
  const _EmptyCategoryRepository();

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async {
    return const [];
  }

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async =>
      null;

  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async => null;

  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String locale,
    required String categorySlug,
    required String productSlug,
  }) async {
    throw UnimplementedError();
  }
}
