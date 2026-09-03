import 'dart:async';

import 'cache_metrics_logger.dart';

/// Coalesces concurrent identical requests onto a single in-flight [Future].
///
/// Important: callers sharing a key are expected to provide an equivalent
/// [loader]. If two concurrent calls use the same key but different loaders,
/// the deduplicator will use the **first** loader received and the second
/// caller will receive the result of that first loader. Producing a different
/// key for a different expected response is the repository's responsibility.
///
/// Read-only contract: this is a deduplicator for **read-side** loaders.
/// Two writes sharing a key would silently coalesce — never use it for
/// mutations (cart, checkout, payment, order, admin writes).
///
/// Observability: every coalesced join (a "saved remote round-trip") is
/// reported via [CacheMetricsLogger.dedupeJoin]. Counting joins over a time
/// window is the simplest way to measure the runtime gain of the
/// deduplicator. The full lifecycle is:
///
/// - first caller for a key      → [CacheMetricsLogger.dedupeStart]
/// - subsequent concurrent calls → [CacheMetricsLogger.dedupeJoin]
/// - in-flight loader resolves   → [CacheMetricsLogger.dedupeComplete]
///   with measured latency
/// - in-flight loader fails      → [CacheMetricsLogger.dedupeError]
class RequestDeduplicator {
  RequestDeduplicator({
    CacheMetricsLogger? metricsLogger,
    DateTime Function()? now,
  }) : _metricsLogger = metricsLogger ?? const NoopCacheMetricsLogger(),
       _now = now ?? DateTime.now;

  final CacheMetricsLogger _metricsLogger;
  final DateTime Function() _now;
  final Map<String, Future<Object?>> _inFlight = <String, Future<Object?>>{};

  /// Runs [loader] under [key] with deduplication. Concurrent callers using
  /// the same [key] all await the same underlying future. Once that future
  /// completes (success **or** error), the slot is freed so the next caller
  /// can retry.
  Future<T> run<T>(
    String key,
    Future<T> Function() loader, {
    String? resourceType,
  }) async {
    final type = resourceType ?? _resourceTypeFor(key);
    final pending = _inFlight[key];
    if (pending != null) {
      _metricsLogger.dedupeJoin(type, key);
      return (await pending) as T;
    }

    _metricsLogger.dedupeStart(type, key);
    final start = _now();
    final future = loader();
    _inFlight[key] = future;
    try {
      final value = await future;
      _metricsLogger.dedupeComplete(type, key, _now().difference(start));
      return value;
    } catch (error, stackTrace) {
      _metricsLogger.dedupeError(type, key, error, stackTrace);
      rethrow;
    } finally {
      // Only remove the slot if it still points to this future. This guards
      // against a newer in-flight request that replaced it before cleanup.
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }
  }

  /// True when [key] currently has an in-flight request. Exposed for tests.
  bool isInFlight(String key) => _inFlight.containsKey(key);

  /// Removes the in-flight slot for [key]. Any already-running request keeps
  /// running and its current waiters still receive its result, but **new**
  /// callers using the same key will start a fresh request instead of
  /// joining the stale one. Use this after mutations so post-mutation reads
  /// don't dedupe onto a pre-mutation in-flight request.
  void invalidate(String key) {
    _inFlight.remove(key);
  }

  /// Same as [invalidate], but for every key starting with [prefix].
  void invalidateByPrefix(String prefix) {
    _inFlight.removeWhere((key, _) => key.startsWith(prefix));
  }

  String _resourceTypeFor(String key) {
    final colonIndex = key.indexOf(':');
    if (colonIndex <= 0) return 'unknown';
    return key.substring(0, colonIndex);
  }
}
