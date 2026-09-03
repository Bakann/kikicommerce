import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;
import 'package:go_router/go_router.dart';

import '../../app/catalog_routes.dart';
import '../../app/app_providers.dart';
import '../../app/cache_providers.dart';
import '../../application/cms/cms_models.dart';
import '../../application/cms/cms_page_repository.dart';
import '../../application/storefront/storefront_chrome_profile.dart';
import '../../application/storefront/storefront_navigation_settings.dart';
import '../../application/storefront/storefront_sport_segment.dart';
import '../../application/storefront/storefront_theme.dart';
import '../providers/drawer_navigation_preloader.dart';
import '../providers/cms_page_provider.dart';
import '../providers/content_locale_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/edit_mode_provider.dart';
import '../providers/sport_home_icon_loading_provider.dart';
import '../providers/sport_segment_providers.dart';
import '../providers/storefront_theme_providers.dart';
import '../navigation/route_visibility.dart';
import '../widgets/cms/cms_admin_auth.dart';
import '../widgets/cms/cms_appearance_block.dart';
import '../widgets/cms/cms_edit_overlay.dart';
import '../widgets/cms/cms_section_renderer.dart';
import '../widgets/cms/cms_section_reveal.dart';
import '../widgets/cms/cms_sections_sidebar.dart';
import '../widgets/cms/sections/category_split_tabs_section.dart';
import '../widgets/cms/sections/hero_campaign_section.dart';
import '../widgets/landing_asset_loading_backdrop.dart';
import '../widgets/navigation/adaptive_bottom_nav.dart';
import '../widgets/navigation/floating_bottom_nav.dart';
import '../widgets/navigation/mobile_fullscreen_menu_overlay.dart';
import '../widgets/navigation/premium_scroll_navbar.dart';
import '../widgets/navigation/premium_shell_navbar.dart';
import '../widgets/navigation/top_navigation_bar.dart';
import '../widgets/storefront_category_drawer.dart';
import '../widgets/storefront_drawer_prefetch.dart';
import '../widgets/storefront_layout.dart';
import '../widgets/storefront_theme_switcher.dart';

@visibleForTesting
const Key storefrontThemeLoadingShellKey = Key(
  'storefront-theme-loading-shell',
);

@visibleForTesting
const Key sportThemeSwitcherOpacityKey = Key('sport-theme-switcher-opacity');

@visibleForTesting
const Key storefrontThemePageSlideKey = Key('storefront-theme-page-slide');

@visibleForTesting
const Key storefrontSegmentSlideKey = Key('storefront-segment-slide');

@visibleForTesting
const Key storefrontHomepageThemeShellKey = Key(
  'storefront-homepage-theme-shell',
);

@visibleForTesting
const Key storefrontSportHomepageSkeletonKey = Key(
  'storefront-sport-homepage-skeleton',
);

class StorefrontLandingPage extends ConsumerStatefulWidget {
  final StorefrontSportSegment? sportSegment;
  final bool enableStartupBackdrop;
  final bool bottomNavHostedByShell;

  const StorefrontLandingPage({
    super.key,
    this.sportSegment,
    this.enableStartupBackdrop = true,
    this.bottomNavHostedByShell = false,
  });

  @override
  ConsumerState<StorefrontLandingPage> createState() =>
      _StorefrontLandingPageState();
}

