import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_category_drawer.dart';

import '../../support/l10n_harness.dart';

void main() {
  testWidgets('drawer variant can render the close header', (tester) async {
    await _pumpContent(
      tester,
      variant: StorefrontNavigationMenuVariant.drawer,
      showCloseHeader: true,
    );

    await tester.pump();

    expect(find.text('Fermer'), findsOneWidget);
  });

  testWidgets('fullscreen variant can hide the close header', (tester) async {
    await _pumpContent(
      tester,
      variant: StorefrontNavigationMenuVariant.fullscreen,
      showCloseHeader: false,
    );

    await tester.pump();

    expect(find.text('Fermer'), findsNothing);
  });

  testWidgets('back tile goes up one level in a 3-level tree (not to the top)', (
    tester,
  ) async {
    await _pumpContent(
      tester,
      variant: StorefrontNavigationMenuVariant.drawer,
      showCloseHeader: true,
      categories: _threeLevelTree(),
    );
    await tester.pumpAndSettle();

    // Top level: the segment roots.
    expect(find.text('Homme'), findsOneWidget);
    expect(find.text('Femme'), findsOneWidget);

    // Drill into Homme → its mid-level categories.
    await tester.tap(find.text('Homme'));
    await tester.pumpAndSettle();
    expect(find.text('Chaussures'), findsOneWidget);
    expect(find.text('Vêtements'), findsOneWidget);
    expect(find.text('Femme'), findsNothing);
    // The intermediate "Chaussures" (which has children) shows a '>' disclosure;
    // childless mids (Vêtements/Sport here) do not.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    // Drill into Chaussures → its leaves (back tile now reads "Chaussures").
    await tester.tap(find.text('Chaussures'));
    await tester.pumpAndSettle();
    expect(find.text('Lifestyle'), findsOneWidget);
    expect(find.text('Jordan'), findsOneWidget);

    // Tap the back tile: must return to Homme's children, NOT the top level.
    await tester.tap(find.text('Chaussures'));
    await tester.pumpAndSettle();
    expect(find.text('Vêtements'), findsOneWidget); // Homme's children again
    expect(find.text('Lifestyle'), findsNothing); // left the leaves
    expect(find.text('Femme'), findsNothing); // did NOT jump to the top
  });

  testWidgets(
    'category tapped from the drawer while in the sport flow opens inside the '
    'sport shell, not the catalog shell',
    (tester) async {
      // Regression: the drawer used to navigate straight to /catalog/<slug>
      // (MainShell → different bottom nav), whereas a landing tile keeps you in
      // /sport/<segment>/<slug> (SportFlowShell → same nav). The drawer now
      // applies the same sportContextualCmsHref rewrite as the tiles.
      final router = GoRouter(
        initialLocation: '/sport/homme',
        routes: [
          GoRoute(
            path: '/sport/:segment',
            builder: (context, state) => Scaffold(
              body: StorefrontNavigationMenuContent(
                variant: StorefrontNavigationMenuVariant.drawer,
                showCloseHeader: false,
                showFooter: false,
                onClose: () {},
              ),
            ),
          ),
          // Destinations, both neutral and fr-localized (the content locale
          // resolves to the fr fallback here, so navigation is /fr-prefixed).
          for (final prefix in const ['', '/fr'])
            GoRoute(
              path: '$prefix/sport/:segment/:categorySlug',
              builder: (context, state) => Scaffold(
                body: Text(
                  'sport-plp:${state.pathParameters['segment']}/'
                  '${state.pathParameters['categorySlug']}',
                ),
              ),
            ),
          for (final prefix in const ['', '/fr'])
            GoRoute(
              path: '$prefix/catalog/:slug',
              builder: (context, state) => Scaffold(
                body: Text('catalog-plp:${state.pathParameters['slug']}'),
              ),
            ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            drawerNavigationRepositoryProvider.overrideWithValue(
              const _FallbackDrawerNavigationRepository(),
            ),
            categoryCatalogRepositoryProvider.overrideWithValue(
              _ListCategoryRepository(const [
                CatalogCategory(
                  id: 'shirts',
                  code: 'SHIRTS',
                  name: 'Shirts',
                  slug: 'shirts',
                ),
              ]),
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

      // "Shirts" is childless, so the tap navigates instead of drilling.
      await tester.tap(find.text('Shirts'));
      await tester.pumpAndSettle();

      // The PLP opened inside the sport shell (/sport/homme/shirts), NOT the
      // catalog shell (/catalog/shirts) — same bottom nav as a landing tile.
      expect(find.text('sport-plp:homme/shirts'), findsOneWidget);
      expect(find.textContaining('catalog-plp'), findsNothing);
    },
  );
}

List<CatalogCategory> _threeLevelTree() {
  return const [
    CatalogCategory(id: 'homme', code: 'HOMME', name: 'Homme', slug: 'homme'),
    CatalogCategory(id: 'femme', code: 'FEMME', name: 'Femme', slug: 'femme'),
    CatalogCategory(
      id: 'enfant',
      code: 'ENFANT',
      name: 'Enfant',
      slug: 'enfant',
    ),
    CatalogCategory(
      id: 'h-chaussures',
      code: 'HOMME_CHAUSSURES',
      name: 'Chaussures',
      slug: 'homme-chaussures',
      parentId: 'homme',
      position: 10,
    ),
    CatalogCategory(
      id: 'h-vetements',
      code: 'HOMME_VETEMENTS',
      name: 'Vêtements',
      slug: 'homme-vetements',
      parentId: 'homme',
      position: 20,
    ),
    CatalogCategory(
      id: 'h-sport',
      code: 'HOMME_SPORT',
      name: 'Sport',
      slug: 'homme-sport',
      parentId: 'homme',
      position: 30,
    ),
    CatalogCategory(
      id: 'h-ch-lifestyle',
      code: 'HOMME_CHAUSSURES_LIFESTYLE',
      name: 'Lifestyle',
      slug: 'homme-chaussures-lifestyle',
      parentId: 'h-chaussures',
      position: 10,
    ),
    CatalogCategory(
      id: 'h-ch-jordan',
      code: 'HOMME_CHAUSSURES_JORDAN',
      name: 'Jordan',
      slug: 'homme-chaussures-jordan',
      parentId: 'h-chaussures',
      position: 20,
    ),
  ];
}

Future<void> _pumpContent(
  WidgetTester tester, {
  required StorefrontNavigationMenuVariant variant,
  required bool showCloseHeader,
  List<CatalogCategory> categories = const [],
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        drawerNavigationRepositoryProvider.overrideWithValue(
          const _FallbackDrawerNavigationRepository(),
        ),
        categoryCatalogRepositoryProvider.overrideWithValue(
          _ListCategoryRepository(categories),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(
          body: StorefrontNavigationMenuContent(
            variant: variant,
            showCloseHeader: showCloseHeader,
            showFooter: true,
            onClose: () {},
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

class _ListCategoryRepository implements CategoryCatalogRepository {
  final List<CatalogCategory> categories;

  const _ListCategoryRepository(this.categories);

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async {
    return categories;
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
