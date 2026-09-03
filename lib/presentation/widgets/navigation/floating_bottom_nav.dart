import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/catalog_routes.dart';
import '../../../app/locale_route_resolver.dart';
import '../../../application/storefront/storefront_sport_segment.dart';
import '../../../config/web_renderer_feature_flags.dart';
import '../../l10n/l10n_extension.dart';
import '../../providers/cart_flight_coordinator_provider.dart';
import '../customer_account_modal.dart';
import '../storefront_layout.dart';
import 'adaptive_bottom_nav.dart';
import 'animated_nav_icon.dart';
import 'animated_shopping_cart_icon.dart';
import 'iridescent_nav_ring.dart';
import 'scroll_motion_signal.dart';
import 'sport_search_magnifying_glass_icon.dart';

@visibleForTesting
bool shouldUseStaticIridescentNavRing({
  required bool isWeb,
  required double viewportWidth,
  bool navbarShadersEnabled = WebRendererFeatureFlags.enableNavbarShaders,
  bool mobileWebFeedbackEnabled =
      WebRendererFeatureFlags.enableMobileWebIridescentFeedback,
}) {
  return !navbarShadersEnabled ||
      (isWeb &&
          !mobileWebFeedbackEnabled &&
          StorefrontLayout.isMobile(viewportWidth));
}

/// Pill-shaped bottom navigation overlay used by the Nike storefront theme.
///
/// Sits above page content via a Stack in the landing page. Safe-area aware so
/// it never collides with the system gesture bar. Four fixed destinations to
/// match the Nike reference while reusing the existing cart and account flows.
///
/// Admin gesture: three rapid taps on the Accueil tile (within a 650ms
/// window) invoke [onHomeTripleTap]. This mirrors the Dior brand triple-tap
/// for revealing edit controls. The first two taps still navigate
/// immediately — there is no buffering window slowing down single taps; the
/// third tap suppresses navigation and fires the reveal instead. The other
/// three destinations have no triple-tap behaviour by design.
class FloatingBottomNav extends ConsumerWidget {
  static const double overlayHeight = 72;
  static const double overlayMargin = 12;
  static const Duration tripleTapWindow = Duration(milliseconds: 650);
  static const Key homeTileKey = ValueKey('sport-bottom-nav-home-tile');
  static const Key searchTileKey = ValueKey('sport-bottom-nav-search-tile');

  /// Three rapid taps on Accueil fire this. Used to reveal admin edit
  /// controls when the Nike theme is active (the top navbar is not
  /// rendered on Nike, so the Dior brand triple-tap entry point isn't
  /// available there).
  final VoidCallback? onHomeTripleTap;
  final VoidCallback? onBeforeNavigate;

  /// Live scroll velocity that animates the Home iridescent lens. Null (e.g. in
  /// isolation tests) leaves the lens at its resting, scroll-independent look.
  final ScrollMotionSignal? scrollMotion;

  /// Drives the rotating Kiki overlay above the Home shader disc while the
  /// landing transition is loading.
  final bool homeIconLoading;

  /// Enables the custom Home ring and Search lens treatments. When disabled,
  /// both destinations render as standard Material icons.
  final bool navbarShadersEnabled;

  /// Total vertical space the overlay reserves at the bottom of the viewport.
  /// Consumers add this to scrollable padding so content isn't masked.
  static double reservedSpaceFor(BuildContext context) {
    return overlayHeight + overlayMargin + MediaQuery.paddingOf(context).bottom;
  }

