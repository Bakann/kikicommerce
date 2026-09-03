import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/cache_providers.dart';
import '../../application/catalog/catalog_invalidations.dart';
import '../../application/navigation/drawer_navigation_models.dart';
import '../../core/cache/kiki_cache_keys.dart';
import '../../core/cache/local_read_cache.dart';
import '../../core/cache/request_deduplicator.dart';
import 'category_providers.dart';
import 'cms_mixed_grid_products_provider.dart';
import 'cms_page_provider.dart';
import 'featured_products_provider.dart';
import 'locale_provider.dart';
import 'media_library_provider.dart';
import 'navigation_providers.dart';
import 'product_foil_provider.dart';
import 'product_providers.dart';
import 'search_providers.dart';

const _categoryCachePrefixes = <String>[
  'categories:',
  'drawerCategories:',
  'defaultCategory:',
  'categoryBySlug:',
];

const _categoryPlaceholderCurrency = 'global';

// A catalog mutation affects every language's cached copy. Cache keys embed the
// content locale, so a single 'global' key no longer matches the locale-keyed
// reads — specific-key invalidations clear the key for each supported locale.
final List<String> _contentLocaleCodes = [
  for (final locale in kSupportedLocales) locale.languageCode,
];

void _invalidateCategoryTreeCache(
  LocalReadCache cache,
  RequestDeduplicator dedup,
) {
  for (final prefix in _categoryCachePrefixes) {
    unawaited(cache.invalidateByPrefix(prefix));
    dedup.invalidateByPrefix(prefix);
  }
}

void _invalidateCategoryBySlugCache(
  LocalReadCache cache,
  RequestDeduplicator dedup,
  String slug,
) {
  for (final locale in _contentLocaleCodes) {
    final key = KikiCacheKeys.categoryBySlug(
      locale: locale,
      currency: _categoryPlaceholderCurrency,
      slug: slug,
    );
    unawaited(cache.invalidate(key));
    dedup.invalidate(key);
  }
}

void _invalidatePlpCache(
  LocalReadCache cache,
  RequestDeduplicator dedup,
  String categoryId,
) {
  for (final locale in _contentLocaleCodes) {
    final key = KikiCacheKeys.plp(
      locale: locale,
      currency: _categoryPlaceholderCurrency,
      categorySlug: categoryId,
    );
    unawaited(cache.invalidate(key));
    dedup.invalidate(key);
  }
}

void _invalidateAllPlpCache(LocalReadCache cache, RequestDeduplicator dedup) {
  unawaited(cache.invalidateByPrefix('plp:'));
  dedup.invalidateByPrefix('plp:');
}

void _invalidateProductCache(
  LocalReadCache cache,
  RequestDeduplicator dedup,
  String productId,
) {
  for (final locale in _contentLocaleCodes) {
    final key = KikiCacheKeys.product(
      locale: locale,
      currency: _categoryPlaceholderCurrency,
      productId: productId,
    );
    unawaited(cache.invalidate(key));
    dedup.invalidate(key);
  }
  final foilKey = KikiCacheKeys.productFoil(productId: productId);
  unawaited(cache.invalidate(foilKey));
  dedup.invalidate(foilKey);
}

void _invalidateAllProductCache(
  LocalReadCache cache,
  RequestDeduplicator dedup,
) {
  unawaited(cache.invalidateByPrefix('product:'));
  dedup.invalidateByPrefix('product:');
  unawaited(cache.invalidateByPrefix('productFoil:'));
  dedup.invalidateByPrefix('productFoil:');
}

// Prefix must match the cache key built in featured_products_provider.dart
// ('featuredProducts:locale=...|currency=...|ids=...'). Changing *which* ids
// a section features already self-heals (the id list is part of the key); this
// sweep handles the other case — a featured product's data (price/text/media)
// changing while the id list stays the same.
void _invalidateFeaturedProductsCache(
  LocalReadCache cache,
  RequestDeduplicator dedup,
) {
  unawaited(cache.invalidateByPrefix('featuredProducts:'));
  dedup.invalidateByPrefix('featuredProducts:');
}

// CMS page and PLP reads share the 'cms:' key prefix (see KikiCacheKeys.cmsPage
// / cmsPlp), so one sweep clears every CMS read.
void _invalidateCmsPagesCache(LocalReadCache cache, RequestDeduplicator dedup) {
  unawaited(cache.invalidateByPrefix('cms:'));
  dedup.invalidateByPrefix('cms:');
}

class CatalogInvalidator {
  const CatalogInvalidator();

  void apply(Ref ref, Iterable<CatalogInvalidationTarget> targets) {
    final sink = _RefCatalogInvalidationSink(ref);
    for (final target in targets) {
      _invalidate(sink, target);
    }
  }

  void applyFromWidget(
    WidgetRef ref,
    Iterable<CatalogInvalidationTarget> targets,
  ) {
    final sink = _WidgetRefCatalogInvalidationSink(ref);
    for (final target in targets) {
      _invalidate(sink, target);
    }
  }

