import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_providers.dart';
import '../../app/cache_providers.dart';
import '../../core/cache/kiki_cache_keys.dart';
import '../../core/cache/kiki_cache_policies.dart';
import '../../domain/catalog/catalog_entities.dart';
import 'content_locale_provider.dart';
import 'edit_mode_provider.dart';

// All four providers below cache through CachedRemoteReader with `dedupe`
// left at its default (true). For category reads the deduplicator brings a
// real win: a single page-load can fan-out to drawer + tree + slug + active
// providers, several of which may share an underlying request shape.
//
// `locale` is the resolved content locale (each language gets its own cache
// slot + the matching translated category names); `currency` is still a
// `'global'` placeholder — a separate axis, out of scope here.

const _placeholderCurrency = 'global';

/// Cache key for the drawer's category fallback list. Exposed so the
/// drawer preloader can warm the exact same slot that
/// [drawerCategoriesProvider] reads at open-time. The caller passes the active
/// content locale so the warmed slot matches the language being read.
String drawerCategoriesCacheKey({
  required String locale,
  required bool includeHidden,
}) {
  return KikiCacheKeys.drawerCategories(
    locale: locale,
    currency: _placeholderCurrency,
    includeHidden: includeHidden,
  );
}

final defaultCategoryProvider = FutureProvider<CatalogCategory?>((ref) {
  final locale = ref.watch(contentLocaleProvider);
  final reader = ref.watch(cachedRemoteReaderProvider);
  return reader.read<CatalogCategory?>(
    key: KikiCacheKeys.defaultCategory(
      locale: locale,
      currency: _placeholderCurrency,
    ),
    resourceType: 'defaultCategory',
    policy: KikiCachePolicies.categories,
    remoteLoader: () => ref.watch(getDefaultCategoryProvider)(locale: locale),
  );
});

final activeCategoriesProvider = FutureProvider<List<CatalogCategory>>((ref) {
  final locale = ref.watch(contentLocaleProvider);
  final reader = ref.watch(cachedRemoteReaderProvider);
  return reader.read<List<CatalogCategory>>(
    key: KikiCacheKeys.categories(
      locale: locale,
      currency: _placeholderCurrency,
    ),
    resourceType: 'categories',
    policy: KikiCachePolicies.categories,
    remoteLoader: () => ref.watch(getActiveCategoriesProvider)(locale: locale),
  );
});

final drawerCategoriesProvider = FutureProvider<List<CatalogCategory>>((ref) {
  final locale = ref.watch(contentLocaleProvider);
  final includeHidden = ref.watch(editModeProvider);
  final reader = ref.watch(cachedRemoteReaderProvider);
  return reader.read<List<CatalogCategory>>(
    key: drawerCategoriesCacheKey(locale: locale, includeHidden: includeHidden),
    resourceType: 'drawerCategories',
    policy: KikiCachePolicies.categories,
    remoteLoader: () => ref.watch(getActiveCategoriesProvider)(
      locale: locale,
      includeHidden: includeHidden,
    ),
  );
});

final categoryBySlugProvider = FutureProvider.family<CatalogCategory?, String>((
  ref,
  slug,
) {
  final locale = ref.watch(contentLocaleProvider);
  final reader = ref.watch(cachedRemoteReaderProvider);
  return reader.read<CatalogCategory?>(
    key: KikiCacheKeys.categoryBySlug(
      locale: locale,
      currency: _placeholderCurrency,
      slug: slug,
    ),
    resourceType: 'categoryBySlug',
    policy: KikiCachePolicies.categories,
    remoteLoader: () =>
        ref.watch(getCategoryBySlugProvider)(slug, locale: locale),
  );
});