  const FloatingBottomNav({
    super.key,
    this.onHomeTripleTap,
    this.onBeforeNavigate,
    this.scrollMotion,
    this.homeIconLoading = false,
    this.navbarShadersEnabled = WebRendererFeatureFlags.enableNavbarShaders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Deferred count: identical to cartItemCountProvider except while an
    // add-to-cart comet is in flight — the increment then appears at impact.
    final cartCount = ref.watch(displayedCartBadgeCountProvider);
    final destinations = _destinationsFor(context);
    final currentLocation = _normalizedRoutePath(GoRouterState.of(context).uri);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Adaptive contrast: an enclosing AdaptiveBottomNav samples the real
    // backdrop luminance behind the pill and supplies it here. It drives only
    // the icon/label colours (the glass stays constant). Defaults to the light
    // backdrop reading when there's no sampler (e.g. isolation tests).
    final brightness = BottomNavBrightness.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, overlayMargin + bottomInset),
      child: _BottomNavBackdropSurface(
        searchLensCutoutEnabled: navbarShadersEnabled,
        child: SizedBox(
          height: overlayHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final dest in destinations)
                  Expanded(
                    child: _NavTile(
                      key: dest.matchPath == CatalogRoutes.home
                          ? homeTileKey
                          : dest.matchPath == CatalogRoutes.search
                          ? searchTileKey
                          : null,
                      destination: dest,
                      isActive: _isActive(currentLocation, dest),
                      brightness: brightness,
                      badgeCount: dest.matchPath == CatalogRoutes.cart
                          ? cartCount
                          : 0,
                      scrollMotion: scrollMotion,
                      homeIconLoading: homeIconLoading && dest.iridescent,
                      navbarShadersEnabled: navbarShadersEnabled,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isActive(String path, _NavDestination dest) {
    if (dest.matchPath == null) return false;
    final target = dest.matchPath!;
    if (target == CatalogRoutes.home) return _isHomeLikeRoute(path);
    return path == target || path.startsWith('$target/');
  }

  List<_NavDestination> _destinationsFor(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = context.l10n;
    // All four tiles use static glyphs wrapped in a
    // hand-rolled Flutter pulse via AnimatedNavIcon — no animated-icon package.
    return [
      _NavDestination(
        label: l10n.navHome,
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        matchPath: CatalogRoutes.home,
        // The hero tile: its icon sits inside the animated iridescent lens.
        iridescent: true,
        onTap: (ctx) => _handleHomeTap(ctx, locale: locale),
        onTripleTap: onHomeTripleTap,
        onBeforeNavigate: onBeforeNavigate,
      ),
      _NavDestination(
        label: l10n.navSearch,
        icon: Icons.search,
        activeIcon: Icons.search,
        magnifyingGlassShader: true,
        matchPath: CatalogRoutes.search,
        onTap: (ctx) => ctx.go(
          CatalogRoutes.localizedLocation(CatalogRoutes.search, locale: locale),
        ),
        onBeforeNavigate: onBeforeNavigate,
      ),
      _NavDestination(
        label: l10n.navCart,
        icon: Icons.shopping_bag_outlined,
        activeIcon: Icons.shopping_bag,
        matchPath: CatalogRoutes.cart,
        // Already on /cart: tapping the active Panier tab must not push a
        // second cart page onto the stack.
        onTap: (ctx) {
          if (GoRouterState.of(ctx).uri.path == CatalogRoutes.cart) return;
          ctx.push(CatalogRoutes.cart);
        },
        onBeforeNavigate: onBeforeNavigate,
      ),
      _NavDestination(
        label: l10n.navProfile,
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        matchPath: null,
        onTap: showCustomerAccountModal,
        onBeforeNavigate: onBeforeNavigate,
      ),
    ];
  }

  void _handleHomeTap(BuildContext context, {required String locale}) {
    final router = GoRouter.of(context);
    final currentPath = _normalizedRoutePath(GoRouterState.of(context).uri);
    if (_isHomeLikeRoute(currentPath)) {
      return;
    }
    if (router.canPop()) {
      router.pop();
      return;
    }
    final fallback = _homeFallbackLocationFor(currentPath);
    context.go(CatalogRoutes.localizedLocation(fallback, locale: locale));
  }
}

String _normalizedRoutePath(Uri uri) {
  return resolveLocaleRoute(uri).routePath;
}

bool _isHomeLikeRoute(String path) {
  return path == CatalogRoutes.home || _isSportSegmentLanding(path);
}

bool _isSportSegmentLanding(String path) {
  final segments = Uri(path: path).pathSegments;
  return segments.length == 2 &&
      segments.first == CatalogRoutes.sportBase.substring(1) &&
      StorefrontSportSegment.tryParse(segments[1]) != null;
}

String _homeFallbackLocationFor(String path) {
  final segments = Uri(path: path).pathSegments;
  if (segments.length >= 2 &&
      segments.first == CatalogRoutes.sportBase.substring(1)) {
    final segment = StorefrontSportSegment.tryParse(segments[1]);
    if (segment != null) {
      return CatalogRoutes.sportSegmentLocation(segment);
    }
  }
  return CatalogRoutes.home;
}

/// Frosted pill behind the nav tiles.
///
/// The resting look is the transparent premium panel (unchanged values). On
/// first display, after a short delay, it plays a one-shot "attention" swell:
/// fill opacity, rim, shadow and a tiny upward lift rise, hold briefly at the
/// peak, then ease back to rest — so the otherwise discreet bar registers once
/// without becoming intrusive. Native Flutter only (AnimationController +
/// Tween/CurveTween + AnimatedBuilder); the backdrop blur sigma is kept
/// constant on purpose (animating it would re-rasterize the backdrop every
/// frame). Confined to this widget so the navbar never rebuilds per frame, and
/// honors reduced-motion.
class _BottomNavBackdropSurface extends StatefulWidget {
  final Widget child;
  final bool searchLensCutoutEnabled;

  const _BottomNavBackdropSurface({
    required this.child,
    required this.searchLensCutoutEnabled,
  });

  @override
  State<_BottomNavBackdropSurface> createState() =>
      _BottomNavBackdropSurfaceState();
}

class _BottomNavBackdropSurfaceState extends State<_BottomNavBackdropSurface>
    with SingleTickerProviderStateMixin {
  // Delay before the intro swell fires (600–900ms window).
  static const _introDelay = Duration(milliseconds: 750);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  // One-shot pulse 0 → 1 → 0: a curved swell up, a brief hold at the peak so
  // the eye catches it, then a curved settle back to rest. Runs on continuous
  // frames (no hold timer) so it never leaves the bar stuck mid-emphasis.
  late final Animation<double> _emphasis = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 38,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(1), weight: 22),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 40,
    ),
  ]).animate(_controller);