  void applyToContainer(
    ProviderContainer container,
    Iterable<CatalogInvalidationTarget> targets,
  ) {
    final sink = _ContainerCatalogInvalidationSink(container);
    for (final target in targets) {
      _invalidate(sink, target);
    }
  }

  void _invalidate(
    _CatalogInvalidationSink sink,
    CatalogInvalidationTarget target,
  ) {
    switch (target) {
      case ProductDetailInvalidation(:final productId):
        _invalidateProductCache(sink.cache, sink.dedup, productId);
        sink.invalidatePdp(productId);
      case CategoryPlpInvalidation(:final categoryId):
        _invalidatePlpCache(sink.cache, sink.dedup, categoryId);
        sink.invalidatePlp(categoryId);
        sink.invalidateCmsMixedGridProducts();
      case CategoryBySlugInvalidation(:final slug):
        _invalidateCategoryBySlugCache(sink.cache, sink.dedup, slug);
        sink.invalidateCategoryBySlug(slug);
      case CategoryTreeInvalidation():
        _invalidateCategoryTreeCache(sink.cache, sink.dedup);
        sink.invalidateCategoryTreeProviders();
      case AllProductListsInvalidation():
        _invalidateAllPlpCache(sink.cache, sink.dedup);
        sink.invalidateAllPlp();
        sink.invalidateCmsMixedGridProducts();
        _invalidateFeaturedProductsCache(sink.cache, sink.dedup);
        sink.invalidateFeaturedProducts();
      case AllProductDetailsInvalidation():
        _invalidateAllProductCache(sink.cache, sink.dedup);
        sink.invalidateAllPdp();
        _invalidateFeaturedProductsCache(sink.cache, sink.dedup);
        sink.invalidateFeaturedProducts();
      case AllProductRoutesInvalidation():
        sink.invalidateProductRoutes();
      case AllSearchResultsInvalidation():
        sink.invalidateSearchResults();
      case DrawerNavigationInvalidation():
        // Clear the cache AND drop any in-flight dedup slot BEFORE
        // invalidating Riverpod: a synchronous listener notification could
        // otherwise trigger a rebuild that re-reads the cache or joins the
        // stale in-flight request before the sweeps run.
        unawaited(sink.cache.invalidateByPrefix('drawer:'));
        sink.dedup.invalidateByPrefix('drawer:');
        // refresh (not invalidate) forces an immediate re-evaluation, so
        // back-to-back invalidations from a "save then safety-net retry"
        // flow each produce their own fetch instead of being coalesced.
        unawaited(sink.refreshMainDrawerNavigation());
      case MediaLibraryInvalidation():
        sink.invalidateMediaLibrary();
      case CmsPagesInvalidation():
        _invalidateCmsPagesCache(sink.cache, sink.dedup);
        sink.invalidateCmsPages();
      case CatalogInvalidationTarget():
        break;
    }
  }
}

abstract interface class _CatalogInvalidationSink {
  LocalReadCache get cache;
  RequestDeduplicator get dedup;

  void invalidatePdp(String productId);
  void invalidateAllPdp();
  void invalidatePlp(String categoryId);
  void invalidateAllPlp();
  void invalidateCmsMixedGridProducts();
  void invalidateFeaturedProducts();
  void invalidateCategoryBySlug(String slug);
  void invalidateCategoryTreeProviders();
  void invalidateProductRoutes();
  void invalidateSearchResults();
  void invalidateMediaLibrary();
  void invalidateCmsPages();
  Future<DrawerNavigationLoadResult> refreshMainDrawerNavigation();
}

class _RefCatalogInvalidationSink implements _CatalogInvalidationSink {
  final Ref _ref;

  const _RefCatalogInvalidationSink(this._ref);

  @override
  LocalReadCache get cache => _ref.read(localReadCacheProvider);

  @override
  RequestDeduplicator get dedup => _ref.read(requestDeduplicatorProvider);

  @override
  void invalidatePdp(String productId) {
    _ref.invalidate(pdpProvider(productId));
    _ref.invalidate(productFoilProvider(productId));
  }

  @override
  void invalidateAllPdp() {
    _ref.invalidate(pdpProvider);
    _ref.invalidate(productFoilProvider);
  }

  @override
  void invalidatePlp(String categoryId) =>
      _ref.invalidate(plpProvider(categoryId));

  @override
  void invalidateAllPlp() => _ref.invalidate(plpProvider);

  @override
  void invalidateCmsMixedGridProducts() =>
      _ref.invalidate(cmsMixedGridProductsProvider);

  @override
  void invalidateFeaturedProducts() =>
      _ref.invalidate(featuredProductsProvider);

  @override
  void invalidateCategoryBySlug(String slug) =>
      _ref.invalidate(categoryBySlugProvider(slug));

  @override
  void invalidateCategoryTreeProviders() {
    _ref.invalidate(activeCategoriesProvider);
    _ref.invalidate(drawerCategoriesProvider);
    _ref.invalidate(defaultCategoryProvider);
    _ref.invalidate(categoryBySlugProvider);
  }

  @override
  void invalidateProductRoutes() => _ref.invalidate(productRouteProvider);

  @override
  void invalidateSearchResults() => _ref.invalidate(searchResultsProvider);

