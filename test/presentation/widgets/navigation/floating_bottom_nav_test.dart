import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/presentation/providers/cart_flight_coordinator_provider.dart';
import 'package:kiki_commerce/presentation/providers/cart_provider.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/animated_shopping_cart_icon.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/floating_bottom_nav.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/iridescent_nav_ring.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/sport_search_magnifying_glass_icon.dart';

import '../../../support/l10n_harness.dart';

// The Home tile is the label-less iridescent hero, so it carries no caption to
// find by text. Locate (and tap) it by its unique ring instead.
final homeTile = find.byType(IridescentNavRing);

class _RecordingObserver extends NavigatorObserver {
  final List<String?> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}

Future<_RecordingObserver> _pumpNav(
  WidgetTester tester, {
  VoidCallback? onHomeTripleTap,
  String initialLocation = CatalogRoutes.home,
  int cartCount = 0,
  bool homeIconLoading = false,
  bool navbarShadersEnabled = true,
}) async {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final observer = _RecordingObserver();
  Scaffold navPage(String label) => Scaffold(
    body: Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Center(child: Text(label)),
        FloatingBottomNav(
          onHomeTripleTap: onHomeTripleTap,
          homeIconLoading: homeIconLoading,
          navbarShadersEnabled: navbarShadersEnabled,
        ),
      ],
    ),
  );

  final router = GoRouter(
    initialLocation: initialLocation,
    observers: [observer],
    routes: [
      GoRoute(
        path: CatalogRoutes.home,
        builder: (context, state) => navPage('Home'),
      ),
      GoRoute(path: '/fr', builder: (context, state) => navPage('Home')),
      GoRoute(path: '/en', builder: (context, state) => navPage('Home')),
      GoRoute(
        path: '/sport/homme',
        builder: (context, state) => navPage('Sport Home'),
      ),
      GoRoute(
        path: '/fr/sport/homme',
        builder: (context, state) => navPage('Sport Home'),
      ),
      GoRoute(
        path: '/en/sport/homme',
        builder: (context, state) => navPage('Sport Home'),
      ),
      GoRoute(
        path: '/sport/homme/shoes',
        builder: (context, state) => navPage('Sport PLP'),
      ),
      GoRoute(
        path: CatalogRoutes.catalogBase,
        builder: (context, state) => navPage('Catalog'),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.catalogBase}',
        builder: (context, state) => navPage('Catalog'),
      ),
      GoRoute(
        path: '/catalog/shoes/product',
        builder: (context, state) => navPage('PDP'),
      ),
      GoRoute(
        path: CatalogRoutes.search,
        builder: (context, state) => const Scaffold(body: Text('Search')),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.search}',
        builder: (context, state) => const Scaffold(body: Text('Search')),
      ),
      GoRoute(
        path: CatalogRoutes.cart,
        builder: (context, state) => navPage('Cart'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [liveCartItemCountProvider.overrideWithValue(cartCount)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        locale: const Locale('fr'),
      ),
    ),
  );
  await tester.pump();
  return observer;
}

