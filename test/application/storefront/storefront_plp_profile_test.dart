import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/storefront/storefront_plp_profile.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';

void main() {
  group('StorefrontPlpProfile.forTheme', () {
    test('Dior-like PLP profile is editorial across every dimension', () {
      final profile = StorefrontPlpProfile.forTheme(StorefrontTheme.dior);
      expect(profile.theme, StorefrontTheme.dior);
      expect(profile.presentation, PlpPresentation.editorial);
      expect(
        profile.productCardPresentation,
        ProductCardPresentation.editorial,
      );
      expect(profile.filterPresentation, PlpFilterPresentation.inlineOrSubtle);
    });

    test('Dior-like keeps CMS-composed PLPs (no direct catalogue grid)', () {
      final profile = StorefrontPlpProfile.forTheme(StorefrontTheme.dior);
      expect(profile.prefersDirectCatalogGrid, isFalse);
    });

    test('Nike-like PLP profile is sport/performance with floating filter', () {
      final profile = StorefrontPlpProfile.forTheme(StorefrontTheme.nike);
      expect(profile.theme, StorefrontTheme.nike);
      expect(profile.presentation, PlpPresentation.sportPerformance);
      expect(
        profile.productCardPresentation,
        ProductCardPresentation.sportPerformance,
      );
      expect(profile.filterPresentation, PlpFilterPresentation.floatingAction);
    });

    test(
      'Nike-like is catalogue-first (prefers the direct catalogue grid)',
      () {
        final profile = StorefrontPlpProfile.forTheme(StorefrontTheme.nike);
        expect(profile.prefersDirectCatalogGrid, isTrue);
      },
    );

    test('mapping is exhaustive over StorefrontTheme', () {
      for (final theme in StorefrontTheme.values) {
        final profile = StorefrontPlpProfile.forTheme(theme);
        expect(profile.theme, theme);
      }
    });
  });
}
