import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/catalog_routes.dart';
import 'mobile_fullscreen_menu_overlay.dart';
import '../storefront_layout.dart';
import 'premium_navbar_surface.dart';
import 'scroll_navbar_state_machine.dart';

double premiumNavReservedHeight(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final width = mediaQuery.size.width;
  final safeTop = mediaQuery.padding.top;

  if (StorefrontLayout.isDesktop(width)) {
    return safeTop + 76;
  }
  if (StorefrontLayout.isTabletOnly(width)) {
    return safeTop + 72;
  }
  return safeTop + 74;
}

class PremiumShellNavbarMetrics extends InheritedWidget {
  final bool isVisible;
  final double reservedHeight;

  const PremiumShellNavbarMetrics({
    super.key,
    required this.isVisible,
    required this.reservedHeight,
    required super.child,
  });

  double get visibleReservedHeight => isVisible ? reservedHeight : 0;

  static PremiumShellNavbarMetrics? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PremiumShellNavbarMetrics>();
  }

  @override
  bool updateShouldNotify(PremiumShellNavbarMetrics oldWidget) {
    return isVisible != oldWidget.isVisible ||
        reservedHeight != oldWidget.reservedHeight;
  }
}

class PremiumShellNavbar extends StatefulWidget {
  final Widget child;
  final String routeKey;
  final bool immersive;
  final double heroHeight;
  final bool forceVisibleLight;
  final Color heroForegroundColor;
  final bool useFullscreenReveal;
  final VoidCallback? onMenuOpenStarted;
  final VoidCallback? onClassicMenuRequested;

  const PremiumShellNavbar({
    super.key,
    required this.child,
    required this.routeKey,
    required this.immersive,
    required this.heroHeight,
    required this.forceVisibleLight,
    this.heroForegroundColor = Colors.white,
    this.useFullscreenReveal = false,
    this.onMenuOpenStarted,
    this.onClassicMenuRequested,
  });

  @override
  State<PremiumShellNavbar> createState() => _PremiumShellNavbarState();
}

