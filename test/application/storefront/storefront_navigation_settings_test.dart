import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/storefront/storefront_navigation_settings.dart';

void main() {
  test('fallback uses drawer', () {
    expect(
      StorefrontNavigationSettings.fallback.mobileMenuStyle,
      MobileMenuStyle.drawer,
    );
  });

  test('fromJson reads drawer', () {
    final settings = StorefrontNavigationSettings.fromJson({
      'id': 'navigation-id',
      'mobileMenuStyle': 'drawer',
    });

    expect(settings.id, 'navigation-id');
    expect(settings.mobileMenuStyle, MobileMenuStyle.drawer);
    expect(settings.hasCategorySplitDisplayMode, isFalse);
  });

  test('fromJson reads fullscreenReveal', () {
    final settings = StorefrontNavigationSettings.fromJson({
      'id': 'navigation-id',
      'mobileMenuStyle': 'fullscreenReveal',
    });

    expect(settings.mobileMenuStyle, MobileMenuStyle.fullscreenReveal);
  });

  test('fromJson falls back to drawer for unknown values', () {
    final settings = StorefrontNavigationSettings.fromJson({
      'id': 'navigation-id',
      'mobileMenuStyle': 'sideways',
    });

    expect(settings.mobileMenuStyle, MobileMenuStyle.drawer);
  });

  test('toPayload stores singleton key, style and split display mode', () {
    final settings = StorefrontNavigationSettings(
      id: 'navigation-id',
      mobileMenuStyle: MobileMenuStyle.fullscreenReveal,
      categorySplitDisplayMode: CategorySplitDisplayMode.expansible,
    );

    expect(settings.toPayload(), {
      'key': storefrontNavigationSettingsKey,
      'mobileMenuStyle': 'fullscreenReveal',
      'categorySplitDisplayMode': 'expansible',
    });
  });

  test('categorySplitDisplayMode defaults to tabs', () {
    expect(
      StorefrontNavigationSettings.fallback.categorySplitDisplayMode,
      CategorySplitDisplayMode.tabs,
    );
    expect(
      StorefrontNavigationSettings.fallback.hasCategorySplitDisplayMode,
      isFalse,
    );
    expect(
      StorefrontNavigationSettings.fromJson(const {}).categorySplitDisplayMode,
      CategorySplitDisplayMode.tabs,
    );
    expect(
      StorefrontNavigationSettings.fromJson(
        const {},
      ).hasCategorySplitDisplayMode,
      isFalse,
    );
  });

  test('fromJson reads + normalizes categorySplitDisplayMode', () {
    expect(
      StorefrontNavigationSettings.fromJson(const {
        'categorySplitDisplayMode': 'expansible',
      }).categorySplitDisplayMode,
      CategorySplitDisplayMode.expansible,
    );
    expect(
      StorefrontNavigationSettings.fromJson(const {
        'categorySplitDisplayMode': 'expansible',
      }).hasCategorySplitDisplayMode,
      isTrue,
    );
    expect(
      StorefrontNavigationSettings.fromJson(const {
        'categorySplitDisplayMode': 'weird',
      }).categorySplitDisplayMode,
      CategorySplitDisplayMode.tabs,
    );
    expect(
      StorefrontNavigationSettings.fromJson(const {
        'categorySplitDisplayMode': 'weird',
      }).hasCategorySplitDisplayMode,
      isFalse,
    );
  });
}
