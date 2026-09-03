import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/locale_route_resolver.dart';

void main() {
  group('resolveLocaleRoute', () {
    test('path locale wins over query locale', () {
      final resolution = resolveLocaleRoute(
        Uri.parse('/fr/search?q=x&lang=en'),
      );

      expect(resolution.pathLocale, const Locale('fr'));
      expect(resolution.queryLocale, isNull);
      expect(resolution.effectiveLocale, const Locale('fr'));
      expect(resolution.canonicalUri.toString(), '/fr/search?q=x');
      expect(resolution.shouldRedirect, isTrue);
    });

    test('locale query canonicalizes a public legacy URL', () {
      final resolution = resolveLocaleRoute(
        Uri.parse('/search?q=kiki&page=2&sort=price&lang=en'),
      );

      expect(resolution.queryLocale, const Locale('en'));
      expect(
        resolution.canonicalUri.toString(),
        '/en/search?q=kiki&page=2&sort=price',
      );
    });

    test('legacy public URLs default deterministically to French', () {
      expect(resolveLocaleRoute(Uri.parse('/')).canonicalUri.toString(), '/fr');
      expect(
        resolveLocaleRoute(
          Uri.parse('/catalog/accessoires'),
        ).canonicalUri.toString(),
        '/fr/catalog/accessoires',
      );
      expect(
        resolveLocaleRoute(
          Uri.parse('/product?productId=123'),
        ).canonicalUri.toString(),
        '/fr/product?productId=123',
      );
    });

    test('root honours the session locale over the French default', () {
      final resolution = resolveLocaleRoute(
        Uri.parse('/'),
        sessionLocale: 'en',
      );

      expect(resolution.effectiveLocale, const Locale('en'));
      expect(resolution.canonicalUri.toString(), '/en');
      expect(resolution.shouldRedirect, isTrue);
    });

    test('root honours the persisted locale over the French default', () {
      expect(
        resolveLocaleRoute(
          Uri.parse('/'),
          persistedLocale: 'en',
        ).canonicalUri.toString(),
        '/en',
      );
    });

    test('root without any preference still defaults to French', () {
      expect(resolveLocaleRoute(Uri.parse('/')).canonicalUri.toString(), '/fr');
    });

    test('non-root public routes ignore session and persisted locale', () {
      expect(
        resolveLocaleRoute(
          Uri.parse('/catalog/accessoires'),
          sessionLocale: 'en',
          persistedLocale: 'en',
        ).canonicalUri.toString(),
        '/fr/catalog/accessoires',
      );
      expect(
        resolveLocaleRoute(
          Uri.parse('/search?q=x'),
          persistedLocale: 'en',
        ).canonicalUri.toString(),
        '/fr/search?q=x',
      );
      expect(
        resolveLocaleRoute(
          Uri.parse('/product?productId=123'),
          persistedLocale: 'en',
        ).canonicalUri.toString(),
        '/fr/product?productId=123',
      );
    });

    test('explicit query locale on root wins over the session locale', () {
      expect(
        resolveLocaleRoute(
          Uri.parse('/?lang=en'),
          sessionLocale: 'fr',
        ).canonicalUri.toString(),
        '/en',
      );
    });

    test('trailing slashes are removed on public localized routes', () {
      expect(
        resolveLocaleRoute(Uri.parse('/en/catalog/')).canonicalUri.toString(),
        '/en/catalog',
      );
      expect(
        resolveLocaleRoute(Uri.parse('/en/')).canonicalUri.toString(),
        '/en',
      );
    });

    test('query-only locale on root redirects to localized root', () {
      expect(
        resolveLocaleRoute(Uri.parse('?lang=en')).canonicalUri.toString(),
        '/en',
      );
    });

    test('invalid and uppercase path locales are canonicalized', () {
      expect(
        resolveLocaleRoute(
          Uri.parse('/de/catalog/foo'),
        ).canonicalUri.toString(),
        '/fr/catalog/foo',
      );
      expect(
        resolveLocaleRoute(
          Uri.parse('/EN/catalog/foo'),
        ).canonicalUri.toString(),
        '/en/catalog/foo',
      );
    });

    test('prefixed neutral routes strip the locale from the canonical URL', () {
      final resolution = resolveLocaleRoute(Uri.parse('/en/cart'));

      expect(resolution.effectiveLocale, const Locale('en'));
      expect(resolution.isNeutralRoute, isTrue);
      expect(resolution.canonicalUri.toString(), '/cart');
    });

    test('neutral routes keep session locale without redirecting', () {
      final resolution = resolveLocaleRoute(
        Uri.parse('/cart'),
        sessionLocale: 'en',
      );

      expect(resolution.effectiveLocale, const Locale('en'));
      expect(resolution.canonicalUri.toString(), '/cart');
      expect(resolution.shouldRedirect, isFalse);
    });
  });

  group('localizedUriFor', () {
    test('switches public URLs and strips locale query params', () {
      expect(
        localizedUriFor(
          Uri.parse('/fr/search?q=x&locale=en'),
          locale: 'en',
        ).toString(),
        '/en/search?q=x',
      );
    });

    test('neutral URLs stay neutral', () {
      expect(
        localizedUriFor(
          Uri.parse('/fr/checkout/payment'),
          locale: 'en',
        ).toString(),
        '/checkout/payment',
      );
    });
  });
}
