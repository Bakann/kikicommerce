import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// `Override` lives in the `riverpod` core package.
// ignore: depend_on_referenced_packages
import 'package:riverpod/misc.dart' show Override;
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/application/storefront/storefront_brand_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_navigation_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/category_providers.dart';
import 'package:kiki_commerce/presentation/providers/product_providers.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_route_page.dart';
import 'package:kiki_commerce/presentation/screens/storefront_home_page.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/floating_bottom_nav.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/main_shell.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/premium_shell_navbar.dart';

void main() {
  testWidgets('luxe apparence renders the premium top nav and no bottom nav', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(tester, theme: StorefrontTheme.dior);
    await tester.pump();

    expect(find.byType(PremiumShellNavbar), findsOneWidget);
    expect(find.byType(FloatingBottomNav), findsNothing);
  });

  testWidgets('sport apparence renders the bottom nav and no top nav', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(tester, theme: StorefrontTheme.nike);
    await tester.pump();

    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(find.byType(PremiumShellNavbar), findsNothing);
  });

  testWidgets('sport chrome catalog PLP loading keeps the simple Home icon', (
    tester,
  ) async {
    final category = Completer<CatalogCategory?>();
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(
      tester,
      theme: StorefrontTheme.nike,
      initialLocation: '/en/catalog/usui-takumi',
      childRoutes: [
        GoRoute(
          path: '/en/catalog/:categorySlug',
          builder: (context, state) => StorefrontHomePage(
            categorySlug: state.pathParameters['categorySlug'],
          ),
        ),
      ],
      overrides: [
        categoryBySlugProvider(
          'usui-takumi',
        ).overrideWith((ref) => category.future),
      ],
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('sport chrome catalog PDP route loading keeps simple Home', (
    tester,
  ) async {
    final routeData = Completer<CatalogProductRouteData?>();
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(
      tester,
      theme: StorefrontTheme.nike,
      initialLocation:
          '/en/catalog/usui-takumi/tension-silencieuse-denim-absolu',
      childRoutes: [
        GoRoute(
          path: '/en/catalog/:categorySlug/:productSlug',
          builder: (context, state) => ProductDetailRoutePage(
            categorySlug: state.pathParameters['categorySlug']!,
            productSlug: state.pathParameters['productSlug']!,
          ),
        ),
      ],
      overrides: [
        productRouteProvider((
          categorySlug: 'usui-takumi',
          productSlug: 'tension-silencieuse-denim-absolu',
        )).overrideWith((ref) => routeData.future),
      ],
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('sport chrome catalog PDP detail loading keeps simple Home', (
    tester,
  ) async {
    final detail = Completer<ProductDetailData>();
    const category = CatalogCategory(
      id: 'usui-takumi',
      code: 'USUI-TAKUMI',
      name: 'Usui Takumi',
      slug: 'usui-takumi',
    );
    await _setViewport(tester, const Size(390, 800));
    await _pumpShell(
      tester,
      theme: StorefrontTheme.nike,
      initialLocation:
          '/en/catalog/usui-takumi/tension-silencieuse-denim-absolu',
      childRoutes: [
        GoRoute(
          path: '/en/catalog/:categorySlug/:productSlug',
          builder: (context, state) => ProductDetailRoutePage(
            categorySlug: state.pathParameters['categorySlug']!,
            productSlug: state.pathParameters['productSlug']!,
            hint: const ProductDetailRouteHint(
              productId: 'tension-denim',
              category: category,
            ),
          ),
        ),
      ],
      overrides: [
        pdpProvider('tension-denim').overrideWith((ref) => detail.future),
      ],
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required StorefrontTheme theme,
  String initialLocation = '/catalog',
  List<RouteBase>? childRoutes,
  List<Override> overrides = const [],
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            MainShell(routeKey: state.uri.toString(), child: child),
        routes:
            childRoutes ??
            [
              GoRoute(
                path: '/catalog',
                builder: (context, state) => const SizedBox(height: 1200),
              ),
            ],
      ),
    ],
  );
  addTearDown(router.dispose);

  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        editingStorefrontThemeProvider.overrideWith((ref) => theme),
        storefrontBrandSettingsProvider.overrideWith(
          (ref) async => const StorefrontBrandSettings(
            id: 'settings-id',
            title: 'Atelier Kiki',
            href: '/',
          ),
        ),
        storefrontNavigationSettingsProvider.overrideWith(
          (ref) async => const StorefrontNavigationSettings(
            mobileMenuStyle: MobileMenuStyle.drawer,
          ),
        ),
        drawerNavigationRepositoryProvider.overrideWithValue(
          const _FallbackDrawerNavigationRepository(),
        ),
        categoryCatalogRepositoryProvider.overrideWithValue(
          const _EmptyCategoryRepository(),
        ),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router),
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
