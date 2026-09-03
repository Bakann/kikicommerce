import 'package:flutter/material.dart';

import 'adaptive_bottom_nav.dart';
import 'floating_bottom_nav.dart';

/// Overlays the Sport [FloatingBottomNav] above [child] and reserves the
/// matching bottom inset so the child's scrollables clear the floating pill.
///
/// This factors out the `Stack` + MediaQuery-padding pattern that
/// `MainShell` applies to shell routes. Pages mounted **outside** the
/// `ShellRoute` (e.g. `/cart`) don't inherit `MainShell` chrome, so they use
/// this helper to render the Sport bottom nav consistently instead of
/// re-deriving the inset math locally.
///
/// The reserved space mirrors `MainShell._buildSportBody`: the original
/// bottom padding plus the overlay's own height and margin. The
/// [FloatingBottomNav] itself re-adds the safe-area inset internally, so the
/// pill and the reserved space line up exactly.
class SportBottomNavOverlay extends StatelessWidget {
  final Widget child;

  /// Forwarded to [FloatingBottomNav]: three rapid taps on Accueil reveal
  /// admin edit controls (the Sport theme has no top-nav entry point).
  final VoidCallback? onHomeTripleTap;

  const SportBottomNavOverlay({
    super.key,
    required this.child,
    this.onHomeTripleTap,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final reservedBottom =
        FloatingBottomNav.overlayHeight + FloatingBottomNav.overlayMargin;

    return AdaptiveBottomNav(
      onHomeTripleTap: onHomeTripleTap,
      child: MediaQuery(
        data: mediaQuery.copyWith(
          padding: mediaQuery.padding.copyWith(
            bottom: mediaQuery.padding.bottom + reservedBottom,
          ),
        ),
        child: child,
      ),
    );
  }
}
