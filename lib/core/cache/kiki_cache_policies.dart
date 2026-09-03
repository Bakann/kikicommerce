import 'cache_policy.dart';
import 'cache_refresh_strategy.dart';

/// Default [CachePolicy] presets per Kiki Commerce resource family.
///
/// Transactional reads (cart, checkout, payment, order, final price/stock)
/// MUST use [transactional]; everything in this list is display-only and may
/// drift behind the server briefly.
class KikiCachePolicies {
  KikiCachePolicies._();

  static const drawer = CachePolicy(
    ttl: Duration(minutes: 10),
    strategy: CacheRefreshStrategy.staleWhileRevalidate,
  );

  static const homepage = CachePolicy(
    ttl: Duration(minutes: 5),
    strategy: CacheRefreshStrategy.staleWhileRevalidate,
  );

  static const plp = CachePolicy(
    ttl: Duration(minutes: 3),
    strategy: CacheRefreshStrategy.staleWhileRevalidate,
  );

  static const product = CachePolicy(
    ttl: Duration(minutes: 2),
    strategy: CacheRefreshStrategy.staleWhileRevalidate,
  );

  static const categories = CachePolicy(
    ttl: Duration(minutes: 15),
    strategy: CacheRefreshStrategy.staleWhileRevalidate,
  );

  static const mediaMetadata = CachePolicy(
    ttl: Duration(days: 7),
    strategy: CacheRefreshStrategy.cacheFirst,
  );

  /// PDP holo foil overlay (`product_foils`): decorative, edited from the
  /// Foil studio, so a short SWR window keeps edits visible quickly.
  static const productFoil = CachePolicy(
    ttl: Duration(minutes: 5),
    strategy: CacheRefreshStrategy.staleWhileRevalidate,
  );

  /// Read-only "always hit the server" policy for transactional reads
  /// (final price, real stock, cart/checkout/order/payment fetches).
  ///
  /// This policy is not a write contract: it disables the cache, but the
  /// surrounding reader still uses the deduplicator. Mutations must NOT go
  /// through [CachedRemoteReader] — call the repository write method
  /// directly. See the read-only contract on [CachedRemoteReader].
  static const transactional = CachePolicy(
    strategy: CacheRefreshStrategy.networkOnly,
  );
}
