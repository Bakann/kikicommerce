import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:kiki_commerce/presentation/widgets/navigation/collapsing_line_icon.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/mobile_fullscreen_menu_overlay.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/premium_navbar_surface.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/premium_shell_navbar.dart';

import '../../../support/l10n_harness.dart';

void main() {
  testWidgets('normal mode reserves top padding and starts light', (
    tester,
  ) async {
    const childKey = ValueKey('shell-child');

    await _pumpShell(
      tester,
      child: const SizedBox(
        key: childKey,
        height: 1200,
        child: ColoredBox(color: Colors.red),
      ),
    );

    expect(tester.getTopLeft(find.byKey(childKey)).dy, 72);
    expect(_surfaceDecoration(tester).color, const Color(0xF5FFFFFF));
  });

  testWidgets('normal mode hides on scroll down and shows on scroll up', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpShell(tester, child: _scrollable(controller));

    controller.jumpTo(48);
    await tester.pump();

    var ignorePointer = tester.widget<IgnorePointer>(
      find.byKey(PremiumNavbarSurface.ignorePointerKey),
    );
    expect(ignorePointer.ignoring, isTrue);

    controller.jumpTo(32);
    await tester.pump();

    ignorePointer = tester.widget<IgnorePointer>(
      find.byKey(PremiumNavbarSurface.ignorePointerKey),
    );
    expect(ignorePointer.ignoring, isFalse);
  });

  testWidgets('normal mode collapses reserved padding after scroll down', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpShell(tester, child: _scrollable(controller));

    expect(_scrollableTop(tester), 72);

    controller.jumpTo(48);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(_scrollableTop(tester), 0);
  });

  testWidgets('normal mode scroll up mid-page shows navbar without padding', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpShell(tester, child: _scrollable(controller));

    controller.jumpTo(48);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    controller.jumpTo(32);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    final ignorePointer = tester.widget<IgnorePointer>(
      find.byKey(PremiumNavbarSurface.ignorePointerKey),
    );
    expect(ignorePointer.ignoring, isFalse);
    expect(_scrollableTop(tester), 0);
  });

  testWidgets('forceVisibleLight keeps reserved padding after scroll', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpShell(
      tester,
      forceVisibleLight: true,
      child: _scrollable(controller),
    );

    controller.jumpTo(48);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(_scrollableTop(tester), 72);
  });

  testWidgets('immersive mode does not reserve top padding and starts hero', (
    tester,
  ) async {
    const childKey = ValueKey('shell-child');

    await _pumpShell(
      tester,
      immersive: true,
      heroHeight: 600,
      child: const SizedBox(
        key: childKey,
        height: 1200,
        child: ColoredBox(color: Colors.red),
      ),
    );

    expect(tester.getTopLeft(find.byKey(childKey)).dy, 0);
    expect(_surfaceDecoration(tester).color, const Color(0x00FFFFFF));
  });

  testWidgets('immersive mode turns light after scrolling past the hero', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpShell(
      tester,
      immersive: true,
      heroHeight: 400,
      child: _scrollable(controller),
    );

    expect(_surfaceDecoration(tester).color, const Color(0x00FFFFFF));

    controller.jumpTo(360);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(_surfaceDecoration(tester).color, const Color(0xF5FFFFFF));
    expect(_scrollableTop(tester), 0);
  });

  testWidgets('route key change resets a hidden navbar to visible', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpShell(
      tester,
      routeKey: '/catalog/a',
      child: _scrollable(controller),
    );

    controller.jumpTo(48);
    await tester.pump();

    var ignorePointer = tester.widget<IgnorePointer>(
      find.byKey(PremiumNavbarSurface.ignorePointerKey),
    );
    expect(ignorePointer.ignoring, isTrue);

    await _pumpShell(
      tester,
      routeKey: '/catalog/b',
      child: _scrollable(controller),
    );

    ignorePointer = tester.widget<IgnorePointer>(
      find.byKey(PremiumNavbarSurface.ignorePointerKey),
    );
    expect(ignorePointer.ignoring, isFalse);
  });

  testWidgets(
    'fullscreen reveal opens overlay without classic drawer callback',
    (tester) async {
      var recordOpenCalls = 0;
      var classicDrawerCalls = 0;

      await _pumpShell(
        tester,
        useFullscreenReveal: true,
        onMenuOpenStarted: () => recordOpenCalls++,
        onClassicMenuRequested: () => classicDrawerCalls++,
        child: const SizedBox(height: 1200),
      );

      await tester.pump();
      await tester.tap(find.byTooltip('Ouvrir le menu'));

      expect(recordOpenCalls, 1);
      expect(classicDrawerCalls, 0);

      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(MobileFullscreenMenuOverlay.overlayKey),
        findsOneWidget,
      );
      expect(find.byTooltip('Fermer le menu'), findsOneWidget);
    },
  );

  testWidgets('fullscreen reveal forces light navbar chrome when open', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      immersive: true,
      heroHeight: 600,
      useFullscreenReveal: true,
      child: const SizedBox(height: 1200),
    );

    await tester.pump();
    expect(_surfaceDecoration(tester).color, const Color(0x00FFFFFF));

    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_surfaceDecoration(tester).color, const Color(0xF5FFFFFF));
    expect(_surfaceDecoration(tester).border?.bottom.color, Colors.transparent);
    final lineIcons = tester.widgetList<DiorCollapsingLineIcon>(
      find.byType(DiorCollapsingLineIcon),
    );
    expect(
      lineIcons.every((icon) => icon.color == const Color(0xFF202020)),
      isTrue,
    );
  });

  testWidgets('fullscreen reveal closes from X and Escape', (tester) async {
    await _pumpShell(
      tester,
      useFullscreenReveal: true,
      child: const SizedBox(height: 1200),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Fermer le menu'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer le menu'));
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.byTooltip('Ouvrir le menu'), findsOneWidget);

    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.byTooltip('Ouvrir le menu'), findsOneWidget);
  });

  testWidgets('fullscreen reveal closes on route key change', (tester) async {
    await _pumpShell(
      tester,
      routeKey: '/catalog/a',
      useFullscreenReveal: true,
      child: const SizedBox(height: 1200),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Fermer le menu'), findsOneWidget);

    await _pumpShell(
      tester,
      routeKey: '/catalog/b',
      useFullscreenReveal: true,
      child: const SizedBox(height: 1200),
    );
    await tester.pump();

    expect(find.byTooltip('Ouvrir le menu'), findsOneWidget);
  });

  testWidgets('fullscreen reveal closes when setting falls back to drawer', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      useFullscreenReveal: true,
      child: const SizedBox(height: 1200),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Fermer le menu'), findsOneWidget);

    await _pumpShell(
      tester,
      useFullscreenReveal: false,
      child: const SizedBox(height: 1200),
    );
    await tester.pump();

    expect(find.byTooltip('Ouvrir le menu'), findsOneWidget);
    expect(find.byKey(MobileFullscreenMenuOverlay.overlayKey), findsNothing);
  });
}

