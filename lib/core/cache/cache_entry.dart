/// A typed entry stored in the local read cache.
///
/// [cachedAt] and [expiresAt] are computed by the cache implementation using
/// an injectable clock so tests stay deterministic.
class CacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  final DateTime? expiresAt;

  const CacheEntry({
    required this.data,
    required this.cachedAt,
    this.expiresAt,
  });

  /// Returns true when [expiresAt] is set and [now] is strictly after it.
  ///
  /// We accept [now] as a parameter (instead of reading [DateTime.now]) so
  /// callers can inject a clock and so tests remain deterministic.
  bool isExpired(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && now.isAfter(expiry);
  }
}