void main() {
  test('uses the static Home ring everywhere when navbar shaders are off', () {
    expect(
      shouldUseStaticIridescentNavRing(isWeb: true, viewportWidth: 390),
      isTrue,
    );
    expect(
      shouldUseStaticIridescentNavRing(isWeb: true, viewportWidth: 768),
      isTrue,
    );
    expect(
      shouldUseStaticIridescentNavRing(isWeb: false, viewportWidth: 390),
      isTrue,
    );
  });

  test('keeps the mobile-web safety fallback after shaders are enabled', () {
    expect(
      shouldUseStaticIridescentNavRing(
        isWeb: true,
        viewportWidth: 390,
        navbarShadersEnabled: true,
      ),
      isTrue,
    );
    expect(
      shouldUseStaticIridescentNavRing(
        isWeb: true,
        viewportWidth: 768,
        navbarShadersEnabled: true,
      ),
      isFalse,
    );
    expect(
      shouldUseStaticIridescentNavRing(
        isWeb: false,
        viewportWidth: 390,
        navbarShadersEnabled: true,
      ),
      isFalse,
    );
    expect(
      shouldUseStaticIridescentNavRing(
        isWeb: true,
        viewportWidth: 390,
        navbarShadersEnabled: true,
        mobileWebFeedbackEnabled: true,
      ),
      isFalse,
    );
  });

  testWidgets('disabled navbar shaders use only standard Home/Search icons', (
    tester,
  ) async {
    await _pumpNav(tester, navbarShadersEnabled: false);

    expect(find.byType(IridescentNavRing), findsNothing);
    expect(find.byType(SportSearchMagnifyingGlassIcon), findsNothing);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byKey(FloatingBottomNav.homeTileKey), findsOneWidget);
    expect(find.byKey(FloatingBottomNav.searchTileKey), findsOneWidget);
  });

  testWidgets('three rapid taps on Accueil fire onHomeTripleTap', (
    tester,
  ) async {
    var triggered = 0;
    await _pumpNav(tester, onHomeTripleTap: () => triggered += 1);

    await tester.tap(homeTile);
    await tester.tap(homeTile);
    await tester.tap(homeTile);
    await tester.pump();

    expect(triggered, 1);
  });

  testWidgets('callback is not fired on the first tap (immediate nav)', (
    tester,
  ) async {
    var triggered = 0;
    await _pumpNav(tester, onHomeTripleTap: () => triggered += 1);

    await tester.tap(homeTile);
    await tester.pump();

    expect(triggered, 0);

    // Drain the 650ms window timer so no Timer is left pending when the
    // widget tester finishes.
    await tester.pump(FloatingBottomNav.tripleTapWindow);
  });

  testWidgets('two taps do not fire onHomeTripleTap', (tester) async {
    var triggered = 0;
    await _pumpNav(tester, onHomeTripleTap: () => triggered += 1);

    await tester.tap(homeTile);
    await tester.tap(homeTile);
    await tester.pump();

    expect(triggered, 0);

    // Drain the 650ms window timer so no Timer is left pending when the
    // widget tester finishes.
    await tester.pump(FloatingBottomNav.tripleTapWindow);
  });

  testWidgets('window expiry resets the counter (3 slow taps = no fire)', (
    tester,
  ) async {
    var triggered = 0;
    await _pumpNav(tester, onHomeTripleTap: () => triggered += 1);

    await tester.tap(homeTile);
    await tester.pump(
      FloatingBottomNav.tripleTapWindow + const Duration(milliseconds: 50),
    );
    await tester.tap(homeTile);
    await tester.pump(
      FloatingBottomNav.tripleTapWindow + const Duration(milliseconds: 50),
    );
    await tester.tap(homeTile);
    await tester.pump();

    expect(triggered, 0);
  });

  testWidgets('non-Home destinations do not receive triple-tap bookkeeping', (
    tester,
  ) async {
    // The real guarantee here is structural, not behavioural: only the
    // Accueil _NavDestination is constructed with onTripleTap, the
    // other three are not. Tapping non-Home items navigates away, so we
    // can't simulate three rapid taps on the same one in a stable
    // router. What we *can* assert is that interacting with each non-
    // Home destination once never wires up the callback.
    var triggered = 0;
    await _pumpNav(tester, onHomeTripleTap: () => triggered += 1);

    await tester.tap(find.text('Panier'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SportSearchMagnifyingGlassIcon));
    await tester.pumpAndSettle();

    expect(triggered, 0);
  });

  testWidgets('without onHomeTripleTap, single tap still navigates', (
    tester,
  ) async {
    await _pumpNav(tester);

    await tester.tap(find.byType(SportSearchMagnifyingGlassIcon));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('renders four destinations and omits Acheter', (tester) async {
    await _pumpNav(tester);

    // Cart and Profile keep their captions.
    for (final label in ['Panier', 'Profil']) {
      expect(find.text(label), findsOneWidget);
    }
    // Home and Search are label-less optical treatments.
    expect(homeTile, findsOneWidget);
    expect(find.text('Accueil'), findsNothing);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.text('Rechercher'), findsNothing);
    expect(find.byType(SportSearchMagnifyingGlassIcon), findsOneWidget);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.text('Acheter'), findsNothing);
    expect(find.byKey(kAnimatedShoppingCartIconKey), findsOneWidget);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
    expect(find.byIcon(Icons.shopping_basket_outlined), findsNothing);
  });

  testWidgets('turns the Home glyph into a rotating brand word while loading', (
    tester,
  ) async {
    await _pumpNav(tester, homeIconLoading: true);

    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsOneWidget,
    );
    expect(tester.widget<IridescentNavRing>(homeTile).isLoading, isTrue);
    expect(find.text('Kiki'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsNothing);
  });

  testWidgets('settles the loading brand word back to the Home icon', (
    tester,
  ) async {
    await _pumpNav(tester, homeIconLoading: true);
    await _pumpNav(tester, homeIconLoading: false);

    await tester.pump(const Duration(milliseconds: 700));

    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
    expect(tester.widget<IridescentNavRing>(homeTile).isLoading, isFalse);
    expect(find.text('Kiki'), findsNothing);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });

  testWidgets('marks Home active on localized Sport landing', (tester) async {
    await _pumpNav(tester, initialLocation: '/en/sport/homme');
    // Settle the icon colour cross-fade before reading it.
    await tester.pumpAndSettle();

    expect(find.text('Sport Home'), findsOneWidget);
    final homeRing = tester.widget<IridescentNavRing>(homeTile);
    expect(homeRing.isActive, isTrue);
    final homeIcon = tester.widget<Icon>(find.byIcon(Icons.home));
    expect(homeIcon.color, Colors.white);
  });

  testWidgets('Home pops PDP and PLP history one entry at a time', (
    tester,
  ) async {
    await _pumpNav(tester, initialLocation: '/sport/homme');
    await tester.pumpAndSettle();

    GoRouter.of(
      tester.element(find.text('Sport Home')),
    ).push('/sport/homme/shoes');
    await tester.pumpAndSettle();
    GoRouter.of(
      tester.element(find.text('Sport PLP')),
    ).push('/catalog/shoes/product');
    await tester.pumpAndSettle();

    expect(find.text('PDP'), findsOneWidget);

    await tester.tap(homeTile);
    await tester.pumpAndSettle();
    expect(find.text('Sport PLP'), findsOneWidget);
    expect(find.text('PDP'), findsNothing);

    await tester.tap(homeTile);
    await tester.pumpAndSettle();
    expect(find.text('Sport Home'), findsOneWidget);
    expect(find.text('Sport PLP'), findsNothing);
  });

  testWidgets('Home falls back to the current Sport segment landing', (
    tester,
  ) async {
    await _pumpNav(tester, initialLocation: '/sport/homme/shoes');

    await tester.tap(homeTile);
    await tester.pumpAndSettle();

    expect(find.text('Sport Home'), findsOneWidget);
  });

  testWidgets('uses a custom clipped backdrop surface', (tester) async {
    await _pumpNav(tester);

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ClipPath), findsWidgets);
  });

  testWidgets('plays a one-shot intro emphasis then settles back to rest', (
    tester,
  ) async {
    await _pumpNav(tester);

    double fillAlpha() {
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(BackdropFilter),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).color!.a;
    }

    // Resting light glass before the intro delay elapses (original
    // transparency — contrast comes from the adaptive glass, not opacity).
    expect(fillAlpha(), closeTo(0.42, 0.001));

    // Past the ~750ms delay and into the swell: the bar reads more solid.
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump(const Duration(milliseconds: 350));
    expect(fillAlpha(), greaterThan(0.7));

    // One shot: it eases back to the resting state and never repeats.
    await tester.pumpAndSettle();
    expect(fillAlpha(), closeTo(0.42, 0.001));
  });

  testWidgets('without onHomeTripleTap, three Home taps do not crash', (
    tester,
  ) async {
    await _pumpNav(tester); // null callback

    await tester.tap(homeTile);
    await tester.tap(homeTile);
    await tester.tap(homeTile);
    await tester.pump();

    // No exception, no reveal mechanism — just navigations.
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the cart-count badge when the cart has items', (
    tester,
  ) async {
    await _pumpNav(tester, cartCount: 2);

    final badge = find.byKey(kSharedNavCartCountBadgeKey);
    expect(badge, findsOneWidget);
    expect(tester.widget<Text>(badge).data, '2');
  });

  testWidgets('shows no badge when the cart is empty', (tester) async {
    await _pumpNav(tester, cartCount: 0);

    expect(find.byKey(kSharedNavCartCountBadgeKey), findsNothing);
  });

  testWidgets(
    'defers the badge bump while a comet flight is pending, pops at impact',
    (tester) async {
      // cartCount 3 = the optimistic add already landed (2 + the new item).
      await _pumpNav(tester, cartCount: 3);
      final badge = find.byKey(kSharedNavCartCountBadgeKey);
      expect(tester.widget<Text>(badge).data, '3');

      final coordinator = ProviderScope.containerOf(
        tester.element(find.byType(FloatingBottomNav)),
      ).read(cartFlightCoordinatorProvider.notifier);

      final id = coordinator.startFlight();
      coordinator.onFlightAddLanded(id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      // Masked back to the pre-add value while the comet is in the air.
      expect(tester.widget<Text>(badge).data, '2');
      expect(
        tester
            .widget<AnimatedShoppingCartIcon>(
              find.byType(AnimatedShoppingCartIcon),
            )
            .openProgress!
            .value,
        greaterThan(0),
      );

      coordinator.onFlightImpact(id);
      await tester.pump();
      expect(tester.widget<Text>(badge).data, '3');

      // The impact pop is a short one-shot: it must settle (the prewarm-dwell
      // suite above guards that nothing animates on mount).
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      coordinator.onFlightDisposed(id);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(badge).data, '3');
      expect(
        tester
            .widget<AnimatedShoppingCartIcon>(
              find.byType(AnimatedShoppingCartIcon),
            )
            .openProgress!
            .value,
        0,
      );
    },
  );

  testWidgets('tapping Panier from another route pushes /cart', (tester) async {
    final observer = await _pumpNav(
      tester,
      initialLocation: CatalogRoutes.catalogBase,
    );
    await tester.pumpAndSettle();
    observer.pushed.clear(); // ignore the initial route push

    await tester.tap(find.text('Panier'));
    await tester.pumpAndSettle();

    expect(observer.pushed, isNotEmpty);
    expect(find.text('Cart'), findsOneWidget);
  });

  testWidgets('tapping the active Panier tab on /cart does not re-push', (
    tester,
  ) async {
    final observer = await _pumpNav(
      tester,
      initialLocation: CatalogRoutes.cart,
    );
    await tester.pumpAndSettle();
    observer.pushed.clear(); // ignore the initial route push

    await tester.tap(find.text('Panier'));
    await tester.pumpAndSettle();

    expect(observer.pushed, isEmpty);
  });
}