Widget _scrollable(ScrollController controller) {
  return ListView(
    key: const ValueKey('shell-scrollable'),
    controller: controller,
    children: const [SizedBox(height: 1600)],
  );
}

double _scrollableTop(WidgetTester tester) {
  return tester.getTopLeft(find.byKey(const ValueKey('shell-scrollable'))).dy;
}

BoxDecoration _surfaceDecoration(WidgetTester tester) {
  final surface = tester.widget<AnimatedContainer>(
    find.byKey(PremiumNavbarSurface.surfaceKey),
  );
  return surface.decoration! as BoxDecoration;
}

Future<void> _pumpShell(
  WidgetTester tester, {
  String routeKey = '/catalog',
  bool immersive = false,
  double heroHeight = 0,
  bool forceVisibleLight = false,
  bool useFullscreenReveal = false,
  VoidCallback? onMenuOpenStarted,
  VoidCallback? onClassicMenuRequested,
  required Widget child,
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
          (ref) async => StorefrontNavigationSettings.fallback,
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
        home: Scaffold(
          body: PremiumShellNavbar(
            routeKey: routeKey,
            immersive: immersive,
            heroHeight: heroHeight,
            forceVisibleLight: forceVisibleLight,
            useFullscreenReveal: useFullscreenReveal,
            onMenuOpenStarted: onMenuOpenStarted,
            onClassicMenuRequested: onClassicMenuRequested,
            child: child,
          ),
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
