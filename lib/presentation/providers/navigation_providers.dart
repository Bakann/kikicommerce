import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../app/app_providers.dart';
import '../../app/cache_providers.dart';
import '../../application/navigation/drawer_navigation_models.dart';
import '../../core/cache/kiki_cache_keys.dart';
import '../../core/cache/kiki_cache_policies.dart';
import 'content_locale_provider.dart';
import 'edit_mode_provider.dart';

/// Side channel that lets a tapped `category_banner_strip` banner open the
/// category drawer already drilled into a specific node. The banner sets this
/// target and calls `Scaffold.openDrawer()`; whichever drawer mode builds next
/// (managed navigation or category fallback) reads it, drills in, and clears
/// it. It is also cleared when the drawer closes, so a later manual open lands
/// at the top level instead of re-drilling stale state.
class DrawerDrillTarget {
  /// Catalog category id — used by the category-fallback drawer.
  final String? categoryId;

  /// Managed-navigation root node id — used by the managed-navigation drawer.
  final String? nodeId;

  const DrawerDrillTarget({this.categoryId, this.nodeId});

  bool get isEmpty => categoryId == null && nodeId == null;
}

/// Pending drill target for the next drawer open. `null` means "open at the
/// top level" (the default behaviour). See [DrawerDrillTarget].
final pendingDrawerDrillTargetProvider = StateProvider<DrawerDrillTarget?>(
  (ref) => null,
);

/// Cache key for the drawer fetch. Item labels are now per-locale, so the key
/// carries the active content locale; currency stays a `global` placeholder and
/// the include-hidden axis is folded into the menu code suffix.
String drawerCacheKey({required String locale, required bool includeHidden}) {
  return KikiCacheKeys.drawer(
    locale: locale,
    currency: 'global',
    menuCode: includeHidden ? 'main_drawer:all' : 'main_drawer:visible',
  );
}

/// Predicate: cache only successful drawer loads. Any fallback (fetch error,
/// menu missing, menu inactive, tree invalid, …) represents a degraded state
/// we want to retry on the next fetch rather than freeze in cache for the
/// TTL window. The cost of an extra PocketBase call on a degraded fetch is
/// far smaller than the cost of showing a stuck fallback to a real user.
bool _shouldCacheDrawerResult(DrawerNavigationLoadResult result) {
  return result.fallbackReason == null;
}

/// FutureProvider for the main drawer navigation tree.
///
/// Note on TTL: this provider calls [Ref.keepAlive], so Riverpod retains the
/// last [DrawerNavigationLoadResult] for the lifetime of the provider. The
/// 10-minute SWR TTL on [KikiCachePolicies.drawer] therefore only fires
/// **when the provider is re-evaluated** — which happens on
/// [Ref.invalidateSelf], a [DrawerNavigationInvalidation] dispatched through
/// [CatalogInvalidator], or a change to [editModeProvider]. The drawer is
/// never refreshed by TTL alone in V1; refreshes are explicit.
final mainDrawerNavigationProvider = FutureProvider<DrawerNavigationLoadResult>((
  ref,
) {
  ref.keepAlive();
  // Watch the content locale so a language switch re-evaluates this
  // keepAlive provider (otherwise it would pin the previous language's tree).
  final locale = ref.watch(contentLocaleProvider);
  final includeHidden = ref.watch(editModeProvider);
  final reader = ref.watch(cachedRemoteReaderProvider);
  final repository = ref.watch(drawerNavigationRepositoryProvider);
  return reader.read<DrawerNavigationLoadResult>(
    key: drawerCacheKey(locale: locale, includeHidden: includeHidden),
    resourceType: 'drawer',
    policy: KikiCachePolicies.drawer,
    remoteLoader: () => repository.fetchMainDrawer(
      locale: locale,
      includeHidden: includeHidden,
    ),
    cachePredicate: _shouldCacheDrawerResult,
    // Riverpod's FutureProvider already serialises concurrent reads of the
    // same key, and an explicit refresh after a mutation must NOT be
    // coalesced with a stale in-flight request. Skip the cross-call dedup
    // layer for this provider.
    dedupe: false,
    // SWR contract: when the cache is stale, the reader returns the stale
    // value immediately and refreshes in background. Without this hook,
    // the UI would keep showing the stale value forever — Riverpod's
    // resolved AsyncValue does not auto-update from cache writes. Re-
    // entering the provider lands a fresh hit because the cache now
    // holds the new value, so no re-fetch occurs.
    //
    // Loop guard: only invalidate when the bg refresh produced a value
    // we actually cached. If it returned a fallback (which the predicate
    // skips), the cache still holds the stale entry and another
    // invalidate would just re-trigger SWR → bg refresh → onFreshData →
    // invalidate, ad infinitum.
    onFreshData: (result) {
      if (_shouldCacheDrawerResult(result)) {
        // Defer off the current build/flush: a warm-cache SWR refresh can
        // invoke this synchronously while a widget (e.g. StorefrontLandingPage)
        // is mid-build, and invalidating then throws "setState during build".
        Future.microtask(ref.invalidateSelf);
      }
    },
  );
});
