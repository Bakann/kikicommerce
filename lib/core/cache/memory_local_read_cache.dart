import 'dart:collection';

import 'cache_entry.dart';
import 'cache_metrics_logger.dart';
import 'cache_policy.dart';
import 'local_read_cache.dart';

/// In-memory implementation of [LocalReadCache] with manual LRU eviction.
///
/// We deliberately do not use `LinkedHashMap(accessOrder: true)` because that
/// constructor does not exist in Dart. Instead we rely on the insertion-order
/// guarantee of [LinkedHashMap] and simulate LRU by removing + re-inserting
/// keys on access:
///
/// - `get(key)` removes the entry and re-inserts it (becomes most-recent).
/// - `put(key, value)` removes any prior entry then inserts (becomes
///   most-recent).
/// - Eviction picks the least-recent key, which is `_cache.keys.first`.
class MemoryLocalReadCache implements LocalReadCache {
  MemoryLocalReadCache({
    this.maxEntries = 300,
    DateTime Function()? now,
    CacheMetricsLogger? metricsLogger,
  }) : assert(maxEntries > 0, 'maxEntries must be > 0'),
       _now = now ?? DateTime.now,
       _metricsLogger = metricsLogger ?? const NoopCacheMetricsLogger();

  final int maxEntries;
  final DateTime Function() _now;
  final CacheMetricsLogger _metricsLogger;

  final LinkedHashMap<String, CacheEntry<Object?>> _cache =
      LinkedHashMap<String, CacheEntry<Object?>>();

  // Invalidation counters. A key's effective [generation] sums three sources
  // so that a loader which captured a generation before an invalidation can
  // never write back, even when the key was not yet in [_cache] at
  // invalidation time (cold-miss read in flight):
  //   - [_globalGeneration]: bumped by clear(), affects every key.
  //   - [_prefixGenerations]: bumped by invalidateByPrefix(), affects every
  //     key sharing the prefix — including keys absent from [_cache].
  //   - [_keyGenerations]: bumped by invalidate(), affects one exact key.
  int _globalGeneration = 0;
  final Map<String, int> _prefixGenerations = <String, int>{};
  final Map<String, int> _keyGenerations = <String, int>{};

  @override
  Future<CacheEntry<T>?> get<T>(String key) async {
    final existing = _cache.remove(key);
    if (existing == null) return null;

    if (existing.isExpired(_now())) {
      // Lazy cleanup: drop expired entries on read and report a miss.
      return null;
    }

    // Re-insert to mark as most-recently-used.
    _cache[key] = existing;
    return existing as CacheEntry<T>;
  }

  @override
  Future<CacheEntry<T>?> peek<T>(String key) async {
    final existing = _cache[key];
    if (existing == null) return null;
    return existing as CacheEntry<T>;
  }

  @override
  Future<void> touch(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _cache[key] = entry;
    }
    return Future.value();
  }

  @override
  int generation(String key) {
    var generation = _globalGeneration + (_keyGenerations[key] ?? 0);
    for (final entry in _prefixGenerations.entries) {
      if (key.startsWith(entry.key)) {
        generation += entry.value;
      }
    }
    return generation;
  }

  @override
  Future<void> put<T>(
    String key,
    T value,
    CachePolicy policy, {
    int? expectedGeneration,
  }) async {
    if (!policy.allowsWrite) return;

    // The entry was invalidated after the loader captured its generation:
    // discard this now-stale write instead of resurrecting the key.
    if (expectedGeneration != null && generation(key) != expectedGeneration) {
      return;
    }

    final currentTime = _now();
    final entry = CacheEntry<T>(
      data: value,
      cachedAt: currentTime,
      expiresAt: policy.expiresAt(currentTime),
    );

    // 1. Remove the existing entry (if any) so the re-insert lands at the
    //    most-recent position.
    _cache.remove(key);

    // 2. Cleanup expired entries before considering eviction. This protects
    //    legitimately recent entries from being dropped while the map is full
    //    of stale ones.
    _evictExpired(currentTime);

    // 3. Insert the new entry as most-recent.
    _cache[key] = entry;

    // 4. If still over capacity, evict the least-recently-used entries.
    while (_cache.length > maxEntries) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
      _metricsLogger.eviction(_resourceTypeFor(oldestKey), oldestKey);
    }
  }

  @override
  Future<void> invalidate(String key) {
    // No async modifier on side-effect methods: callers (Riverpod
    // invalidation paths) need the work to be visible *synchronously* before
    // a subsequent provider re-evaluation. The returned future is already
    // resolved.
    _keyGenerations[key] = (_keyGenerations[key] ?? 0) + 1;
    _cache.remove(key);
    return Future.value();
  }

  @override
  Future<void> invalidateByPrefix(String prefix) {
    // Bump the prefix generation rather than per-key, so a cold-miss read for
    // a key matching this prefix that is still in flight (and therefore not
    // yet in _cache) is also discarded when its put() lands.
    _prefixGenerations[prefix] = (_prefixGenerations[prefix] ?? 0) + 1;
    _cache.removeWhere((key, _) => key.startsWith(prefix));
    return Future.value();
  }

  @override
  Future<void> clear() {
    _globalGeneration += 1;
    _cache.clear();
    return Future.value();
  }

  /// Test/observability helper: current number of entries (including ones
  /// that may be expired but not yet cleaned up).
  int get debugLength => _cache.length;

  void _evictExpired(DateTime now) {
    _cache.removeWhere((_, entry) => entry.isExpired(now));
  }

  /// Best-effort resource type extraction from a cache key. Keys are produced
  /// by [KikiCacheKeys] in the form `<resourceType>:<rest>`; if no prefix is
  /// found we fall back to `unknown` so metrics still receive a label.
  String _resourceTypeFor(String key) {
    final colonIndex = key.indexOf(':');
    if (colonIndex <= 0) return 'unknown';
    return key.substring(0, colonIndex);
  }
}
