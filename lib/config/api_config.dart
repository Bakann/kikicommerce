import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://kiki-commerce.pockethost.io',
  );

  // Backward-compatible alias for call sites or tests still importing baseUrl.
  static const String baseUrl = apiBaseUrl;

  /// Whether `--dart-define=MEDIA_BASE_URL=...` was provided at build time.
  /// Note: `bool.hasEnvironment` returns true even for an empty value, so
  /// this alone is not sufficient — [assertMediaConfigured] also checks
  /// that the value parses as an absolute URL.
  static const bool hasMediaBaseUrl = bool.hasEnvironment('MEDIA_BASE_URL');

  static const String mediaBaseUrl = String.fromEnvironment(
    'MEDIA_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  /// True when [mediaBaseUrl] was provided AND looks usable — non-empty
  /// after trim, with an explicit scheme and host. `--dart-define=MEDIA_BASE_URL=`
  /// or `--dart-define=MEDIA_BASE_URL=kikicommerce.com/img` both fail this
  /// check.
  static bool get isMediaBaseUrlUsable =>
      hasMediaBaseUrl && isMediaBaseUrlValueUsable(mediaBaseUrl);

  /// Pure predicate version of [isMediaBaseUrlUsable] — exposed so tests
  /// can exercise the URL-validation branches without resorting to a
  /// release build with `--dart-define=MEDIA_BASE_URL=...`. Returns true
  /// iff [rawValue] is a non-empty string that parses as an absolute URL.
  @visibleForTesting
  static bool isMediaBaseUrlValueUsable(String? rawValue) {
    if (rawValue == null) return false;
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  /// Whether `--dart-define=CT_CATALOG_PROXY_URL=...` was provided at build
  /// time. As with [hasMediaBaseUrl], this is true even for an empty value,
  /// so [isCtCatalogProxyUrlUsable] also validates the URL shape.
  static const bool hasCtCatalogProxyUrl = bool.hasEnvironment(
    'CT_CATALOG_PROXY_URL',
  );

  /// Public Cloudflare Worker URL for the experimental commercetools catalog
  /// lab page (`/lab/commercetools-products`). Never holds a secret — the
  /// commercetools credentials live in the Worker, not in Flutter.
  static const String ctCatalogProxyUrl = String.fromEnvironment(
    'CT_CATALOG_PROXY_URL',
  );

  /// True when [ctCatalogProxyUrl] was provided AND looks usable — non-empty
  /// after trim, with an explicit scheme and host.
  static bool get isCtCatalogProxyUrlUsable =>
      hasCtCatalogProxyUrl && isCtCatalogProxyUrlValueUsable(ctCatalogProxyUrl);

  /// Pure predicate version of [isCtCatalogProxyUrlUsable]. Public (unlike the
  /// test-only [isMediaBaseUrlValueUsable]) because the lab provider validates
  /// a runtime-overridable URL value, not just the compile-time const — see
  /// `commercetoolsListingItemsProvider`. Mirrors the same validation rules.
  static bool isCtCatalogProxyUrlValueUsable(String? rawValue) {
    if (rawValue == null) return false;
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    // Must be the Worker base URL only — the API client appends `/products`,
    // so a value already carrying a path (e.g. `.../products`) would double up.
    return uri.path.isEmpty || uri.path == '/';
  }

  /// Validates media configuration at startup. Call once from `main()`.
  ///
  /// In release builds, throws if `MEDIA_BASE_URL` was not provided, is
  /// empty, or doesn't look like an absolute URL — otherwise the
  /// storefront would silently serve images via PocketBase (or produce
  /// broken `/api/files/...` paths). In debug builds, only logs a warning.
  static void assertMediaConfigured({
    bool? isReleaseMode,
    bool? isMediaBaseUrlUsableOverride,
  }) {
    final isRelease = isReleaseMode ?? kReleaseMode;
    final hasMedia = isMediaBaseUrlUsableOverride ?? isMediaBaseUrlUsable;
    if (hasMedia) return;
    if (isRelease) {
      throw StateError(
        'MEDIA_BASE_URL is required in release builds and must be an '
        'absolute URL (scheme + host). '
        'Pass --dart-define=MEDIA_BASE_URL=https://<cdn-host>/<prefix> '
        'at build time. Without it the storefront serves images directly '
        'from PocketBase, bypassing the Cloudflare media proxy.',
      );
    }
    debugPrint(
      '[ApiConfig] WARNING: MEDIA_BASE_URL is missing or unusable; '
      'falling back to API_BASE_URL ($apiBaseUrl). Acceptable in '
      'development but MUST be set for production builds.',
    );
  }
}
