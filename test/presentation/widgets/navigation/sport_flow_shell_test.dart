import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/application/storefront/storefront_sport_segment.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/presentation/navigation/product_detail_navigation.dart';
import 'package:kiki_commerce/presentation/providers/cart_provider.dart';
import 'package:kiki_commerce/presentation/providers/category_providers.dart';
import 'package:kiki_commerce/presentation/providers/product_providers.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_route_page.dart';
import 'package:kiki_commerce/presentation/screens/product_list_page.dart';
import 'package:kiki_commerce/presentation/screens/storefront_home_page.dart';
import 'package:kiki_commerce/presentation/widgets/cms/cms_href.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/adaptive_bottom_nav.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/floating_bottom_nav.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/sport_flow_shell.dart';

import '../../../support/l10n_harness.dart';

void main() {
  // The whole point of SportFlowShell: navigating between its child routes must
  // NOT recreate the bottom nav. If the nav lived at a different tree position
  // per route, Flutter would rebuild a fresh tile Element and reset its state.
  testWidgets(
    'keeps one AdaptiveBottomNav and Home tile across landing -> PLP',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/en/sport/homme',
        routes: [
          ShellRoute(
            builder: (context, state, child) => SportFlowShell(child: child),
            routes: [
              GoRoute(
                path: '/en/sport/homme',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  child: Scaffold(body: Center(child: Text('sport-landing'))),
                ),
              ),
              GoRoute(
                path: '/en/sport/homme/:slug',
                pageBuilder: (context, state) => const NoTransitionPage<void>(
                  child: Scaffold(body: Center(child: Text('sport-plp'))),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [liveCartItemCountProvider.overrideWithValue(0)],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: const Locale('fr'),
          ),
        ),
      );
      await tester.pump();

      // On the sport landing: capture the live nav State and Home tile Element.
      expect(find.text('sport-landing'), findsOneWidget);
      expect(find.byType(AdaptiveBottomNav), findsOneWidget);
      expect(find.byKey(FloatingBottomNav.homeTileKey), findsOneWidget);
      final navOnLanding = tester.state(find.byType(AdaptiveBottomNav));
      final homeTileOnLanding = tester.element(
        find.byKey(FloatingBottomNav.homeTileKey),
      );

      // Navigate to the sport PLP — a sibling child of the SAME shell.
      router.go('/en/sport/homme/summer-essentials');
      await tester.pump();
      await tester.pump();
      expect(find.text('sport-plp'), findsOneWidget);
      expect(find.text('sport-landing'), findsNothing);

      final navOnPlp = tester.state(find.byType(AdaptiveBottomNav));
      final homeTileOnPlp = tester.element(
        find.byKey(FloatingBottomNav.homeTileKey),
      );

      // The cardinal guarantee: same instances → the nav and its stateful Home
      // destination were NOT recreated by the navigation.
      expect(
        identical(navOnLanding, navOnPlp),
        isTrue,
        reason:
            'AdaptiveBottomNav State must persist across shell child routes',
      );
      expect(
        identical(homeTileOnLanding, homeTileOnPlp),
        isTrue,
        reason: 'Home tile Element must persist across shell child routes',
      );

      // And back again, to be thorough.
      router.go('/en/sport/homme');
      await tester.pump();
      await tester.pump();
      expect(find.text('sport-landing'), findsOneWidget);
      expect(
        identical(navOnLanding, tester.state(find.byType(AdaptiveBottomNav))),
        isTrue,
      );
    },
  );

  // Instance persistence is necessary but NOT sufficient: the nav must also stay
  // visually put while the page slides underneath it. This mirrors the real
  // router (landing = MaterialPage with a transition, PLP = default page) and
  // checks the nav does not move mid-transition.
  testWidgets('bottom nav stays fixed on screen while the page transitions', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/en/sport/femme',
      routes: [
        ShellRoute(
          builder: (context, state, child) => SportFlowShell(child: child),
          routes: [
            GoRoute(
              path: '/en/sport/femme',
              pageBuilder: (context, state) => const MaterialPage<void>(
                child: Scaffold(body: Center(child: Text('landing'))),
              ),
            ),
            GoRoute(
              path: '/en/sport/femme/:slug',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('plp'))),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [liveCartItemCountProvider.overrideWithValue(0)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
        ),
      ),
    );
    await tester.pump();

    final navAtRest = tester.getRect(find.byType(FloatingBottomNav));

    router.go('/en/sport/femme/shoes');
    await tester.pump(); // kick off the page transition
    await tester.pump(const Duration(milliseconds: 150)); // mid-transition
    final navMidTransition = tester.getRect(find.byType(FloatingBottomNav));

    // The nav must NOT be dragged along by the page slide.
    expect(
      navMidTransition,
      navAtRest,
      reason: 'the persistent nav must stay put while the page transitions',
    );

    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(FloatingBottomNav)), navAtRest);
  });

  testWidgets('sport PLP product loading keeps the simple Home icon', (
    tester,
  ) async {
    final products = Completer<CatalogPageData>();
    final router = GoRouter(
      initialLocation: '/en/sport/femme/les-fleurs',
      routes: [
        ShellRoute(
          builder: (context, state, child) => SportFlowShell(child: child),
          routes: [
            GoRoute(
              path: '/en/sport/femme/:slug',
              builder: (context, state) => Scaffold(
                body: ProductListPage(
                  categoryId: state.pathParameters['slug']!,
                  heroSlugKey: state.pathParameters['slug']!,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveCartItemCountProvider.overrideWithValue(0),
          effectiveStorefrontThemeAsyncProvider.overrideWithValue(
            const AsyncValue.data(StorefrontTheme.nike),
          ),
          plpProvider('les-fleurs').overrideWith((ref) async {
            return products.future;
          }),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(kPlpLoadingGridSkeletonKey), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);

    products.complete(
      const CatalogPageData(
        page: 1,
        perPage: 20,
        totalItems: 0,
        totalPages: 1,
        categoryId: 'les-fleurs',
        categoryName: 'Les fleurs',
        items: [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(kPlpLoadingGridSkeletonKey), findsNothing);
    expect(find.text('Les fleurs'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
  });

  testWidgets('sport PLP category loading keeps the simple Home icon', (
    tester,
  ) async {
    final category = Completer<CatalogCategory?>();
    final router = GoRouter(
      initialLocation: '/en/sport/femme/les-fleurs',
      routes: [
        ShellRoute(
          builder: (context, state, child) => SportFlowShell(child: child),
          routes: [
            GoRoute(
              path: '/en/sport/femme/:slug',
              builder: (context, state) => Scaffold(
                body: StorefrontHomePage(
                  categorySlug: state.pathParameters['slug'],
                  sportSegment: StorefrontSportSegment.femme,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveCartItemCountProvider.overrideWithValue(0),
          categoryBySlugProvider(
            'les-fleurs',
          ).overrideWith((ref) => category.future),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);

    category.complete(null);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
  });

  testWidgets('sport PDP route loading keeps the simple Home icon', (
    tester,
  ) async {
    final routeData = Completer<CatalogProductRouteData?>();
    final router = GoRouter(
      initialLocation: '/en/sport/femme/boots/pegasus',
      routes: [
        ShellRoute(
          builder: (context, state, child) => SportFlowShell(child: child),
          routes: [
            GoRoute(
              path: '/en/sport/femme/:categorySlug',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('sport-plp'))),
            ),
            GoRoute(
              path: '/en/sport/femme/:categorySlug/:productSlug',
              builder: (context, state) => ProductDetailRoutePage(
                categorySlug: state.pathParameters['categorySlug']!,
                productSlug: state.pathParameters['productSlug']!,
                sportSegment: StorefrontSportSegment.femme,
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveCartItemCountProvider.overrideWithValue(0),
          productRouteProvider((
            categorySlug: 'boots',
            productSlug: 'pegasus',
          )).overrideWith((ref) => routeData.future),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);

    router.go('/en/sport/femme/boots');
    await tester.pumpAndSettle();

    expect(find.text('sport-plp'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
  });

  testWidgets('sport PDP product loading keeps the simple Home icon', (
    tester,
  ) async {
    final detail = Completer<ProductDetailData>();
    const category = CatalogCategory(
      id: 'boots',
      code: 'BOOTS',
      name: 'Boots',
      slug: 'boots',
    );
    final router = GoRouter(
      initialLocation: '/en/sport/femme/boots/pegasus',
      routes: [
        ShellRoute(
          builder: (context, state, child) => SportFlowShell(child: child),
          routes: [
            GoRoute(
              path: '/en/sport/femme/:categorySlug',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('sport-plp'))),
            ),
            GoRoute(
              path: '/en/sport/femme/:categorySlug/:productSlug',
              builder: (context, state) => ProductDetailRoutePage(
                categorySlug: state.pathParameters['categorySlug']!,
                productSlug: state.pathParameters['productSlug']!,
                sportSegment: StorefrontSportSegment.femme,
                hint: const ProductDetailRouteHint(
                  productId: 'pegasus',
                  category: category,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveCartItemCountProvider.overrideWithValue(0),
          pdpProvider('pegasus').overrideWith((ref) => detail.future),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);

    router.go('/en/sport/femme/boots');
    await tester.pumpAndSettle();

    expect(find.text('sport-plp'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
  });

  // The real category tiles navigate with context.push (not go). With go_router
  // + ShellRoute, push can shove a *new* shell instance onto the ROOT navigator
  // instead of pushing the page inside the existing shell — which slides the
  // whole nav. This reproduces the actual landing->PLP path.
  testWidgets('push (as the real tiles do) keeps ONE static nav instance', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/en/sport/femme',
      routes: [
        ShellRoute(
          builder: (context, state, child) => SportFlowShell(child: child),
          routes: [
            GoRoute(
              path: '/en/sport/femme',
              pageBuilder: (context, state) => const MaterialPage<void>(
                child: Scaffold(body: Center(child: Text('landing'))),
              ),
            ),
            GoRoute(
              path: '/en/sport/femme/:slug',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('plp'))),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [liveCartItemCountProvider.overrideWithValue(0)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
        ),
      ),
    );
    await tester.pump();

    final navState = tester.state(find.byType(AdaptiveBottomNav));
    final navRect = tester.getRect(find.byType(FloatingBottomNav));

    router.push('/en/sport/femme/shoes'); // the real tiles push
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150)); // mid-transition

    // If push re-instantiates the shell there will be two navs (old + new)
    // during the transition, and/or a fresh State, and/or a moving rect.
    expect(
      find.byType(FloatingBottomNav),
      findsOneWidget,
      reason: 'push must not create a second shell nav',
    );
    expect(
      identical(navState, tester.state(find.byType(AdaptiveBottomNav))),
      isTrue,
      reason: 'push must not recreate the shell nav',
    );
    expect(
      tester.getRect(find.byType(FloatingBottomNav)),
      navRect,
      reason: 'push must not slide the nav',
    );

    await tester.pumpAndSettle();
  });

  testWidgets(
    'catalog CMS hrefs opened from sport routes stay in the sport shell',
    (tester) async {
      final previousUrlReflection = GoRouter.optionURLReflectsImperativeAPIs;
      GoRouter.optionURLReflectsImperativeAPIs = true;
      addTearDown(
        () => GoRouter.optionURLReflectsImperativeAPIs = previousUrlReflection,
      );
      final router = GoRouter(
        initialLocation: '/en/sport/femme',
        routes: [
          ShellRoute(
            builder: (context, state, child) => SportFlowShell(child: child),
            routes: [
              GoRoute(
                path: '/en/sport/femme',
                pageBuilder: (context, state) => MaterialPage<void>(
                  child: Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () =>
                            launchCmsHref(context, '/catalog/les-fleurs'),
                        child: const Text('Open catalog href'),
                      ),
                    ),
                  ),
                ),
              ),
              GoRoute(
                path: '/en/sport/femme/:slug',
                builder: (context, state) => Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('sport-plp-${state.pathParameters['slug']}'),
                        TextButton(
                          onPressed: () =>
                              launchCmsHref(context, '/catalog/training'),
                          child: const Text('Open second catalog href'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [liveCartItemCountProvider.overrideWithValue(0)],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: const Locale('en'),
          ),
        ),
      );
      await tester.pump();

      final navState = tester.state(find.byType(AdaptiveBottomNav));
      final homeTileElement = tester.element(
        find.byKey(FloatingBottomNav.homeTileKey),
      );

      await tester.tap(find.text('Open catalog href'));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/en/sport/femme/les-fleurs',
      );
      expect(find.text('sport-plp-les-fleurs'), findsOneWidget);
      expect(
        identical(navState, tester.state(find.byType(AdaptiveBottomNav))),
        isTrue,
        reason: 'catalog CMS hrefs from sport landing must reuse the sport nav',
      );
      expect(
        identical(
          homeTileElement,
          tester.element(find.byKey(FloatingBottomNav.homeTileKey)),
        ),
        isTrue,
      );

      await tester.tap(find.text('Open second catalog href'));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        '/en/sport/femme/training',
      );
      expect(find.text('sport-plp-training'), findsOneWidget);
      expect(
        identical(navState, tester.state(find.byType(AdaptiveBottomNav))),
        isTrue,
        reason: 'catalog CMS hrefs from sport PLPs must stay in the shell too',
      );
      expect(
        identical(
          homeTileElement,
          tester.element(find.byKey(FloatingBottomNav.homeTileKey)),
        ),
        isTrue,
      );
    },
  );

  testWidgets('home -> sport PLP keeps the same shell bottom nav', (
    tester,
  ) async {
    final previousUrlReflection = GoRouter.optionURLReflectsImperativeAPIs;
    GoRouter.optionURLReflectsImperativeAPIs = true;
    addTearDown(
      () => GoRouter.optionURLReflectsImperativeAPIs = previousUrlReflection,
    );

    final router = GoRouter(
      initialLocation: '/en',
      routes: [
        ShellRoute(
          builder: (context, state, child) => SportFlowShell(child: child),
          routes: [
            GoRoute(
              path: '/en',
              pageBuilder: (context, state) => MaterialPage<void>(
                child: Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () =>
                          context.push('/en/sport/homme/summer-essentials'),
                      child: const Text('Open sport PLP'),
                    ),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/en/sport/homme/:slug',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Text('sport-plp-${state.pathParameters['slug']}'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveCartItemCountProvider.overrideWithValue(0),
          effectiveStorefrontThemeAsyncProvider.overrideWithValue(
            const AsyncValue.data(StorefrontTheme.nike),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AdaptiveBottomNav), findsOneWidget);
    final navState = tester.state(find.byType(AdaptiveBottomNav));
    final homeTileElement = tester.element(
      find.byKey(FloatingBottomNav.homeTileKey),
    );

    await tester.tap(find.text('Open sport PLP'));
    await tester.pump(); // transition start
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(AdaptiveBottomNav), findsOneWidget);
    expect(
      identical(navState, tester.state(find.byType(AdaptiveBottomNav))),
      isTrue,
      reason: '/en -> /sport/... must not swap nav hosts',
    );
    expect(
      identical(
        homeTileElement,
        tester.element(find.byKey(FloatingBottomNav.homeTileKey)),
      ),
      isTrue,
    );

    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/en/sport/homme/summer-essentials',
    );
    expect(find.text('sport-plp-summer-essentials'), findsOneWidget);
    expect(
      identical(navState, tester.state(find.byType(AdaptiveBottomNav))),
      isTrue,
    );
  });

  testWidgets('product detail opened from sport PLP stays in the sport shell', (
    tester,
  ) async {
    final previousUrlReflection = GoRouter.optionURLReflectsImperativeAPIs;
    GoRouter.optionURLReflectsImperativeAPIs = true;
    addTearDown(
      () => GoRouter.optionURLReflectsImperativeAPIs = previousUrlReflection,
    );

    const category = CatalogCategory(
      id: 'boots',
      code: 'BOOTS',
      name: 'Boots',
      slug: 'boots',
    );
    const product = CatalogProduct(
      id: 'pegasus',
      code: 'PEGASUS',
      name: 'Pegasus',
      slug: 'pegasus',
    );

    final router = GoRouter(
      initialLocation: '/fr/sport/femme/boots',
      routes: [
        ShellRoute(
          builder: (context, state, child) => SportFlowShell(child: child),
          routes: [
            GoRoute(
              path: '/fr/sport/femme/boots',
              pageBuilder: (context, state) => MaterialPage<void>(
                child: Scaffold(
                  body: Center(
                    child: Consumer(
                      builder: (context, ref, _) => TextButton(
                        onPressed: () => openProductDetail(
                          context,
                          ref,
                          product: product,
                          prices: const [],
                          routeName: '/catalog/boots/pegasus',
                          category: category,
                          source: ProductDetailEntrySource.plp,
                        ),
                        child: const Text('Open product'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/fr/sport/femme/boots/:productSlug',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: Text(
                    'sport-pdp-${state.pathParameters['productSlug']}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [liveCartItemCountProvider.overrideWithValue(0)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
        ),
      ),
    );
    await tester.pump();

    final navState = tester.state(find.byType(AdaptiveBottomNav));
    final homeTileElement = tester.element(
      find.byKey(FloatingBottomNav.homeTileKey),
    );

    await tester.tap(find.text('Open product'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/sport/femme/boots/pegasus',
    );
    expect(find.text('sport-pdp-pegasus'), findsOneWidget);
    expect(
      identical(navState, tester.state(find.byType(AdaptiveBottomNav))),
      isTrue,
      reason: 'PLP -> PDP must not switch from SportFlowShell to MainShell',
    );
    expect(
      identical(
        homeTileElement,
        tester.element(find.byKey(FloatingBottomNav.homeTileKey)),
      ),
      isTrue,
    );

    router.pop();
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/sport/femme/boots',
    );
    expect(
      identical(navState, tester.state(find.byType(AdaptiveBottomNav))),
      isTrue,
      reason: 'PDP -> PLP pop must keep the original sport nav mounted',
    );
    expect(
      identical(
        homeTileElement,
        tester.element(find.byKey(FloatingBottomNav.homeTileKey)),
      ),
      isTrue,
    );
  });
}