  Timer? _introTimer;

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(_introDelay, _runIntroEmphasis);
  }

  void _runIntroEmphasis() {
    if (!mounted) return;
    // Reduced-motion: leave the bar at its resting transparent state.
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0); // one shot — never repeats.
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(48);
    // The glass itself never adapts (no jarring tint snap on scroll-stop) — it
    // stays the original transparent white frost; the nav icons carry the
    // contrast instead. The peak briefly makes the bar more solid + lifted for
    // the one-shot intro swell.
    const baseColor = Colors.white;
    final fillTween = Tween<double>(begin: 0.42, end: 0.82);
    final borderTween = Tween<double>(begin: 0.52, end: 0.95);
    final shadowAlphaTween = Tween<double>(begin: 0.09, end: 0.26);
    final shadowBlurTween = Tween<double>(begin: 30, end: 44);
    final shadowSpreadTween = Tween<double>(begin: 0, end: 2);
    final liftTween = Tween<double>(begin: 0, end: -3);

    return AnimatedBuilder(
      animation: _emphasis,
      // `child` is built once; only the surface decoration recomputes per frame.
      child: widget.child,
      builder: (context, child) {
        final t = _emphasis;
        return Transform.translate(
          offset: Offset(0, liftTween.evaluate(t)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: shadowAlphaTween.evaluate(t),
                  ),
                  blurRadius: shadowBlurTween.evaluate(t),
                  spreadRadius: shadowSpreadTween.evaluate(t),
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: ClipPath(
                    clipper: _SearchLensGlassClipper(
                      cutoutEnabled: widget.searchLensCutoutEnabled,
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: baseColor.withValues(
                            alpha: fillTween.evaluate(t),
                          ),
                          borderRadius: radius,
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: borderTween.evaluate(t),
                            ),
                            width: 1,
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                ?child,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchLensGlassClipper extends CustomClipper<Path> {
  final bool cutoutEnabled;

  const _SearchLensGlassClipper({required this.cutoutEnabled});

  @override
  Path getClip(Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(48)),
      );

    if (cutoutEnabled) {
      final tileWidth = (size.width - 16) / 4;
      final searchTileCenter = Offset(8 + tileWidth * 1.5, size.height / 2);
      // Match the centered lens inside SportSearchMagnifyingGlassIcon. Keep the
      // opening to the glass only: the rim and handle should sit on the nav
      // surface, not punch a larger transparent disc through it.
      path.addOval(Rect.fromCircle(center: searchTileCenter, radius: 16));
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _SearchLensGlassClipper oldClipper) =>
      oldClipper.cutoutEnabled != cutoutEnabled;
}

class _NavDestination {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String? matchPath;

  /// When true the destination is rendered as the [IridescentNavRing] Home hero.
  final bool iridescent;

  /// When true the search glyph is rendered with the Sport loupe shader.
  final bool magnifyingGlassShader;

  final void Function(BuildContext context) onTap;
  final VoidCallback? onTripleTap;
  final VoidCallback? onBeforeNavigate;

  const _NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.matchPath,
    required this.onTap,
    this.iridescent = false,
    this.magnifyingGlassShader = false,
    this.onTripleTap,
    this.onBeforeNavigate,
  });
}

class _NavTile extends StatefulWidget {
  final _NavDestination destination;
  final bool isActive;
  final Brightness brightness;
  final int badgeCount;
  final ScrollMotionSignal? scrollMotion;
  final bool homeIconLoading;
  final bool navbarShadersEnabled;

  const _NavTile({
    super.key,
    required this.destination,
    required this.isActive,
    required this.brightness,
    this.badgeCount = 0,
    this.scrollMotion,
    this.homeIconLoading = false,
    required this.navbarShadersEnabled,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  int _tapCount = 0;
  // Bumped on each navigating tap so the animated icon re-pulses even when the
  // tile is already active. Drives only this tile's icon, never per-frame work.
  int _playToken = 0;
  Timer? _windowTimer;

  @override
  void dispose() {
    _windowTimer?.cancel();
    super.dispose();
  }

  void _pulse() {
    setState(() => _playToken++);
  }

  void _handleTap(BuildContext context) {
    final tripleTap = widget.destination.onTripleTap;

    // No triple-tap binding: fire navigation immediately, no bookkeeping.
    if (tripleTap == null) {
      _pulse();
      widget.destination.onBeforeNavigate?.call();
      widget.destination.onTap(context);
      return;
    }

    _tapCount += 1;

    // Third tap inside the window: skip navigation, fire reveal, reset.
    if (_tapCount >= 3) {
      _tapCount = 0;
      _windowTimer?.cancel();
      _windowTimer = null;
      tripleTap();
      return;
    }

    // First or second tap: navigate immediately (no latency added) and
    // restart the window so a slow third tap doesn't trigger reveal.
    _windowTimer?.cancel();
    _windowTimer = Timer(FloatingBottomNav.tripleTapWindow, () {
      if (!mounted) return;
      _tapCount = 0;
    });
    _pulse();
    widget.destination.onBeforeNavigate?.call();
    widget.destination.onTap(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    // Over a dark backdrop the icons go light; over a bright one they keep the
    // original dark/grey. The colour is cross-faded (below) so an adaptation at
    // scroll-stop reads as a gentle tint shift, not a snap.
    final activeColor = isDark ? Colors.white : const Color(0xFF111111);
    final inactiveColor = isDark
        ? const Color(0xFFB9BBC1)
        : const Color(0xFF8E8E8E);
    final targetColor = widget.isActive ? activeColor : inactiveColor;

    return InkResponse(
      onTap: () => _handleTap(context),
      radius: 40,
      child: TweenAnimationBuilder<Color?>(
        // Reduced-motion: snap to the colour (Duration.zero = no tween).
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        tween: ColorTween(end: targetColor),
        builder: (context, animatedColor, _) {
          final color = animatedColor ?? targetColor;
          final iridescent = widget.destination.iridescent;
          final useIridescentHome = iridescent && widget.navbarShadersEnabled;
          final useCustomSearch =
              widget.destination.magnifyingGlassShader &&
              widget.navbarShadersEnabled;
          final icon = widget.isActive
              ? widget.destination.activeIcon
              : widget.destination.icon;
          Widget iconUnit = AnimatedNavIcon(
            isActive: widget.isActive,
            playToken: _playToken,
            child: useIridescentHome
                ? _HomeRingGlyph(
                    icon: icon,
                    color: Colors.white,
                    isLoading: widget.homeIconLoading,
                    shadows: const [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                      Shadow(color: Color(0x40FFFFFF), blurRadius: 2),
                    ],
                  )
                : widget.destination.matchPath == CatalogRoutes.cart
                ? _CartCometImpactAnchor(
                    color: color,
                    brightness: widget.brightness,
                    badgeCount: widget.badgeCount,
                  )
                : _IconWithBadge(
                    icon: icon,
                    color: color,
                    isActive: widget.isActive,
                    brightness: widget.brightness,
                    badgeCount: widget.badgeCount,
                    magnifyingGlassShader: useCustomSearch,
                  ),
          );
          if (useIridescentHome) {
            iconUnit = IridescentNavRing(
              isActive: widget.isActive,
              isLoading: widget.homeIconLoading,
              staticFallback: shouldUseStaticIridescentNavRing(
                isWeb: kIsWeb,
                viewportWidth: MediaQuery.sizeOf(context).width,
                navbarShadersEnabled: widget.navbarShadersEnabled,
              ),
              playToken: _playToken,
              scrollMotion: widget.scrollMotion,
              child: iconUnit,
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconUnit,
                // The Home and Search hero glyphs are label-less: just the
                // centered optical treatment. The other tiles keep captions.
                if (!iridescent &&
                    !widget.destination.magnifyingGlassShader) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.destination.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: widget.isActive
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeRingGlyph extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool isLoading;
  final List<Shadow> shadows;

  const _HomeRingGlyph({
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.shadows,
  });

  @override
  State<_HomeRingGlyph> createState() => _HomeRingGlyphState();
}

class _HomeRingGlyphState extends State<_HomeRingGlyph>
    with TickerProviderStateMixin {
  static const _spinDuration = Duration(milliseconds: 760);
  static const _morphDuration = Duration(milliseconds: 360);

  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: _spinDuration,
  );
  late final AnimationController _morphController = AnimationController(
    vsync: this,
    duration: _morphDuration,
    value: widget.isLoading ? 1 : 0,
  );
  late final Listenable _glyphAnimation = Listenable.merge([
    _spinController,
    _morphController,
  ]);

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) {
      _spinController.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionState();
  }

  @override
  void didUpdateWidget(_HomeRingGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      _syncMotionState();
    }
  }

  void _syncMotionState() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _spinController.stop();
      _spinController.value = 0;
      _morphController.value = 0;
      return;
    }

    if (widget.isLoading) {
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
      _morphController.forward();
      return;
    }

    _morphController.reverse();
    _settleSpinToUpright();
  }

  void _settleSpinToUpright() {
    if (!_spinController.isAnimating && _spinController.value == 0) {
      return;
    }
    final remaining = (1 - _spinController.value).clamp(0.0, 1.0);
    final settleDuration = Duration(
      milliseconds: (220 + remaining * 360).round(),
    );
    _spinController
        .animateTo(1, duration: settleDuration, curve: Curves.easeOutCubic)
        .whenComplete(() {
          if (!mounted || widget.isLoading) return;
          _spinController.value = 0;
        });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Icon(widget.icon, size: 24, color: widget.color);
    }

    return SizedBox.square(
      dimension: 30,
      child: AnimatedBuilder(
        animation: _glyphAnimation,
        builder: (context, _) {
          final morph = Curves.easeInOutCubic.transform(_morphController.value);
          final angle = _spinController.value * math.pi * 2;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (morph < 0.999)
                Opacity(
                  opacity: 1 - morph,
                  child: Icon(
                    widget.icon,
                    size: 24,
                    color: widget.color,
                    shadows: widget.shadows,
                  ),
                ),
              if (morph > 0.001)
                Opacity(
                  opacity: morph,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002)
                      ..rotateY(angle),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Kiki',
                        key: const ValueKey(
                          'sport-bottom-nav-home-loading-brand-word',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: widget.color,
                          height: 0.9,
                          shadows: widget.shadows,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Cart tile icon+badge, instrumented as the add-to-cart comet's target.
///
/// Registers a global-rect resolver with [CartFlightCoordinator] (resolved
/// once per flight, never per frame) and plays the impact choreography when
/// [CartFlightBadgeState.impactTick] bumps: icon squash-recover with a short
/// glow, then the macaron pop — the deferred count swaps in the same frame.
///
/// Never animates on mount: the controller is created idle and only runs on
/// an explicit tick, as a short one-shot, so the prewarm-dwell nav tests
/// (long pump + pumpAndSettle) keep settling.
class _CartCometImpactAnchor extends ConsumerStatefulWidget {
  final Color color;
  final Brightness brightness;
  final int badgeCount;

  const _CartCometImpactAnchor({
    required this.color,
    required this.brightness,
    required this.badgeCount,
  });

  @override
  ConsumerState<_CartCometImpactAnchor> createState() =>
      _CartCometImpactAnchorState();
}

class _CartCometImpactAnchorState extends ConsumerState<_CartCometImpactAnchor>
    with TickerProviderStateMixin {
  static const _openDuration = Duration(milliseconds: 500);
  static const _bounceDuration = Duration(milliseconds: 300);
  static const _impactDuration = Duration(milliseconds: 360);

  late final CartFlightCoordinator _coordinator;
  late final AnimationController _openController = AnimationController(
    vsync: this,
    duration: _openDuration,
    reverseDuration: const Duration(milliseconds: 420),
  );
  late final AnimationController _bounceController = AnimationController(
    vsync: this,
    duration: _bounceDuration,
  );
  late final AnimationController _impactController = AnimationController(
    vsync: this,
    duration: _impactDuration,
  );
  // Macaron pop lands after the squash, matching the spec's 84–90% window.
  late final Animation<double> _badgeScale = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 35),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.0,
        end: 1.25,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.25,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 35,
    ),
  ]).animate(_impactController);
  // Short glow burst around the impact instant, tinted like the trail.
  late final Animation<double> _glow = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 35,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 40),
  ]).animate(_impactController);
  int? _lastIncomingFlightCount;

  @override
  void initState() {
    super.initState();
    // Cached so dispose() never touches `ref`. Registered per mounted tile
    // (latest wins) rather than a shared GlobalKey: go_router `push` can keep
    // two navs alive at once, which a shared key would crash on.
    _coordinator = ref.read(cartFlightCoordinatorProvider.notifier);
    _coordinator.registerCartAnchor(this, _resolveGlobalRect);
    if (ref.read(cartFlightCoordinatorProvider).incomingFlightCount > 0) {
      _openController.value = 1;
    }
  }

  @override
  void dispose() {
    _coordinator.unregisterCartAnchor(this);
    _impactController.dispose();
    _bounceController.dispose();
    _openController.dispose();
    super.dispose();
  }

  Rect? _resolveGlobalRect() {
    if (!mounted) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  void _playImpact() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _impactController.forward(from: 0);
    _bounceController.forward(from: 0);
  }

  void _syncIncomingFlights(int count) {
    if (!mounted) return;
    final shouldOpen = count > 0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _openController.value = shouldOpen ? 1 : 0;
      return;
    }
    if (shouldOpen) {
      _openController.forward();
    } else {
      _openController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final incomingFlightCount = ref.watch(
      cartFlightCoordinatorProvider.select((s) => s.incomingFlightCount),
    );
    if (_lastIncomingFlightCount != incomingFlightCount) {
      _lastIncomingFlightCount = incomingFlightCount;
      _syncIncomingFlights(incomingFlightCount);
    }
    ref.listen(cartFlightCoordinatorProvider.select((s) => s.impactTick), (
      previous,
      next,
    ) {
      if (previous != null && next != previous) _playImpact();
    });

    return AnimatedBuilder(
      animation: _impactController,
      // Built once; only the transforms/glow recompute per frame.
      child: AnimatedShoppingCartIcon(
        color: widget.color,
        size: 24,
        brightness: widget.brightness,
        badgeCount: widget.badgeCount,
        openProgress: _openController,
        bounceProgress: _bounceController,
        badgeScale: _badgeScale,
      ),
      builder: (context, child) {
        final glow = _glow.value;
        final unit = child!;
        if (glow <= 0.001) return unit;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8EC5FF).withValues(alpha: 0.8 * glow),
                blurRadius: 14 + 8 * glow,
                spreadRadius: 1 + 2 * glow,
              ),
            ],
          ),
          child: unit,
        );
      },
    );
  }
}

