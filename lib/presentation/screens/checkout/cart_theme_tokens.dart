import 'package:flutter/material.dart';

import '../../../application/storefront/storefront_theme.dart';

/// Visual tokens scoped to the **cart page only**.
///
/// Deliberately narrow: it carries just the values the cart views
/// ([LuxeCartView] / [SportCartView]) consume, so the Sport apparence can be
/// built without migrating the shared `checkout/*` design tokens (which are
/// still used by the downstream checkout funnel). When the funnel itself
/// gains a Sport apparence, promote a shared token layer then — not now.
///
/// Mirrors the established `forTheme` pattern used by `StorefrontThemeTokens`
/// and `StorefrontPlpProfile`.
class CartThemeTokens {
  final Color background;
  final Color primaryText;
  final Color secondaryText;
  final Color border;
  final Color primaryButtonBackground;
  final Color primaryButtonForeground;
  final double radius;

  /// Page / empty-state heading.
  final TextStyle titleStyle;

  /// Standard body copy (line item names, summary rows).
  final TextStyle bodyStyle;

  /// Muted secondary copy (subtitles, captions, prices secondary line).
  final TextStyle captionStyle;

  const CartThemeTokens({
    required this.background,
    required this.primaryText,
    required this.secondaryText,
    required this.border,
    required this.primaryButtonBackground,
    required this.primaryButtonForeground,
    required this.radius,
    required this.titleStyle,
    required this.bodyStyle,
    required this.captionStyle,
  });

  /// Dior-like: serif headings on a light-grey canvas. Mirrors the historical
  /// luxe `kCheckout*` values so a future luxe consumer matches pixel-for-pixel.
  static const CartThemeTokens dior = CartThemeTokens(
    background: Color(0xFFF8F8F8),
    primaryText: Color(0xFF2E3032),
    secondaryText: Color(0xFF7F858A),
    border: Color(0xFFE0E0E0),
    primaryButtonBackground: Color(0xFF343A40),
    primaryButtonForeground: Colors.white,
    radius: 4,
    titleStyle: TextStyle(
      fontFamily: 'CormorantGaramond',
      fontSize: 32,
      fontWeight: FontWeight.w500,
      color: Color(0xFF2E3032),
    ),
    bodyStyle: TextStyle(
      fontFamily: 'Montserrat',
      fontSize: 15,
      color: Color(0xFF2E3032),
    ),
    captionStyle: TextStyle(
      fontFamily: 'Montserrat',
      fontSize: 13.5,
      color: Color(0xFF7F858A),
    ),
  );

  /// Nike-like: bold Inter sans on a white canvas, rounded affordances, a
  /// black primary CTA. Matches the Sport apparence used across the app
  /// (`StorefrontThemeTokens.nike`, `FloatingBottomNav`).
  static const CartThemeTokens nike = CartThemeTokens(
    background: Colors.white,
    primaryText: Color(0xFF111111),
    secondaryText: Color(0xFF6B7177),
    border: Color(0xFFECECEC),
    primaryButtonBackground: Color(0xFF111111),
    primaryButtonForeground: Colors.white,
    radius: 14,
    titleStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.2,
      color: Color(0xFF111111),
    ),
    bodyStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: Color(0xFF111111),
    ),
    captionStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      color: Color(0xFF6B7177),
    ),
  );

  static CartThemeTokens forTheme(StorefrontTheme theme) {
    return switch (theme) {
      StorefrontTheme.nike => nike,
      StorefrontTheme.dior => dior,
    };
  }
}
