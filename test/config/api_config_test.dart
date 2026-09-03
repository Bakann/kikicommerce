import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/config/api_config.dart';

void main() {
  group('ApiConfig.assertMediaConfigured', () {
    test('returns silently when MEDIA_BASE_URL is provided', () {
      expect(
        () => ApiConfig.assertMediaConfigured(
          isReleaseMode: true,
          isMediaBaseUrlUsableOverride: true,
        ),
        returnsNormally,
      );
    });

    test('throws StateError in release when MEDIA_BASE_URL is missing', () {
      expect(
        () => ApiConfig.assertMediaConfigured(
          isReleaseMode: true,
          isMediaBaseUrlUsableOverride: false,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('MEDIA_BASE_URL is required in release builds'),
          ),
        ),
      );
    });

    test('does not throw in debug when MEDIA_BASE_URL is missing', () {
      expect(
        () => ApiConfig.assertMediaConfigured(
          isReleaseMode: false,
          isMediaBaseUrlUsableOverride: false,
        ),
        returnsNormally,
      );
    });
  });

  group('ApiConfig.isMediaBaseUrlValueUsable', () {
    test('accepts absolute https URL', () {
      expect(
        ApiConfig.isMediaBaseUrlValueUsable('https://kikicommerce.com/img'),
        isTrue,
      );
    });

    test('accepts absolute http URL', () {
      expect(
        ApiConfig.isMediaBaseUrlValueUsable('http://localhost:8090'),
        isTrue,
      );
    });

    test('rejects null', () {
      expect(ApiConfig.isMediaBaseUrlValueUsable(null), isFalse);
    });

    test('rejects empty string (--dart-define=MEDIA_BASE_URL=)', () {
      expect(ApiConfig.isMediaBaseUrlValueUsable(''), isFalse);
    });

    test('rejects whitespace-only value', () {
      expect(ApiConfig.isMediaBaseUrlValueUsable('   '), isFalse);
    });

    test('rejects scheme-less URL', () {
      expect(
        ApiConfig.isMediaBaseUrlValueUsable('kikicommerce.com/img'),
        isFalse,
      );
    });

    test('rejects scheme-only URL with no host', () {
      expect(ApiConfig.isMediaBaseUrlValueUsable('https://'), isFalse);
    });
  });

  group('ApiConfig.isCtCatalogProxyUrlValueUsable', () {
    test('accepts absolute https worker URL', () {
      expect(
        ApiConfig.isCtCatalogProxyUrlValueUsable(
          'https://kiki-ct-catalog-proxy.herocospo.workers.dev',
        ),
        isTrue,
      );
    });

    test('rejects null', () {
      expect(ApiConfig.isCtCatalogProxyUrlValueUsable(null), isFalse);
    });

    test('rejects empty string (--dart-define=CT_CATALOG_PROXY_URL=)', () {
      expect(ApiConfig.isCtCatalogProxyUrlValueUsable(''), isFalse);
    });

    test('rejects scheme-less URL', () {
      expect(
        ApiConfig.isCtCatalogProxyUrlValueUsable(
          'kiki-ct-catalog-proxy.herocospo.workers.dev/products',
        ),
        isFalse,
      );
    });

    test('accepts base URL with a trailing slash', () {
      expect(
        ApiConfig.isCtCatalogProxyUrlValueUsable(
          'https://kiki-ct-catalog-proxy.herocospo.workers.dev/',
        ),
        isTrue,
      );
    });

    test('rejects a base URL that already carries a path', () {
      expect(
        ApiConfig.isCtCatalogProxyUrlValueUsable(
          'https://kiki-ct-catalog-proxy.herocospo.workers.dev/products',
        ),
        isFalse,
      );
    });
  });
}
