import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/catalog_routes.dart';
import '../../../app/locale_route_resolver.dart';
import '../../../application/storefront/storefront_chrome_profile.dart';
import '../../../application/storefront/storefront_sport_segment.dart';
import '../../../application/storefront/storefront_theme.dart';
import '../../providers/edit_mode_provider.dart';
import '../../providers/sport_home_icon_loading_provider.dart';
import '../../providers/storefront_theme_providers.dart';
import '../storefront_category_drawer.dart';
import '../storefront_drawer_prefetch.dart';
import 'adaptive_bottom_nav.dart';
import 'floating_bottom_nav.dart';

/// Persistent shell for the sport flow and the public home route.
///
/// This is a single [ShellRoute] builder, so go_router keeps this widget — and
/// therefore the one [AdaptiveBottomNav] (and its [IridescentNavRing], ring
/// animation and scroll signal) it hosts — **mounted across its child routes**
/// whenever the active route/theme needs the floating Sport nav. Navigating
/// home <-> sport landing <-> sport PLP/PDP swaps only [child]; the bottom nav
/// stays the *same instance* throughout, so its animation never restarts on
/// navigation.
///
/// The nav lives here, at a fixed tree position, on purpose: were it rebuilt
/// per page (a different ancestor chain) Flutter would recreate its State and
/// the animation would reset. Each child route therefore brings its own
/// Scaffold/chrome and must NOT render its own bottom nav.
class SportFlowShell extends ConsumerWidget {
  final Widget child;

  const SportFlowShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routePath = resolveLocaleRoute(
      GoRouterState.of(context).uri,
    ).routePath;
    if (!_shouldShowBottomNav(routePath, ref)) {
      return child;
    }
    final homeIconLoading = _canShowHomeIconLoading(routePath)
        ? ref.watch(sportHomeIconLoadingProvider)
        : false;

    // The nav lives above the per-route Scaffolds (so it persists), which means
    // it is outside their Material. Provide a transparent Material here so the
    // nav tiles' InkResponse has an ink context without forcing a second
    // Scaffold around the page.
    return Material(
      type: MaterialType.transparency,
      child: AdaptiveBottomNav(
        onHomeTripleTap: () =>
            ref.read(editControlsVisibleProvider.notifier).state = true,
        homeIconLoading: homeIconLoading,
        child: child,
      ),
    );
  }

  bool _shouldShowBottomNav(String routePath, WidgetRef ref) {
    if (_isSportRoute(routePath)) {
      return true;
    }

    final activeTheme = ref.watch(effectiveStorefrontThemeAsyncProvider).value;
    if (activeTheme == null) {
      return false;
    }
    return StorefrontChromeProfile.forTheme(activeTheme).showFloatingBottomNav;
  }

  bool _isSportRoute(String routePath) {
    return routePath == CatalogRoutes.sportBase ||
        routePath.startsWith('${CatalogRoutes.sportBase}/');
  }

  bool _canShowHomeIconLoading(String routePath) {
    if (routePath == CatalogRoutes.home) return true;
    final segments = Uri(path: routePath).pathSegments;
    if (segments.isEmpty ||
        segments.first != CatalogRoutes.sportBase.substring(1)) {
      return false;
    }
    final segment = segments.length >= 2
        ? StorefrontSportSegment.tryParse(segments[1])
        : null;
    if (segment == null) return false;
    // Segment landing, category PLP, and product PDP. Each page publishes its
    // own loading state, so a stale PLP animation cannot leak into the PDP.
    return segments.length == 2 || segments.length == 3 || segments.length == 4;
  }
}

/// Per-route chrome for a sport **PLP** hosted by [SportFlowShell].
///
/// The sport PLP page ([StorefrontHomePage]) has no Scaffold of its own — it
/// used to inherit one from `MainShell`. Now that it lives under
/// [SportFlowShell] instead, this provides the same things `MainShell` gave it
/// for the sport theme: the forced nike theme, the category drawer, and the
/// bottom inset that reserves room for the floating nav (which the shell paints
/// above this). It deliberately does NOT render a bottom nav — that is the
/// shell's single persistent instance.
class SportFlowPlpScaffold extends StatelessWidget {
  final Widget child;

  const SportFlowPlpScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        effectiveStorefrontThemeAsyncProvider.overrideWithValue(
          AsyncValue.data(StorefrontTheme.nike),
        ),
      ],
      child: StorefrontDrawerPrefetch(
        child: Scaffold(
          backgroundColor: Colors.white,
          drawer: const StorefrontCategoryDrawer(),
          body: _reserveBottomNavSpace(context, child),
        ),
      ),
    );
  }

  // Mirror MainShell._buildSportBody: inflate the bottom padding so the page's
  // scrollables clear the floating nav the shell overlays.
  Widget _reserveBottomNavSpace(BuildContext context, Widget child) {
    final mediaQuery = MediaQuery.of(context);
    final reservedBottom =
        FloatingBottomNav.overlayHeight + FloatingBottomNav.overlayMargin;
    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: mediaQuery.padding.copyWith(
          bottom: mediaQuery.padding.bottom + reservedBottom,
        ),
      ),
      child: child,
    );
  }
}

/// Per-route provider/padding scope for a sport **PDP** hosted by
/// [SportFlowShell].
///
/// The PDP already owns its Scaffold and drawer. Wrapping it in another
/// Scaffold would duplicate chrome, so this only applies the forced sport theme
/// and the bottom inset that keeps PDP scrollables above the persistent nav.
class SportFlowPdpScope extends StatelessWidget {
  final Widget child;

  const SportFlowPdpScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        effectiveStorefrontThemeAsyncProvider.overrideWithValue(
          AsyncValue.data(StorefrontTheme.nike),
        ),
      ],
      child: _reserveBottomNavSpace(context, child),
    );
  }

  Widget _reserveBottomNavSpace(BuildContext context, Widget child) {
    final mediaQuery = MediaQuery.of(context);
    final reservedBottom =
        FloatingBottomNav.overlayHeight + FloatingBottomNav.overlayMargin;
    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: mediaQuery.padding.copyWith(
          bottom: mediaQuery.padding.bottom + reservedBottom,
        ),
      ),
      child: child,
    );
  }
}
