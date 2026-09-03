import 'package:flutter/material.dart';

const storefrontActiveThemeKey = 'active_theme';

enum StorefrontTheme {
  dior('dior'),
  nike('nike');

  final String wireName;

  const StorefrontTheme(this.wireName);

  static const fallback = StorefrontTheme.dior;

  static StorefrontTheme? tryFromWireName(String? value) {
    final normalized = value?.trim().toLowerCase();
    for (final theme in StorefrontTheme.values) {
      if (theme.wireName == normalized) return theme;
    }
    return null;
  }

  static StorefrontTheme fromWireName(String? value) {
    final theme = tryFromWireName(value);
    if (theme != null) return theme;
    return fallback;
  }

  String get displayLabel => switch (this) {
    StorefrontTheme.dior => 'Luxe',
    StorefrontTheme.nike => 'Sport',
  };
}

/// CMS page code resolved from the active storefront theme.
///
/// Kept as a function (rather than baked into the enum) so we can evolve the
/// naming convention without touching consumers: the Dior theme currently
/// reuses the historical `homepage` code to avoid a risky rename. When the
/// Nike branch is fully stabilised, this can move to `homepage_dior` /
/// `homepage_nike` together.
String homepageCodeFor(StorefrontTheme theme) {
  switch (theme) {
    case StorefrontTheme.dior:
      return 'homepage';
    case StorefrontTheme.nike:
      return 'homepage_nike';
  }
}

class StorefrontActiveTheme {
  final String? id;
  final StorefrontTheme theme;

  const StorefrontActiveTheme({this.id, required this.theme});

  static const fallback = StorefrontActiveTheme(
    theme: StorefrontTheme.fallback,
  );

  factory StorefrontActiveTheme.fromJson(Map<String, dynamic> json) {
    return StorefrontActiveTheme(
      id: (json['id'] as String?)?.trim(),
      theme: StorefrontTheme.fromWireName(json['theme'] as String?),
    );
  }

  Map<String, dynamic> toPayload() {
    return {'key': storefrontActiveThemeKey, 'theme': theme.wireName};
  }
}

enum StorefrontNavChromeStyle { topScroll, bottomFloat }

/// Visual + structural tokens that change with the storefront theme.
///
/// These are intentionally a small set of values that downstream widgets can
/// opt into. The default ThemeData stays Material-driven; theming concerns
/// that don't fit a ThemeData (nav chrome style, section spacing) live here.
class StorefrontThemeTokens {
  final StorefrontTheme theme;
  final String fontFamily;
  final StorefrontNavChromeStyle navChrome;
  final double horizontalPadding;
  final double sectionSpacing;
  final double tileRadius;
  final TextStyle sectionTitleStyle;
  final Color scaffoldBackground;
  final Color emptyPlaceholderBackground;

  const StorefrontThemeTokens({
    required this.theme,
    required this.fontFamily,
    required this.navChrome,
    required this.horizontalPadding,
    required this.sectionSpacing,
    required this.tileRadius,
    required this.sectionTitleStyle,
    required this.scaffoldBackground,
    required this.emptyPlaceholderBackground,
  });

  static const StorefrontThemeTokens dior = StorefrontThemeTokens(
    theme: StorefrontTheme.dior,
    fontFamily: 'CormorantGaramond',
    navChrome: StorefrontNavChromeStyle.topScroll,
    horizontalPadding: 24,
    sectionSpacing: 48,
    tileRadius: 0,
    sectionTitleStyle: TextStyle(
      fontFamily: 'CormorantGaramond',
      fontSize: 28,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      color: Color(0xFF111111),
    ),
    scaffoldBackground: Color(0xFF000000),
    emptyPlaceholderBackground: Color(0xFF1B1B1B),
  );

  static const StorefrontThemeTokens nike = StorefrontThemeTokens(
    theme: StorefrontTheme.nike,
    fontFamily: 'Inter',
    navChrome: StorefrontNavChromeStyle.bottomFloat,
    horizontalPadding: 20,
    sectionSpacing: 32,
    tileRadius: 8,
    sectionTitleStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.1,
      color: Color(0xFF111111),
    ),
    scaffoldBackground: Color(0xFFFFFFFF),
    emptyPlaceholderBackground: Color(0xFFF7F6F2),
  );

  static StorefrontThemeTokens forTheme(StorefrontTheme theme) {
    return switch (theme) {
      StorefrontTheme.dior => dior,
      StorefrontTheme.nike => nike,
    };
  }
}
