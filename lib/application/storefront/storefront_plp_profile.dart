import 'storefront_theme.dart';

/// Style of the overall PLP layout.
///
/// - [editorial]: the historical Dior layout — generous outer padding, wide
///   gutters between cards, a serif centered title, comfortable spacing.
/// - [sportPerformance]: a denser, more direct mobile-first layout — edge-to-
///   edge product grid, tight gutters, compact header, surfaced filter and
///   category controls.
enum PlpPresentation { editorial, sportPerformance }

/// Style of an individual product card on the PLP.
///
/// - [editorial]: centered name + price, no overlays on the image.
/// - [sportPerformance]: left-aligned bold name + price, optional favorite
///   shortcut overlaid on the image.
enum ProductCardPresentation { editorial, sportPerformance }

/// How filter controls are surfaced on the PLP.
///
/// - [inlineOrSubtle]: filter affordances stay inline with the page chrome
///   (or are not surfaced yet on this layout).
/// - [floatingAction]: a circular floating button is rendered above the
///   grid as a persistent shortcut. The action target is opt-in: the
///   profile only states "the affordance is wanted", not what it opens.
enum PlpFilterPresentation { inlineOrSubtle, floatingAction }

/// PLP-only variation profile.
///
/// Born from a real visual variation (the Nike-like sport PLP). Kept
/// intentionally narrow — each field maps to a concrete decision actually
/// read by the PLP today. Sibling profiles (PDP, cart, checkout) should be
/// introduced the same way: only when a real caller appears.
class StorefrontPlpProfile {
  final StorefrontTheme theme;
  final PlpPresentation presentation;
  final ProductCardPresentation productCardPresentation;
  final PlpFilterPresentation filterPresentation;

  /// When true, the public catalogue page renders the direct catalogue grid
  /// ([ProductListPage]) rather than a CMS-composed PLP (hero / editorial /
  /// SEO sections), even when a CMS PLP exists for the category.
  ///
  /// This is a *render-path* decision tied to the apparence, not a data
  /// migration: the CMS PLP records are untouched, and admins in edit mode
  /// still reach the CMS PLP to manage it. The sport apparence is
  /// catalogue-first (dense grid, no editorial sections), so it opts in;
  /// the luxury apparence keeps its CMS-curated PLPs.
  final bool prefersDirectCatalogGrid;

  const StorefrontPlpProfile({
    required this.theme,
    required this.presentation,
    required this.productCardPresentation,
    required this.filterPresentation,
    required this.prefersDirectCatalogGrid,
  });

  /// Dior-like / default: the historical PLP, unchanged.
  static const StorefrontPlpProfile dior = StorefrontPlpProfile(
    theme: StorefrontTheme.dior,
    presentation: PlpPresentation.editorial,
    productCardPresentation: ProductCardPresentation.editorial,
    filterPresentation: PlpFilterPresentation.inlineOrSubtle,
    prefersDirectCatalogGrid: false,
  );

  /// Nike-like / sport: denser, mobile-first, surfaced filter affordance,
  /// catalogue-first (bypasses CMS PLP composition in public read).
  static const StorefrontPlpProfile nike = StorefrontPlpProfile(
    theme: StorefrontTheme.nike,
    presentation: PlpPresentation.sportPerformance,
    productCardPresentation: ProductCardPresentation.sportPerformance,
    filterPresentation: PlpFilterPresentation.floatingAction,
    prefersDirectCatalogGrid: true,
  );

  static StorefrontPlpProfile forTheme(StorefrontTheme theme) {
    return switch (theme) {
      StorefrontTheme.dior => dior,
      StorefrontTheme.nike => nike,
    };
  }
}
