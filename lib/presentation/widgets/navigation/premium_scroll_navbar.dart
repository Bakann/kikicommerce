import 'package:flutter/material.dart';

import 'premium_navbar_surface.dart';
import 'scroll_navbar_state_machine.dart';
import 'top_navigation_bar.dart';

class PremiumScrollNavbar extends StatefulWidget {
  static const surfaceKey = PremiumNavbarSurface.surfaceKey;
  static const ignorePointerKey = PremiumNavbarSurface.ignorePointerKey;

  final ScrollController scrollController;
  final double heroHeight;
  final bool forceVisibleLight;
  final NavRevealTapCallback? onMenuTap;
  final NavRevealTapCallback? onSearchTap;
  final VoidCallback? onBrandTripleTap;
  final bool isMenuOpen;
  final Animation<double>? menuProgress;
  final bool hideChromeForOpenMenu;
  final bool hideTrailingDestinations;
  final Animation<double>? themeSwitcherVisualPosition;
  final bool forceCenteredThemeSwitcher;

  const PremiumScrollNavbar({
    super.key,
    required this.scrollController,
    required this.heroHeight,
    this.forceVisibleLight = false,
    this.onMenuTap,
    this.onSearchTap,
    this.onBrandTripleTap,
    this.isMenuOpen = false,
    this.menuProgress,
    this.hideChromeForOpenMenu = false,
    this.hideTrailingDestinations = false,
    this.themeSwitcherVisualPosition,
    this.forceCenteredThemeSwitcher = false,
  });

  @override
  State<PremiumScrollNavbar> createState() => _PremiumScrollNavbarState();
}

class _PremiumScrollNavbarState extends State<PremiumScrollNavbar> {
  final ScrollNavbarStateMachine _stateMachine = ScrollNavbarStateMachine();
  ScrollNavbarSnapshot _snapshot = ScrollNavbarSnapshot.initial;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleScroll);
    _snapshot = _stateMachine.update(
      offset: 0,
      heroHeight: widget.heroHeight,
      forceVisibleLight: widget.forceVisibleLight,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleScroll();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PremiumScrollNavbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleScroll);
      widget.scrollController.addListener(_handleScroll);
    }
    if (oldWidget.heroHeight != widget.heroHeight ||
        oldWidget.forceVisibleLight != widget.forceVisibleLight ||
        oldWidget.scrollController != widget.scrollController) {
      _syncSnapshot();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    if (!widget.scrollController.hasClients) {
      return;
    }
    _syncSnapshot();
  }

  void _syncSnapshot() {
    final positions = widget.scrollController.positions;
    final offset = positions.length == 1 ? positions.single.pixels : 0.0;
    final next = _stateMachine.update(
      offset: offset,
      heroHeight: widget.heroHeight,
      forceVisibleLight: widget.forceVisibleLight,
    );
    if (next == _snapshot) {
      return;
    }
    setState(() {
      _snapshot = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumNavbarSurface(
      snapshot: _snapshot,
      heroForegroundColor: Colors.white,
      onMenuTap: widget.onMenuTap,
      onSearchTap: widget.onSearchTap,
      onBrandTripleTap: widget.onBrandTripleTap,
      isMenuOpen: widget.isMenuOpen,
      menuProgress: widget.menuProgress,
      hideChromeForOpenMenu: widget.hideChromeForOpenMenu,
      hideTrailingDestinations: widget.hideTrailingDestinations,
      themeSwitcherVisualPosition: widget.themeSwitcherVisualPosition,
      forceCenteredThemeSwitcher: widget.forceCenteredThemeSwitcher,
    );
  }
}