/// A nav icon with an optional cart-count badge (the Sport "macaron").
class _IconWithBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isActive;
  final Brightness brightness;
  final int badgeCount;
  final bool magnifyingGlassShader;

  const _IconWithBadge({
    required this.icon,
    required this.color,
    required this.isActive,
    required this.brightness,
    required this.badgeCount,
    this.magnifyingGlassShader = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = badgeCount <= 0
        ? null
        : (badgeCount > 99 ? '99+' : '$badgeCount');
    // Invert the macaron on the dark glass so it doesn't melt into the panel.
    final isDark = brightness == Brightness.dark;
    final badgeColor = isDark ? Colors.white : const Color(0xFF111111);
    final badgeTextColor = isDark ? const Color(0xFF111111) : Colors.white;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        magnifyingGlassShader
            ? SportSearchMagnifyingGlassIcon(
                color: color,
                isActive: isActive,
                shaderEnabled: true,
              )
            : Icon(icon, size: 24, color: color),
        if (label != null)
          Positioned(
            top: -6,
            right: -9,
            child: _BadgeMacaron(
              label: label,
              color: badgeColor,
              textColor: badgeTextColor,
            ),
          ),
      ],
    );
  }
}

/// The cart-count macaron itself, shared between the static badge and the
/// comet-impact popping one.
class _BadgeMacaron extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _BadgeMacaron({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        key: kSharedNavCartCountBadgeKey,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
