import 'storefront_theme.dart';

/// Bundle of chrome decisions that vary between storefront themes.
///
/// The storefront supports several apparences (Dior-like luxury editorial,
/// Nike-like sport/performance) on top of one shared engine: same CMS
/// models, repositories, routing, catalogue, cache. The bits that *do*
/// differ — does the page show a `PremiumScrollNavbar`? a
/// `FloatingBottomNav`? does content start below the status bar? — used
/// to be answered inline in `StorefrontLandingPage` with scattered
/// `effectiveTheme == StorefrontTheme.nike` checks. This profile pulls
/// those answers into one pure value so the landing page can read each
/// decision by name, and so the contract between themes is explicit and
/// testable.
///
/// Add a field here when a new chrome decision starts diverging between
/// themes; do **not** add fields for differences that already live in
/// `StorefrontThemeTokens` (visual tokens), in CMS section configs (e.g.
/// `nikeGrid3` layout), or in shared widgets that take their behaviour
/// from props.
class StorefrontChromeProfile {
  final StorefrontTheme theme;

  /// Renders `PremiumScrollNavbar` at the top of the landing page.
  final bool showPremiumTopNav;

  /// Renders `FloatingBottomNav` at the bottom of the landing page.
  final bool showFloatingBottomNav;

  /// The first section is laid out below the system status area.
  ///
  /// Themes that paint a full-bleed hero behind the navbar (Dior) leave
  /// this false so the hero can extend to the top of the viewport. Themes
  /// without a top nav (Nike) set it true so content does not collide
  /// with the status bar.
  final bool startsContentBelowStatusBar;

  /// The empty-homepage state offers a "seed this theme" admin hint.
  ///
  /// Used by themes that ship a curated seed payload (Nike). Themes that
  /// share the historical default homepage (Dior on `homepage`) do not
  /// surface the hint because no seed flow exists for them.
  final bool showEmptyStateSeedHint;

  const StorefrontChromeProfile({
    required this.theme,
    required this.showPremiumTopNav,
    required this.showFloatingBottomNav,
    required this.startsContentBelowStatusBar,
    required this.showEmptyStateSeedHint,
  });

  /// Dior-like: luxury editorial chrome. Premium top nav, full-bleed hero,
  /// no floating bottom nav, no seed-hint nudge.
  static const StorefrontChromeProfile dior = StorefrontChromeProfile(
    theme: StorefrontTheme.dior,
    showPremiumTopNav: true,
    showFloatingBottomNav: false,
    startsContentBelowStatusBar: false,
    showEmptyStateSeedHint: false,
  );

  /// Nike-like: sport/performance chrome. No top nav, floating bottom nav,
  /// content clears the status bar, empty state nudges admins to seed.
  static const StorefrontChromeProfile nike = StorefrontChromeProfile(
    theme: StorefrontTheme.nike,
    showPremiumTopNav: false,
    showFloatingBottomNav: true,
    startsContentBelowStatusBar: true,
    showEmptyStateSeedHint: true,
  );

  static StorefrontChromeProfile forTheme(StorefrontTheme theme) {
    return switch (theme) {
      StorefrontTheme.dior => dior,
      StorefrontTheme.nike => nike,
    };
  }
}
