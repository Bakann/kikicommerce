import 'cache_refresh_strategy.dart';

/// Describes how a cache entry should be loaded, refreshed and expired.
class CachePolicy {
  final Duration? ttl;
  final CacheRefreshStrategy strategy;

  const CachePolicy({this.ttl, required this.strategy});

  bool get allowsRead => strategy != CacheRefreshStrategy.networkOnly;

  bool get allowsWrite => strategy != CacheRefreshStrategy.networkOnly;

  /// Returns the absolute expiration timestamp for an entry written at [now],
  /// or null if the policy has no TTL (entries never expire by time alone).
  DateTime? expiresAt(DateTime now) {
    final ttlValue = ttl;
    if (ttlValue == null) return null;
    return now.add(ttlValue);
  }
}
