/// Refresh strategies supported by the Local Read Cache V1.
///
/// Strategies define how a cached value interacts with a remote loader:
///
/// - [cacheFirst]: serve fresh cache, otherwise hit the network and write back.
/// - [staleWhileRevalidate]: serve stale cache immediately and refresh in
///   background.
/// - [networkFirst]: try network first, fall back to cache on failure.
/// - [networkOnly]: bypass the cache entirely (used for transactional data
///   such as cart, checkout, payment, orders, final price/stock).
enum CacheRefreshStrategy {
  cacheFirst,
  staleWhileRevalidate,
  networkFirst,
  networkOnly,
}