class _PremiumShellNavbarState extends State<PremiumShellNavbar>
    with SingleTickerProviderStateMixin {
  static const double _topReserveZone = 12;
  static const _paddingDuration = Duration(milliseconds: 240);
  static const _paddingCurve = Curves.easeOutCubic;

  ScrollNavbarStateMachine _stateMachine = ScrollNavbarStateMachine();
  late ScrollNavbarSnapshot _snapshot;
  late final AnimationController _menuController;
  bool _isNearTop = true;
  bool _isMobileMenuOpen = false;
  Offset? _mobileMenuRevealOriginGlobal;
  MobileFullscreenMenuMode _mobileMenuMode =
      MobileFullscreenMenuMode.navigation;

  @override
  void initState() {
    super.initState();
    _snapshot = _initialSnapshot();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 240),
    );
  }

  @override
  void didUpdateWidget(covariant PremiumShellNavbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeChanged = oldWidget.routeKey != widget.routeKey;
    if (routeChanged ||
        oldWidget.immersive != widget.immersive ||
        oldWidget.heroHeight != widget.heroHeight ||
        oldWidget.forceVisibleLight != widget.forceVisibleLight) {
      _reset();
    }
    if (routeChanged || !widget.useFullscreenReveal) {
      _closeMobileMenu(immediate: !widget.useFullscreenReveal);
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  ScrollNavbarSnapshot _initialSnapshot() {
    return _stateMachine.update(
      offset: 0,
      heroHeight: widget.immersive ? widget.heroHeight : 0,
      forceVisibleLight: widget.forceVisibleLight,
    );
  }

  void _reset() {
    _stateMachine = ScrollNavbarStateMachine();
    setState(() {
      _isNearTop = true;
      _snapshot = _initialSnapshot();
    });
  }

  void _handleMenuPressed(Offset? globalOrigin) {
    if (widget.useFullscreenReveal) {
      if (_isMobileMenuOpen &&
          _mobileMenuMode == MobileFullscreenMenuMode.navigation) {
        _closeMobileMenu();
      } else if (_isMobileMenuOpen &&
          _mobileMenuMode == MobileFullscreenMenuMode.search) {
        _closeSearchPanel();
      } else {
        widget.onMenuOpenStarted?.call();
        _openMobileMenu(MobileFullscreenMenuMode.navigation, globalOrigin);
      }
      return;
    }

    widget.onMenuOpenStarted?.call();
    widget.onClassicMenuRequested?.call();
  }

  void _handleSearchPressed(Offset? globalOrigin) {
    if (!widget.useFullscreenReveal) {
      context.go(
        CatalogRoutes.localizedLocation(
          CatalogRoutes.search,
          locale: Localizations.localeOf(context).languageCode,
        ),
      );
      return;
    }

    if (_isMobileMenuOpen &&
        _mobileMenuMode == MobileFullscreenMenuMode.search) {
      _closeSearchPanel();
      return;
    }

    _openMobileMenu(MobileFullscreenMenuMode.search, globalOrigin);
  }

  void _openMobileMenu(MobileFullscreenMenuMode mode, Offset? globalOrigin) {
    setState(() {
      _mobileMenuMode = mode;
      _mobileMenuRevealOriginGlobal = globalOrigin;
      _isMobileMenuOpen = true;
    });
    _menuController.forward();
  }

  void _closeMobileMenu({bool immediate = false}) {
    if (!_isMobileMenuOpen && _menuController.value == 0) {
      return;
    }
    setState(() {
      _isMobileMenuOpen = false;
    });
    if (immediate) {
      _menuController.value = 0;
    } else {
      _menuController.reverse();
    }
  }

  void _closeSearchPanel() {
    _closeMobileMenu();
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final offset = notification.metrics.pixels.clamp(0.0, double.infinity);
    final nextIsNearTop = offset <= _topReserveZone;
    final next = _stateMachine.update(
      offset: offset,
      heroHeight: widget.immersive ? widget.heroHeight : 0,
      forceVisibleLight: widget.forceVisibleLight,
    );
    if (next != _snapshot || nextIsNearTop != _isNearTop) {
      setState(() {
        _isNearTop = nextIsNearTop;
        _snapshot = next;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final shouldReserveTop =
        widget.forceVisibleLight || (!widget.immersive && _isNearTop);
    final navReservedHeight = premiumNavReservedHeight(context);
    final topPadding = shouldReserveTop ? navReservedHeight : 0.0;
    return PopScope<Object?>(
      canPop: !_isMobileMenuOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isMobileMenuOpen) {
          _closeMobileMenu();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: AnimatedPadding(
              duration: _paddingDuration,
              curve: _paddingCurve,
              padding: EdgeInsets.only(top: topPadding),
              child: PremiumShellNavbarMetrics(
                isVisible: _snapshot.isVisible,
                reservedHeight: navReservedHeight,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScroll,
                  child: ExcludeSemantics(
                    excluding: _isMobileMenuOpen,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
          if (widget.useFullscreenReveal)
            Positioned.fill(
              child: MobileFullscreenMenuOverlay(
                progress: _menuController,
                isOpen: _isMobileMenuOpen,
                topInset: navReservedHeight,
                mode: _mobileMenuMode,
                revealOriginGlobal: _mobileMenuRevealOriginGlobal,
                onClose: _closeMobileMenu,
                onSearchClose: _closeSearchPanel,
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PremiumNavbarSurface(
              snapshot: _snapshot,
              heroForegroundColor: widget.heroForegroundColor,
              onMenuTap: _handleMenuPressed,
              onSearchTap: _handleSearchPressed,
              isMenuOpen: _isMobileMenuOpen,
              menuProgress: _menuController,
              hideChromeForOpenMenu:
                  widget.useFullscreenReveal && _isMobileMenuOpen,
            ),
          ),
        ],
      ),
    );
  }
}
