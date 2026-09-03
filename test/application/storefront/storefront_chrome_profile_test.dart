import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/storefront/storefront_chrome_profile.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';

void main() {
  group('StorefrontChromeProfile.forTheme', () {
    test('Dior-like uses premium top nav and no floating bottom nav', () {
      final profile = StorefrontChromeProfile.forTheme(StorefrontTheme.dior);
      expect(profile.theme, StorefrontTheme.dior);
      expect(profile.showPremiumTopNav, isTrue);
      expect(profile.showFloatingBottomNav, isFalse);
    });

    test('Dior-like keeps the hero behind the nav (no status-bar inset)', () {
      final profile = StorefrontChromeProfile.forTheme(StorefrontTheme.dior);
      expect(profile.startsContentBelowStatusBar, isFalse);
    });

    test('Dior-like empty homepage does not surface the seed-hint nudge', () {
      final profile = StorefrontChromeProfile.forTheme(StorefrontTheme.dior);
      expect(profile.showEmptyStateSeedHint, isFalse);
    });

    test('Nike-like uses floating bottom nav and no premium top nav', () {
      final profile = StorefrontChromeProfile.forTheme(StorefrontTheme.nike);
      expect(profile.theme, StorefrontTheme.nike);
      expect(profile.showPremiumTopNav, isFalse);
      expect(profile.showFloatingBottomNav, isTrue);
    });

    test('Nike-like starts content below the status bar', () {
      final profile = StorefrontChromeProfile.forTheme(StorefrontTheme.nike);
      expect(profile.startsContentBelowStatusBar, isTrue);
    });

    test('Nike-like empty homepage surfaces the seed-hint nudge', () {
      final profile = StorefrontChromeProfile.forTheme(StorefrontTheme.nike);
      expect(profile.showEmptyStateSeedHint, isTrue);
    });

    test('the mapping is exhaustive over StorefrontTheme', () {
      for (final theme in StorefrontTheme.values) {
        final profile = StorefrontChromeProfile.forTheme(theme);
        expect(profile.theme, theme);
      }
    });
  });
}