class _StorefrontLandingPageState extends ConsumerState<StorefrontLandingPage>
    with TickerProviderStateMixin {
  static const double _kThemeDragSlop = 8;
  static const double _kThemeSwipeCommitFraction = 0.35;
  static const double _kThemeSwipeCommitVelocity = 600;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isCmsSidebarExpanded = true;
  late final AnimationController _menuController;
  // Drives the lateral theme slide: idle at 1, programmatic switch animates
  // 0→1, an interactive swipe sets the value directly to follow the finger.
  late final AnimationController _pagerController;
  bool _isMobileMenuOpen = false;
  bool _isSportThemeSwitcherVisible = true;
  Offset? _mobileMenuRevealOriginGlobal;
  MobileFullscreenMenuMode _mobileMenuMode =
      MobileFullscreenMenuMode.navigation;
  StorefrontTheme? _displayedTheme;
  _HomepageSnapshot? _currentHomepageSnapshot;
  _HomepageSnapshot? _outgoingHomepageSnapshot;
  ScrollController? _outgoingScrollController;
  Offset _themePageTransitionBeginOffset = Offset.zero;
  int _themePageTransitionGeneration = 0;
  String? _lastOpportunisticPrecacheKey;
  Timer? _luxePrewarmTimer;
  bool _luxePrewarmAttempted = false;
  String? _lastLuxePrewarmKey;
  // Opportunistic prewarm of one adjacent segment tab (e.g. Homme → Femme),
  // mirroring the Sport → Luxe prewarm above.
  Timer? _segmentPrewarmTimer;
  bool _isSegmentPrewarming = false; // guards against a 2nd prewarm in-flight
  legacy.StateController<bool>? _homeIconLoadingController;
  bool? _lastPublishedHomeIconLoading;
  // Segments whose CMS bundle has been SUCCESSFULLY warmed this session. Only
  // added after the fetch resolves, so a failed/interrupted target is not
  // incorrectly considered warm.
  final Set<StorefrontSportSegment> _segmentPrewarmDone =
      <StorefrontSportSegment>{};
  // Source segments that already launched one sibling prewarm. This prevents a
  // long dwell on Homme from warming Femme, then Enfant, then every remaining
  // sibling in the background.
  final Set<StorefrontSportSegment> _segmentPrewarmSources =
      <StorefrontSportSegment>{};
  // Interactive theme-swipe state.
  bool _isThemeDragging = false;
  bool _isCommittingSwipe = false;
  bool _isProgrammaticThemeTransition = false;
  bool _isMobileSwipeEnabled = false;
  StorefrontTheme? _dragTargetTheme;
  _HomepageSnapshot? _dragTargetSnapshot;
  ScrollController? _dragTargetScrollController;
  double _dragBeginDx = 0;
  double _dragAccumulatedDx = 0;
  double _dragWidth = 1;
  // Sport-segment slide state (Homme/Femme/Enfant). Independent from the theme
  // slide above: the tab row stays pinned while only the content below slides
  // horizontally. Theme is forced to Nike on sport routes, so the theme pager
  // is always at rest during a segment slide.
  late final AnimationController _segmentPagerController;
  _HomepageSnapshot? _outgoingSegmentSnapshot;
  ScrollController? _outgoingSegmentScrollController;
  double _segmentSlideBeginDx = 0;
  int _segmentTransitionGeneration = 0;
  bool _isSegmentTransition = false;
  // The Homme/Femme/Enfant tab row is identical across segments, so we capture
  // it once at the start of a segment switch and keep it pinned for the whole
  // transition — including any post-slide CMS loading — so the tabs never
  // skeleton-out while the content below loads.
  CmsSectionConfig? _pinnedSegmentTabRow;
  final ValueNotifier<bool> _startupAssetsReady = ValueNotifier(false);
  bool _startupAssetResolutionScheduled = false;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _pagerController = AnimationController(
      vsync: this,
      value: 1,
      duration: _StorefrontThemePageSlide.duration,
    );
    _segmentPagerController = AnimationController(
      vsync: this,
      value: 1,
      duration: _SportSegmentSlide.duration,
    );
    // When the fullscreen menu finishes opening/closing the parent does not
    // otherwise rebuild, so re-evaluate _isMobileSwipeEnabled on settle.
    _menuController.addStatusListener(_handleMenuAnimationStatus);
    _scrollController.addListener(_syncSportThemeSwitcherVisibility);
    // The public landing can live outside MainShell, so it must warm the
    // active cart itself; otherwise a reload on /fr leaves the nav badge at 0
    // until the visitor opens the cart page.
    unawaited(ref.read(cartControllerProvider.notifier).prefetchActiveCart());
    // The prewarm store is intentionally non-reactive, but creating its
    // provider lazily from a background prewarm can race with a landing build
    // when a user taps into a segment while that same CMS request is resolving.
    // Instantiate it with the page so later writes only mutate the store object.
    ref.read(homepageSegmentPrewarmStoreProvider);
    _homeIconLoadingController = ref.read(
      sportHomeIconLoadingProvider.notifier,
    );
    _recordLastSportSegment();
  }

  /// Persist the Sport segment currently shown so cart entry points (which
  /// have no bare `/sport` route to fall back to) can return the visitor to
  /// the segment they last browsed. Fire-and-forget I/O — not a provider
  /// mutation — so it is safe to call from lifecycle methods.
  void _recordLastSportSegment() {
    final segment = widget.sportSegment;
    if (segment == null) return;
    unawaited(ref.read(lastSportSegmentStoreProvider).write(segment));
  }

  @override
  void didUpdateWidget(covariant StorefrontLandingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tapping a Homme/Femme/Enfant tab now reuses this page+State (stable route
    // key) and only changes widget.sportSegment. We intentionally keep
    // _currentHomepageSnapshot (the OLD segment) so _syncHomepagePresentation —
    // running in the build that follows — can capture it as the outgoing page
    // and drive the in-page content slide. The theme can never change here
    // (sport routes are pinned to Nike), so no theme-transition reset is needed.
    if (oldWidget.sportSegment != widget.sportSegment) {
      // Drop the prewarm timer armed for the previous segment; build() re-arms
      // for the new segment once it settles. Any in-flight prewarm self-guards
      // on widget.sportSegment and finishes harmlessly. Keep
      // _segmentPrewarmDone — the warmed pages stay useful.
      _segmentPrewarmTimer?.cancel();
      _segmentPrewarmTimer = null;
      _recordLastSportSegment();
    }
  }

  @override
  void dispose() {
    _clearPublishedHomeIconLoading();
    _luxePrewarmTimer?.cancel();
    _segmentPrewarmTimer?.cancel();
    _scrollController.removeListener(_syncSportThemeSwitcherVisibility);
    _menuController.removeStatusListener(_handleMenuAnimationStatus);
    _menuController.dispose();
    _pagerController.dispose();
    _segmentPagerController.dispose();
    _dragTargetScrollController?.dispose();
    _outgoingScrollController?.dispose();
    _outgoingSegmentScrollController?.dispose();
    _scrollController.dispose();
    _startupAssetsReady.dispose();
    super.dispose();
  }

  void _clearPublishedHomeIconLoading() {
    if (_lastPublishedHomeIconLoading == null) return;
    _homeIconLoadingController?.state = false;
    _lastPublishedHomeIconLoading = null;
  }

  void _publishHomeIconLoading(bool isLoading) {
    final shellOwnsBottomNav =
        widget.bottomNavHostedByShell || widget.sportSegment != null;
    if (!shellOwnsBottomNav) {
      if (_lastPublishedHomeIconLoading == null) return;
      isLoading = false;
    }
    if (_lastPublishedHomeIconLoading == isLoading) return;
    _lastPublishedHomeIconLoading = isLoading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastPublishedHomeIconLoading != isLoading) return;
      _homeIconLoadingController?.state = isLoading;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = ref.watch(editModeProvider);
    final areEditControlsVisible = ref.watch(editControlsVisibleProvider);
    final previewTheme = ref.watch(editingStorefrontThemeProvider);
    final themeAsync = ref.watch(effectiveStorefrontThemeAsyncProvider);
    final effectiveTheme = widget.sportSegment != null
        ? StorefrontTheme.nike
        : themeAsync.value;

    if (effectiveTheme == null) {
      _publishHomeIconLoading(false);
      return _withStartupBackdrop(
        LandingGradientLoadingCoordinator(
          idleBackgroundColor: const Color(0xFFF7F6F2),
          animate: widget.enableStartupBackdrop,
          child: _ThemeLoadingShell(
            animateGradient: widget.enableStartupBackdrop,
          ),
        ),
      );
    }

    final contentLocale = ref.watch(contentLocaleProvider);
    final prewarmedSegmentResolution =
        !isEditMode && widget.sportSegment != null
        ? ref
              .read(homepageSegmentPrewarmStoreProvider)
              .read(locale: contentLocale, segment: widget.sportSegment!)
        : null;
    final homepageResolutionAsync = prewarmedSegmentResolution != null
        ? AsyncValue<HomepageCmsResolution>.data(prewarmedSegmentResolution)
        : ref.watch(homepageCmsForSegmentProvider(widget.sportSegment));
    final pageAsync = homepageResolutionAsync.whenData(
      (resolution) => resolution.bundle,
    );
    final homepageResolution = homepageResolutionAsync.value;
    _syncHomepagePresentation(
      context: context,
      effectiveTheme: effectiveTheme,
      sportSegment: widget.sportSegment,
      pageAsync: pageAsync,
      usedCmsFallback: homepageResolution?.usedFallback ?? false,
      requestedCmsCode: homepageResolution?.requestedCode,
      resolvedCmsCode: homepageResolution?.resolvedCode,
    );
    if (widget.enableStartupBackdrop) {
      _scheduleStartupAssetResolution(context);
    }

    final displayedTheme = _displayedTheme ?? effectiveTheme;
    final switcherPosition = _themeSwitcherPositionFor(displayedTheme);
    _maybeScheduleLuxePrewarm(displayedTheme);
    _maybeScheduleSegmentPrewarm();
    final themeTokens = StorefrontThemeTokens.forTheme(displayedTheme);
    final chrome = StorefrontChromeProfile.forTheme(displayedTheme);
    final showFloatingBottomNav = chrome.showFloatingBottomNav;
    final isVisibleLandingHomeIconLoading =
        showFloatingBottomNav &&
        _currentHomepageSnapshot?.kind == _HomepageSnapshotKind.shell;
    _publishHomeIconLoading(isVisibleLandingHomeIconLoading);
    // Nike intentionally has no PremiumScrollNavbar: brand_segment + the
    // Homme/Femme/Enfant tabs scroll with the page and act as the chrome.
    // The bottom nav carries wishlist / account / cart. If we ever ship a
    // compact Nike top nav, set the profile's `showPremiumTopNav` to true
    // and pass hideTrailingDestinations to the navbar (the flag is already
    // plumbed through the stack).
    final showTopNav = chrome.showPremiumTopNav;
    final showSportThemeSwitcherSlot = showFloatingBottomNav && !showTopNav;
    final wantsFullscreenReveal = ref.watch(
      storefrontNavigationSettingsProvider.select(
        (async) =>
            async.value?.mobileMenuStyle == MobileMenuStyle.fullscreenReveal,
      ),
    );
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);
    final useFullscreenReveal = showTopNav && isMobile && wantsFullscreenReveal;
    _isMobileSwipeEnabled =
        isMobile &&
        !isEditMode &&
        !_isMobileMenuOpen &&
        _menuController.value == 0 &&
        // Don't start a new swipe over a tap-driven slide already in flight.
        // (Drag-driven commit/spring-back animations are fine — gating on the
        // drag flags here would yank the active recognizer mid-gesture.)
        !_isProgrammaticThemeTransition;
    final sections =
        _currentHomepageSnapshot?.bundle?.sections ??
        const <CmsSectionConfig>[];
    final heroHeight = _currentHomepageSnapshot != null
        ? _heroHeightFor(
            context: context,
            sections: sections,
            isEditMode: isEditMode,
          )
        : _loadingHeroHeightFor(context);

    if (!useFullscreenReveal && _isMobileMenuOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _closeMobileMenu(immediate: true);
        }
      });
    }

    final homepageBody =
        _isSegmentTransition && _currentHomepageSnapshot != null
        ? _buildSegmentTransition(
            context: context,
            isEditMode: isEditMode,
            previewTheme: previewTheme,
          )
        : _buildHomepageTransition(
            context: context,
            isEditMode: isEditMode,
            previewTheme: previewTheme,
            fallbackTheme: displayedTheme,
          );

    // During an interactive swipe the slide renders the CURRENT theme as the
    // outgoing page and the drag TARGET as the incoming page (both following
    // the finger). Otherwise it renders the normal current body plus any
    // programmatic-transition outgoing snapshot.
    final Offset slideBeginOffset;
    final Widget slideChild;
    final Widget? slideOutgoing;
    if (_isThemeDragging && _dragTargetSnapshot != null) {
      slideBeginOffset = Offset(_dragBeginDx, 0);
      slideChild = _buildHomepageBody(
        context: context,
        snapshot: _dragTargetSnapshot!,
        scrollController: _dragTargetScrollController!,
        isEditMode: isEditMode,
        previewTheme: previewTheme,
      );
      slideOutgoing = _currentHomepageSnapshot == null
          ? null
          : _buildHomepageBody(
              context: context,
              snapshot: _currentHomepageSnapshot!,
              scrollController: _scrollController,
              isEditMode: isEditMode,
              previewTheme: previewTheme,
            );
    } else {
      slideBeginOffset = _themePageTransitionBeginOffset;
      slideChild = homepageBody;
      slideOutgoing = _outgoingHomepageSnapshot == null
          ? null
          : _buildHomepageBody(
              context: context,
              snapshot: _outgoingHomepageSnapshot!,
              scrollController: _outgoingScrollController!,
              isEditMode: isEditMode,
              previewTheme: previewTheme,
            );
    }

    return _withStartupBackdrop(
      LandingGradientLoadingCoordinator(
        idleBackgroundColor: themeTokens.scaffoldBackground,
        animate: widget.enableStartupBackdrop,
        child: StorefrontDrawerPrefetch(
          child: Scaffold(
            key: _scaffoldKey,
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            drawerEnableOpenDragGesture:
                !useFullscreenReveal && !_isMobileSwipeEnabled,
            drawer: const StorefrontCategoryDrawer(),
            floatingActionButton: areEditControlsVisible
                ? _EditModeFab(isEditMode: isEditMode)
                : null,
            body: _maybeAdaptiveBottomNav(
              showFloatingBottomNav,
              Stack(
                fit: StackFit.expand,
                children: [
                  RawGestureDetector(
                    gestures: _isMobileSwipeEnabled
                        ? <Type, GestureRecognizerFactory>{
                            HorizontalDragGestureRecognizer:
                                GestureRecognizerFactoryWithHandlers<
                                  HorizontalDragGestureRecognizer
                                >(HorizontalDragGestureRecognizer.new, (
                                  instance,
                                ) {
                                  instance
                                    ..onStart = _onThemeDragStart
                                    ..onUpdate = _onThemeDragUpdate
                                    ..onEnd = _onThemeDragEnd;
                                }),
                          }
                        : const <Type, GestureRecognizerFactory>{},
                    child: _StorefrontThemePageSlide(
                      // Keyed by the displayed theme (not the transition generation):
                      // remount the incoming body on a theme change so the inner
                      // AnimatedSwitcher never crossfades two content bodies sharing
                      // _scrollController, while staying stable within a theme and
                      // during a drag (displayed theme is unchanged until commit).
                      key: ValueKey('theme-page-${displayedTheme.wireName}'),
                      beginOffset: slideBeginOffset,
                      progress: _pagerController,
                      outgoing: slideOutgoing,
                      child: slideChild,
                    ),
                  ),
                  if (useFullscreenReveal)
                    Positioned.fill(
                      child: MobileFullscreenMenuOverlay(
                        progress: _menuController,
                        isOpen: _isMobileMenuOpen,
                        topInset: premiumNavReservedHeight(context),
                        mode: _mobileMenuMode,
                        revealOriginGlobal: _mobileMenuRevealOriginGlobal,
                        onClose: _closeMobileMenu,
                        onSearchClose: _closeSearchPanel,
                      ),
                    ),
                  if (showTopNav)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: PremiumScrollNavbar(
                        scrollController: _scrollController,
                        heroHeight: heroHeight,
                        forceVisibleLight: isEditMode,
                        onMenuTap: (origin) =>
                            _handleMenuTap(useFullscreenReveal, origin),
                        onSearchTap: (origin) =>
                            _handleSearchTap(useFullscreenReveal, origin),
                        isMenuOpen: _isMobileMenuOpen,
                        menuProgress: _menuController,
                        hideChromeForOpenMenu:
                            useFullscreenReveal && _isMobileMenuOpen,
                        onBrandTripleTap: _revealEditControls,
                        themeSwitcherVisualPosition: switcherPosition,
                        // On mobile landing the switcher is the primary universe-nav
                        // control: keep it centered (same slot as Sport) so it stays
                        // put across a swipe instead of jumping to the leading slot.
                        forceCenteredThemeSwitcher: isMobile,
                      ),
                    ),
                  if (showSportThemeSwitcherSlot)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _SportThemeSwitcherNavSlot(
                        isVisible: _isSportThemeSwitcherVisible,
                        themeSwitcherVisualPosition: switcherPosition,
                        onThemeSelected: _handleThemeSwitcherSelection,
                      ),
                    ),
                ],
              ),
              homeIconLoading: isVisibleLandingHomeIconLoading,
            ),
          ),
        ),
      ),
    );
  }

  /// Overlays the adaptive floating bottom nav on the landing content (so its
  /// glass samples the imagery behind it); passes the content through untouched
  /// on the chrome that has no bottom nav.
  Widget _maybeAdaptiveBottomNav(
    bool showBottomNav,
    Widget content, {
    required bool homeIconLoading,
  }) {
    // Routes hosted by SportFlowShell must not render a page-local nav: the
    // shell owns the single persistent instance across home/sport transitions.
    if (widget.bottomNavHostedByShell || widget.sportSegment != null) {
      return content;
    }
    if (!showBottomNav) return content;
    return AdaptiveBottomNav(
      onHomeTripleTap: _revealEditControls,
      homeIconLoading: homeIconLoading,
      child: content,
    );
  }

  Widget _withStartupBackdrop(Widget child) {
    if (!widget.enableStartupBackdrop) return child;
    return LandingAssetLoadingBackdrop(
      assetsReady: _startupAssetsReady,
      child: child,
    );
  }

  void _scheduleStartupAssetResolution(BuildContext context) {
    if (_startupAssetsReady.value || _startupAssetResolutionScheduled) return;

    final snapshot = _currentHomepageSnapshot;
    if (snapshot == null || snapshot.kind == _HomepageSnapshotKind.shell) {
      return;
    }

    _startupAssetResolutionScheduled = true;
    final urls = snapshot.kind == _HomepageSnapshotKind.content
        ? _homepageTransitionImageUrls(
            context: context,
            snapshot: snapshot,
            limit: 2,
          )
        : const <String>[];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.wait(
        urls.map((url) async {
          try {
            await precacheImage(
              _transitionPrecacheProvider(context, url),
              context,
            );
          } catch (_) {
            // A missing critical image must not pin the startup backdrop.
          }
        }),
      );
      if (mounted) _startupAssetsReady.value = true;
    });
  }

  void _openDrawerFromNavbar() {
    unawaited(
      ref.read(drawerNavigationPreloaderProvider.notifier).recordOpen(),
    );
    _scaffoldKey.currentState?.openDrawer();
  }

  void _handleMenuTap(bool useFullscreenReveal, Offset? globalOrigin) {
    if (!useFullscreenReveal) {
      _openDrawerFromNavbar();
      return;
    }

    if (_isMobileMenuOpen &&
        _mobileMenuMode == MobileFullscreenMenuMode.navigation) {
      _closeMobileMenu();
      return;
    }
    if (_isMobileMenuOpen &&
        _mobileMenuMode == MobileFullscreenMenuMode.search) {
      _closeSearchPanel();
      return;
    }

    unawaited(
      ref.read(drawerNavigationPreloaderProvider.notifier).recordOpen(),
    );
    setState(() {
      _mobileMenuMode = MobileFullscreenMenuMode.navigation;
      _mobileMenuRevealOriginGlobal = globalOrigin;
      _isMobileMenuOpen = true;
    });
    _menuController.forward();
  }

  void _handleSearchTap(bool useFullscreenReveal, Offset? globalOrigin) {
    if (!useFullscreenReveal) {
      context.go(
        CatalogRoutes.localizedLocation(
          CatalogRoutes.search,
          locale: ref.read(contentLocaleProvider),
        ),
      );
      return;
    }

    if (_isMobileMenuOpen &&
        _mobileMenuMode == MobileFullscreenMenuMode.search) {
      _closeSearchPanel();
      return;
    }

    setState(() {
      _mobileMenuMode = MobileFullscreenMenuMode.search;
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

  void _revealEditControls() {
    ref.read(editControlsVisibleProvider.notifier).state = true;
  }

  Future<void> _handleThemeSwitcherSelection(StorefrontTheme theme) async {
    await writeVisitorStorefrontThemeOverride(ref, theme);
    if (!mounted) return;
    if (widget.sportSegment != null && theme != StorefrontTheme.nike) {
      context.go(
        CatalogRoutes.localizedLocation(
          CatalogRoutes.home,
          locale: ref.read(contentLocaleProvider),
        ),
      );
    }
  }

  void _handleMenuAnimationStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.dismissed ||
        status == AnimationStatus.completed) {
      setState(() {});
    }
  }

  void _syncHomepagePresentation({
    required BuildContext context,
    required StorefrontTheme effectiveTheme,
    required StorefrontSportSegment? sportSegment,
    required AsyncValue<CmsPageBundle?> pageAsync,
    required bool usedCmsFallback,
    required String? requestedCmsCode,
    required String? resolvedCmsCode,
  }) {
    // A swipe commit already moved the displayed theme to the target locally;
    // hold that state (and keep showing the target homepage) until the async
    // visitor-override write lands and the resolved theme catches up — without
    // it we would briefly see effectiveTheme as the OLD theme and start a
    // second slide back.
    if (_isCommittingSwipe) {
      if (effectiveTheme == _displayedTheme) {
        _isCommittingSwipe = false;
      } else {
        return;
      }
    }

    // targetTheme is the resolved user/admin intent for this build,
    // independent from the currently displayed transition state.
    final targetTheme = effectiveTheme;
    final previousSnapshot = _currentHomepageSnapshot;

    // Hold the current page through a transient reload (SWR revalidation) to
    // avoid a shell flash — but only for a pure refresh (same theme AND same
    // segment). A segment change while loading must fall through so the
    // incoming segment's shell can slide in.
    if (pageAsync.isLoading &&
        !pageAsync.hasError &&
        previousSnapshot != null &&
        previousSnapshot.theme == targetTheme &&
        previousSnapshot.sportSegment == sportSegment) {
      _displayedTheme = targetTheme;
      return;
    }

    final nextSnapshot =
        _HomepageSnapshot.fromAsyncValue(
          theme: targetTheme,
          sportSegment: sportSegment,
          pageAsync: pageAsync,
          usedCmsFallback: usedCmsFallback,
          requestedCmsCode: requestedCmsCode,
          resolvedCmsCode: resolvedCmsCode,
        ) ??
        _HomepageSnapshot.shell(theme: targetTheme, sportSegment: sportSegment);
    if (previousSnapshot == null) {
      _displayedTheme = targetTheme;
      _currentHomepageSnapshot = nextSnapshot;
      _themePageTransitionBeginOffset = Offset.zero;
      return;
    }

    if (previousSnapshot.theme == targetTheme) {
      // Same theme, different sport segment: slide the content below the pinned
      // tab row instead of swapping instantly. Only start from a settled
      // content page (not mid-load) and when not already mid-segment-slide.
      if (previousSnapshot.sportSegment != sportSegment &&
          previousSnapshot.kind == _HomepageSnapshotKind.content &&
          !_isSegmentTransition) {
        _startSegmentTransition(
          context: context,
          previousSnapshot: previousSnapshot,
          nextSnapshot: nextSnapshot,
        );
        return;
      }
      _displayedTheme = targetTheme;
      _currentHomepageSnapshot = nextSnapshot;
      // The incoming segment finished loading after its slide already settled:
      // end the transition so the page returns to the normal scrolling list
      // (tab row back inside it). Only when the slide animation is done — an
      // early content arrival mid-slide is handled by the animation's
      // completion callback instead.
      if (_isSegmentTransition &&
          !_segmentPagerController.isAnimating &&
          _segmentPagerController.value == 1 &&
          nextSnapshot.kind != _HomepageSnapshotKind.shell) {
        _endSegmentTransition();
      }
      _precacheHomepageTransitionImagesIfNeeded(
        context: context,
        snapshot: nextSnapshot,
      );
      return;
    }

    _startHomepageThemeTransition(
      context: context,
      previousSnapshot: previousSnapshot,
      nextSnapshot: nextSnapshot,
    );
  }

  void _startHomepageThemeTransition({
    required BuildContext context,
    required _HomepageSnapshot previousSnapshot,
    required _HomepageSnapshot nextSnapshot,
  }) {
    _outgoingScrollController?.dispose();
    _outgoingScrollController = ScrollController(
      initialScrollOffset: _scrollController.hasClients
          ? _scrollController.offset
          : 0,
    );
    if (nextSnapshot.kind == _HomepageSnapshotKind.shell) {
      _scheduleIncomingScrollResetForShell();
    }
    _outgoingHomepageSnapshot = previousSnapshot;
    _currentHomepageSnapshot = nextSnapshot;
    _displayedTheme = nextSnapshot.theme;
    _themePageTransitionBeginOffset = storefrontThemePageTransitionBeginOffset(
      previousTheme: previousSnapshot.theme,
      nextTheme: nextSnapshot.theme,
    );
    _themePageTransitionGeneration += 1;
    // Drive the slide from the shared controller, mirroring the previous
    // TweenAnimationBuilder (eased, 560ms). Setting value = 0 is the only
    // listener-notifying op and is safe here because the AnimatedBuilder is a
    // not-yet-built descendant of this build; animateTo only starts the ticker.
    _pagerController.value = 0;
    _isProgrammaticThemeTransition = true;
    final generation = _themePageTransitionGeneration;
    // This runs only when the slide completes naturally — a TickerFuture does
    // NOT complete its primary future on cancellation. That's fine: the only
    // thing that cancels a programmatic slide is another programmatic slide
    // (the swipe is disabled while one is in flight), and that newer transition
    // re-sets the flag and clears it via its own completion (guarded by the
    // generation check below). The explicit setState recomputes
    // _isMobileSwipeEnabled even when _clearOutgoingHomepageSnapshot
    // early-returns (outgoing already null), so the swipe can't stay disabled.
    _pagerController
        .animateTo(
          1,
          duration: _StorefrontThemePageSlide.duration,
          curve: Curves.easeInOutCubic,
        )
        .whenComplete(() {
          if (!mounted || generation != _themePageTransitionGeneration) return;
          setState(() => _isProgrammaticThemeTransition = false);
          _clearOutgoingHomepageSnapshot(generation);
        });
    _precacheHomepageTransitionImagesIfNeeded(
      context: context,
      snapshot: nextSnapshot,
    );
  }

  // Slides the content below the pinned Homme/Femme/Enfant tab row when the
  // sport segment changes. Independent from the theme slide above: the theme is
  // pinned to Nike on sport routes, so _pagerController stays at rest.
  void _startSegmentTransition({
    required BuildContext context,
    required _HomepageSnapshot previousSnapshot,
    required _HomepageSnapshot nextSnapshot,
  }) {
    final previousSegment = previousSnapshot.sportSegment;
    final nextSegment = nextSnapshot.sportSegment;
    final beginOffset = (previousSegment != null && nextSegment != null)
        ? storefrontSegmentSlideBeginOffset(
            previousSegment: previousSegment,
            nextSegment: nextSegment,
          )
        : Offset.zero;
    // No direction to slide (missing/equal segments): swap instantly.
    if (beginOffset == Offset.zero) {
      _displayedTheme = nextSnapshot.theme;
      _currentHomepageSnapshot = nextSnapshot;
      _precacheHomepageTransitionImagesIfNeeded(
        context: context,
        snapshot: nextSnapshot,
      );
      return;
    }

    _outgoingSegmentScrollController?.dispose();
    _outgoingSegmentScrollController = ScrollController(
      initialScrollOffset: _scrollController.hasClients
          ? _scrollController.offset
          : 0,
    );
    if (nextSnapshot.kind == _HomepageSnapshotKind.shell) {
      _scheduleIncomingScrollResetForShell();
    }
    // Capture the outgoing tab row (identical across segments) to pin for the
    // whole transition. Rendered later with the new active segment.
    _pinnedSegmentTabRow = _tabRowSectionFor(
      previousSnapshot,
      isEditMode: false,
    );
    _outgoingSegmentSnapshot = previousSnapshot;
    _currentHomepageSnapshot = nextSnapshot;
    _displayedTheme = nextSnapshot.theme;
    _segmentSlideBeginDx = beginOffset.dx;
    _segmentTransitionGeneration += 1;
    _isSegmentTransition = true;
    // value = 0 is the only listener-notifying op and is safe here: the
    // AnimatedBuilder is a not-yet-built descendant of this build; animateTo
    // only starts the ticker.
    _segmentPagerController.value = 0;
    final generation = _segmentTransitionGeneration;
    _segmentPagerController
        .animateTo(
          1,
          duration: _SportSegmentSlide.duration,
          curve: Curves.easeInOutCubic,
        )
        .whenComplete(() {
          if (!mounted || generation != _segmentTransitionGeneration) return;
          setState(() {
            // Slide done: drop the outgoing pane. Keep the transition (and the
            // pinned real tab row) alive until the incoming page resolves to
            // content, so a slow CMS load shows a content-only skeleton below
            // the real tabs instead of the full shell skeleton — which would
            // skeleton-ize the tabs even though they never change.
            _outgoingSegmentSnapshot = null;
            _outgoingSegmentScrollController?.dispose();
            _outgoingSegmentScrollController = null;
            if (_currentHomepageSnapshot?.kind != _HomepageSnapshotKind.shell) {
              _endSegmentTransition();
            }
          });
        });
    _precacheHomepageTransitionImagesIfNeeded(
      context: context,
      snapshot: nextSnapshot,
    );
  }

  void _endSegmentTransition() {
    _isSegmentTransition = false;
    _pinnedSegmentTabRow = null;
  }

  void _precacheHomepageTransitionImagesIfNeeded({
    required BuildContext context,
    required _HomepageSnapshot snapshot,
  }) {
    if (!isCurrentRoute(context)) return;
    final imageUrls = _homepageTransitionImageUrls(
      context: context,
      snapshot: snapshot,
    );
    if (imageUrls.isEmpty) return;
    final preloadKey =
        '${snapshot.theme.wireName}:${snapshot.bundle?.page.id ?? 'none'}:'
        '${imageUrls.join('|')}';
    if (_lastOpportunisticPrecacheKey == preloadKey) return;
    _lastOpportunisticPrecacheKey = preloadKey;
    unawaited(_precacheHomepageTransitionImages(context, imageUrls));
  }

  // Opportunistic, strictly non-blocking pre-warm of the Luxe homepage while
  // the user dwells on the Sport landing page. Never mutates transition state.
  void _maybeScheduleLuxePrewarm(StorefrontTheme displayedTheme) {
    if (displayedTheme != StorefrontTheme.nike || !isCurrentRoute(context)) {
      _luxePrewarmTimer?.cancel();
      _luxePrewarmTimer = null;
      return;
    }
    // Re-armable if the timer is cancelled before it fires (e.g. the user
    // leaves Sport within the delay and returns later); blocked only once a
    // real prewarm attempt has run.
    if (_luxePrewarmAttempted || _luxePrewarmTimer != null) return;
    _luxePrewarmTimer = Timer(const Duration(milliseconds: 1000), () {
      _luxePrewarmTimer = null;
      if (!mounted) return;
      if (!isCurrentRoute(context)) return;
      if ((_displayedTheme ?? StorefrontTheme.nike) != StorefrontTheme.nike) {
        return;
      }
      _luxePrewarmAttempted = true;
      unawaited(_prewarmLuxeHomepage());
    });
  }

  Future<void> _prewarmLuxeHomepage() async {
    if (!isCurrentRoute(context)) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final request = CmsPageRequest(
      code: homepageCodeFor(StorefrontTheme.dior),
      locale: container.read(contentLocaleProvider),
    );
    CmsPageBundle? bundle;
    try {
      bundle = await readCachedCmsPageBundle(
        repository: container.read(cmsPageRepositoryProvider),
        reader: container.read(cachedRemoteReaderProvider),
        request: request,
      );
    } catch (_) {
      return;
    }
    if (!mounted || !isCurrentRoute(context)) return;
    if ((_displayedTheme ?? StorefrontTheme.nike) != StorefrontTheme.nike) {
      return;
    }
    if (bundle == null || bundle.sections.isEmpty) return;

    final snapshot = _HomepageSnapshot.content(
      theme: StorefrontTheme.dior,
      sportSegment: null,
      bundle: bundle,
    );
    final urls = _homepageTransitionImageUrls(
      context: context,
      snapshot: snapshot,
      limit: 2,
    );
    if (urls.isEmpty) return;
    final key = 'luxe-prewarm:${bundle.page.id}:${urls.join('|')}';
    if (_lastLuxePrewarmKey == key) return;
    _lastLuxePrewarmKey = key;
    try {
      await _precacheHomepageTransitionImages(context, urls);
    } catch (_) {
      // A failed pre-warm must never surface.
    }
  }

  // Opportunistic prewarm of one adjacent segment tab (e.g. Homme → Femme) so
  // the likely next tap shows content immediately without warming every sibling
  // page in the background. Mirrors the Luxe prewarm but: gated on the CURRENT
  // page being settled content (so it never competes with the current page's
  // own load on a slow backend), staggered after the Luxe prewarm, and warming
  // the shared CMS cache plus a non-reactive segment snapshot so navigation
  // resolves synchronously with no skeleton frame. Never mutates transition
  // state.
  void _maybeScheduleSegmentPrewarm() {
    if (!isCurrentRoute(context)) {
      _segmentPrewarmTimer?.cancel();
      _segmentPrewarmTimer = null;
      return;
    }
    final snapshot = _currentHomepageSnapshot;
    final current = _sportSegmentForSnapshot(snapshot);
    if (current == null) {
      _segmentPrewarmTimer?.cancel();
      _segmentPrewarmTimer = null;
      return;
    }
    // Only once the current page is shown as content for this exact segment and
    // nothing is animating — otherwise we'd add load while the page is still
    // resolving.
    if (snapshot?.kind != _HomepageSnapshotKind.content) return;
    if (_isSegmentTransition ||
        _outgoingHomepageSnapshot != null ||
        _isThemeDragging ||
        _isCommittingSwipe ||
        _isProgrammaticThemeTransition) {
      return;
    }
    if (_isSegmentPrewarming || _segmentPrewarmTimer != null) return;
    if (_segmentPrewarmSources.contains(current)) return;
    if (_nextSegmentToPrewarm(current) == null) return;

    // Keep the sibling prewarm behind the same stability window the landing
    // tests assert: the visible segment must remain settled before we add
    // background CMS reads.
    _segmentPrewarmTimer = Timer(const Duration(milliseconds: 1500), () {
      _segmentPrewarmTimer = null;
      if (!mounted) return;
      if (!isCurrentRoute(context)) return;
      final settled = _currentHomepageSnapshot;
      final segment = _sportSegmentForSnapshot(settled);
      if (segment == null) return;
      if (settled?.kind != _HomepageSnapshotKind.content) return;
      if (_isSegmentTransition) return;
      unawaited(_prewarmSiblingSegments(segment));
    });
  }

  StorefrontSportSegment? _sportSegmentForSnapshot(
    _HomepageSnapshot? snapshot,
  ) {
    if (snapshot?.theme != StorefrontTheme.nike) return null;
    return snapshot!.sportSegment ?? StorefrontSportSegment.homme;
  }

  Future<void> _prewarmSiblingSegments(StorefrontSportSegment current) async {
    if (_isSegmentPrewarming) return;
    if (!isCurrentRoute(context)) return;
    if (!_segmentPrewarmSources.add(current)) return;
    _isSegmentPrewarming = true;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final segment = _nextSegmentToPrewarm(current);
      if (segment == null) return;
      if (!mounted ||
          !isCurrentRoute(context) ||
          _sportSegmentForSnapshot(_currentHomepageSnapshot) == null) {
        return;
      }
      // Mark only on success so the target can still be warmed later from a
      // different visible segment if this fetch fails.
      final warmed = await _prewarmSegment(container, segment);
      if (warmed) _segmentPrewarmDone.add(segment);
    } finally {
      _isSegmentPrewarming = false;
    }
  }

  /// Warms a sibling segment. Returns true once its CMS bundle has resolved
  /// (and is therefore cached). Returns false only when the CMS fetch itself
  /// failed, so the target can be warmed later from another visible segment.
  Future<bool> _prewarmSegment(
    ProviderContainer container,
    StorefrontSportSegment segment,
  ) async {
    // Capture the locale once so the fetch and the store key agree even if the
    // visitor switches language mid-prewarm.
    final locale = container.read(contentLocaleProvider);
    final HomepageCmsResolution resolution;
    try {
      resolution = await _readSegmentHomepageResolution(
        container: container,
        segment: segment,
        locale: locale,
      );
    } catch (_) {
      return false; // CMS not warmed; do not mark the target as warm.
    }
    container
        .read(homepageSegmentPrewarmStoreProvider)
        .write(locale: locale, segment: segment, resolution: resolution);
    return true;
  }

  StorefrontSportSegment? _nextSegmentToPrewarm(
    StorefrontSportSegment current,
  ) {
    final values = StorefrontSportSegment.values;
    final index = values.indexOf(current);
    final candidates = <StorefrontSportSegment>[
      if (index + 1 < values.length) values[index + 1],
      if (index - 1 >= 0) values[index - 1],
    ];
    for (final candidate in candidates) {
      if (!_segmentPrewarmDone.contains(candidate)) return candidate;
    }
    return null;
  }

  Future<HomepageCmsResolution> _readSegmentHomepageResolution({
    required ProviderContainer container,
    required StorefrontSportSegment segment,
    required String locale,
  }) async {
    final repository = container.read(cmsPageRepositoryProvider);
    final reader = container.read(cachedRemoteReaderProvider);
    final requestedCode = homepageCodeForSportSegment(segment);
    final requestedBundle = await readCachedCmsPageBundle(
      repository: repository,
      reader: reader,
      request: CmsPageRequest(code: requestedCode, locale: locale),
    );
    if (requestedBundle != null) {
      return HomepageCmsResolution(
        bundle: requestedBundle,
        requestedCode: requestedCode,
        resolvedCode: requestedCode,
        usedFallback: false,
      );
    }

    final fallbackSegment = segment.homepageFallback;
    if (fallbackSegment == null) {
      return HomepageCmsResolution(
        bundle: null,
        requestedCode: requestedCode,
        resolvedCode: null,
        usedFallback: false,
      );
    }

    final fallbackCode = homepageCodeForSportSegment(fallbackSegment);
    final fallbackBundle = await readCachedCmsPageBundle(
      repository: repository,
      reader: reader,
      request: CmsPageRequest(code: fallbackCode, locale: locale),
    );
    return HomepageCmsResolution(
      bundle: fallbackBundle,
      requestedCode: requestedCode,
      resolvedCode: fallbackBundle == null ? null : fallbackCode,
      usedFallback: fallbackBundle != null,
    );
  }

  void _scheduleIncomingScrollResetForShell() {
    // _startHomepageThemeTransition runs from build(), so the jumpTo cannot be
    // synchronous: it notifies _syncSportThemeSwitcherVisibility, whose
    // setState would then fire during build. Defer it to the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentHomepageSnapshot?.kind != _HomepageSnapshotKind.shell) return;
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.pixels == position.minScrollExtent) return;
      _scrollController.jumpTo(position.minScrollExtent);
    });
  }

  Widget _buildHomepageTransition({
    required BuildContext context,
    required bool isEditMode,
    required StorefrontTheme? previewTheme,
    required StorefrontTheme fallbackTheme,
  }) {
    final snapshot = _currentHomepageSnapshot;
    if (snapshot == null) {
      final tokens = StorefrontThemeTokens.forTheme(fallbackTheme);
      return ColoredBox(color: tokens.emptyPlaceholderBackground);
    }

    return AnimatedSwitcher(
      // Avoid a double crossfade when a swipe commit swaps the snapshot.
      duration: _isCommittingSwipe
          ? Duration.zero
          : const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: KeyedSubtree(
        key: snapshot.animationKey,
        child: _buildHomepageBody(
          context: context,
          snapshot: snapshot,
          scrollController: _scrollController,
          isEditMode: isEditMode,
          previewTheme: previewTheme,
        ),
      ),
    );
  }

  Widget _buildHomepageBody({
    required BuildContext context,
    required _HomepageSnapshot snapshot,
    required ScrollController scrollController,
    required bool isEditMode,
    required StorefrontTheme? previewTheme,
    // During a segment slide the tab row is pinned ABOVE this body, so it is
    // excluded here and the top inset (which normally clears the pinned theme
    // switcher slot) is collapsed to zero.
    bool excludeTabRow = false,
  }) {
    final chrome = StorefrontChromeProfile.forTheme(snapshot.theme);
    final showFloatingBottomNav = chrome.showFloatingBottomNav;
    final showTopNav = chrome.showPremiumTopNav;
    final showSportThemeSwitcherSlot = showFloatingBottomNav && !showTopNav;
    final bottomContentInset = showFloatingBottomNav
        ? FloatingBottomNav.reservedSpaceFor(context) + 16
        : 0.0;
    // Dior's first section is a full-bleed hero that paints behind the nav.
    // Sport has no premium navbar, but the shared theme switcher is pinned in
    // the same chrome slot; reserve that height so CMS tabs do not overlap it.
    final topContentInset = excludeTabRow
        ? 0.0
        : (showSportThemeSwitcherSlot
              ? premiumNavReservedHeight(context)
              : (chrome.startsContentBelowStatusBar
                    ? MediaQuery.paddingOf(context).top + 12
                    : 0.0));

    final Widget body;
    switch (snapshot.kind) {
      case _HomepageSnapshotKind.shell:
        body = excludeTabRow
            ? _SportHomepageLoadingSkeleton(
                showTabs: false,
                topContentInsetOverride: 0,
                animateGradient: widget.enableStartupBackdrop,
              )
            : _ThemeHomepageShell(
                theme: snapshot.theme,
                animateGradient: widget.enableStartupBackdrop,
                activeSegment: snapshot.theme == StorefrontTheme.nike
                    ? _sportSegmentForSnapshot(snapshot)
                    : null,
              );
      case _HomepageSnapshotKind.empty:
      case _HomepageSnapshotKind.error:
        body = _EmptyHomepage(
          background: _homepageInterimBackground(snapshot.theme),
          showSeedHint: isEditMode && chrome.showEmptyStateSeedHint,
          showAppearanceControls: isEditMode || previewTheme != null,
        );
      case _HomepageSnapshotKind.content:
        final bundle = snapshot.bundle!;
        body = _CmsHomepageBody(
          pageId: bundle.page.id,
          sections: bundle.sections,
          scrollController: scrollController,
          isEditMode: isEditMode,
          isSidebarExpanded: _isCmsSidebarExpanded,
          onSidebarExpandedChanged: (value) {
            setState(() => _isCmsSidebarExpanded = value);
          },
          bottomContentInset: bottomContentInset,
          topContentInset: topContentInset,
          excludeTabRow: excludeTabRow,
          hideThemeSwitcherBrandSegment: showSportThemeSwitcherSlot,
          activeSportSegment: snapshot.theme == StorefrontTheme.nike
              ? _sportSegmentForSnapshot(snapshot)
              : null,
          showCmsFallbackHint: isEditMode && snapshot.usedCmsFallback,
          requestedCmsCode: snapshot.requestedCmsCode,
          resolvedCmsCode: snapshot.resolvedCmsCode,
        );
    }
    return LandingGradientLoadingBackground(
      idleBackgroundColor: _homepageSnapshotBackground(snapshot),
      child: body,
    );
  }

  // Builds the segment slide: the Homme/Femme/Enfant tab row pinned at the top
  // (active = the tapped segment, snapped) while the content below slides
  // horizontally from the outgoing segment to the incoming one.
  Widget _buildSegmentTransition({
    required BuildContext context,
    required bool isEditMode,
    required StorefrontTheme? previewTheme,
  }) {
    final incoming = _currentHomepageSnapshot!;
    final outgoing = _outgoingSegmentSnapshot;
    // The pinned tab row is captured once at transition start so it stays real
    // (never a skeleton) for the whole switch, including post-slide loading.
    final tabRowSection = _pinnedSegmentTabRow;

    Widget pane(_HomepageSnapshot snapshot, ScrollController controller) {
      return _buildHomepageBody(
        context: context,
        snapshot: snapshot,
        scrollController: controller,
        isEditMode: isEditMode,
        previewTheme: previewTheme,
        excludeTabRow: tabRowSection != null,
      );
    }

    Widget? pinnedTabRow;
    if (tabRowSection != null) {
      pinnedTabRow = Padding(
        padding: EdgeInsets.only(top: premiumNavReservedHeight(context)),
        child: renderCmsSection(
          context,
          tabRowSection,
          isEditMode: false,
          activeSportSegment: widget.sportSegment,
        ),
      );
    }

    return _SportSegmentSlide(
      background: _homepageSnapshotBackground(incoming),
      beginOffset: Offset(_segmentSlideBeginDx, 0),
      progress: _segmentPagerController,
      pinnedTabRow: pinnedTabRow,
      outgoing: outgoing == null
          ? null
          : pane(outgoing, _outgoingSegmentScrollController!),
      child: pane(incoming, _scrollController),
    );
  }

  CmsSectionConfig? _tabRowSectionFor(
    _HomepageSnapshot snapshot, {
    required bool isEditMode,
  }) {
    final sections = snapshot.bundle?.sections;
    if (sections == null) return null;
    final chrome = StorefrontChromeProfile.forTheme(snapshot.theme);
    final showSportThemeSwitcherSlot =
        chrome.showFloatingBottomNav && !chrome.showPremiumTopNav;
    final visible = _visibleHomepageSections(
      sections,
      isEditMode: isEditMode,
      hideThemeSwitcherBrandSegment: showSportThemeSwitcherSlot,
    );
    return _splitTabRow(visible).tabs;
  }

  List<String> _homepageTransitionImageUrls({
    required BuildContext context,
    required _HomepageSnapshot snapshot,
    int limit = 4,
  }) {
    final sections = snapshot.bundle?.sections;
    if (sections == null || sections.isEmpty) return const [];

    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);
    final urls = <String>[];

    CmsMediaRef? responsiveMedia({
      required CmsMediaRef? mobile,
      required CmsMediaRef? desktop,
    }) {
      return isMobile ? (mobile ?? desktop) : (desktop ?? mobile);
    }

    void addMedia(CmsMediaRef? media, {required String size}) {
      if (media == null || !media.isUsable || media.isVideo) return;
      urls.add(media.thumbUrl(size: size));
    }

    for (final section in sections) {
      switch (section) {
        case CmsHeroSection(:final data):
          addMedia(
            responsiveMedia(
              mobile: data.mediaMobile,
              desktop: data.mediaDesktop,
            ),
            size: '1800x1200f',
          );
        case CmsCollectionHeroSection(:final data):
          addMedia(
            responsiveMedia(
              mobile: data.imageMobile,
              desktop: data.imageDesktop,
            ),
            size: isMobile ? '800x1000' : '1400x900',
          );
        case CmsEditorialSection(:final data):
          if (data.mediaType != 'video') {
            addMedia(
              responsiveMedia(
                mobile: data.mediaMobile,
                desktop: data.mediaDesktop,
              ),
              size: '1200x1500f',
            );
          }
        case CmsCategoryTilesSection(:final data):
          for (final tile in data.tiles.take(4)) {
            addMedia(tile.media, size: '800x800f');
          }
        case CmsHorizontalTileCarouselSection(:final data):
          for (final item in data.items.take(4)) {
            addMedia(item.media, size: '800x800f');
          }
        case CmsCategoryBannerStripSection(:final data):
          // The full-bleed shared background is the heaviest above-the-fold
          // image; the host renders it at this exact thumb size.
          addMedia(data.sharedBackgroundMedia, size: '1600x1200f');
        // Brand-segment items render as 64x64 icons that decode in well under a
        // frame — not worth a transition-precache slot, so they fall through.
        case _:
          break;
      }
      if (urls.length >= limit) break;
    }

    return urls.toSet().take(limit).toList(growable: false);
  }

  Future<void> _precacheHomepageTransitionImages(
    BuildContext context,
    List<String> urls,
  ) async {
    await Future.wait(
      urls.map((url) async {
        try {
          await precacheImage(
            _transitionPrecacheProvider(context, url),
            context,
          );
        } catch (_) {
          // A failed preload should never affect the visible transition.
        }
      }),
    ).timeout(const Duration(milliseconds: 200), onTimeout: () => const []);
  }

  // These URLs already point at a server-side thumb (e.g. `1800x1200f`), but
  // that can still be well above what the section actually renders (a
  // full-bleed hero/banner rarely exceeds the screen width). Decoding it
  // un-resized was costing 300ms+ per image on a mid-tier phone (profiled via
  // test_driver/scroll_perf_test.dart) and got thrown away the moment the
  // real widget decoded it again at its own (smaller) render size. Capping to
  // the screen's physical pixel width keeps full-bleed images crisp while
  // skipping that wasted oversized decode.
  ImageProvider _transitionPrecacheProvider(BuildContext context, String url) {
    final mediaQuery = MediaQuery.of(context);
    final maxWidth = (mediaQuery.size.width * mediaQuery.devicePixelRatio)
        .round()
        .clamp(1, 2400);
    return ResizeImage(CachedNetworkImageProvider(url), width: maxWidth);
  }

  // Animation for the theme-switcher pill (0 = Sport, 1 = Luxe), driven by the
  // pager so the pill tracks the page slide in real time. Built per landing
  // rebuild (cheap) but ticked only inside the switcher's own AnimatedBuilder,
  // so the navbar around it is not rebuilt every frame. On mobile landing the
  // switcher slot is forced centered on both themes (see forceCenteredThemeSwitcher),
  // so the control keeps the same coordinates across a swipe.
  Animation<double> _themeSwitcherPositionFor(StorefrontTheme displayedTheme) {
    double indexOf(StorefrontTheme theme) =>
        _themeSwitcherIndex(theme).toDouble();
    final double from;
    final double to;
    if (_isThemeDragging &&
        _dragTargetTheme != null &&
        _displayedTheme != null) {
      from = indexOf(_displayedTheme!);
      to = indexOf(_dragTargetTheme!);
    } else if (_outgoingHomepageSnapshot != null && _displayedTheme != null) {
      from = indexOf(_outgoingHomepageSnapshot!.theme);
      to = indexOf(_displayedTheme!);
    } else {
      from = indexOf(displayedTheme);
      to = from;
    }
    return _pagerController.drive(Tween<double>(begin: from, end: to));
  }

  void _clearOutgoingHomepageSnapshot(int transitionGeneration) {
    if (transitionGeneration != _themePageTransitionGeneration) return;
    if (_outgoingHomepageSnapshot == null) return;
    setState(() {
      _outgoingHomepageSnapshot = null;
      _outgoingScrollController?.dispose();
      _outgoingScrollController = null;
    });
  }

  // The theme the user reaches by dragging in [dx]'s direction, or null at the
  // edge (no neighbour that way). With two themes only one direction is valid.
  StorefrontTheme? _swipeTargetFor(StorefrontTheme current, double dx) {
    final target = current == StorefrontTheme.nike
        ? StorefrontTheme.dior
        : StorefrontTheme.nike;
    final beginOffset = storefrontThemePageTransitionBeginOffset(
      previousTheme: current,
      nextTheme: target,
    );
    // The target enters from beginOffset's side, so the revealing drag goes the
    // opposite way: dragging toward the target raises progress only when dx's
    // sign is the opposite of beginOffset.dx.
    if (dx.sign != -beginOffset.dx.sign) return null;
    return target;
  }

  void _onThemeDragStart(DragStartDetails details) {
    _dragAccumulatedDx = 0;
    _dragWidth = context.size?.width ?? MediaQuery.sizeOf(context).width;
  }

  void _onThemeDragUpdate(DragUpdateDetails details) {
    final current = _displayedTheme;
    if (current == null) return;
    _dragAccumulatedDx += details.delta.dx;

    if (!_isThemeDragging) {
      if (_dragAccumulatedDx.abs() < _kThemeDragSlop) return;
      final target = _swipeTargetFor(current, _dragAccumulatedDx);
      if (target == null) return; // edge: resist, no movement
      _beginThemeDrag(current: current, target: target);
    }

    if (_dragWidth <= 0) return;
    final frac = (_dragAccumulatedDx / _dragWidth) * -_dragBeginDx;
    _pagerController.value = frac.clamp(0.0, 1.0);
  }

  void _beginThemeDrag({
    required StorefrontTheme current,
    required StorefrontTheme target,
  }) {
    final beginOffset = storefrontThemePageTransitionBeginOffset(
      previousTheme: current,
      nextTheme: target,
    );
    _dragBeginDx = beginOffset.dx;
    final targetAsync = ref.read(
      cmsPageProvider(
        CmsPageRequest(
          code: homepageCodeFor(target),
          locale: ref.read(contentLocaleProvider),
        ),
      ),
    );
    final targetSnapshot =
        _HomepageSnapshot.fromAsyncValue(
          theme: target,
          sportSegment: null,
          pageAsync: targetAsync,
          usedCmsFallback: false,
          requestedCmsCode: homepageCodeFor(target),
          resolvedCmsCode: null,
        ) ??
        _HomepageSnapshot.shell(theme: target, sportSegment: null);
    _dragTargetScrollController?.dispose();
    _dragTargetScrollController = ScrollController();
    setState(() {
      _isThemeDragging = true;
      _dragTargetTheme = target;
      _dragTargetSnapshot = targetSnapshot;
    });
  }

  void _onThemeDragEnd(DragEndDetails details) {
    if (!_isThemeDragging) return;
    final velocity = details.primaryVelocity ?? 0;
    final revealVelocity = velocity * -_dragBeginDx;
    final commit =
        _pagerController.value >= _kThemeSwipeCommitFraction ||
        revealVelocity > _kThemeSwipeCommitVelocity;
    if (commit) {
      _commitThemeSwipe();
    } else {
      _springBackThemeSwipe();
    }
  }

  void _commitThemeSwipe() {
    _isCommittingSwipe = true;
    _pagerController
        .animateTo(
          1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        )
        .then((_) {
          if (!mounted) return;
          _onSwipeCommitDone();
        });
  }

  void _onSwipeCommitDone() {
    final target = _dragTargetTheme;
    final targetSnapshot = _dragTargetSnapshot;
    if (target == null || targetSnapshot == null) {
      _isCommittingSwipe = false;
      return;
    }
    setState(() {
      _outgoingScrollController?.dispose();
      _outgoingScrollController = ScrollController(
        initialScrollOffset: _scrollController.hasClients
            ? _scrollController.offset
            : 0,
      );
      _outgoingHomepageSnapshot = _currentHomepageSnapshot;
      _currentHomepageSnapshot = targetSnapshot;
      _displayedTheme = target;
      _themePageTransitionBeginOffset = Offset(_dragBeginDx, 0);
      _themePageTransitionGeneration += 1;
      // Leave drag mode: the target migrates from its drag controller to the
      // primary _scrollController (it was at the top, so it re-attaches at 0).
      _isThemeDragging = false;
      _dragTargetTheme = null;
      _dragTargetSnapshot = null;
      _dragTargetScrollController?.dispose();
      _dragTargetScrollController = null;
      _pagerController.value = 1;
    });
    final generation = _themePageTransitionGeneration;
    // Persist the choice; _syncHomepagePresentation holds the committed state
    // (via _isCommittingSwipe) until the resolved theme catches up. If the
    // write fails, release the guard so the screen reconciles to the actually
    // resolved theme instead of staying frozen on a non-persisted choice.
    unawaited(
      writeVisitorStorefrontThemeOverride(ref, target).catchError((Object _) {
        if (!mounted) return;
        setState(() => _isCommittingSwipe = false);
      }),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _clearOutgoingHomepageSnapshot(generation);
    });
  }

  void _springBackThemeSwipe() {
    _pagerController
        .animateBack(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .then((_) {
          if (!mounted) return;
          _onSwipeSpringBackDone();
        });
  }

  void _onSwipeSpringBackDone() {
    setState(() {
      _isThemeDragging = false;
      _dragTargetTheme = null;
      _dragTargetSnapshot = null;
      _dragTargetScrollController?.dispose();
      _dragTargetScrollController = null;
      _pagerController.value = 1;
    });
  }

  void _syncSportThemeSwitcherVisibility() {
    if (!_scrollController.hasClients) return;
    final nextVisible = _scrollController.offset <= 8;
    if (nextVisible == _isSportThemeSwitcherVisible) return;
    setState(() => _isSportThemeSwitcherVisible = nextVisible);
  }
}

