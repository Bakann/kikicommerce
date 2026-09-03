import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/cms/cms_page_repository.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/category_plp_hero_provider.dart';
import 'package:kiki_commerce/presentation/providers/category_providers.dart';
import 'package:kiki_commerce/presentation/providers/cms_page_provider.dart';
import 'package:kiki_commerce/presentation/providers/product_providers.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/screens/product_list_page.dart';
import 'package:kiki_commerce/presentation/widgets/animations/add_to_cart_comet/add_to_cart_comet.dart';

import '../../support/l10n_harness.dart';

void main() {
  testWidgets('sport PLP header shows back arrow and category once', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveStorefrontThemeAsyncProvider.overrideWithValue(
            const AsyncValue.data(StorefrontTheme.nike),
          ),
          plpProvider('boots').overrideWith(
            (ref) async => const CatalogPageData(
              page: 1,
              perPage: 20,
              totalItems: 0,
              totalPages: 1,
              categoryId: 'boots',
              categoryName: "Men's Football Boots",
              items: [],
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
          home: const Scaffold(body: ProductListPage(categoryId: 'boots')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text("Men's Football Boots"), findsOneWidget);
  });

  testWidgets('sport PLP with carried hero image keeps CMS PLP cold', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 760));
    tester.view.physicalSize = const Size(430, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var cmsPlpReads = 0;
    final router = GoRouter(
      initialLocation: '/fr/sport/homme/boots',
      routes: [
        GoRoute(
          path: '${CatalogRoutes.sportBase}/:segment',
          builder: (_, state) => Scaffold(
            body: Text('Segment ${state.pathParameters['segment']}'),
          ),
        ),
        GoRoute(
          path: '${CatalogRoutes.sportBase}/:segment/:categorySlug',
          builder: (_, state) => Scaffold(
            body: ProductListPage(
              categoryId: state.pathParameters['categorySlug']!,
              heroSlugKey: state.pathParameters['categorySlug']!,
            ),
          ),
        ),
        GoRoute(
          path: '/fr${CatalogRoutes.sportBase}/:segment',
          builder: (_, state) => Scaffold(
            body: Text('Segment ${state.pathParameters['segment']}'),
          ),
        ),
        GoRoute(
          path: '/fr${CatalogRoutes.sportBase}/:segment/:categorySlug',
          builder: (_, state) => Scaffold(
            body: ProductListPage(
              categoryId: state.pathParameters['categorySlug']!,
              heroSlugKey: state.pathParameters['categorySlug']!,
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveStorefrontThemeAsyncProvider.overrideWithValue(
            const AsyncValue.data(StorefrontTheme.nike),
          ),
          activeCategoriesProvider.overrideWith((ref) async => const []),
          categoryPlpHeroShuttleProvider('boots').overrideWith(
            (ref) => const CategoryPlpHeroShuttle(
              imageUrl: 'https://example.test/boots-tile.jpg',
            ),
          ),
          plpProvider(
            'boots',
          ).overrideWith((ref) async => _pageDataWithProducts('boots')),
          cmsPlpProvider(
            const CmsPlpRequest(categoryId: 'boots', locale: defaultCmsLocale),
          ).overrideWith((ref) async {
            cmsPlpReads += 1;
            return _plpHeroImageBundle();
          }),
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
    tester.takeException();

    expect(find.text("Men's Football Boots"), findsOneWidget);
    expect(find.byKey(kPlpHeroBackButtonKey), findsOneWidget);
    expect(find.byTooltip('Retour'), findsOneWidget);
    expect(find.byTooltip('Retour au niveau précédent'), findsNothing);
    expect(_plpHeroBackButtonOpacity(tester), 1);
    expect(cmsPlpReads, 0);

    await tester.tap(find.byKey(kPlpHeroBackButtonKey));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/fr/sport/homme');

    router.go('/fr/sport/homme/boots');
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.byKey(kPlpHeroBackButtonKey), findsOneWidget);

    final scrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.maxScrollExtent > 0);
    final initialPixels = scrollable.position.pixels;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pump(const Duration(milliseconds: 200));

    expect(scrollable.position.pixels, greaterThan(initialPixels + 390));
    expect(_plpHeroBackButtonOpacity(tester), 0);
  });

  testWidgets('sport PLP loading uses skeleton instead of catalogue fallback', (
    tester,
  ) async {
    final products = Completer<CatalogPageData>();
    await tester.binding.setSurfaceSize(const Size(430, 760));
    tester.view.physicalSize = const Size(430, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveStorefrontThemeAsyncProvider.overrideWithValue(
            const AsyncValue.data(StorefrontTheme.nike),
          ),
          activeCategoriesProvider.overrideWith((ref) async => const []),
          plpProvider('boots').overrideWith((ref) async => products.future),
          cmsPlpProvider(
            const CmsPlpRequest(categoryId: 'boots', locale: defaultCmsLocale),
          ).overrideWith((ref) async => _plpHeroImageBundle()),
        ],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
          home: const Scaffold(
            body: ProductListPage(categoryId: 'boots', heroSlugKey: 'boots'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Catalogue'), findsNothing);
    expect(find.byKey(kPlpLoadingHeaderSkeletonKey), findsOneWidget);
    expect(find.byKey(kPlpLoadingGridSkeletonKey), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    products.complete(_pageDataWithProducts('boots'));
    await tester.pumpAndSettle();

    expect(find.byKey(kPlpLoadingHeaderSkeletonKey), findsNothing);
    expect(find.byKey(kPlpLoadingGridSkeletonKey), findsNothing);
    expect(find.text("Men's Football Boots"), findsOneWidget);
  });

  group('sport PLP add-to-cart comet warm-up', () {
    tearDown(() {
      debugForceAddToCartCometWarmUpWeb = false;
      debugOnAddToCartCometWarmUpScheduled = null;
      AddToCartCometController.debugResetShaderWarmUpForTest();
    });

    testWidgets('web mobile sport PLP arms the warm-up after dwell', (
      tester,
    ) async {
      debugForceAddToCartCometWarmUpWeb = true;
      var warmUpCalls = 0;
      debugOnAddToCartCometWarmUpScheduled = () => warmUpCalls += 1;

      await _pumpWarmUpPlp(
        tester,
        theme: StorefrontTheme.nike,
        size: const Size(430, 760),
      );
      await tester.pump();

      expect(find.byKey(kPlpAddToCartCometWarmUpHostKey), findsOneWidget);
      expect(warmUpCalls, 0);

      await tester.pump(const Duration(milliseconds: 599));
      expect(warmUpCalls, 0);

      await tester.pump(const Duration(milliseconds: 2));
      expect(warmUpCalls, 1);

      // Let the real-surface warm frames run to completion (texture + four
      // painted frames) so the test ends with the layer dormant.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(AddToCartCometController.debugShaderWarmUpDone, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty web mobile sport PLP does not arm the warm-up', (
      tester,
    ) async {
      debugForceAddToCartCometWarmUpWeb = true;
      var warmUpCalls = 0;
      debugOnAddToCartCometWarmUpScheduled = () => warmUpCalls += 1;

      await _pumpWarmUpPlp(
        tester,
        theme: StorefrontTheme.nike,
        size: const Size(430, 760),
        hasProducts: false,
      );
      await tester.pump();

      expect(find.byKey(kPlpAddToCartCometWarmUpHostKey), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 700));
      expect(warmUpCalls, 0);
      expect(AddToCartCometController.debugShaderWarmUpDone, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('warm-up never arms outside web-mobile sport motion path', (
      tester,
    ) async {
      debugForceAddToCartCometWarmUpWeb = true;
      var warmUpCalls = 0;
      debugOnAddToCartCometWarmUpScheduled = () => warmUpCalls += 1;

      Future<void> expectDisabled({
        required StorefrontTheme theme,
        required Size size,
        bool disableAnimations = false,
      }) async {
        await _pumpWarmUpPlp(
          tester,
          theme: theme,
          size: size,
          disableAnimations: disableAnimations,
        );
        await tester.pump(const Duration(milliseconds: 700));
        // The host stays mounted (stable tree shape under the debug force),
        // but the runtime gates keep the warm-up from ever arming.
        expect(find.byKey(kPlpAddToCartCometWarmUpHostKey), findsOneWidget);
        expect(warmUpCalls, 0);
        expect(AddToCartCometController.debugShaderWarmUpDone, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }

      await expectDisabled(
        theme: StorefrontTheme.dior,
        size: const Size(430, 760),
      );
      await expectDisabled(
        theme: StorefrontTheme.nike,
        size: const Size(900, 760),
      );
      await expectDisabled(
        theme: StorefrontTheme.nike,
        size: const Size(430, 760),
        disableAnimations: true,
      );
    });
  });

  testWidgets('sport PLP does not load categories before back fallback', (
    tester,
  ) async {
    var categoryReads = 0;
    final router = GoRouter(
      initialLocation: '/fr/catalog/shirts',
      routes: [
        GoRoute(
          path: '/fr${CatalogRoutes.catalogBase}',
          builder: (_, _) => const Scaffold(body: Text('Catalog Root')),
        ),
        GoRoute(
          path: '/fr${CatalogRoutes.catalogBase}/:categorySlug',
          builder: (_, state) => Scaffold(
            body: ProductListPage(
              categoryId: state.pathParameters['categorySlug']!,
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveStorefrontThemeAsyncProvider.overrideWithValue(
            const AsyncValue.data(StorefrontTheme.nike),
          ),
          activeCategoriesProvider.overrideWith((ref) async {
            categoryReads += 1;
            return const <CatalogCategory>[];
          }),
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

    expect(categoryReads, 0);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(categoryReads, 1);
    expect(router.routeInformationProvider.value.uri.path, '/fr/catalog');
  });

  testWidgets('direct sport PLP back arrow navigates to the parent route', (
    tester,
  ) async {
    final router = _router(initialLocation: '/fr/sport/homme/boots');
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/fr/sport/homme');
  });

  testWidgets('deep sport PLP back arrow removes only the last path segment', (
    tester,
  ) async {
    final router = _router(initialLocation: '/fr/sport/homme/boots/running');
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/sport/homme/boots',
    );
  });

  testWidgets('sport PLP path fallback preserves portable query params', (
    tester,
  ) async {
    final router = _router(
      initialLocation: '/fr/sport/homme/boots?sort=price&size=42',
    );
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, '/fr/sport/homme');
    expect(uri.queryParameters['sort'], 'price');
    expect(uri.queryParameters.containsKey('size'), isFalse);
  });

  testWidgets('sport PLP path fallback keeps encoded parent slugs', (
    tester,
  ) async {
    final router = _router(
      initialLocation: '/fr/sport/homme/caf%C3%A9/running',
    );
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/fr/sport/homme/caf%C3%A9',
    );
  });

  testWidgets('non-sport fallback goes to catalog parent route', (
    tester,
  ) async {
    final router = _router(initialLocation: '/fr/catalog/boots');
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/fr/catalog');
  });

  testWidgets('single-segment PLP fallback goes to catalog base', (
    tester,
  ) async {
    final router = _router(initialLocation: CatalogRoutes.sportBase);
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/fr/catalog');
  });

  testWidgets('PLP back arrow resolves the real parent from catalog data', (
    tester,
  ) async {
    const shirts = CatalogCategory(
      id: 'shirts',
      code: 'SHIRTS',
      name: 'Shirts',
      slug: 'shirts',
      parentId: 'summer',
    );
    const summer = CatalogCategory(
      id: 'summer',
      code: 'SUMMER',
      name: 'Summer',
      slug: 'summer',
    );

    final router = GoRouter(
      initialLocation: '/fr/catalog/shirts',
      routes: [
        GoRoute(
          path: '/fr${CatalogRoutes.catalogBase}',
          builder: (_, _) => const Scaffold(body: Text('Catalog Root')),
        ),
        GoRoute(
          path: '/fr${CatalogRoutes.catalogBase}/:categorySlug',
          builder: (_, state) => Scaffold(
            body: ProductListPage(
              categoryId: state.pathParameters['categorySlug']!,
            ),
          ),
        ),
        GoRoute(
          path: '${CatalogRoutes.catalogBase}/:categorySlug',
          builder: (_, state) => Scaffold(
            body: ProductListPage(
              categoryId: state.pathParameters['categorySlug']!,
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveStorefrontThemeAsyncProvider.overrideWithValue(
            const AsyncValue.data(StorefrontTheme.nike),
          ),
          activeCategoriesProvider.overrideWith(
            (ref) async => const [shirts, summer],
          ),
          plpProvider('shirts').overrideWith(
            (ref) async => const CatalogPageData(
              page: 1,
              perPage: 20,
              totalItems: 0,
              totalPages: 1,
              categoryId: 'shirts',
              categoryName: 'Shirts',
              category: shirts,
              items: [],
            ),
          ),
          plpProvider('summer').overrideWith(
            (ref) async => const CatalogPageData(
              page: 1,
              perPage: 20,
              totalItems: 0,
              totalPages: 1,
              categoryId: 'summer',
              categoryName: 'Summer',
              category: summer,
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

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Real parent ("summer") wins over the URL-only fallback, which would have
    // stripped the last segment down to "/catalog".
    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/catalog/summer',
    );
  });

  testWidgets('empty PLP resolves its parent from the category list', (
    tester,
  ) async {
    // No products, so CatalogPageData.category is null (nothing to derive it
    // from). The back action must still reach the real parent via the
    // categoryId lookup against activeCategoriesProvider.
    const shirts = CatalogCategory(
      id: 'shirts',
      code: 'SHIRTS',
      name: 'Shirts',
      slug: 'shirts',
      parentId: 'summer',
    );
    const summer = CatalogCategory(
      id: 'summer',
      code: 'SUMMER',
      name: 'Summer',
      slug: 'summer',
    );

    final router = GoRouter(
      initialLocation: '/fr/catalog/shirts',
      routes: [
        GoRoute(
          path: '/fr${CatalogRoutes.catalogBase}',
          builder: (_, _) => const Scaffold(body: Text('Catalog Root')),
        ),
        GoRoute(
          path: '/fr${CatalogRoutes.catalogBase}/:categorySlug',
          builder: (_, state) => Scaffold(
            body: ProductListPage(
              categoryId: state.pathParameters['categorySlug']!,
            ),
          ),
        ),
        GoRoute(
          path: '${CatalogRoutes.catalogBase}/:categorySlug',
          builder: (_, state) => Scaffold(
            body: ProductListPage(
              categoryId: state.pathParameters['categorySlug']!,
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveStorefrontThemeAsyncProvider.overrideWithValue(
            const AsyncValue.data(StorefrontTheme.nike),
          ),
          activeCategoriesProvider.overrideWith(
            (ref) async => const [shirts, summer],
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
          plpProvider('summer').overrideWith(
            (ref) async => const CatalogPageData(
              page: 1,
              perPage: 20,
              totalItems: 0,
              totalPages: 1,
              categoryId: 'summer',
              categoryName: 'Summer',
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

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/catalog/summer',
    );
  });

  testWidgets('back degrades to the URL-only fallback while categories load', (
    tester,
  ) async {
    // Documented behaviour: the business parent needs the category list to map
    // a parentId to a slug. Until activeCategoriesProvider resolves, the back
    // action falls back to the URL-only parent instead of blocking the button.
    const shirts = CatalogCategory(
      id: 'shirts',
      code: 'SHIRTS',
      name: 'Shirts',
      slug: 'shirts',
      parentId: 'summer',
    );

    final router = GoRouter(
      initialLocation: '/fr/catalog/shirts',
      routes: [
        GoRoute(
          path: '/fr${CatalogRoutes.catalogBase}',
          builder: (_, _) => const Scaffold(body: Text('Catalog Root')),
        ),
        GoRoute(
          path: '/fr${CatalogRoutes.catalogBase}/:categorySlug',
          builder: (_, state) => Scaffold(
            body: ProductListPage(
              categoryId: state.pathParameters['categorySlug']!,
            ),
          ),
        ),
        GoRoute(
          path: CatalogRoutes.catalogBase,
          builder: (_, _) => const Scaffold(body: Text('Catalog Root')),
        ),
        GoRoute(
          path: '${CatalogRoutes.catalogBase}/:categorySlug',
          builder: (_, state) => Scaffold(
            body: ProductListPage(
              categoryId: state.pathParameters['categorySlug']!,
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveStorefrontThemeAsyncProvider.overrideWithValue(
            const AsyncValue.data(StorefrontTheme.nike),
          ),
          // Never completes: the category list stays in the loading state.
          activeCategoriesProvider.overrideWith(
            (ref) => Completer<List<CatalogCategory>>().future,
          ),
          plpProvider('shirts').overrideWith(
            (ref) async => const CatalogPageData(
              page: 1,
              perPage: 20,
              totalItems: 0,
              totalPages: 1,
              categoryId: 'shirts',
              categoryName: 'Shirts',
              category: shirts,
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

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // The real parent ("/catalog/summer") is not reachable yet, so the URL-only
    // fallback strips the last segment down to "/catalog".
    expect(router.routeInformationProvider.value.uri.path, '/fr/catalog');
  });

  testWidgets('sport PLP back arrow uses navigator history when present', (
    tester,
  ) async {
    final router = _router(initialLocation: '/start');
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    router.push('/sport/homme/boots');
    await tester.pumpAndSettle();
    expect(find.text("Men's Football Boots"), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Start Page'), findsOneWidget);
  });
}

Future<void> _pumpWarmUpPlp(
  WidgetTester tester, {
  required StorefrontTheme theme,
  required Size size,
  bool disableAnimations = false,
  bool hasProducts = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        effectiveStorefrontThemeAsyncProvider.overrideWithValue(
          AsyncValue.data(theme),
        ),
        activeCategoriesProvider.overrideWith(
          (ref) async => const <CatalogCategory>[],
        ),
        plpProvider('boots').overrideWith(
          (ref) async =>
              hasProducts ? _pageDataWithProducts('boots') : _pageData('boots'),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        locale: const Locale('fr'),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: disableAnimations,
          ),
          child: const Scaffold(body: ProductListPage(categoryId: 'boots')),
        ),
      ),
    ),
  );
}

Widget _harness(GoRouter router) {
  return ProviderScope(
    overrides: [
      effectiveStorefrontThemeAsyncProvider.overrideWithValue(
        const AsyncValue.data(StorefrontTheme.nike),
      ),
      activeCategoriesProvider.overrideWith(
        (ref) async => const <CatalogCategory>[],
      ),
      plpProvider('boots').overrideWith((ref) async => _pageData('boots')),
      plpProvider('running').overrideWith((ref) async => _pageData('running')),
      plpProvider('café').overrideWith((ref) async => _pageData('café')),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      locale: const Locale('fr'),
    ),
  );
}

GoRouter _router({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              const Text('Start Page'),
              TextButton(
                onPressed: () => context.push('/sport/homme/boots'),
                child: const Text('Open PLP'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: CatalogRoutes.sportBase,
        builder: (_, _) =>
            const Scaffold(body: ProductListPage(categoryId: 'boots')),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.sportBase}',
        builder: (_, _) =>
            const Scaffold(body: ProductListPage(categoryId: 'boots')),
      ),
      GoRoute(
        path: '${CatalogRoutes.sportBase}/:segment',
        builder: (_, state) =>
            Scaffold(body: Text('Segment ${state.pathParameters['segment']}')),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.sportBase}/:segment',
        builder: (_, state) =>
            Scaffold(body: Text('Segment ${state.pathParameters['segment']}')),
      ),
      GoRoute(
        path: CatalogRoutes.catalogBase,
        builder: (_, _) => const Scaffold(body: Text('Catalog Root')),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.catalogBase}',
        builder: (_, _) => const Scaffold(body: Text('Catalog Root')),
      ),
      GoRoute(
        path: '${CatalogRoutes.catalogBase}/:categorySlug',
        builder: (_, state) => Scaffold(
          body: ProductListPage(
            categoryId: state.pathParameters['categorySlug']!,
          ),
        ),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.catalogBase}/:categorySlug',
        builder: (_, state) => Scaffold(
          body: ProductListPage(
            categoryId: state.pathParameters['categorySlug']!,
          ),
        ),
      ),
      GoRoute(
        path: '${CatalogRoutes.sportBase}/:segment/:categorySlug',
        builder: (_, state) => Scaffold(
          body: ProductListPage(
            categoryId: state.pathParameters['categorySlug']!,
          ),
        ),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.sportBase}/:segment/:categorySlug',
        builder: (_, state) => Scaffold(
          body: ProductListPage(
            categoryId: state.pathParameters['categorySlug']!,
          ),
        ),
      ),
      GoRoute(
        path: '${CatalogRoutes.sportBase}/:segment/:categorySlug/:childSlug',
        builder: (_, state) => Scaffold(
          body: ProductListPage(categoryId: state.pathParameters['childSlug']!),
        ),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.sportBase}/:segment/:categorySlug/:childSlug',
        builder: (_, state) => Scaffold(
          body: ProductListPage(categoryId: state.pathParameters['childSlug']!),
        ),
      ),
      GoRoute(
        path:
            '${CatalogRoutes.sportBase}/:segment/:categorySlug/:childSlug/:leafSlug',
        builder: (_, state) => Scaffold(
          body: ProductListPage(categoryId: state.pathParameters['leafSlug']!),
        ),
      ),
      GoRoute(
        path:
            '/fr${CatalogRoutes.sportBase}/:segment/:categorySlug/:childSlug/:leafSlug',
        builder: (_, state) => Scaffold(
          body: ProductListPage(categoryId: state.pathParameters['leafSlug']!),
        ),
      ),
    ],
  );
}

CatalogPageData _pageData(String categoryId) {
  return CatalogPageData(
    page: 1,
    perPage: 20,
    totalItems: 0,
    totalPages: 1,
    categoryId: categoryId,
    categoryName: categoryId == 'running' ? 'Running' : "Men's Football Boots",
    items: const [],
  );
}

CatalogPageData _pageDataWithProducts(String categoryId) {
  final category = CatalogCategory(
    id: categoryId,
    code: categoryId.toUpperCase(),
    name: categoryId == 'running' ? 'Running' : "Men's Football Boots",
    slug: categoryId,
  );
  return CatalogPageData(
    page: 1,
    perPage: 20,
    totalItems: 4,
    totalPages: 1,
    categoryId: categoryId,
    categoryName: category.name,
    category: category,
    items: [
      for (var index = 0; index < 4; index += 1)
        CatalogListingItem(
          id: 'listing-$index',
          categoryId: categoryId,
          productId: 'product-$index',
          category: category,
          product: CatalogProduct(
            id: 'product-$index',
            code: 'PRODUCT-$index',
            name: 'Product $index',
            slug: 'product-$index',
          ),
          prices: [
            CatalogPrice(
              id: 'price-$index',
              productId: 'product-$index',
              price: 20.0 + index,
              isDefault: true,
              currencySymbol: '€',
              currencyCode: 'EUR',
            ),
          ],
        ),
    ],
  );
}

CmsPageBundle _plpHeroImageBundle() {
  return CmsPageBundle(
    page: const CmsPageRecord(
      id: 'page-hero',
      code: 'plp-boots',
      locale: 'fr',
      title: 'Boots',
      isActive: true,
      pageType: CmsPageType.plp,
      sourceCategoryId: 'boots',
    ),
    sections: [
      CmsHeroSection(
        const CmsSectionRecord(
          id: 'section-hero',
          pageId: 'page-hero',
          sectionId: 'hero',
          sectionType: CmsSectionType.heroCampaign,
          rawSectionType: 'hero_campaign',
          position: 0,
          isActive: true,
          config: {},
        ),
        const HeroCampaignConfig(
          title: 'Club Tropicana',
          heightMode: 'square',
          mediaDesktop: CmsMediaRef(
            recordId: 'media-1',
            collectionId: 'media',
            filename: 'hero.jpg',
          ),
        ),
      ),
    ],
  );
}

double _plpHeroBackButtonOpacity(WidgetTester tester) {
  final opacityFinder = find.ancestor(
    of: find.byKey(kPlpHeroBackButtonKey),
    matching: find.byType(AnimatedOpacity),
  );
  return tester.widget<AnimatedOpacity>(opacityFinder).opacity;
}