  @override
  void invalidateMediaLibrary() => _ref.invalidate(mediaLibraryProvider);

  @override
  void invalidateCmsPages() {
    _ref.invalidate(homepageCmsProvider);
    _ref.invalidate(homepageCmsForSegmentProvider);
    _ref.invalidate(cmsPageProvider);
    _ref.invalidate(cmsPlpProvider);
  }

  @override
  Future<DrawerNavigationLoadResult> refreshMainDrawerNavigation() {
    return _ref.refresh(mainDrawerNavigationProvider.future);
  }
}

class _WidgetRefCatalogInvalidationSink implements _CatalogInvalidationSink {
  final WidgetRef _ref;

  const _WidgetRefCatalogInvalidationSink(this._ref);

  @override
  LocalReadCache get cache => _ref.read(localReadCacheProvider);

  @override
  RequestDeduplicator get dedup => _ref.read(requestDeduplicatorProvider);

  @override
  void invalidatePdp(String productId) {
    _ref.invalidate(pdpProvider(productId));
    _ref.invalidate(productFoilProvider(productId));
  }

  @override
  void invalidateAllPdp() {
    _ref.invalidate(pdpProvider);
    _ref.invalidate(productFoilProvider);
  }

  @override
  void invalidatePlp(String categoryId) =>
      _ref.invalidate(plpProvider(categoryId));

  @override
  void invalidateAllPlp() => _ref.invalidate(plpProvider);

  @override
  void invalidateCmsMixedGridProducts() =>
      _ref.invalidate(cmsMixedGridProductsProvider);

  @override
  void invalidateFeaturedProducts() =>
      _ref.invalidate(featuredProductsProvider);

  @override
  void invalidateCategoryBySlug(String slug) =>
      _ref.invalidate(categoryBySlugProvider(slug));

  @override
  void invalidateCategoryTreeProviders() {
    _ref.invalidate(activeCategoriesProvider);
    _ref.invalidate(drawerCategoriesProvider);
    _ref.invalidate(defaultCategoryProvider);
    _ref.invalidate(categoryBySlugProvider);
  }

  @override
  void invalidateProductRoutes() => _ref.invalidate(productRouteProvider);

  @override
  void invalidateSearchResults() => _ref.invalidate(searchResultsProvider);

  @override
  void invalidateMediaLibrary() => _ref.invalidate(mediaLibraryProvider);

  @override
  void invalidateCmsPages() {
    _ref.invalidate(homepageCmsProvider);
    _ref.invalidate(homepageCmsForSegmentProvider);
    _ref.invalidate(cmsPageProvider);
    _ref.invalidate(cmsPlpProvider);
  }

  @override
  Future<DrawerNavigationLoadResult> refreshMainDrawerNavigation() {
    return _ref.refresh(mainDrawerNavigationProvider.future);
  }
}

class _ContainerCatalogInvalidationSink implements _CatalogInvalidationSink {
  final ProviderContainer _container;

  const _ContainerCatalogInvalidationSink(this._container);

  @override
  LocalReadCache get cache => _container.read(localReadCacheProvider);

  @override
  RequestDeduplicator get dedup => _container.read(requestDeduplicatorProvider);

  @override
  void invalidatePdp(String productId) {
    _container.invalidate(pdpProvider(productId));
    _container.invalidate(productFoilProvider(productId));
  }

  @override
  void invalidateAllPdp() {
    _container.invalidate(pdpProvider);
    _container.invalidate(productFoilProvider);
  }

  @override
  void invalidatePlp(String categoryId) =>
      _container.invalidate(plpProvider(categoryId));

  @override
  void invalidateAllPlp() => _container.invalidate(plpProvider);

  @override
  void invalidateCmsMixedGridProducts() =>
      _container.invalidate(cmsMixedGridProductsProvider);

  @override
  void invalidateFeaturedProducts() =>
      _container.invalidate(featuredProductsProvider);

  @override
  void invalidateCategoryBySlug(String slug) =>
      _container.invalidate(categoryBySlugProvider(slug));

  @override
  void invalidateCategoryTreeProviders() {
    _container.invalidate(activeCategoriesProvider);
    _container.invalidate(drawerCategoriesProvider);
    _container.invalidate(defaultCategoryProvider);
    _container.invalidate(categoryBySlugProvider);
  }

  @override
  void invalidateProductRoutes() => _container.invalidate(productRouteProvider);

  @override
  void invalidateSearchResults() =>
      _container.invalidate(searchResultsProvider);

  @override
  void invalidateMediaLibrary() => _container.invalidate(mediaLibraryProvider);

  @override
  void invalidateCmsPages() {
    _container.invalidate(homepageCmsProvider);
    _container.invalidate(homepageCmsForSegmentProvider);
    _container.invalidate(cmsPageProvider);
    _container.invalidate(cmsPlpProvider);
  }

  @override
  Future<DrawerNavigationLoadResult> refreshMainDrawerNavigation() {
    return _container.refresh(mainDrawerNavigationProvider.future);
  }
}

final catalogInvalidatorProvider = Provider<CatalogInvalidator>((ref) {
  return const CatalogInvalidator();
});