Color _homepageInterimBackground(StorefrontTheme theme) {
  return switch (theme) {
    StorefrontTheme.dior => const Color(0xFFF4F1EA),
    StorefrontTheme.nike => const Color(0xFFF7F6F2),
  };
}

Color _homepageSnapshotBackground(_HomepageSnapshot snapshot) {
  return switch (snapshot.kind) {
    _HomepageSnapshotKind.shell ||
    _HomepageSnapshotKind.empty ||
    _HomepageSnapshotKind.error => _homepageInterimBackground(snapshot.theme),
    _HomepageSnapshotKind.content => StorefrontThemeTokens.forTheme(
      snapshot.theme,
    ).scaffoldBackground,
  };
}

@visibleForTesting
Offset storefrontThemePageTransitionBeginOffset({
  required StorefrontTheme previousTheme,
  required StorefrontTheme nextTheme,
}) {
  final previousIndex = _themeSwitcherIndex(previousTheme);
  final nextIndex = _themeSwitcherIndex(nextTheme);
  if (previousIndex == nextIndex) return Offset.zero;
  // Treat themes as side-by-side pages (Sport index 0, Luxe index 1): moving to
  // a higher index brings the target in from the right (begin offset +1), so the
  // natural reveal gesture is a leftward swipe. Lower index mirrors it.
  final motionDirection = nextIndex > previousIndex ? 1.0 : -1.0;
  return Offset(motionDirection, 0);
}

