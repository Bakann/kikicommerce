import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/storefront/storefront_brand_settings.dart';

void main() {
  test(
    'fromJson falls back to default title and href when values are empty',
    () {
      final settings = StorefrontBrandSettings.fromJson({
        'id': 'settings-id',
        'brandTitle': ' ',
        'brandHref': '',
      });

      expect(settings.id, 'settings-id');
      expect(settings.title, defaultStorefrontBrandTitle);
      expect(settings.href, defaultStorefrontBrandHref);
      expect(settings.replaceMobileLogoWithThemeSwitcher, isFalse);
    },
  );

  test('fromJson reads mobile logo replacement flag', () {
    final settings = StorefrontBrandSettings.fromJson({
      'id': 'settings-id',
      'brandTitle': 'Atelier Kiki',
      'brandHref': '/',
      'replaceMobileLogoWithThemeSwitcher': true,
    });

    expect(settings.replaceMobileLogoWithThemeSwitcher, isTrue);
  });

  test('toPayload stores singleton key and normalized href', () {
    final settings = StorefrontBrandSettings(
      id: 'settings-id',
      title: ' Atelier Kiki ',
      href: ' ',
      replaceMobileLogoWithThemeSwitcher: true,
    );

    expect(settings.toPayload(), {
      'key': storefrontBrandSettingsKey,
      'brandTitle': 'Atelier Kiki',
      'brandHref': defaultStorefrontBrandHref,
      'replaceMobileLogoWithThemeSwitcher': true,
    });
  });
}
