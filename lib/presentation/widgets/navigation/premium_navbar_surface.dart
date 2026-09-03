import 'package:flutter/material.dart';

import 'scroll_navbar_state_machine.dart';
import 'top_navigation_bar.dart';

class PremiumNavbarSurface extends StatelessWidget {
  static const surfaceKey = ValueKey('premium-scroll-navbar-surface');
  static const ignorePointerKey = ValueKey(
    'premium-scroll-navbar-ignore-pointer',
  );

  static const _duration = Duration(milliseconds: 240);
  static const _curve = Curves.easeOutCubic;
  static const _lightForeground = Color(0xFF202020);
  static const _transparentWhite = Color(0x00FFFFFF);
  static const _lightBackground = Color(0xF5FFFFFF);
  static const _lightBorder = Color(0x14000000);

  final ScrollNavbarSnapshot snapshot;
  final Color heroForegroundColor;
  final NavRevealTapCallback? onMenuTap;
  final NavRevealTapCallback? onSearchTap;
  final VoidCallback? onBrandTripleTap;
  final bool isMenuOpen;
  final Animation<double>? menuProgress;
  final bool hideChromeForOpenMenu;
  final bool hideTrailingDestinations;
  final Animation<double>? themeSwitcherVisualPosition;
  final bool forceCenteredThemeSwitcher;

  const PremiumNavbarSurface({
    super.key,
    required this.snapshot,
    this.heroForegroundColor = Colors.white,
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: menuProgress ?? kAlwaysDismissedAnimation,
      builder: (context, child) {
        final menuStyleProgress = (isMenuOpen ? 1.0 : menuProgress?.value ?? 0)
            .clamp(0.0, 1.0);
        final progress = snapshot.styleProgress > menuStyleProgress
            ? snapshot.styleProgress
            : menuStyleProgress;
        final foreground = Color.lerp(
          heroForegroundColor,
          _lightForeground,
          progress,
        )!;
        final background = Color.lerp(
          _transparentWhite,
          _lightBackground,
          progress,
        )!;
        final borderColor = Color.lerp(
          Colors.transparent,
          _lightBorder,
          progress,
        )!;
        final effectiveBorderColor = hideChromeForOpenMenu
            ? Colors.transparent
            : borderColor;
        final isVisible = snapshot.isVisible;

        return AnimatedSlide(
          duration: _duration,
          curve: _curve,
          offset: isVisible ? Offset.zero : const Offset(0, -0.16),
          child: AnimatedOpacity(
            duration: _duration,
            curve: _curve,
            opacity: isVisible ? 1 : 0,
            child: IgnorePointer(
              key: PremiumNavbarSurface.ignorePointerKey,
              ignoring: !isVisible,
              child: ExcludeSemantics(
                excluding: !isVisible,
                child: AnimatedContainer(
                  key: PremiumNavbarSurface.surfaceKey,
                  duration: _duration,
                  curve: _curve,
                  decoration: BoxDecoration(
                    color: background,
                    border: Border(
                      bottom: BorderSide(color: effectiveBorderColor),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: TopNavigationBar(
                      foregroundColor: foreground,
                      onMenuTap: onMenuTap,
                      onSearchTap: onSearchTap,
                      onBrandTripleTap: onBrandTripleTap,
                      isMenuOpen: isMenuOpen,
                      menuProgress: menuProgress,
                      hideChromeForOpenMenu: hideChromeForOpenMenu,
                      hideTrailingDestinations: hideTrailingDestinations,
                      themeSwitcherVisualPosition: themeSwitcherVisualPosition,
                      forceCenteredThemeSwitcher: forceCenteredThemeSwitcher,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