int _themeSwitcherIndex(StorefrontTheme theme) {
  return switch (theme) {
    StorefrontTheme.nike => 0,
    StorefrontTheme.dior => 1,
  };
}

int _sportSegmentIndex(StorefrontSportSegment segment) {
  return switch (segment) {
    StorefrontSportSegment.homme => 0,
    StorefrontSportSegment.femme => 1,
    StorefrontSportSegment.enfant => 2,
  };
}

@visibleForTesting
Offset storefrontSegmentSlideBeginOffset({
  required StorefrontSportSegment previousSegment,
  required StorefrontSportSegment nextSegment,
}) {
  final previousIndex = _sportSegmentIndex(previousSegment);
  final nextIndex = _sportSegmentIndex(nextSegment);
  if (previousIndex == nextIndex) return Offset.zero;
  // Segments are side-by-side pages (Homme 0, Femme 1, Enfant 2): moving to a
  // higher index brings the incoming content in from the right (begin offset
  // +1); a lower index mirrors it.
  return Offset(nextIndex > previousIndex ? 1.0 : -1.0, 0);
}

enum _HomepageSnapshotKind { content, shell, empty, error }

class _HomepageSnapshot {
  final StorefrontTheme theme;
  final StorefrontSportSegment? sportSegment;
  final CmsPageBundle? bundle;
  final _HomepageSnapshotKind kind;
  final bool usedCmsFallback;
  final String? requestedCmsCode;
  final String? resolvedCmsCode;

