import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/cache_providers.dart';
import '../../application/cms/cms_page_repository.dart';
import '../../application/storefront/storefront_sport_segment.dart';
import '../../application/storefront/storefront_theme.dart';
import '../../core/cache/cached_remote_reader.dart';
import '../../core/cache/kiki_cache_keys.dart';
import '../../core/cache/kiki_cache_policies.dart';
import 'content_locale_provider.dart';
import 'storefront_theme_providers.dart';

const String defaultCmsLocale = 'fr';

// CMS reads are currency-agnostic; pass a stable placeholder so the key shape
// matches the other cache keys. Locale is the real axis here.
const String _cmsPlaceholderCurrency = 'global';

class CmsPageRequest {
  final String code;
  final String locale;

  const CmsPageRequest({required this.code, required this.locale});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CmsPageRequest && other.code == code && other.locale == locale;

  @override
  int get hashCode => Object.hash(code, locale);
}

class CmsPlpRequest {
  final String categoryId;
  final String locale;

  const CmsPlpRequest({required this.categoryId, required this.locale});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CmsPlpRequest &&
          other.categoryId == categoryId &&
          other.locale == locale;

  @override
  int get hashCode => Object.hash(categoryId, locale);
}

/// CMS page read cached through [CachedRemoteReader] with the SWR `homepage`
/// policy. Without this, every navigation re-fetched `pages` + `page_sections`
/// from PocketBase; now repeat visits within the TTL are served from cache and
/// concurrent reads are deduplicated. Edits sweep the `cms:` prefix via
/// CmsPagesInvalidation, so cached content never outlives an admin change.
final cmsPageProvider = FutureProvider.family<CmsPageBundle?, CmsPageRequest>((
  ref,
  request,
) {
  final repository = ref.watch(cmsPageRepositoryProvider);
  final reader = ref.watch(cachedRemoteReaderProvider);
  return readCachedCmsPageBundle(
    repository: repository,
    reader: reader,
    request: request,
  );
});

Future<CmsPageBundle?> readCachedCmsPageBundle({
  required CmsPageRepository repository,
  required CachedRemoteReader reader,
  required CmsPageRequest request,
}) {
  return reader.read<CmsPageBundle?>(
    key: KikiCacheKeys.cmsPage(
      locale: request.locale,
      currency: _cmsPlaceholderCurrency,
      pageCode: request.code,
    ),
    resourceType: 'cms',
    policy: KikiCachePolicies.homepage,
    remoteLoader: () async {
      final result = _bundleOrNull(
        await repository.fetchPage(code: request.code, locale: request.locale),
      );
      if (result != null) return result;

      // Locale fallback: if a non-default locale is missing, try the default.
      if (request.locale != defaultCmsLocale) {
        return _bundleOrNull(
          await repository.fetchPage(
            code: request.code,
            locale: defaultCmsLocale,
          ),
        );
      }
      return null;
    },
  );
}

/// CMS PLP page read, cached like [cmsPageProvider] (shared `cms:` prefix).
final cmsPlpProvider = FutureProvider.family<CmsPageBundle?, CmsPlpRequest>((
  ref,
  request,
) {
  final repository = ref.watch(cmsPageRepositoryProvider);
  final reader = ref.watch(cachedRemoteReaderProvider);
  return reader.read<CmsPageBundle?>(
    key: KikiCacheKeys.cmsPlp(
      locale: request.locale,
      currency: _cmsPlaceholderCurrency,
      categoryId: request.categoryId,
    ),
    resourceType: 'cms',
    policy: KikiCachePolicies.homepage,
    remoteLoader: () async {
      final result = _bundleOrNull(
        await repository.fetchPlpForCategory(
          categoryId: request.categoryId,
          locale: request.locale,
        ),
      );
      if (result != null) return result;

      if (request.locale != defaultCmsLocale) {
        return _bundleOrNull(
          await repository.fetchPlpForCategory(
            categoryId: request.categoryId,
            locale: defaultCmsLocale,
          ),
        );
      }
      return null;
    },
  );
});

CmsPageBundle? _bundleOrNull(CmsPageLoadResult result) {
  switch (result) {
    case CmsPageFound(:final bundle):
      return bundle;
    case CmsPageMissing():
      return null;
    case CmsPageFailure(:final error, :final stackTrace):
      Error.throwWithStackTrace(error, stackTrace);
  }
}

class HomepageCmsResolution {
  final CmsPageBundle? bundle;
  final String requestedCode;
  final String? resolvedCode;
  final bool usedFallback;

  const HomepageCmsResolution({
    required this.bundle,
    required this.requestedCode,
    required this.resolvedCode,
    required this.usedFallback,
  });
}

class HomepageSegmentPrewarmStore {
  // Keyed by (locale, segment) so a language switch never serves a snapshot
  // prewarmed in the previous language — the landing then falls through to
  // homepageCmsForSegmentProvider, which fetches the active locale.
  final Map<
    ({String locale, StorefrontSportSegment segment}),
    HomepageCmsResolution
  >
  _resolutions = {};

  HomepageCmsResolution? read({
    required String locale,
    required StorefrontSportSegment segment,
  }) {
    return _resolutions[(locale: locale, segment: segment)];
  }

  void write({
    required String locale,
    required StorefrontSportSegment segment,
    required HomepageCmsResolution resolution,
  }) {
    _resolutions[(locale: locale, segment: segment)] = resolution;
  }
}

final homepageSegmentPrewarmStoreProvider =
    Provider<HomepageSegmentPrewarmStore>((ref) {
      return HomepageSegmentPrewarmStore();
    });

final homepageCmsForSegmentProvider =
    FutureProvider.family<HomepageCmsResolution, StorefrontSportSegment?>((
      ref,
      segment,
    ) async {
      final locale = ref.watch(contentLocaleProvider);
      final requestedCode = segment != null
          ? homepageCodeForSportSegment(segment)
          : homepageCodeFor(
              await ref.watch(resolvedStorefrontThemeProvider.future),
            );
      final requestedBundle = await ref.watch(
        cmsPageProvider(
          CmsPageRequest(code: requestedCode, locale: locale),
        ).future,
      );
      if (requestedBundle != null) {
        return HomepageCmsResolution(
          bundle: requestedBundle,
          requestedCode: requestedCode,
          resolvedCode: requestedCode,
          usedFallback: false,
        );
      }

      final fallbackSegment = segment?.homepageFallback;
      if (fallbackSegment == null) {
        return HomepageCmsResolution(
          bundle: null,
          requestedCode: requestedCode,
          resolvedCode: null,
          usedFallback: false,
        );
      }

      final fallbackCode = homepageCodeForSportSegment(fallbackSegment);
      final fallbackBundle = await ref.watch(
        cmsPageProvider(
          CmsPageRequest(code: fallbackCode, locale: locale),
        ).future,
      );
      return HomepageCmsResolution(
        bundle: fallbackBundle,
        requestedCode: requestedCode,
        resolvedCode: fallbackBundle == null ? null : fallbackCode,
        // Only "used" when the fallback actually resolved a page. If it is also
        // missing the page renders empty, and the edit-mode fallback hint must
        // not claim a fallback was applied.
        usedFallback: fallbackBundle != null,
      );
    });

final homepageCmsProvider = FutureProvider<CmsPageBundle?>((ref) async {
  final resolution = await ref.watch(
    homepageCmsForSegmentProvider(null).future,
  );
  return resolution.bundle;
});
