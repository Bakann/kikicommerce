import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/catalog_routes.dart';
import '../../../app/locale_route_resolver.dart';
import '../../../app/app_providers.dart';
import '../../../application/storefront/storefront_chrome_profile.dart';
import '../../../application/storefront/storefront_navigation_settings.dart';
import '../../../application/storefront/storefront_theme.dart';
import '../../providers/cart_provider.dart';
import '../../providers/drawer_navigation_preloader.dart';
import '../../providers/edit_mode_provider.dart';
import '../../providers/sport_home_icon_loading_provider.dart';
import '../../providers/storefront_shell_provider.dart';
import '../../providers/storefront_theme_providers.dart';
import '../storefront_category_drawer.dart';
import '../storefront_drawer_prefetch.dart';
import '../storefront_layout.dart';
import 'adaptive_bottom_nav.dart';
import 'floating_bottom_nav.dart';
import 'premium_shell_navbar.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  final String routeKey;
  final bool transparentHeader;
  final Color? headerForegroundColor;
  final StorefrontTheme? forcedTheme;

  const MainShell({
    super.key,
    required this.child,
    required this.routeKey,
    this.transparentHeader = false,
    this.headerForegroundColor,
    this.forcedTheme,
  });

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Warm the cart so the badge reflects the server-side cart on cold start;
    // the cached count from CartItemCountNotifier covers the gap before this
    // resolves.
    unawaited(ref.read(cartControllerProvider.notifier).prefetchActiveCart());
    // Note: the drawer warm-up is triggered by StorefrontDrawerPrefetch,
    // which is mounted on every page that hosts the drawer — including
    // the landing page (outside this ShellRoute). Triggering from here
    // would only cover routes inside the shell.
  }

  void _revealEditControls() {
    ref.read(editControlsVisibleProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    final shellState = ref.watch(storefrontShellProvider);
    final isEditMode = ref.watch(editModeProvider);
    // Chrome (top nav vs bottom nav) follows the active apparence, the same
    // way the landing page does via StorefrontChromeProfile. While the theme
    // is loading we keep the luxe top nav (the fallback theme is Dior), then
    // swap once resolved. The landing page lives outside this ShellRoute and
    // owns its own chrome, so there is no double bottom nav.
    final theme =
        widget.forcedTheme ??
        ref.watch(effectiveStorefrontThemeAsyncProvider).value;
    final chrome = theme == null
        ? null
        : StorefrontChromeProfile.forTheme(theme);
    final showTopNav = chrome?.showPremiumTopNav ?? true;
    final showBottomNav = chrome?.showFloatingBottomNav ?? false;
    final routePath = _routePathFor(widget.routeKey);
    final homeIconLoading = showBottomNav && _canShowHomeIconLoading(routePath)
        ? ref.watch(sportHomeIconLoadingProvider)
        : false;

    final wantsFullscreenReveal = ref.watch(
      storefrontNavigationSettingsProvider.select(
        (async) =>
            async.value?.mobileMenuStyle == MobileMenuStyle.fullscreenReveal,
      ),
    );
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);
    final useFullscreenReveal = showTopNav && isMobile && wantsFullscreenReveal;
    // Immersive (hero behind a transparent top nav) only applies to the
    // top-nav chrome. Sport chrome has no top nav, so content starts below
    // the status bar on a plain white background.
    final wantsImmersive =
        showTopNav &&
        (widget.transparentHeader || shellState.isImmersive) &&
        !isEditMode;
    final heroForegroundColor =
        shellState.headerForegroundColor ??
        widget.headerForegroundColor ??
        Colors.white;

    final shellChild = _themedChild(widget.child);
    final Widget body = showTopNav
        ? PremiumShellNavbar(
            routeKey: widget.routeKey,
            immersive: wantsImmersive,
            heroHeight: wantsImmersive ? (shellState.heroHeight ?? 0) : 0,
            forceVisibleLight: isEditMode,
            heroForegroundColor: heroForegroundColor,
            useFullscreenReveal: useFullscreenReveal,
            onMenuOpenStarted: () {
              unawaited(
                ref
                    .read(drawerNavigationPreloaderProvider.notifier)
                    .recordOpen(),
              );
            },
            onClassicMenuRequested: () =>
                _scaffoldKey.currentState?.openDrawer(),
            child: shellChild,
          )
        : _buildSportBody(context, shellChild);

    return StorefrontDrawerPrefetch(
      child: Scaffold(
        key: _scaffoldKey,
        extendBodyBehindAppBar: wantsImmersive,
        backgroundColor: wantsImmersive ? Colors.black : Colors.white,
        drawerEnableOpenDragGesture: !useFullscreenReveal,
        drawer: const StorefrontCategoryDrawer(),
        body: showBottomNav
            ? AdaptiveBottomNav(
                onHomeTripleTap: _revealEditControls,
                homeIconLoading: homeIconLoading,
                child: body,
              )
            : body,
      ),
    );
  }

  String _routePathFor(String routeKey) {
    final uri = Uri.tryParse(routeKey);
    if (uri == null) {
      return routeKey;
    }
    return resolveLocaleRoute(uri).routePath;
  }

  bool _canShowHomeIconLoading(String routePath) {
    final segments = Uri(path: routePath).pathSegments;
    if (segments.isEmpty ||
        segments.first != CatalogRoutes.catalogBase.substring(1)) {
      return false;
    }
    return segments.length <= 3;
  }

  /// Sport chrome body: no top nav. Inflate the bottom padding so page
  /// scrollables clear the floating bottom nav overlay, then hand the child
  /// the extra inset through MediaQuery (the same padding any SafeArea-aware
  /// descendant already honours).
  Widget _themedChild(Widget child) {
    final forcedTheme = widget.forcedTheme;
    if (forcedTheme == null) {
      return child;
    }
    return ProviderScope(
      overrides: [
        effectiveStorefrontThemeAsyncProvider.overrideWithValue(
          AsyncValue.data(forcedTheme),
        ),
      ],
      child: child,
    );
  }

  Widget _buildSportBody(BuildContext context, Widget child) {
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