  const _HomepageSnapshot({
    required this.theme,
    required this.sportSegment,
    required this.bundle,
    required this.kind,
    this.usedCmsFallback = false,
    this.requestedCmsCode,
    this.resolvedCmsCode,
  });

  factory _HomepageSnapshot.content({
    required StorefrontTheme theme,
    required StorefrontSportSegment? sportSegment,
    required CmsPageBundle bundle,
    bool usedCmsFallback = false,
    String? requestedCmsCode,
    String? resolvedCmsCode,
  }) {
    return _HomepageSnapshot(
      theme: theme,
      sportSegment: sportSegment,
      bundle: bundle,
      kind: _HomepageSnapshotKind.content,
      usedCmsFallback: usedCmsFallback,
      requestedCmsCode: requestedCmsCode,
      resolvedCmsCode: resolvedCmsCode,
    );
  }

  factory _HomepageSnapshot.shell({
    required StorefrontTheme theme,
    required StorefrontSportSegment? sportSegment,
  }) {
    return _HomepageSnapshot(
      theme: theme,
      sportSegment: sportSegment,
      bundle: null,
      kind: _HomepageSnapshotKind.shell,
    );
  }

  factory _HomepageSnapshot.empty({
    required StorefrontTheme theme,
    required StorefrontSportSegment? sportSegment,
    bool usedCmsFallback = false,
    String? requestedCmsCode,
    String? resolvedCmsCode,
  }) {
    return _HomepageSnapshot(
      theme: theme,
      sportSegment: sportSegment,
      bundle: null,
      kind: _HomepageSnapshotKind.empty,
      usedCmsFallback: usedCmsFallback,
      requestedCmsCode: requestedCmsCode,
      resolvedCmsCode: resolvedCmsCode,
    );
  }

