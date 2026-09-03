import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/application/cart/cart_guest_session_store.dart';
import 'package:kiki_commerce/application/cart/cart_read_models.dart';
import 'package:kiki_commerce/application/cart/cart_repository.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/cms/cms_page_repository.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/catalog/product_search_repository.dart';
import 'package:kiki_commerce/application/catalog/search_query.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/application/storefront/storefront_brand_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_navigation_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_sport_segment.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/data/local/visitor_storefront_theme_store.dart';
import 'package:kiki_commerce/domain/cart/cart_entities.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/cms_page_provider.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/screens/storefront_landing_page.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/category_split_tabs_section.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/animated_shopping_cart_icon.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/floating_bottom_nav.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/sport_flow_shell.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/mobile_fullscreen_menu_overlay.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/premium_scroll_navbar.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/hero_campaign_section.dart';
import 'package:kiki_commerce/presentation/widgets/landing_asset_loading_backdrop.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_theme_switcher.dart';

import '../../support/l10n_harness.dart';

void main() {
  test('theme page transition follows the switch direction', () {
    // Side-by-side pages (Sport index 0, Luxe index 1): Sport->Luxe brings Luxe
    // in from the right (+1), Luxe->Sport brings Sport in from the left (-1).
    expect(
      storefrontThemePageTransitionBeginOffset(
        previousTheme: StorefrontTheme.nike,
        nextTheme: StorefrontTheme.dior,
      ),
      const Offset(1, 0),
    );
    expect(
      storefrontThemePageTransitionBeginOffset(
        previousTheme: StorefrontTheme.dior,
        nextTheme: StorefrontTheme.nike,
      ),
      const Offset(-1, 0),
    );
  });

  test('segment slide follows the tab order', () {
    // Homme 0, Femme 1, Enfant 2: moving to a higher index brings the incoming
    // content in from the right (+1); a lower index mirrors it; equal = no move.
    expect(
      storefrontSegmentSlideBeginOffset(
        previousSegment: StorefrontSportSegment.homme,
        nextSegment: StorefrontSportSegment.enfant,
      ),
      const Offset(1, 0),
    );
    expect(
      storefrontSegmentSlideBeginOffset(
        previousSegment: StorefrontSportSegment.enfant,
        nextSegment: StorefrontSportSegment.homme,
      ),
      const Offset(-1, 0),
    );
    expect(
      storefrontSegmentSlideBeginOffset(
        previousSegment: StorefrontSportSegment.femme,
        nextSegment: StorefrontSportSegment.femme,
      ),
      Offset.zero,
    );
  });

  testWidgets('landing mobile fullscreenReveal opens fullscreen overlay', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(tester, MobileMenuStyle.fullscreenReveal);

    await tester.pump();
    expect(
      tester.getSize(find.byKey(MobileFullscreenMenuOverlay.panelKey)).height,
      0,
    );

    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    expect(scaffold.isDrawerOpen, isFalse);
    expect(find.byKey(MobileFullscreenMenuOverlay.overlayKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(MobileFullscreenMenuOverlay.panelKey)).height,
      greaterThan(0),
    );

    await tester.tap(find.byTooltip('Fermer le menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(tester.takeException(), isNull);
  });

  testWidgets('landing mobile fullscreenReveal category items navigate', (
    tester,
  ) async {
    const category = CatalogCategory(
      id: 'cat-fleurs',
      code: 'fleurs',
      name: 'Fleurs magiques',
      slug: 'fleurs-magiques',
    );

    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      categories: const [category],
    );

    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Fleurs magiques'));
    await tester.pumpAndSettle();

    expect(find.text('PLP fleurs-magiques'), findsOneWidget);
  });

  testWidgets('landing desktop fullscreenReveal falls back to classic drawer', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1180, 900));
    await _pumpLanding(tester, MobileMenuStyle.fullscreenReveal);

    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pumpAndSettle();

    final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
    expect(scaffold.isDrawerOpen, isTrue);
    expect(find.byKey(MobileFullscreenMenuOverlay.overlayKey), findsNothing);
  });

  testWidgets('landing Nike theme hides top nav and keeps bottom nav', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
    );
    await tester.pump();

    expect(find.byType(PremiumScrollNavbar), findsNothing);
    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(find.byTooltip('Ouvrir le menu'), findsNothing);
    expect(find.byTooltip('Recherche'), findsNothing);
  });

  testWidgets('landing prefetches an existing cart badge on cold start', (
    tester,
  ) async {
    final cartRepository = _LandingCartRepository(
      view: CartView(
        cart: _landingCart,
        entries: [
          _landingEntry(id: 'entry-1', quantity: 2),
          _landingEntry(id: 'entry-2', quantity: 1),
        ],
      ),
    );

    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cartRepository: cartRepository,
      guestSessionStore: _LandingGuestSessionStore(
        activeCart: const CachedActiveCart(
          cartId: 'cart-1',
          currencyCode: 'EUR',
        ),
      ),
    );
    await tester.pump();

    expect(cartRepository.getCartWithEntriesCalls, 1);
    final badge = tester.widget<Text>(find.byKey(kSharedNavCartCountBadgeKey));
    expect(badge.data, '3');
  });

  testWidgets('landing Nike loading shell renders the sport skeleton', (
    tester,
  ) async {
    final pendingHomepage = Completer<CmsPageBundle?>();

    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      homepageBuilder: (_) => pendingHomepage.future,
    );
    await tester.pump();

    expect(find.byKey(storefrontHomepageThemeShellKey), findsOneWidget);
    expect(find.byKey(storefrontSportHomepageSkeletonKey), findsOneWidget);
    expect(find.byType(LandingGradientLoadingSurface), findsOneWidget);
    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
    expect(find.byIcon(Icons.home), findsOneWidget);

    pendingHomepage.complete(null);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
  });

  testWidgets('sport segment tabs swap the CMS landing bundle', (tester) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpSegmentLanding(tester);
    await tester.pumpAndSettle();

    expect(find.text('Moment Homme'), findsOneWidget);
    expect(find.text('Moment Femme'), findsNothing);
    expect(find.text('Moment Enfant'), findsNothing);

    await tester.tap(find.text('Femme'));
    await tester.pumpAndSettle();

    expect(find.text('Moment Homme'), findsNothing);
    expect(find.text('Moment Femme'), findsOneWidget);
    expect(find.text('Moment Enfant'), findsNothing);
    expect(find.text('Catalog Route'), findsNothing);

    await tester.tap(find.text('Enfant'));
    await tester.pumpAndSettle();

    expect(find.text('Moment Homme'), findsNothing);
    expect(find.text('Moment Femme'), findsNothing);
    expect(find.text('Moment Enfant'), findsOneWidget);
    expect(find.text('Catalog Route'), findsNothing);
  });

  testWidgets('expansible segment selection stays expansible on destination', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpSegmentLanding(
      tester,
      categories: _segmentDrawerCategories,
      navigationSettings: const StorefrontNavigationSettings(
        mobileMenuStyle: MobileMenuStyle.drawer,
        categorySplitDisplayMode: CategorySplitDisplayMode.expansible,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Expansible), findsOneWidget);
    expect(find.text('Homme'), findsOneWidget);
    expect(find.text('Femme'), findsNothing);
    expect(find.text('Enfant'), findsNothing);

    await tester.tap(find.text('Homme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Femme'));
    await tester.pumpAndSettle();

    expect(find.text('Moment Femme'), findsOneWidget);
    expect(find.byType(CategorySplitTabsSection), findsOneWidget);
    expect(find.byType(Expansible), findsOneWidget);
    expect(find.text('Femme'), findsOneWidget);
    expect(find.text('Homme'), findsNothing);
    expect(find.text('Enfant'), findsNothing);
    expect(find.text('Parcourir'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legacy expansible Homme config stays expansible after segment selection',
    (tester) async {
      await _setViewport(tester, const Size(390, 800));
      await _pumpSegmentLanding(
        tester,
        categories: _segmentDrawerCategories,
        hommeBundle: () async => _segmentHomepageBundle(
          pageId: 'homepage-nike',
          pageCode: 'homepage_nike',
          activeSegment: StorefrontSportSegment.homme,
          momentLabel: 'Moment Homme',
          tabsDisplayMode: 'expansible',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Expansible), findsOneWidget);
      expect(find.text('Homme'), findsOneWidget);

      await tester.tap(find.text('Homme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Femme'));
      await tester.pumpAndSettle();

      expect(find.text('Moment Femme'), findsOneWidget);
      expect(find.byType(Expansible), findsOneWidget);
      expect(find.text('Femme'), findsOneWidget);
      expect(find.text('Homme'), findsNothing);
      expect(find.text('Parcourir'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tab switch slides content below a single pinned tab row', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpSegmentLanding(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Femme'));
    await tester.pump(); // navigate + start slide (incoming shell)
    await tester.pump(); // incoming Femme bundle resolves

    // Homme(0) -> Femme(1) enters from the right (+1).
    expect(_segmentSlideDx(tester), closeTo(1, 0.001));

    await tester.pump(const Duration(milliseconds: 180));

    // Mid-slide: the tab row is pinned exactly once while both the outgoing and
    // incoming content panes are mounted and sliding.
    final dx = _segmentSlideDx(tester);
    expect(dx, lessThan(1));
    expect(dx, greaterThan(0));
    expect(find.byType(CategorySplitTabsSection), findsOneWidget);
    expect(find.text('Moment Homme'), findsOneWidget);
    expect(find.text('Moment Femme'), findsOneWidget);

    // The pinned tab row must stay full-width / left-aligned during the slide —
    // not shrink to its content and center (which made the tabs jump).
    expect(tester.getTopLeft(find.byType(CategorySplitTabsSection)).dx, 0);
    expect(tester.getSize(find.byType(CategorySplitTabsSection)).width, 390);

    await tester.pumpAndSettle();

    // Settled: slide torn down, only the incoming page remains, tab row is back
    // in the scrolling list.
    expect(find.byKey(storefrontSegmentSlideKey), findsNothing);
    expect(find.text('Moment Homme'), findsNothing);
    expect(find.text('Moment Femme'), findsOneWidget);
    expect(find.byType(CategorySplitTabsSection), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab row stays real (never a skeleton) while the segment loads', (
    tester,
  ) async {
    final femme = Completer<CmsPageBundle?>();
    await _setViewport(tester, const Size(390, 800));
    await _pumpSegmentLanding(tester, femmeBundle: () => femme.future);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Femme'));
    await tester.pump(); // navigate + start slide (Femme still loading)
    await tester.pump(const Duration(milliseconds: 400)); // past the slide

    // Slide finished but Femme is still loading: the real tab row must stay
    // (no skeleton boxes for the tabs that never change) with only a
    // content-area skeleton below it.
    expect(find.byType(CategorySplitTabsSection), findsOneWidget);
    expect(find.text('Homme'), findsOneWidget);
    expect(find.text('Femme'), findsOneWidget);
    expect(find.text('Enfant'), findsOneWidget);
    expect(find.byKey(storefrontSportHomepageSkeletonKey), findsOneWidget);

    femme.complete(
      _segmentHomepageBundle(
        pageId: 'homepage-nike-femme',
        pageCode: 'homepage_nike_femme',
        activeSegment: StorefrontSportSegment.femme,
        momentLabel: 'Moment Femme',
      ),
    );
    await tester.pumpAndSettle();

    // Resolved: settle to the normal list with the real tabs and new content.
    expect(find.byKey(storefrontSegmentSlideKey), findsNothing);
    expect(find.byKey(storefrontSportHomepageSkeletonKey), findsNothing);
    expect(find.byType(CategorySplitTabsSection), findsOneWidget);
    expect(find.text('Moment Femme'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sport skeleton keeps the real active segment header while loading',
    (tester) async {
      final femme = Completer<CmsPageBundle?>();
      await _setViewport(tester, const Size(390, 800));
      // Direct load of /sport/femme with the page still loading → full skeleton.
      await _pumpSegmentLanding(
        tester,
        initialLocation: '/sport/femme',
        femmeBundle: () => femme.future,
      );
      await tester.pump();

      // The content area below the segment header is a placeholder skeleton...
      expect(find.byKey(storefrontSportHomepageSkeletonKey), findsOneWidget);
      // ...but the header is the real active segment label (not a grey block),
      // matching the centered expansible landing header.
      expect(find.text('Homme'), findsNothing);
      expect(find.text('Femme'), findsOneWidget);
      expect(find.text('Enfant'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Femme')).style?.fontWeight,
        FontWeight.w700,
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
        findsNothing,
      );
      expect(find.byIcon(Icons.home), findsOneWidget);
      // The segment section still occupies the full row, but the visible label
      // is centered like the resolved landing.
      expect(tester.getSize(find.byType(CategorySplitTabsSection)).width, 390);
      expect(tester.getCenter(find.text('Femme')).dx, closeTo(184, 12));

      // Resolving the page swaps the skeleton for content.
      femme.complete(
        _segmentHomepageBundle(
          pageId: 'homepage-nike-femme',
          pageCode: 'homepage_nike_femme',
          activeSegment: StorefrontSportSegment.femme,
          momentLabel: 'Moment Femme',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(storefrontSportHomepageSkeletonKey), findsNothing);
      expect(
        find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
        findsNothing,
      );
      expect(find.text('Moment Femme'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('prewarms one adjacent segment page after the dwell delay', (
    tester,
  ) async {
    final reads = <String, int>{};
    await _setViewport(tester, const Size(390, 800));
    await _pumpSegmentLanding(
      tester,
      onCmsRead: (code) => reads[code] = (reads[code] ?? 0) + 1,
    );
    await tester.pump(const Duration(milliseconds: 650));
    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );

    // Sibling codes are only ever fetched by the prewarm (Homme is non-null, so
    // no fallback reads them), so we can assert on their counts directly.
    expect(reads['homepage_nike_femme'] ?? 0, 0);
    expect(reads['homepage_nike_enfant'] ?? 0, 0);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(reads['homepage_nike_femme'], 1);
    expect(reads['homepage_nike_enfant'] ?? 0, 0);
    // The visible page is unchanged.
    expect(
      find.byKey(const ValueKey('sport-bottom-nav-home-loading-brand-word')),
      findsNothing,
    );
    expect(find.text('Moment Homme'), findsOneWidget);
    expect(find.text('Homme'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'root Nike landing prewarms only Femme as Homme adjacent sibling',
    (tester) async {
      final reads = <String, int>{};
      await _setViewport(tester, const Size(390, 800));
      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        theme: StorefrontTheme.nike,
        cmsBundle: _segmentHomepageBundle(
          pageId: 'homepage-nike',
          pageCode: 'homepage_nike',
          activeSegment: StorefrontSportSegment.homme,
          momentLabel: 'Moment Homme',
        ),
        cmsBuilder: (request) async {
          reads[request.code] = (reads[request.code] ?? 0) + 1;
          return switch (request.code) {
            'homepage_nike_femme' => _segmentHomepageBundle(
              pageId: 'homepage-nike-femme',
              pageCode: 'homepage_nike_femme',
              activeSegment: StorefrontSportSegment.femme,
              momentLabel: 'Moment Femme',
            ),
            'homepage_nike_enfant' => _segmentHomepageBundle(
              pageId: 'homepage-nike-enfant',
              pageCode: 'homepage_nike_enfant',
              activeSegment: StorefrontSportSegment.enfant,
              momentLabel: 'Moment Enfant',
            ),
            _ => null,
          };
        },
        disableAnimations: true,
      );
      await tester.pumpAndSettle();

      expect(reads['homepage_nike_femme'] ?? 0, 0);
      expect(reads['homepage_nike_enfant'] ?? 0, 0);

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      expect(reads['homepage_nike_femme'], 1);
      expect(reads['homepage_nike_enfant'] ?? 0, 0);
      expect(find.text('Moment Homme'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Homme')).style?.fontWeight,
        FontWeight.w700,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('segment prewarm fires once and not on every rebuild', (
    tester,
  ) async {
    final reads = <String, int>{};
    await _setViewport(tester, const Size(390, 800));
    await _pumpSegmentLanding(
      tester,
      onCmsRead: (code) => reads[code] = (reads[code] ?? 0) + 1,
      disableAnimations: true,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(reads['homepage_nike_femme'], 1);
    expect(reads['homepage_nike_enfant'] ?? 0, 0);

    // Force several rebuilds: this visible segment already launched its one
    // allowed prewarm, so no extra sibling read may fire.
    for (var i = 1; i <= 3; i++) {
      tester.view.physicalSize = Size(390 + i.toDouble(), 800);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(reads['homepage_nike_femme'], 1);
    expect(reads['homepage_nike_enfant'] ?? 0, 0);
  });

  testWidgets('segment prewarm fires only after the stability delay', (
    tester,
  ) async {
    final reads = <String, int>{};
    await _setViewport(tester, const Size(390, 800));
    await _pumpSegmentLanding(
      tester,
      onCmsRead: (code) => reads[code] = (reads[code] ?? 0) + 1,
      disableAnimations: true,
    );
    // Reach Homme content (arms the timer) without advancing the clock.
    await tester.pump();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 1400));
    expect(reads['homepage_nike_femme'] ?? 0, 0);
    expect(reads['homepage_nike_enfant'] ?? 0, 0);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(reads['homepage_nike_femme'], 1);
    expect(reads['homepage_nike_enfant'] ?? 0, 0);
  });

  testWidgets('segment prewarm skips when the landing route is covered', (
    tester,
  ) async {
    final reads = <String, int>{};
    await _setViewport(tester, const Size(390, 800));
    await _pumpSegmentLanding(
      tester,
      onCmsRead: (code) => reads[code] = (reads[code] ?? 0) + 1,
      disableAnimations: true,
    );
    await tester.pumpAndSettle();

    GoRouter.of(
      tester.element(find.text('Moment Homme')),
    ).push(CatalogRoutes.catalogBase);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text('Catalog Route'), findsOneWidget);
    expect(reads['homepage_nike_femme'] ?? 0, 0);
    expect(reads['homepage'] ?? 0, 0);
  });

  testWidgets('no segment prewarm when the landing is not on a sport route', (
    tester,
  ) async {
    final reads = <String, int>{};
    await _setViewport(tester, const Size(430, 932));
    // Luxe landing on the home route: no sport segment.
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.dior,
      cmsBundle: _scrollableLuxeHomepageBundle(),
      cmsBuilder: (request) async {
        reads[request.code] = (reads[request.code] ?? 0) + 1;
        return null;
      },
      disableAnimations: true,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(reads['homepage_nike_femme'] ?? 0, 0);
    expect(reads['homepage_nike_enfant'] ?? 0, 0);
  });

  testWidgets('segment prewarm swallows a sibling fetch failure', (
    tester,
  ) async {
    final reads = <String, int>{};
    await _setViewport(tester, const Size(390, 800));
    // Femme (the one adjacent sibling prewarmed from Homme) fails: the failure
    // is swallowed without crashing or disturbing the visible page.
    await _pumpSegmentLanding(
      tester,
      femmeBundle: () =>
          Future<CmsPageBundle?>.error(Exception('femme cms failed')),
      onCmsRead: (code) => reads[code] = (reads[code] ?? 0) + 1,
      disableAnimations: true,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(reads['homepage_nike_femme'], 1); // attempted, then swallowed
    expect(reads['homepage_nike_enfant'] ?? 0, 0);
    expect(tester.takeException(), isNull);
    expect(find.text('Moment Homme'), findsOneWidget);
  });

  testWidgets(
    'segment navigation after prewarm shows content without a skeleton',
    (tester) async {
      await _setViewport(tester, const Size(390, 800));
      await _pumpSegmentLanding(tester, disableAnimations: true);
      await tester.pumpAndSettle();
      // Dwell long enough for the prewarm to warm Femme.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Femme'));
      await tester.pump(); // a single frame

      // Femme resolves synchronously from the warmed cache: content slides in
      // immediately, with no shell-skeleton frame.
      expect(find.byKey(storefrontSportHomepageSkeletonKey), findsNothing);
      expect(find.text('Moment Femme'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Moment Homme'), findsNothing);
      expect(find.text('Moment Femme'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'segment prewarm remains warm after a long dwell before navigation',
    (tester) async {
      final reads = <String, int>{};
      await _setViewport(tester, const Size(390, 800));
      await _pumpSegmentLanding(
        tester,
        onCmsRead: (code) => reads[code] = (reads[code] ?? 0) + 1,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      expect(reads['homepage_nike_femme'], 1);
      expect(reads['homepage_nike_enfant'] ?? 0, 0);

      await tester.pump(const Duration(seconds: 20));
      await tester.tap(find.text('Femme'));
      await tester.pump();

      expect(reads['homepage_nike_femme'], 1);
      expect(find.byKey(storefrontSportHomepageSkeletonKey), findsNothing);
      expect(find.text('Moment Femme'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(reads['homepage_nike_femme'], 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'root Nike segment prewarm remains warm after a long dwell before navigation',
    (tester) async {
      final reads = <String, int>{};
      await _setViewport(tester, const Size(390, 800));
      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        theme: StorefrontTheme.nike,
        cmsBundle: _segmentHomepageBundle(
          pageId: 'homepage-nike',
          pageCode: 'homepage_nike',
          activeSegment: StorefrontSportSegment.homme,
          momentLabel: 'Moment Homme',
        ),
        cmsBuilder: (request) async {
          reads[request.code] = (reads[request.code] ?? 0) + 1;
          return switch (request.code) {
            'homepage_nike_femme' => _segmentHomepageBundle(
              pageId: 'homepage-nike-femme',
              pageCode: 'homepage_nike_femme',
              activeSegment: StorefrontSportSegment.femme,
              momentLabel: 'Moment Femme',
            ),
            'homepage_nike_enfant' => _segmentHomepageBundle(
              pageId: 'homepage-nike-enfant',
              pageCode: 'homepage_nike_enfant',
              activeSegment: StorefrontSportSegment.enfant,
              momentLabel: 'Moment Enfant',
            ),
            _ => null,
          };
        },
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      expect(reads['homepage_nike_femme'], 1);
      expect(reads['homepage_nike_enfant'] ?? 0, 0);

      await tester.pump(const Duration(seconds: 20));
      await tester.tap(find.text('Femme'));
      await tester.pump();

      expect(reads['homepage_nike_femme'], 1);
      expect(find.byKey(storefrontSportHomepageSkeletonKey), findsNothing);

      await tester.pumpAndSettle();
      expect(reads['homepage_nike_femme'], 1);
      expect(find.text('Moment Femme'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'segment prewarm targets one adjacent sibling of current segment',
    (tester) async {
      final reads = <String, int>{};
      await _setViewport(tester, const Size(390, 800));
      await _pumpSegmentLanding(
        tester,
        initialLocation: '/sport/femme',
        onCmsRead: (code) => reads[code] = (reads[code] ?? 0) + 1,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // From Femme, prewarm the next adjacent tab (Enfant); never fetch Homme.
      expect(reads['homepage_nike'] ?? 0, 0);
      expect(reads['homepage_nike_enfant'], 1);
      expect(reads['homepage_nike_femme'], 1);
    },
  );

  testWidgets(
    'a rebuild during an in-flight segment prewarm does not double it',
    (tester) async {
      final reads = <String, int>{};
      final femme = Completer<CmsPageBundle?>();
      await _setViewport(tester, const Size(390, 800));
      await _pumpSegmentLanding(
        tester,
        femmeBundle: () => femme.future,
        onCmsRead: (code) => reads[code] = (reads[code] ?? 0) + 1,
        disableAnimations: true,
      );
      await tester.pumpAndSettle();
      // Fire the timer; the prewarm starts and blocks on Femme (unresolved).
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(reads['homepage_nike_femme'], 1);

      // Rebuild repeatedly while the prewarm is in flight: the in-flight guard
      // must prevent a second prewarm.
      for (var i = 1; i <= 3; i++) {
        tester.view.physicalSize = Size(390 + i.toDouble(), 800);
        await tester.pump();
      }
      expect(reads['homepage_nike_femme'], 1);

      femme.complete(
        _segmentHomepageBundle(
          pageId: 'homepage-nike-femme',
          pageCode: 'homepage_nike_femme',
          activeSegment: StorefrontSportSegment.femme,
          momentLabel: 'Moment Femme',
        ),
      );
      await tester.pumpAndSettle();
      expect(reads['homepage_nike_femme'], 1);
      expect(reads['homepage_nike_enfant'] ?? 0, 0);
    },
  );

  testWidgets('no segment prewarm until the current page is content', (
    tester,
  ) async {
    final reads = <String, int>{};
    final homme = Completer<CmsPageBundle?>();
    await _setViewport(tester, const Size(390, 800));
    await _pumpSegmentLanding(
      tester,
      hommeBundle: () => homme.future,
      onCmsRead: (code) => reads[code] = (reads[code] ?? 0) + 1,
      disableAnimations: true,
    );
    // Homme is stuck loading (shell): no sibling prewarm may run.
    await tester.pump(const Duration(milliseconds: 2000));
    expect(reads['homepage_nike_femme'] ?? 0, 0);
    expect(reads['homepage_nike_enfant'] ?? 0, 0);

    homme.complete(
      _segmentHomepageBundle(
        pageId: 'homepage-nike',
        pageCode: 'homepage_nike',
        activeSegment: StorefrontSportSegment.homme,
        momentLabel: 'Moment Homme',
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(reads['homepage_nike_femme'], 1);
    expect(reads['homepage_nike_enfant'] ?? 0, 0);
  });

  testWidgets('sport segment theme switcher tap exits to Luxe landing', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpSegmentLanding(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sport-landing')), findsOneWidget);
    expect(find.byType(FloatingBottomNav), findsOneWidget);

    await tester.tap(find.text('Atelier Kiki'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.dior,
    );
    expect(find.byKey(const ValueKey('sport-landing')), findsNothing);
    expect(find.byType(PremiumScrollNavbar), findsOneWidget);
    expect(find.byType(FloatingBottomNav), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landing Nike theme keeps an admin reveal entry point', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
    );
    await tester.pump();

    expect(find.byType(PremiumScrollNavbar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    // Three rapid taps on Accueil mirror the Dior brand triple-tap and
    // reveal the edit FAB. The first two taps still navigate (no
    // buffered single-tap latency); only the third suppresses
    // navigation to trigger the reveal.
    await tester.tap(find.byKey(FloatingBottomNav.homeTileKey));
    await tester.tap(find.byKey(FloatingBottomNav.homeTileKey));
    await tester.tap(find.byKey(FloatingBottomNav.homeTileKey));
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets(
    'theme switcher keeps the same logo-slot coordinates across themes',
    (tester) async {
      await _setViewport(tester, const Size(430, 932));
      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        replaceMobileLogoWithThemeSwitcher: true,
      );
      await tester.pump();

      final luxeRect = tester.getRect(find.byType(StorefrontThemeSwitcher));
      expect(
        luxeRect.width,
        greaterThanOrEqualTo(storefrontThemeSwitcherLogoSlotWidth),
      );

      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        theme: StorefrontTheme.nike,
        replaceMobileLogoWithThemeSwitcher: true,
      );
      await tester.pump();

      final sportRect = tester.getRect(find.byType(StorefrontThemeSwitcher));

      expect(sportRect.topLeft, luxeRect.topLeft);
      expect(sportRect.size, luxeRect.size);
    },
  );

  testWidgets('landing page slides with the theme switch direction', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      previewTheme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );

    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.dior;
    await tester.pump();

    // Sport->Luxe: Luxe enters from the right (begin offset +1).
    expect(_themePageSlideDx(tester), closeTo(1, 0.001));

    await tester.pump(const Duration(milliseconds: 210));
    expect(_themePageSlideDx(tester), lessThan(1));
    expect(_themePageSlideDx(tester), greaterThan(0));

    await tester.pumpAndSettle();
    expect(_themePageSlideDx(tester), 0);

    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.nike;
    await tester.pump();

    // Luxe->Sport: Sport enters from the left (begin offset -1).
    expect(_themePageSlideDx(tester), closeTo(-1, 0.001));

    await tester.pump(const Duration(milliseconds: 210));
    expect(_themePageSlideDx(tester), greaterThan(-1));
    expect(_themePageSlideDx(tester), lessThan(0));
  });

  testWidgets('landing page starts theme slide while target homepage loads', (
    tester,
  ) async {
    final luxeHomepage = Completer<CmsPageBundle?>();

    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      previewTheme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      homepageBuilder: (ref) async {
        final theme = await ref.watch(resolvedStorefrontThemeProvider.future);
        if (theme == StorefrontTheme.nike) return _scrollableHomepageBundle();
        return luxeHomepage.future;
      },
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );

    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.dior;
    await tester.pump();

    expect(find.byType(FloatingBottomNav), findsNothing);
    expect(find.byType(PremiumScrollNavbar), findsOneWidget);
    expect(find.byKey(storefrontHomepageThemeShellKey), findsOneWidget);
    // Sport->Luxe enters from the right (+1).
    expect(_themePageSlideDx(tester), closeTo(1, 0.001));

    await tester.pumpAndSettle();
    expect(_themePageSlideDx(tester), 0);
    expect(find.byKey(storefrontHomepageThemeShellKey), findsOneWidget);

    luxeHomepage.complete(_luxeHomepageBundle());
    await tester.pump();
    await tester.pump();
    expect(_themePageSlideDx(tester), 0);
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byType(FloatingBottomNav), findsNothing);
    expect(find.byType(PremiumScrollNavbar), findsOneWidget);
    expect(find.byKey(storefrontHomepageThemeShellKey), findsNothing);
    expect(find.text('Luxe hero'), findsOneWidget);
    expect(_themePageSlideDx(tester), 0);
  });

  testWidgets(
    'landing page resolves target shell to empty without a new slide',
    (tester) async {
      final luxeHomepage = Completer<CmsPageBundle?>();

      await _setViewport(tester, const Size(430, 932));
      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        previewTheme: StorefrontTheme.nike,
        cmsBundle: _scrollableHomepageBundle(),
        homepageBuilder: (ref) async {
          final theme = await ref.watch(resolvedStorefrontThemeProvider.future);
          if (theme == StorefrontTheme.nike) return _scrollableHomepageBundle();
          return luxeHomepage.future;
        },
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StorefrontLandingPage)),
      );
      container.read(editingStorefrontThemeProvider.notifier).state =
          StorefrontTheme.dior;
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(storefrontHomepageThemeShellKey), findsOneWidget);
      expect(_themePageSlideDx(tester), 0);

      luxeHomepage.complete(null);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      expect(find.byKey(storefrontHomepageThemeShellKey), findsNothing);
      expect(_themePageSlideDx(tester), 0);
    },
  );

  testWidgets(
    'landing page resolves target shell to error without a new slide',
    (tester) async {
      final luxeHomepage = Completer<CmsPageBundle?>();

      await _setViewport(tester, const Size(430, 932));
      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        previewTheme: StorefrontTheme.nike,
        cmsBundle: _scrollableHomepageBundle(),
        homepageBuilder: (ref) async {
          final theme = await ref.watch(resolvedStorefrontThemeProvider.future);
          if (theme == StorefrontTheme.nike) return _scrollableHomepageBundle();
          return luxeHomepage.future;
        },
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StorefrontLandingPage)),
      );
      container.read(editingStorefrontThemeProvider.notifier).state =
          StorefrontTheme.dior;
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(storefrontHomepageThemeShellKey), findsOneWidget);
      expect(_themePageSlideDx(tester), 0);

      luxeHomepage.completeError(Exception('CMS failed'), StackTrace.current);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_themePageSlideDx(tester), 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('landing page ignores stale target resolution after reswitch', (
    tester,
  ) async {
    final luxeHomepage = Completer<CmsPageBundle?>();

    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      previewTheme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      homepageBuilder: (ref) async {
        final theme = await ref.watch(resolvedStorefrontThemeProvider.future);
        if (theme == StorefrontTheme.nike) return _scrollableHomepageBundle();
        return luxeHomepage.future;
      },
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.dior;
    await tester.pump();
    expect(find.byKey(storefrontHomepageThemeShellKey), findsOneWidget);

    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.nike;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(find.byType(PremiumScrollNavbar), findsNothing);
    expect(find.text('Section 0'), findsOneWidget);

    luxeHomepage.complete(_luxeHomepageBundle());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(find.byType(PremiumScrollNavbar), findsNothing);
    expect(find.text('Section 0'), findsOneWidget);
    expect(find.text('Luxe hero'), findsNothing);
    expect(_themePageSlideDx(tester), 0);
  });

  testWidgets(
    'switching to a loading target from a scrolled page does not setState during build',
    (tester) async {
      final luxeHomepage = Completer<CmsPageBundle?>();

      await _setViewport(tester, const Size(430, 932));
      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        previewTheme: StorefrontTheme.nike,
        cmsBundle: _scrollableHomepageBundle(),
        homepageBuilder: (ref) async {
          final theme = await ref.watch(resolvedStorefrontThemeProvider.future);
          if (theme == StorefrontTheme.nike) return _scrollableHomepageBundle();
          return luxeHomepage.future;
        },
      );
      await tester.pumpAndSettle();

      // Scroll the Sport homepage down so the theme switcher is hidden; this is
      // the state whose scroll-listener setState would fire during build if the
      // shell scroll reset jumped synchronously.
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      scrollable.position.jumpTo(160);
      await tester.pump();
      expect(_sportThemeSwitcherOpacity(tester), 0);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StorefrontLandingPage)),
      );
      container.read(editingStorefrontThemeProvider.notifier).state =
          StorefrontTheme.dior;
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(storefrontHomepageThemeShellKey), findsOneWidget);
    },
  );

  testWidgets(
    'incoming homepage content starts at the top after a scrolled shell transition',
    (tester) async {
      final luxeHomepage = Completer<CmsPageBundle?>();

      await _setViewport(tester, const Size(430, 932));
      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        previewTheme: StorefrontTheme.nike,
        cmsBundle: _scrollableHomepageBundle(),
        homepageBuilder: (ref) async {
          final theme = await ref.watch(resolvedStorefrontThemeProvider.future);
          if (theme == StorefrontTheme.nike) return _scrollableHomepageBundle();
          return luxeHomepage.future;
        },
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      scrollable.position.jumpTo(160);
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StorefrontLandingPage)),
      );
      container.read(editingStorefrontThemeProvider.notifier).state =
          StorefrontTheme.dior;
      await tester.pump();
      await tester.pumpAndSettle();

      luxeHomepage.complete(_scrollableLuxeHomepageBundle());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(storefrontHomepageThemeShellKey), findsNothing);
      expect(find.text('Luxe section 0'), findsOneWidget);
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        0,
      );
    },
  );

  testWidgets('luxe prewarm leaves the visible Sport landing unchanged', (
    tester,
  ) async {
    var luxeReads = 0;

    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async {
        if (request.code == 'homepage') luxeReads++;
        return _scrollableLuxeHomepageBundle();
      },
    );
    await tester.pump(const Duration(milliseconds: 999));
    expect(luxeReads, 0);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(luxeReads, 1);
    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(find.byType(PremiumScrollNavbar), findsNothing);
    expect(_themePageSlideDx(tester), 0);
    expect(find.text('Luxe section 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('luxe prewarm swallows fetch failures', (tester) async {
    var luxeReads = 0;

    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async {
        if (request.code == 'homepage') {
          luxeReads++;
          throw Exception('luxe cms failed');
        }
        return null;
      },
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(luxeReads, 1);
    expect(tester.takeException(), isNull);
    expect(find.byType(FloatingBottomNav), findsOneWidget);
  });

  testWidgets('switching to Luxe before prewarm fires still shows the shell', (
    tester,
  ) async {
    final luxeHomepage = Completer<CmsPageBundle?>();

    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      previewTheme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      homepageBuilder: (ref) async {
        final theme = await ref.watch(resolvedStorefrontThemeProvider.future);
        if (theme == StorefrontTheme.nike) return _scrollableHomepageBundle();
        return luxeHomepage.future;
      },
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.dior;
    await tester.pump();

    expect(find.byKey(storefrontHomepageThemeShellKey), findsOneWidget);
    // Sport->Luxe enters from the right (+1).
    expect(_themePageSlideDx(tester), closeTo(1, 0.001));

    await tester.pumpAndSettle();
    expect(_themePageSlideDx(tester), 0);
    expect(find.byKey(storefrontHomepageThemeShellKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('luxe prewarm fires once and not on every rebuild', (
    tester,
  ) async {
    var luxeReads = 0;

    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async {
        if (request.code == 'homepage') luxeReads++;
        return _scrollableLuxeHomepageBundle();
      },
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();
    expect(luxeReads, 1);

    // Force several rebuilds via MediaQuery changes; the arm-once guard must
    // prevent any additional prewarm read.
    for (var i = 1; i <= 3; i++) {
      tester.view.physicalSize = Size(430 + i.toDouble(), 932);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(luxeReads, 1);
  });

  testWidgets('luxe prewarm fires only after the stability delay', (
    tester,
  ) async {
    var luxeReads = 0;

    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async {
        if (request.code == 'homepage') luxeReads++;
        return _scrollableLuxeHomepageBundle();
      },
    );

    await tester.pump(const Duration(milliseconds: 800));
    expect(luxeReads, 0);

    await tester.pump(const Duration(milliseconds: 300));
    expect(luxeReads, 1);
  });

  testWidgets('luxe prewarm re-arms after an early switch away from Sport', (
    tester,
  ) async {
    var luxeReads = 0;

    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      previewTheme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      homepageBuilder: (ref) async {
        final theme = await ref.watch(resolvedStorefrontThemeProvider.future);
        if (theme == StorefrontTheme.nike) return _scrollableHomepageBundle();
        return _scrollableLuxeHomepageBundle();
      },
      cmsBuilder: (request) async {
        if (request.code == 'homepage') luxeReads++;
        return _scrollableLuxeHomepageBundle();
      },
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );

    // Leave Sport before the timer fires: it is cancelled, no prewarm runs.
    await tester.pump(const Duration(milliseconds: 500));
    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.dior;
    await tester.pumpAndSettle();
    expect(luxeReads, 0);

    // Return to Sport: the prewarm must be able to arm again and fire.
    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.nike;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    expect(luxeReads, greaterThan(0));
  });

  testWidgets('no luxe prewarm when the landing starts on Luxe', (
    tester,
  ) async {
    var luxeReads = 0;

    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.dior,
      cmsBundle: _scrollableLuxeHomepageBundle(),
      cmsBuilder: (request) async {
        if (request.code == 'homepage') luxeReads++;
        return _scrollableLuxeHomepageBundle();
      },
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();

    expect(luxeReads, 0);
  });

  testWidgets('swipe past threshold commits the theme switch', (tester) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async => _scrollableLuxeHomepageBundle(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(find.byType(PremiumScrollNavbar), findsNothing);

    // Sport->Luxe is a leftward swipe.
    await tester.drag(
      find.byKey(storefrontThemePageSlideKey),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.dior,
    );
    expect(find.byType(PremiumScrollNavbar), findsOneWidget);
    expect(find.byType(FloatingBottomNav), findsNothing);
    expect(_themePageSlideDx(tester), 0);
  });

  testWidgets('swipe below threshold springs back without switching', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async => _scrollableLuxeHomepageBundle(),
    );
    await tester.pumpAndSettle();

    // Small leftward drag (valid Sport->Luxe direction) below the threshold.
    await tester.drag(
      find.byKey(storefrontThemePageSlideKey),
      const Offset(-40, 0),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.nike,
    );
    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(find.byType(PremiumScrollNavbar), findsNothing);
    expect(_themePageSlideDx(tester), 0);
  });

  testWidgets('a fast fling commits even on a short drag', (tester) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async => _scrollableLuxeHomepageBundle(),
    );
    await tester.pumpAndSettle();

    // Short, fast leftward fling (Sport->Luxe).
    await tester.fling(
      find.byKey(storefrontThemePageSlideKey),
      const Offset(-120, 0),
      1200,
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.dior,
    );
    expect(find.byType(PremiumScrollNavbar), findsOneWidget);
  });

  testWidgets('swiping toward an absent neighbour does not switch', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.dior,
      cmsBundle: _luxeHomepageBundle(),
      cmsBuilder: (request) async => _scrollableHomepageBundle(),
    );
    await tester.pumpAndSettle();

    // On Dior the only valid swipe reveals Nike (drag right); dragging left has
    // no neighbour, so it must resist and not switch.
    await tester.drag(
      find.byKey(storefrontThemePageSlideKey),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.dior,
    );
    expect(_themePageSlideDx(tester), 0);
  });

  testWidgets('a vertical drag scrolls without switching the theme', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async => _scrollableLuxeHomepageBundle(),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    await tester.drag(
      find.byKey(storefrontThemePageSlideKey),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.nike,
    );
    expect(_themePageSlideDx(tester), 0);
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('swipe is disabled while the fullscreen menu is open', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.dior,
      cmsBundle: _luxeHomepageBundle(),
      cmsBuilder: (request) async => _scrollableHomepageBundle(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(
      find.byKey(MobileFullscreenMenuOverlay.overlayKey),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.dior,
    );
  });

  testWidgets('swipe re-enables after the fullscreen menu closes', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.dior,
      cmsBundle: _scrollableLuxeHomepageBundle(),
      cmsBuilder: (request) async => _scrollableHomepageBundle(),
    );
    await tester.pumpAndSettle();

    // Open then fully close the fullscreen menu.
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Fermer le menu'));
    await tester.pumpAndSettle();

    // On Dior, the valid swipe reveals Nike via a rightward drag.
    await tester.drag(
      find.byKey(storefrontThemePageSlideKey),
      const Offset(320, 0),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.nike,
    );
  });

  testWidgets('a failed override write does not freeze the commit state', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async => _scrollableLuxeHomepageBundle(),
      visitorThemeStore: _InMemoryVisitorStorefrontThemeStore(
        failOnWrite: true,
      ),
    );
    await tester.pumpAndSettle();

    // Sport->Luxe leftward swipe.
    await tester.drag(
      find.byKey(storefrontThemePageSlideKey),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();

    // The override never persisted, so the screen reconciles back to the
    // resolved Sport theme instead of staying frozen on Luxe.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.nike,
    );
    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a drag during a programmatic transition is ignored', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      previewTheme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async => _scrollableLuxeHomepageBundle(),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    // Start a tap-driven transition, then try to drag mid-animation.
    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.dior;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(
      find.byKey(storefrontThemePageSlideKey),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();

    // The programmatic transition still lands on Dior; the drag did nothing.
    expect(_themePageSlideDx(tester), 0);
    expect(find.byType(PremiumScrollNavbar), findsOneWidget);
    expect(find.byType(FloatingBottomNav), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipe re-enables after a rapidly replaced programmatic switch', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      previewTheme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async => _scrollableLuxeHomepageBundle(),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    // Start a transition, then replace it mid-flight with another.
    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.dior;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.nike;
    await tester.pumpAndSettle();
    // Drop the admin preview so the next swipe writes and resolves through the
    // visitor override path.
    container.read(editingStorefrontThemeProvider.notifier).state = null;
    await tester.pumpAndSettle();

    // After everything settles the swipe must be usable again: drag Sport→Luxe
    // (leftward).
    await tester.drag(
      find.byKey(storefrontThemePageSlideKey),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();

    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.dior,
    );
    // Guards against the cross-theme "ScrollController attached to multiple
    // scroll views" crash this scenario originally triggered.
    expect(tester.takeException(), isNull);
  });

  testWidgets('switcher pill tracks a Sport->Luxe drag to mid-position', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async => _scrollableLuxeHomepageBundle(),
      replaceMobileLogoWithThemeSwitcher: true,
    );
    await tester.pumpAndSettle();

    // Sport selected: pill sits in the left half.
    expect(
      _switcherPillCenterDx(tester),
      lessThan(_switcherCenterDx(tester) - 8),
    );

    final center = tester.getCenter(find.byKey(storefrontThemePageSlideKey));
    final gesture = await tester.startGesture(center);
    // Leftward half-width drag -> ~0.5 progress toward Luxe. Step the move so
    // the horizontal recognizer wins the arena before the bulk of the delta.
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-195, 0));
    await tester.pump();

    // At ~mid-drag the pill is centered between the two segments.
    expect(
      _switcherPillCenterDx(tester),
      closeTo(_switcherCenterDx(tester), 6),
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('switcher pill springs back to Sport below threshold', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async => _scrollableLuxeHomepageBundle(),
      replaceMobileLogoWithThemeSwitcher: true,
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(storefrontThemePageSlideKey),
      const Offset(-40, 0),
    );
    await tester.pumpAndSettle();

    // Sprang back to Sport: pill in the left half.
    expect(
      _switcherPillCenterDx(tester),
      lessThan(_switcherCenterDx(tester) - 8),
    );
  });

  testWidgets('switcher pill finishes at Luxe after a commit', (tester) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      cmsBuilder: (request) async => _scrollableLuxeHomepageBundle(),
      replaceMobileLogoWithThemeSwitcher: true,
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(storefrontThemePageSlideKey),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();

    // Committed to Luxe: pill in the right half.
    expect(
      _switcherPillCenterDx(tester),
      greaterThan(_switcherCenterDx(tester) + 8),
    );
  });

  testWidgets('switcher pill moves from Luxe toward Sport on a drag', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.dior,
      cmsBundle: _luxeHomepageBundle(),
      cmsBuilder: (request) async => _scrollableHomepageBundle(),
      replaceMobileLogoWithThemeSwitcher: true,
    );
    await tester.pumpAndSettle();

    // Luxe selected: pill in the right half.
    final luxePillDx = _switcherPillCenterDx(tester);
    expect(luxePillDx, greaterThan(_switcherCenterDx(tester) + 8));

    final center = tester.getCenter(find.byKey(storefrontThemePageSlideKey));
    final gesture = await tester.startGesture(center);
    // Rightward drag reveals Sport; the pill slides back toward the center.
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(195, 0));
    await tester.pump();

    expect(
      _switcherPillCenterDx(tester),
      closeTo(_switcherCenterDx(tester), 6),
    );
    expect(_switcherPillCenterDx(tester), lessThan(luxePillDx));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('tap switcher animates the pill in the same direction', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      previewTheme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      replaceMobileLogoWithThemeSwitcher: true,
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    // Pill starts under Sport (left half).
    expect(
      _switcherPillCenterDx(tester),
      lessThan(_switcherCenterDx(tester) - 8),
    );

    container.read(editingStorefrontThemeProvider.notifier).state =
        StorefrontTheme.dior;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 210));

    // Mid-animation the pill is in flight between the two segments.
    final mid = _switcherPillCenterDx(tester);
    final switcherCenter = _switcherCenterDx(tester);
    expect(mid, greaterThan(switcherCenter - 30));
    expect(mid, lessThan(switcherCenter + 30));

    await tester.pumpAndSettle();
    expect(
      _switcherPillCenterDx(tester),
      greaterThan(_switcherCenterDx(tester) + 8),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap centered switcher commits the unselected theme', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    final visitorThemeStore = _InMemoryVisitorStorefrontThemeStore();
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      visitorThemeStore: visitorThemeStore,
      replaceMobileLogoWithThemeSwitcher: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atelier Kiki'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.dior,
    );
    expect(
      _switcherPillCenterDx(tester),
      greaterThan(_switcherCenterDx(tester) + 8),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap centered switcher updates an active preview theme', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      previewTheme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
      replaceMobileLogoWithThemeSwitcher: true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atelier Kiki'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(
      container.read(editingStorefrontThemeProvider),
      StorefrontTheme.dior,
    );
    expect(
      await container.read(resolvedStorefrontThemeProvider.future),
      StorefrontTheme.dior,
    );
    expect(
      _switcherPillCenterDx(tester),
      greaterThan(_switcherCenterDx(tester) + 8),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'default brand settings: landing mobile keeps the switcher centered on both themes',
    (tester) async {
      // Even without replaceMobileLogoWithThemeSwitcher, the mobile landing
      // forces the centered slot so the swipe control stays put across themes.
      await _setViewport(tester, const Size(430, 932));
      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        previewTheme: StorefrontTheme.nike,
        cmsBundle: _scrollableHomepageBundle(),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(storefrontThemeSwitcherPillKey), findsOneWidget);
      final sportCenter = _switcherCenterDx(tester);
      // The centered switcher uses the brand title for the Luxe segment (its
      // logo-slot rendering), the same on Sport as on Luxe.
      expect(find.text('Atelier Kiki'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StorefrontLandingPage)),
      );
      container.read(editingStorefrontThemeProvider.notifier).state =
          StorefrontTheme.dior;
      await tester.pumpAndSettle();

      expect(find.byType(PremiumScrollNavbar), findsOneWidget);
      expect(find.byKey(storefrontThemeSwitcherPillKey), findsOneWidget);
      final luxeCenter = _switcherCenterDx(tester);

      // Both centered near the viewport center -> no slot jump at commit, and
      // the Luxe-segment label stays consistent across themes.
      const viewportCenter = 430 / 2;
      expect(sportCenter, closeTo(viewportCenter, 24));
      expect(luxeCenter, closeTo(sportCenter, 2));
      expect(find.text('Atelier Kiki'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hero campaign uses light media fallback colors', (tester) async {
    await _setViewport(tester, const Size(390, 800));
    await tester.pumpWidget(
      const MaterialApp(
        home: HeroCampaignSection(
          config: HeroCampaignConfig(title: 'Hero', heightMode: 'xl'),
        ),
      ),
    );

    expect(_coloredBoxWithColor(const Color(0xFF1B1B1B)), findsNothing);
    expect(_coloredBoxWithColor(const Color(0xFFF4F1EA)), findsOneWidget);
  });

  testWidgets('landing Nike theme switcher hides below the top of the page', (
    tester,
  ) async {
    await _setViewport(tester, const Size(430, 932));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
      cmsBundle: _scrollableHomepageBundle(),
    );
    // Settle the loading shell → content crossfade so only the page's vertical
    // ListView remains (the shell's real tab row carries a horizontal scrollable
    // that would otherwise make find.byType(Scrollable) ambiguous mid-crossfade).
    await tester.pumpAndSettle();

    expect(_sportThemeSwitcherOpacity(tester), 1);

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    scrollable.position.jumpTo(160);
    await tester.pump();

    expect(_sportThemeSwitcherOpacity(tester), 0);

    scrollable.position.jumpTo(0);
    await tester.pump();

    expect(_sportThemeSwitcherOpacity(tester), 1);
  });

  testWidgets(
    'landing Nike: a single tap on Accueil does not reveal admin controls',
    (tester) async {
      await _setViewport(tester, const Size(390, 800));
      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        theme: StorefrontTheme.nike,
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.byKey(FloatingBottomNav.homeTileKey));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);

      // Drain the 650ms triple-tap window timer so no Timer is left
      // pending when the widget tester finishes.
      await tester.pump(FloatingBottomNav.tripleTapWindow);
    },
  );

  testWidgets(
    'landing Nike: two taps on Accueil do not reveal admin controls',
    (tester) async {
      await _setViewport(tester, const Size(390, 800));
      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        theme: StorefrontTheme.nike,
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.byKey(FloatingBottomNav.homeTileKey));
      await tester.tap(find.byKey(FloatingBottomNav.homeTileKey));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);

      // Drain the 650ms triple-tap window timer so no Timer is left
      // pending when the widget tester finishes.
      await tester.pump(FloatingBottomNav.tripleTapWindow);
    },
  );

  testWidgets(
    'landing Nike: non-Home destinations do not receive triple-tap bookkeeping',
    (tester) async {
      // Same structural-guarantee framing as the unit test: only the
      // Accueil _NavDestination is constructed with onTripleTap. Once we
      // tap a non-Home destination it navigates / opens a sheet, so we
      // can't reliably triple-tap the same item. We assert that
      // interacting with each non-Home destination never reveals the FAB.
      await _setViewport(tester, const Size(390, 800));
      await _pumpLanding(
        tester,
        MobileMenuStyle.fullscreenReveal,
        theme: StorefrontTheme.nike,
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);

      for (final label in ['Rechercher', 'Panier', 'Profil']) {
        final finder = find.text(label);
        if (finder.evaluate().isEmpty) continue;
        await tester.tap(finder, warnIfMissed: false);
        await tester.pump();
      }

      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );

  testWidgets('landing Nike bottom nav opens cart route, not checkout', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(
      tester,
      MobileMenuStyle.fullscreenReveal,
      theme: StorefrontTheme.nike,
    );
    await tester.pump();

    await tester.tap(find.text('Panier'));
    await tester.pumpAndSettle();

    expect(find.text('Cart Route'), findsOneWidget);
  });

  testWidgets('landing Nike preview can be cancelled when homepage is empty', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(
      tester,
      MobileMenuStyle.drawer,
      previewTheme: StorefrontTheme.nike,
    );
    await tester.pump();

    expect(find.byType(FloatingBottomNav), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pump();

    expect(find.byType(FloatingBottomNav), findsNothing);
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets('landing brand triple tap reveals hidden edit controls', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1180, 900));
    await _pumpLanding(tester, MobileMenuStyle.drawer);
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pumpAndSettle();
    expect(find.text('Activer le mode édition'), findsNothing);

    Navigator.of(tester.element(find.byType(Scaffold))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atelier Kiki'));
    await tester.tap(find.text('Atelier Kiki'));
    await tester.tap(find.text('Atelier Kiki'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorefrontLandingPage)),
    );
    expect(container.read(editModeProvider), isFalse);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byTooltip('Ouvrir le menu'));
    await tester.pumpAndSettle();
    expect(find.text('Activer le mode édition'), findsOneWidget);
  });

  testWidgets(
    'landing premium search opens overlay and submits to search route',
    (tester) async {
      await _setViewport(tester, const Size(390, 800));
      await _pumpLanding(tester, MobileMenuStyle.fullscreenReveal);
      await tester.pump();

      await tester.tap(find.byTooltip('Recherche'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(MobileFullscreenMenuOverlay.overlayKey),
        findsOneWidget,
      );
      expect(
        find.byKey(MobileFullscreenMenuOverlay.searchFieldKey),
        findsOneWidget,
      );
      expect(find.byTooltip('Fermer le menu'), findsOneWidget);
      final searchField = tester.widget<TextField>(
        find.byKey(MobileFullscreenMenuOverlay.searchFieldKey),
      );
      expect(searchField.decoration?.hintStyle?.fontSize, 28);
      expect(searchField.style?.fontSize, 30);
      expect(searchField.style?.fontWeight, FontWeight.w700);

      await tester.enterText(
        find.byKey(MobileFullscreenMenuOverlay.searchFieldKey),
        'mac',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Search mac'), findsOneWidget);
    },
  );

  testWidgets('landing premium search close returns to the page', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(tester, MobileMenuStyle.fullscreenReveal);
    await tester.pump();

    await tester.tap(find.byTooltip('Recherche'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.getSize(find.byKey(MobileFullscreenMenuOverlay.panelKey)).height,
      greaterThan(0),
    );

    await tester.tap(find.byTooltip('Fermer le menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.getSize(find.byKey(MobileFullscreenMenuOverlay.panelKey)).height,
      0,
    );
    expect(find.byKey(MobileFullscreenMenuOverlay.contentKey), findsNothing);
  });

  testWidgets('landing premium search refocuses input after reopening', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 800));
    await _pumpLanding(tester, MobileMenuStyle.fullscreenReveal);
    await tester.pump();

    await tester.tap(find.byTooltip('Recherche'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    _expectSearchFieldFocused(tester);

    await tester.tap(find.byTooltip('Fermer le menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byTooltip('Recherche'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    _expectSearchFieldFocused(tester);
  });
}

void _expectSearchFieldFocused(WidgetTester tester) {
  final editableFinder = find.descendant(
    of: find.byKey(MobileFullscreenMenuOverlay.searchFieldKey),
    matching: find.byType(EditableText),
  );
  final editable = tester.widget<EditableText>(editableFinder);
  expect(editable.focusNode.hasFocus, isTrue);
}

double _sportThemeSwitcherOpacity(WidgetTester tester) {
  return tester
      .widget<AnimatedOpacity>(find.byKey(sportThemeSwitcherOpacityKey))
      .opacity;
}

double _switcherPillCenterDx(WidgetTester tester) {
  return tester.getRect(find.byKey(storefrontThemeSwitcherPillKey)).center.dx;
}

double _switcherCenterDx(WidgetTester tester) {
  return tester.getRect(find.byType(StorefrontThemeSwitcher)).center.dx;
}

double _themePageSlideDx(WidgetTester tester) {
  return tester
      .widget<FractionalTranslation>(find.byKey(storefrontThemePageSlideKey))
      .translation
      .dx;
}

double _segmentSlideDx(WidgetTester tester) {
  return tester
      .widget<FractionalTranslation>(find.byKey(storefrontSegmentSlideKey))
      .translation
      .dx;
}

Finder _coloredBoxWithColor(Color color) {
  return find.byWidgetPredicate(
    (widget) => widget is ColoredBox && widget.color == color,
  );
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

CmsPageBundle _scrollableHomepageBundle() {
  return CmsPageBundle(
    page: const CmsPageRecord(
      id: 'homepage-nike',
      code: 'homepage_nike',
      locale: 'fr',
      title: 'Homepage Nike',
      isActive: true,
    ),
    sections: List.generate(
      3,
      (index) => CmsHeroSection(
        CmsSectionRecord(
          id: 'hero-$index',
          pageId: 'homepage-nike',
          sectionId: 'hero-$index',
          sectionType: CmsSectionType.heroCampaign,
          rawSectionType: CmsSectionType.heroCampaign.wireName,
          position: index,
          isActive: true,
          config: const {},
        ),
        HeroCampaignConfig(title: 'Section $index', heightMode: 'xl'),
      ),
    ),
  );
}

CmsPageBundle _luxeHomepageBundle() {
  return CmsPageBundle(
    page: const CmsPageRecord(
      id: 'homepage',
      code: 'homepage',
      locale: 'fr',
      title: 'Homepage Luxe',
      isActive: true,
    ),
    sections: [
      CmsHeroSection(
        const CmsSectionRecord(
          id: 'luxe-hero',
          pageId: 'homepage',
          sectionId: 'luxe-hero',
          sectionType: CmsSectionType.heroCampaign,
          rawSectionType: 'hero_campaign',
          position: 0,
          isActive: true,
          config: {},
        ),
        const HeroCampaignConfig(title: 'Luxe hero', heightMode: 'xl'),
      ),
    ],
  );
}

CmsPageBundle _scrollableLuxeHomepageBundle() {
  return CmsPageBundle(
    page: const CmsPageRecord(
      id: 'homepage',
      code: 'homepage',
      locale: 'fr',
      title: 'Homepage Luxe',
      isActive: true,
    ),
    sections: List.generate(
      3,
      (index) => CmsHeroSection(
        CmsSectionRecord(
          id: 'luxe-hero-$index',
          pageId: 'homepage',
          sectionId: 'luxe-hero-$index',
          sectionType: CmsSectionType.heroCampaign,
          rawSectionType: CmsSectionType.heroCampaign.wireName,
          position: index,
          isActive: true,
          config: const {},
        ),
        HeroCampaignConfig(title: 'Luxe section $index', heightMode: 'xl'),
      ),
    ),
  );
}

Future<void> _pumpLanding(
  WidgetTester tester,
  MobileMenuStyle style, {
  List<CatalogCategory> categories = const [],
  StorefrontTheme theme = StorefrontTheme.dior,
  StorefrontTheme? previewTheme,
  CmsPageBundle? cmsBundle,
  Future<CmsPageBundle?> Function(Ref ref)? homepageBuilder,
  Future<CmsPageBundle?> Function(CmsPageRequest request)? cmsBuilder,
  VisitorStorefrontThemeStore? visitorThemeStore,
  bool replaceMobileLogoWithThemeSwitcher = false,
  bool disableAnimations = false,
  CartRepository? cartRepository,
  CartGuestSessionStore? guestSessionStore,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    overridePlatformDefaultLocation: true,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const StorefrontLandingPage(enableStartupBackdrop: false),
      ),
      GoRoute(
        path: '/fr',
        builder: (context, state) =>
            const StorefrontLandingPage(enableStartupBackdrop: false),
      ),
      GoRoute(
        path: '${CatalogRoutes.sportBase}/:segment',
        pageBuilder: (context, state) {
          final segment = StorefrontSportSegment.parse(
            state.pathParameters['segment'],
          );
          return MaterialPage<void>(
            key: const ValueKey('sport-page'),
            child: StorefrontLandingPage(
              key: const ValueKey('sport-landing'),
              sportSegment: segment,
              enableStartupBackdrop: false,
            ),
          );
        },
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.sportBase}/:segment',
        pageBuilder: (context, state) {
          final segment = StorefrontSportSegment.parse(
            state.pathParameters['segment'],
          );
          return MaterialPage<void>(
            key: const ValueKey('sport-page'),
            child: StorefrontLandingPage(
              key: const ValueKey('sport-landing'),
              sportSegment: segment,
              enableStartupBackdrop: false,
            ),
          );
        },
      ),
      GoRoute(
        path: CatalogRoutes.catalogBase,
        builder: (context, state) => const Text('Catalog Route'),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.catalogBase}',
        builder: (context, state) => const Text('Catalog Route'),
      ),
      GoRoute(
        path: '/catalog/:categorySlug',
        builder: (context, state) =>
            Text('PLP ${state.pathParameters['categorySlug']}'),
      ),
      GoRoute(
        path: '/fr/catalog/:categorySlug',
        builder: (context, state) =>
            Text('PLP ${state.pathParameters['categorySlug']}'),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            Text('Search ${state.uri.queryParameters['q']}'),
      ),
      GoRoute(
        path: '/fr/search',
        builder: (context, state) =>
            Text('Search ${state.uri.queryParameters['q']}'),
      ),
      GoRoute(
        path: CatalogRoutes.cart,
        builder: (context, state) => const Text('Cart Route'),
      ),
      GoRoute(
        path: CatalogRoutes.checkout,
        builder: (context, state) => const Text('Checkout Route'),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cmsPageRepositoryProvider.overrideWithValue(
          _CallbackCmsPageRepository((request) async {
            if (cmsBuilder != null) {
              return cmsBuilder(request);
            }
            return cmsBundle;
          }),
        ),
        cmsPageProvider.overrideWith((ref, request) async {
          final theme = await ref.watch(resolvedStorefrontThemeProvider.future);
          if (request.code == homepageCodeFor(theme)) {
            return homepageBuilder != null
                ? homepageBuilder(ref)
                : Future.value(cmsBundle);
          }
          if (cmsBuilder != null) {
            return cmsBuilder(request);
          }
          return cmsBundle;
        }),
        storefrontBrandSettingsProvider.overrideWith(
          (ref) async => StorefrontBrandSettings(
            id: 'settings-id',
            title: 'Atelier Kiki',
            href: '/',
            replaceMobileLogoWithThemeSwitcher:
                replaceMobileLogoWithThemeSwitcher,
          ),
        ),
        storefrontNavigationSettingsProvider.overrideWith(
          (ref) async => StorefrontNavigationSettings(mobileMenuStyle: style),
        ),
        drawerNavigationRepositoryProvider.overrideWithValue(
          const _FallbackDrawerNavigationRepository(),
        ),
        categoryCatalogRepositoryProvider.overrideWithValue(
          _CategoryRepository(categories),
        ),
        productSearchRepositoryProvider.overrideWithValue(
          const _NoSearchRepository(),
        ),
        cartRepositoryProvider.overrideWithValue(
          cartRepository ?? _LandingCartRepository(),
        ),
        guestSessionStoreProvider.overrideWithValue(
          guestSessionStore ?? _LandingGuestSessionStore(),
        ),
        activeStorefrontThemeProvider.overrideWith(
          (ref) async => StorefrontActiveTheme(theme: theme),
        ),
        visitorStorefrontThemeStoreProvider.overrideWithValue(
          visitorThemeStore ?? _InMemoryVisitorStorefrontThemeStore(),
        ),
        if (previewTheme != null)
          editingStorefrontThemeProvider.overrideWith((ref) => previewTheme),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        locale: const Locale('fr'),
        builder: disableAnimations
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
            : null,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpSegmentLanding(
  WidgetTester tester, {
  String initialLocation = '/sport/homme',
  StorefrontNavigationSettings navigationSettings =
      StorefrontNavigationSettings.fallback,
  List<CatalogCategory> categories = const [],
  Future<CmsPageBundle?> Function()? hommeBundle,
  Future<CmsPageBundle?> Function()? femmeBundle,
  Future<CmsPageBundle?> Function()? enfantBundle,
  void Function(String code)? onCmsRead,
  bool disableAnimations = false,
  CartRepository? cartRepository,
  CartGuestSessionStore? guestSessionStore,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: true,
    routes: [
      GoRoute(
        path: CatalogRoutes.home,
        builder: (context, state) =>
            const StorefrontLandingPage(enableStartupBackdrop: false),
      ),
      GoRoute(
        path: '/fr',
        builder: (context, state) =>
            const StorefrontLandingPage(enableStartupBackdrop: false),
      ),
      // Mirror the real app router: the sport landing lives under the
      // SportFlowShell, which owns the persistent bottom nav (the landing no
      // longer renders its own).
      ShellRoute(
        builder: (context, state, child) => SportFlowShell(child: child),
        routes: [
          GoRoute(
            path: '${CatalogRoutes.sportBase}/:segment',
            pageBuilder: (context, state) {
              final segment = StorefrontSportSegment.parse(
                state.pathParameters['segment'],
              );
              // Stable, segment-independent keys so navigating between segments
              // reuses the same page+State and drives the in-page content slide
              // instead of a full Navigator transition.
              return MaterialPage<void>(
                key: const ValueKey('sport-page'),
                child: StorefrontLandingPage(
                  key: const ValueKey('sport-landing'),
                  sportSegment: segment,
                  enableStartupBackdrop: false,
                ),
              );
            },
          ),
          GoRoute(
            path: '/fr${CatalogRoutes.sportBase}/:segment',
            pageBuilder: (context, state) {
              final segment = StorefrontSportSegment.parse(
                state.pathParameters['segment'],
              );
              return MaterialPage<void>(
                key: const ValueKey('sport-page'),
                child: StorefrontLandingPage(
                  key: const ValueKey('sport-landing'),
                  sportSegment: segment,
                  enableStartupBackdrop: false,
                ),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: CatalogRoutes.catalogBase,
        builder: (context, state) => const Text('Catalog Route'),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.catalogBase}',
        builder: (context, state) => const Text('Catalog Route'),
      ),
      GoRoute(
        path: CatalogRoutes.search,
        builder: (context, state) => const Text('Search Route'),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.search}',
        builder: (context, state) => const Text('Search Route'),
      ),
      GoRoute(
        path: CatalogRoutes.cart,
        builder: (context, state) => const Text('Cart Route'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cmsPageRepositoryProvider.overrideWithValue(
          _CallbackCmsPageRepository((request) async {
            onCmsRead?.call(request.code);
            return switch (request.code) {
              'homepage_nike' when hommeBundle != null => hommeBundle(),
              'homepage_nike' => _segmentHomepageBundle(
                pageId: 'homepage-nike',
                pageCode: 'homepage_nike',
                activeSegment: StorefrontSportSegment.homme,
                momentLabel: 'Moment Homme',
              ),
              'homepage_nike_femme' when femmeBundle != null => femmeBundle(),
              'homepage_nike_femme' => _segmentHomepageBundle(
                pageId: 'homepage-nike-femme',
                pageCode: 'homepage_nike_femme',
                activeSegment: StorefrontSportSegment.femme,
                momentLabel: 'Moment Femme',
              ),
              'homepage_nike_enfant' when enfantBundle != null =>
                enfantBundle(),
              'homepage_nike_enfant' => _segmentHomepageBundle(
                pageId: 'homepage-nike-enfant',
                pageCode: 'homepage_nike_enfant',
                activeSegment: StorefrontSportSegment.enfant,
                momentLabel: 'Moment Enfant',
              ),
              _ => null,
            };
          }),
        ),
        cmsPageProvider.overrideWith((ref, request) async {
          onCmsRead?.call(request.code);
          return switch (request.code) {
            'homepage_nike' when hommeBundle != null => hommeBundle(),
            'homepage_nike' => _segmentHomepageBundle(
              pageId: 'homepage-nike',
              pageCode: 'homepage_nike',
              activeSegment: StorefrontSportSegment.homme,
              momentLabel: 'Moment Homme',
            ),
            'homepage_nike_femme' when femmeBundle != null => femmeBundle(),
            'homepage_nike_femme' => _segmentHomepageBundle(
              pageId: 'homepage-nike-femme',
              pageCode: 'homepage_nike_femme',
              activeSegment: StorefrontSportSegment.femme,
              momentLabel: 'Moment Femme',
            ),
            'homepage_nike_enfant' when enfantBundle != null => enfantBundle(),
            'homepage_nike_enfant' => _segmentHomepageBundle(
              pageId: 'homepage-nike-enfant',
              pageCode: 'homepage_nike_enfant',
              activeSegment: StorefrontSportSegment.enfant,
              momentLabel: 'Moment Enfant',
            ),
            _ => null,
          };
        }),
        storefrontBrandSettingsProvider.overrideWith(
          (ref) async => const StorefrontBrandSettings(
            id: 'settings-id',
            title: 'Atelier Kiki',
            href: '/',
          ),
        ),
        storefrontNavigationSettingsProvider.overrideWith(
          (ref) async => navigationSettings,
        ),
        drawerNavigationRepositoryProvider.overrideWithValue(
          const _FallbackDrawerNavigationRepository(),
        ),
        categoryCatalogRepositoryProvider.overrideWithValue(
          _CategoryRepository(categories),
        ),
        productSearchRepositoryProvider.overrideWithValue(
          const _NoSearchRepository(),
        ),
        cartRepositoryProvider.overrideWithValue(
          cartRepository ?? _LandingCartRepository(),
        ),
        guestSessionStoreProvider.overrideWithValue(
          guestSessionStore ?? _LandingGuestSessionStore(),
        ),
        activeStorefrontThemeProvider.overrideWith(
          (ref) async =>
              const StorefrontActiveTheme(theme: StorefrontTheme.nike),
        ),
        visitorStorefrontThemeStoreProvider.overrideWithValue(
          _InMemoryVisitorStorefrontThemeStore(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        locale: const Locale('fr'),
        builder: disableAnimations
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              )
            : null,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

const _segmentDrawerCategories = [
  CatalogCategory(id: 'h', code: 'HOMME', name: 'Homme', slug: 'homme'),
  CatalogCategory(id: 'f', code: 'FEMME', name: 'Femme', slug: 'femme'),
  CatalogCategory(id: 'e', code: 'ENFANT', name: 'Enfant', slug: 'enfant'),
  CatalogCategory(
    id: 'h_ch',
    code: 'HOMME_CH',
    name: 'Chaussures Homme',
    slug: 'homme-chaussures',
    parentId: 'h',
  ),
  CatalogCategory(
    id: 'f_ch',
    code: 'FEMME_CH',
    name: 'Chaussures Femme',
    slug: 'femme-chaussures',
    parentId: 'f',
  ),
];

CmsPageBundle _segmentHomepageBundle({
  required String pageId,
  required String pageCode,
  required StorefrontSportSegment activeSegment,
  required String momentLabel,
  String? tabsDisplayMode,
}) {
  return CmsPageBundle(
    page: CmsPageRecord(
      id: pageId,
      code: pageCode,
      locale: 'fr',
      title: pageCode,
      isActive: true,
    ),
    sections: [
      CmsCategorySplitTabsSection(
        CmsSectionRecord(
          id: '$pageId-tabs',
          pageId: pageId,
          sectionId: '$pageId-tabs',
          sectionType: CmsSectionType.categorySplitTabs,
          rawSectionType: CmsSectionType.categorySplitTabs.wireName,
          position: 0,
          isActive: true,
          config: const {},
        ),
        CategorySplitTabsConfig(
          defaultActiveIndex: activeSegment.index,
          displayMode: tabsDisplayMode,
          items: const [
            CategorySplitTabItem(
              label: 'Homme',
              href: '/sport/homme',
              segment: 'homme',
            ),
            CategorySplitTabItem(
              label: 'Femme',
              href: '/sport/femme',
              segment: 'femme',
            ),
            CategorySplitTabItem(
              label: 'Enfant',
              href: '/sport/enfant',
              segment: 'enfant',
            ),
          ],
        ),
      ),
      CmsHorizontalTileCarouselSection(
        CmsSectionRecord(
          id: '$pageId-moment',
          pageId: pageId,
          sectionId: '$pageId-moment',
          sectionType: CmsSectionType.horizontalTileCarousel,
          rawSectionType: CmsSectionType.horizontalTileCarousel.wireName,
          position: 1,
          isActive: true,
          config: const {},
        ),
        HorizontalTileCarouselConfig(
          title: 'En ce moment',
          items: [HorizontalTileItem(label: momentLabel, href: '/catalog')],
        ),
      ),
    ],
  );
}

class _CallbackCmsPageRepository implements CmsPageRepository {
  const _CallbackCmsPageRepository(this.loadPage);

  final Future<CmsPageBundle?> Function(CmsPageRequest request) loadPage;

  @override
  Future<CmsPageLoadResult> fetchPage({
    required String code,
    required String locale,
  }) async {
    try {
      final bundle = await loadPage(CmsPageRequest(code: code, locale: locale));
      if (bundle == null) return const CmsPageMissing();
      return CmsPageFound(bundle);
    } catch (error, stackTrace) {
      return CmsPageFailure(error, stackTrace);
    }
  }

  @override
  Future<CmsPageLoadResult> fetchPlpForCategory({
    required String categoryId,
    required String locale,
  }) async {
    return const CmsPageMissing();
  }
}

class _InMemoryVisitorStorefrontThemeStore
    implements VisitorStorefrontThemeStore {
  _InMemoryVisitorStorefrontThemeStore({this.failOnWrite = false});

  final bool failOnWrite;
  StorefrontTheme? _override;

  @override
  Future<StorefrontTheme?> readOverride() async => _override;

  @override
  Future<void> writeOverride(StorefrontTheme theme) async {
    if (failOnWrite) throw Exception('write failed');
    _override = theme;
  }

  @override
  Future<void> clearOverride() async {
    _override = null;
  }
}

class _LandingGuestSessionStore implements CartGuestSessionStore {
  CachedActiveCart? activeCart;
  String? _guestId;

  _LandingGuestSessionStore({this.activeCart});

  @override
  Future<void> clearGuestId() async {
    _guestId = null;
    activeCart = null;
  }

  @override
  Future<String> ensureGuestId() async {
    return _guestId ??= 'guest-1';
  }

  @override
  Future<String?> peekGuestId() async => _guestId;

  @override
  Future<CachedActiveCart?> peekActiveCart() async => activeCart;

  @override
  Future<void> cacheActiveCart({
    required String cartId,
    required String currencyCode,
  }) async {
    activeCart = CachedActiveCart(cartId: cartId, currencyCode: currencyCode);
  }

  @override
  Future<void> clearActiveCart() async {
    activeCart = null;
  }
}

class _LandingCartRepository implements CartRepository {
  final CartView? view;
  int getCartWithEntriesCalls = 0;

  _LandingCartRepository({this.view});

  @override
  Future<CartAddAck> addToCartAck({
    required String guestId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
    required String idempotencyKey,
    String? cachedCartId,
    String? cachedCartCurrencyCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Cart?> findActiveCartForGuest(String guestId) async => view?.cart;

  @override
  Future<Cart> createGuestCart({
    required String guestId,
    required String currencyCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CartView> getCartWithEntries(String cartId) async {
    getCartWithEntriesCalls += 1;
    return view ?? CartView(cart: _landingCart, entries: const []);
  }

  @override
  Future<CartEntry?> findEntryForProduct({
    required String cartId,
    required String productId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CartEntry> addEntry({
    required String cartId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CartEntry> updateEntryQuantity({
    required CartEntry entry,
    required int quantity,
    double? unitPrice,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeEntry(String entryId) {
    throw UnimplementedError();
  }

  @override
  Future<CartView> clearCart(String cartId) {
    throw UnimplementedError();
  }

  @override
  Future<CartView> recomputeAndSaveTotals(String cartId) {
    throw UnimplementedError();
  }
}

const _landingCart = Cart(
  id: 'cart-1',
  guestId: 'guest-1',
  currencyCode: 'EUR',
);

CartEntry _landingEntry({required String id, required int quantity}) {
  return CartEntry(
    id: id,
    cartId: 'cart-1',
    productId: 'product-$id',
    productNameSnapshot: 'Produit $id',
    quantity: quantity,
    unitPrice: 15,
    lineTotal: 15.0 * quantity,
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

class _CategoryRepository implements CategoryCatalogRepository {
  final List<CatalogCategory> categories;

  const _CategoryRepository(this.categories);

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

/// Keeps the search overlay's suggestion fetch offline in landing tests.
class _NoSearchRepository implements ProductSearchRepository {
  const _NoSearchRepository();

  @override
  Future<SearchResultPage> searchProducts(SearchQuery query) async =>
      const SearchResultPage.empty();

  @override
  Future<List<String>> suggestProductNames(
    String query, {
    int limit = 8,
  }) async => const <String>[];
}