  factory _HomepageSnapshot.error({
    required StorefrontTheme theme,
    required StorefrontSportSegment? sportSegment,
    bool usedCmsFallback = false,
    String? requestedCmsCode,
    String? resolvedCmsCode,
  }) {
    return _HomepageSnapshot(
      theme: theme,
      sportSegment: sportSegment,
      bundle: null,
      kind: _HomepageSnapshotKind.error,
      usedCmsFallback: usedCmsFallback,
      requestedCmsCode: requestedCmsCode,
      resolvedCmsCode: resolvedCmsCode,
    );
  }

  Key get animationKey {
    final pageId = bundle?.page.id ?? 'none';
    final segmentKey = sportSegment?.wireName ?? 'default';
    return ValueKey(
      'homepage-${theme.wireName}-$segmentKey-${kind.name}-$pageId',
    );
  }

  static _HomepageSnapshot? fromAsyncValue({
    required StorefrontTheme theme,
    required StorefrontSportSegment? sportSegment,
    required AsyncValue<CmsPageBundle?> pageAsync,
    required bool usedCmsFallback,
    required String? requestedCmsCode,
    required String? resolvedCmsCode,
  }) {
    if (pageAsync.hasValue) {
      final bundle = pageAsync.value;
      if (bundle == null || bundle.sections.isEmpty) {
        return _HomepageSnapshot.empty(
          theme: theme,
          sportSegment: sportSegment,
          usedCmsFallback: usedCmsFallback,
          requestedCmsCode: requestedCmsCode,
          resolvedCmsCode: resolvedCmsCode,
        );
      }
      return _HomepageSnapshot.content(
        theme: theme,
        sportSegment: sportSegment,
        bundle: bundle,
        usedCmsFallback: usedCmsFallback,
        requestedCmsCode: requestedCmsCode,
        resolvedCmsCode: resolvedCmsCode,
      );
    }
    if (pageAsync.hasError) {
      return _HomepageSnapshot.error(
        theme: theme,
        sportSegment: sportSegment,
        usedCmsFallback: usedCmsFallback,
        requestedCmsCode: requestedCmsCode,
        resolvedCmsCode: resolvedCmsCode,
      );
    }
    if (pageAsync.isLoading) return null;
    return null;
  }
}

class _StorefrontThemePageSlide extends StatelessWidget {
  final Offset beginOffset;
  final Animation<double> progress;
  final Widget? outgoing;
  final Widget child;

  const _StorefrontThemePageSlide({
    super.key,
    required this.beginOffset,
    required this.progress,
    this.outgoing,
    required this.child,
  });

  static const duration = Duration(milliseconds: 560);

  @override
  Widget build(BuildContext context) {
    final hasOutgoing = outgoing != null && beginOffset != Offset.zero;
    return ClipRect(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final p = progress.value;
          final incomingOffset = Offset.lerp(beginOffset, Offset.zero, p)!;
          final outgoingOffset = Offset.lerp(Offset.zero, -beginOffset, p)!;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (hasOutgoing)
                FractionalTranslation(
                  translation: outgoingOffset,
                  child: outgoing,
                ),
              FractionalTranslation(
                key: storefrontThemePageSlideKey,
                translation: incomingOffset,
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Segment slide (Homme/Femme/Enfant): the tab row stays pinned at the top
/// while only the content below slides horizontally, directional by segment
/// order. Mirrors [_StorefrontThemePageSlide] for the sliding part.
class _SportSegmentSlide extends StatelessWidget {
  final Color background;
  final Offset beginOffset;
  final Animation<double> progress;
  final Widget? pinnedTabRow;
  final Widget? outgoing;
  final Widget child;

  const _SportSegmentSlide({
    required this.background,
    required this.beginOffset,
    required this.progress,
    this.pinnedTabRow,
    this.outgoing,
    required this.child,
  });

  static const duration = Duration(milliseconds: 360);

  @override
  Widget build(BuildContext context) {
    final hasOutgoing = outgoing != null && beginOffset != Offset.zero;
    final slidingContent = ClipRect(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final p = progress.value;
          final incomingOffset = Offset.lerp(beginOffset, Offset.zero, p)!;
          final outgoingOffset = Offset.lerp(Offset.zero, -beginOffset, p)!;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (hasOutgoing)
                FractionalTranslation(
                  translation: outgoingOffset,
                  child: outgoing,
                ),
              FractionalTranslation(
                key: storefrontSegmentSlideKey,
                translation: incomingOffset,
                child: child,
              ),
            ],
          );
        },
      ),
    );

    return LandingGradientLoadingBackground(
      idleBackgroundColor: background,
      // stretch: the pinned tab row must fill the width so its tabs stay
      // left-aligned (matching the scrolling list). Without it the Column
      // centers the content-sized row, so the tabs jump to center during the
      // slide and snap back to the left when it settles.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?pinnedTabRow,
          Expanded(child: slidingContent),
        ],
      ),
    );
  }
}

class _SportThemeSwitcherNavSlot extends StatelessWidget {
  final bool isVisible;
  final Animation<double>? themeSwitcherVisualPosition;
  final StorefrontThemeSelectionCallback? onThemeSelected;

  const _SportThemeSwitcherNavSlot({
    required this.isVisible,
    this.themeSwitcherVisualPosition,
    this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
          key: sportThemeSwitcherOpacityKey,
          opacity: isVisible ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: TopNavigationBar(
            foregroundColor: const Color(0xFF111111),
            showOnlyThemeSwitcher: true,
            hideTrailingDestinations: true,
            themeSwitcherVisualPosition: themeSwitcherVisualPosition,
            onThemeSelected: onThemeSelected,
          ),
        ),
      ),
    );
  }
}

class _ThemeHomepageShell extends StatelessWidget {
  final StorefrontTheme theme;
  final StorefrontSportSegment? activeSegment;
  final bool animateGradient;

  const _ThemeHomepageShell({
    required this.theme,
    required this.animateGradient,
    this.activeSegment,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: storefrontHomepageThemeShellKey,
      child: switch (theme) {
        StorefrontTheme.nike => _SportHomepageLoadingSkeleton(
          activeSegment: activeSegment,
          animateGradient: animateGradient,
        ),
        StorefrontTheme.dior => LandingGradientLoadingSurface(
          animate: animateGradient,
          child: SizedBox(
            width: double.infinity,
            height: MediaQuery.sizeOf(context).height,
          ),
        ),
      },
    );
  }
}

class _SportHomepageLoadingSkeleton extends StatelessWidget {
  // During a segment slide the tab row is pinned separately, so the skeleton
  // drops its own tab row and collapses the top inset that would clear it.
  final bool showTabs;
  final double? topContentInsetOverride;
  // The segment labels are fixed (from StorefrontSportSegment), so the skeleton
  // renders the real, tappable segment control — never grey blocks. Only the
  // content below is a placeholder.
  final StorefrontSportSegment? activeSegment;
  final bool animateGradient;

  const _SportHomepageLoadingSkeleton({
    this.showTabs = true,
    this.topContentInsetOverride,
    this.activeSegment,
    this.animateGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final chrome = StorefrontChromeProfile.forTheme(StorefrontTheme.nike);
    final topContentInset =
        topContentInsetOverride ?? premiumNavReservedHeight(context);
    final bottomContentInset = chrome.showFloatingBottomNav
        ? FloatingBottomNav.reservedSpaceFor(context) + 16
        : 0.0;

    return ExcludeSemantics(
      child: LandingGradientLoadingSurface(
        key: storefrontSportHomepageSkeletonKey,
        animate: animateGradient,
        child: SizedBox.expand(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Padding(
                padding: EdgeInsets.only(
                  top: topContentInset,
                  bottom: bottomContentInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // stretch: the segment header/content placeholders fill the
                  // same width as the resolved CMS sections.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showTabs)
                      _SportSkeletonTabs(activeSegment: activeSegment),
                    _SportSkeletonCarousel(
                      width: width,
                      titleWidth: 206,
                      isMomentSection: true,
                      labelWidths: const [122, 146, 104],
                    ),
                    _SportSkeletonBannerStrip(width: width),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Builds the segment control config from the fixed segment enum — no CMS bundle
// needed — so the skeleton can show the real header while loading.
CategorySplitTabsConfig _sportSegmentTabsConfig() {
  return CategorySplitTabsConfig(
    // The current Sport landing uses the centered expansible segment header.
    // This fallback keeps the first loading frame aligned even if the async
    // global navigation setting has not resolved yet.
    displayMode: CategorySplitDisplayMode.expansible.value,
    items: [
      for (final segment in StorefrontSportSegment.values)
        CategorySplitTabItem(
          label: segment.displayLabel,
          href: CatalogRoutes.sportSegmentLocation(segment),
          segment: segment.wireName,
        ),
    ],
  );
}

class _SportSkeletonTabs extends StatelessWidget {
  final StorefrontSportSegment? activeSegment;

  const _SportSkeletonTabs({this.activeSegment});

  @override
  Widget build(BuildContext context) {
    // Reuse the real segment header: identical styling and still tappable so
    // the user can open the segment menu while the page loads.
    return CategorySplitTabsSection(
      config: _sportSegmentTabsConfig(),
      activeSportSegment: activeSegment,
    );
  }
}

class _SportSkeletonCarousel extends StatelessWidget {
  final double width;
  final double titleWidth;
  final bool isMomentSection;
  final List<double> labelWidths;

  const _SportSkeletonCarousel({
    required this.width,
    required this.titleWidth,
    required this.labelWidths,
    this.isMomentSection = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = StorefrontLayout.isMobile(width);
    final horizontalPadding = StorefrontLayout.nikeContentPaddingFor(width);
    final viewportWidth = width - (horizontalPadding * 2);
    final tileWidth = isMobile
        ? viewportWidth / (isMomentSection ? 2.24 : 2.04)
        : 280.0;
    final tileGap = isMobile ? 4.0 : 8.0;

    return Padding(
      padding: EdgeInsets.only(
        top: isMobile ? (isMomentSection ? 8 : 30) : 24,
        bottom: isMobile ? (isMomentSection ? 2 : 12) : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              isMobile ? 26 : 20,
            ),
            child: _SportSkeletonBlock(
              width: titleWidth,
              height: isMobile ? 32 : 38,
              radius: 7,
              color: const Color(0xFFE7E5DF),
            ),
          ),
          SizedBox(
            height: tileWidth + 46,
            width: double.infinity,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                child: Padding(
                  padding: EdgeInsets.only(left: horizontalPadding),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < labelWidths.length; i++) ...[
                        _SportSkeletonTile(
                          size: tileWidth,
                          labelWidth: labelWidths[i],
                        ),
                        if (i < labelWidths.length - 1)
                          SizedBox(width: tileGap),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SportSkeletonTile extends StatelessWidget {
  final double size;
  final double labelWidth;

  const _SportSkeletonTile({required this.size, required this.labelWidth});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SportSkeletonBlock(
            width: size,
            height: size,
            radius: 8,
            color: const Color(0xFFEDEAE3),
          ),
          const SizedBox(height: 10),
          _SportSkeletonBlock(
            width: labelWidth.clamp(0, size).toDouble(),
            height: 20,
            radius: 5,
          ),
        ],
      ),
    );
  }
}

class _SportSkeletonBannerStrip extends StatelessWidget {
  final double width;

  const _SportSkeletonBannerStrip({required this.width});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = StorefrontLayout.isMobile(width);
    final bannerHeight = isMobile ? size.width * 0.28 : size.height * 0.22;
    final clampedBannerHeight = isMobile
        ? bannerHeight.clamp(108.0, 132.0).toDouble()
        : bannerHeight.clamp(160.0, 220.0).toDouble();

    return Padding(
      padding: EdgeInsets.only(top: isMobile ? 20 : 24, bottom: 8),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            _SportSkeletonBanner(height: clampedBannerHeight, index: i),
            if (i < 2) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _SportSkeletonBanner extends StatelessWidget {
  final double height;
  final int index;

  const _SportSkeletonBanner({required this.height, required this.index});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = StorefrontLayout.isMobile(width);
    final horizontalPadding = isMobile
        ? StorefrontLayout.nikeContentPaddingFor(width)
        : 24.0;

    final colors = switch (index) {
      0 => (const Color(0x1F60A5FA), const Color(0x1F60A5FA)),
      1 => (const Color(0x1F1E3A8A), const Color(0x1F60A5FA)),
      _ => (const Color(0x1F243E91), const Color(0x1F243E91)),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [colors.$1, colors.$2],
        ),
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 20,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _SportSkeletonBlock(
              width: isMobile ? 156 : 230,
              height: isMobile ? 30 : 38,
              radius: 7,
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
    );
  }
}

class _SportSkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final Color color;

  const _SportSkeletonBlock({
    this.width,
    required this.height,
    this.radius = 6,
    this.color = const Color(0xFFEBE9E3),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ThemeLoadingShell extends StatelessWidget {
  final bool animateGradient;

  const _ThemeLoadingShell({required this.animateGradient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: storefrontThemeLoadingShellKey,
      backgroundColor: Colors.transparent,
      body: LandingGradientLoadingSurface(
        animate: animateGradient,
        child: const SafeArea(
          child: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditModeFab extends ConsumerWidget {
  final bool isEditMode;

  const _EditModeFab({required this.isEditMode});

  Future<void> _toggleEditMode(BuildContext context, WidgetRef ref) async {
    if (isEditMode) {
      ref.read(editModeProvider.notifier).state = false;
      return;
    }

    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;
    ref.read(editModeProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.small(
      backgroundColor: isEditMode
          ? const Color(0xFFA8892E)
          : const Color(0xFF2B2B2B),
      onPressed: () => _toggleEditMode(context, ref),
      child: Icon(
        isEditMode ? Icons.close : Icons.edit,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

class _CmsHomepageBody extends StatelessWidget {
  final String pageId;
  final List<CmsSectionConfig> sections;
  final ScrollController scrollController;
  final bool isEditMode;
  final bool isSidebarExpanded;
  final ValueChanged<bool> onSidebarExpandedChanged;
  final double bottomContentInset;
  final double topContentInset;
  final bool hideThemeSwitcherBrandSegment;
  // During a segment slide the tab row is pinned separately, so drop it from
  // this scrolling body.
  final bool excludeTabRow;
  final StorefrontSportSegment? activeSportSegment;
  final bool showCmsFallbackHint;
  final String? requestedCmsCode;
  final String? resolvedCmsCode;

  const _CmsHomepageBody({
    required this.pageId,
    required this.sections,
    required this.scrollController,
    required this.isEditMode,
    required this.isSidebarExpanded,
    required this.onSidebarExpandedChanged,
    this.bottomContentInset = 0,
    this.topContentInset = 0,
    this.hideThemeSwitcherBrandSegment = false,
    this.excludeTabRow = false,
    this.activeSportSegment,
    this.showCmsFallbackHint = false,
    this.requestedCmsCode,
    this.resolvedCmsCode,
  });

  @override
  Widget build(BuildContext context) {
    final base = _visibleHomepageSections(
      sections,
      isEditMode: isEditMode,
      hideThemeSwitcherBrandSegment: hideThemeSwitcherBrandSegment,
    );
    final visible = excludeTabRow ? _splitTabRow(base).rest : base;

    final nextPosition = sections.isEmpty
        ? 0
        : (sections
                  .map((s) => s.record.position)
                  .reduce((a, b) => a > b ? a : b) +
              1);

    final sectionsList = ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(
        top: topContentInset,
        bottom: bottomContentInset,
      ),
      itemCount: visible.length + (showCmsFallbackHint ? 1 : 0),
      itemBuilder: (context, index) {
        if (showCmsFallbackHint && index == 0) {
          return _CmsFallbackHintBanner(
            requestedCmsCode: requestedCmsCode,
            resolvedCmsCode: resolvedCmsCode,
          );
        }
        final sectionIndex = showCmsFallbackHint ? index - 1 : index;
        final section = visible[sectionIndex];
        final rendered = renderCmsSection(
          context,
          section,
          isEditMode: isEditMode,
          activeSportSegment: activeSportSegment,
        );

        final Widget revealed;
        if (!shouldRevealSection(
          index: sectionIndex,
          section: section,
          isSegmentedLanding: activeSportSegment != null,
        )) {
          revealed = rendered;
        } else {
          final staggerIndex = (sectionIndex - 2).clamp(0, 3).toInt();
          revealed = CmsSectionReveal(
            key: ValueKey('cms-reveal-${section.record.id}'),
            revealId: section.record.id,
            style: revealStyleFor(section),
            duration: const Duration(milliseconds: 720),
            delay: Duration(milliseconds: 150 * staggerIndex),
            child: rendered,
          );
        }

        if (!isEditMode) return revealed;

        return CmsEditOverlay(
          section: section,
          allSections: sections,
          pageId: pageId,
          child: revealed,
        );
      },
    );

    if (!isEditMode) {
      return sectionsList;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        sectionsList,
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          child: CmsSectionsSidebar(
            pageId: pageId,
            sections: sections,
            nextPosition: nextPosition,
            isExpanded: isSidebarExpanded,
            onExpandedChanged: onSidebarExpandedChanged,
          ),
        ),
        if (!isSidebarExpanded)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 84,
            left: 12,
            child: CmsSidebarToggleButton(
              isExpanded: false,
              onPressed: () => onSidebarExpandedChanged(true),
            ),
          ),
      ],
    );
  }
}

class _CmsFallbackHintBanner extends StatelessWidget {
  final String? requestedCmsCode;
  final String? resolvedCmsCode;

  const _CmsFallbackHintBanner({
    required this.requestedCmsCode,
    required this.resolvedCmsCode,
  });

  @override
  Widget build(BuildContext context) {
    final requested = requestedCmsCode?.trim();
    final resolved = resolvedCmsCode?.trim();
    final hasResolved = resolved != null && resolved.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E5),
          border: Border.all(color: const Color(0xFFE3B872)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          hasResolved
              ? 'Page CMS spécifique manquante'
                    '${requested == null || requested.isEmpty ? '' : ' ($requested)'}'
                    ' - repli sur $resolved.'
              : 'Page CMS spécifique et repli manquants'
                    '${requested == null || requested.isEmpty ? '' : ' ($requested)'}.',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C3D00),
          ),
        ),
      ),
    );
  }
}

/// Determines whether a section should animate in.
/// The first two sections (index < 2) and any full-bleed heroes
/// are strictly kept static to protect the top of the page from
/// compositing glitches on Flutter Web.
@visibleForTesting
bool shouldRevealSection({
  required int index,
  required CmsSectionConfig section,
  required bool isSegmentedLanding,
}) {
  // Tabbed Sport landings (Homme/Femme/Enfant) animate the whole page with a
  // horizontal slide on every switch. A per-section reveal on top replays a
  // fade each time the incoming segment mounts — most visibly on the large dark
  // category_banner_strip — so suppress per-section reveals there entirely and
  // let the slide be the only transition.
  if (isSegmentedLanding) return false;
  if (index < 2) return false;
  return switch (section) {
    CmsHeroSection() => false,
    CmsCollectionHeroSection() => false,
    _ => true,
  };
}

/// Picks a reveal style for sections that are allowed to animate.
/// Full-bleed heroes are normally excluded by shouldRevealSection.
/// If this function is called directly for a hero, it returns the safest
/// available style: premiumFadeUp.
@visibleForTesting
CmsSectionRevealStyle revealStyleFor(CmsSectionConfig section) {
  return switch (section) {
    CmsHeroSection() => CmsSectionRevealStyle.premiumFadeUp,
    CmsCollectionHeroSection() => CmsSectionRevealStyle.premiumFadeUp,
    CmsEditorialSection() => CmsSectionRevealStyle.splitOpen,
    CmsEditorialIntroSection() => CmsSectionRevealStyle.splitOpen,
    CmsCategoryTilesSection() => CmsSectionRevealStyle.cascadeFromTop,
    CmsFeaturedProductsSection() => CmsSectionRevealStyle.cascadeFromTop,
    CmsMixedProductGridSection() => CmsSectionRevealStyle.cascadeFromTop,
    CmsServiceCardsSection() => CmsSectionRevealStyle.slideUp,
    CmsSeoTextSection() => CmsSectionRevealStyle.slideUp,
    CmsDiscoverLinksSection() => CmsSectionRevealStyle.slideUp,
    CmsHorizontalTileCarouselSection() => CmsSectionRevealStyle.slideUp,
    CmsBrandSegmentSection() => CmsSectionRevealStyle.slideUp,
    CmsCategorySplitTabsSection() => CmsSectionRevealStyle.slideUp,
    CmsCategoryBannerStripSection() => CmsSectionRevealStyle.slideUp,
    CmsUnknownSection() => CmsSectionRevealStyle.slideUp,
  };
}

class _EmptyHomepage extends StatelessWidget {
  final Color background;
  final bool showSeedHint;
  final bool showAppearanceControls;

  const _EmptyHomepage({
    this.background = const Color(0xFF1B1B1B),
    this.showSeedHint = false,
    this.showAppearanceControls = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showSeedHint && !showAppearanceControls) {
      return ColoredBox(color: background);
    }
    return ColoredBox(
      color: background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showSeedHint)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 40,
                        color: Color(0xFF8E8E8E),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Aucune page homepage_nike.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Lance la migration PocketBase '
                        '`1777000360_seed_homepage_nike_fr.js` ou crée la page '
                        '`homepage_nike` (locale fr) avec une section.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6F6F6F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (showAppearanceControls)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              left: 16,
              child: const SizedBox(width: 304, child: CmsAppearanceBlock()),
            ),
        ],
      ),
    );
  }
}

List<CmsSectionConfig> _visibleHomepageSections(
  List<CmsSectionConfig> sections, {
  required bool isEditMode,
  bool hideThemeSwitcherBrandSegment = false,
}) {
  if (hideThemeSwitcherBrandSegment) {
    final withoutThemeSwitcher = sections
        .where((s) => !_isThemeSwitcherBrandSegment(s))
        .toList(growable: false);
    if (isEditMode) return withoutThemeSwitcher;
    return withoutThemeSwitcher
        .where((s) => s.record.isActive && s is! CmsUnknownSection)
        .toList(growable: false);
  }

  if (isEditMode) {
    return sections;
  }
  return sections
      .where((s) => s.record.isActive && s is! CmsUnknownSection)
      .toList(growable: false);
}

bool _isThemeSwitcherBrandSegment(CmsSectionConfig section) {
  return section is CmsBrandSegmentSection &&
      section.data.mode == BrandSegmentMode.themeSwitcher;
}

/// Splits the (already-filtered) visible sections into the leading tab-row
/// section and the remaining content, so the tab row can be pinned while the
/// content below slides during a segment transition. Returns a null [tabs] when
/// the page has no [CmsCategorySplitTabsSection] (then [rest] is the full list).
({CmsSectionConfig? tabs, List<CmsSectionConfig> rest}) _splitTabRow(
  List<CmsSectionConfig> visible,
) {
  final index = visible.indexWhere((s) => s is CmsCategorySplitTabsSection);
  if (index < 0) return (tabs: null, rest: visible);
  return (
    tabs: visible[index],
    rest: [...visible.take(index), ...visible.skip(index + 1)],
  );
}

double _heroHeightFor({
  required BuildContext context,
  required List<CmsSectionConfig> sections,
  required bool isEditMode,
}) {
  final visible = _visibleHomepageSections(sections, isEditMode: isEditMode);
  if (visible.isEmpty) {
    return 0;
  }
  if (visible.first case CmsHeroSection(:final data)) {
    return _heroHeightFromMode(context, mode: data.heightMode);
  }
  return 0;
}

double _loadingHeroHeightFor(BuildContext context) {
  return _heroHeightFromMode(context, mode: 'xl');
}

double _heroHeightFromMode(BuildContext context, {required String mode}) {
  final width = MediaQuery.sizeOf(context).width;
  final isTablet = StorefrontLayout.isTabletOnly(width);
  final isDesktop = StorefrontLayout.isDesktop(width);
  return HeroCampaignSection.heightFor(
    mode: mode,
    viewportHeight: MediaQuery.sizeOf(context).height,
    isMobile: !isTablet && !isDesktop,
  );
}
