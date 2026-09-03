import 'package:flutter/foundation.dart';

import 'cache_metrics_logger.dart';
import 'cache_metrics_snapshot.dart';

/// Decorator that counts every event going through a [CacheMetricsLogger]
/// and exposes the totals as a [CacheMetricsSnapshot].
///
/// Wrap your real logger (typically [ConsoleCacheMetricsLogger] in dev,
/// [NoopCacheMetricsLogger] in release) so the aggregation runs alongside
/// the per-event sink without changing any cache logic.
///
/// Read-only contract: this is a passive observer. It never throws and
/// never mutates anything other than its own counters.
///
/// Concurrency model (Dart single-isolate):
/// - Counters are updated synchronously on the Dart event loop.
/// - The logger does not `await` inside event handlers, so individual
///   increments cannot be interleaved within the same isolate.
/// - Snapshots remain best-effort because they can be taken **between**
///   two events; the snapshot is consistent at the moment it is built
///   but the underlying counters keep moving immediately afterwards.
/// - This is suitable for dev telemetry, not for correctness-critical
///   logic. We deliberately avoid pulling in a `synchronized` package or
///   a Mutex — the dev-only use case does not warrant the overhead.
///
/// Memory: counters grow as new resource types appear. There is no
/// fixed-size or time-window eviction in V1; call [reset] manually (e.g.
/// at app foreground or on user action) when you want a fresh window.
class AggregateCacheMetricsLogger implements CacheMetricsLogger {
  AggregateCacheMetricsLogger({
    CacheMetricsLogger? delegate,
    DateTime Function()? now,
  }) : _delegate = delegate ?? const NoopCacheMetricsLogger(),
       _now = now ?? DateTime.now;

  final CacheMetricsLogger _delegate;
  final DateTime Function() _now;
  final Map<String, _Counters> _byResource = <String, _Counters>{};

  _Counters _slot(String resourceType) =>
      _byResource.putIfAbsent(resourceType, _Counters.new);

  @override
  void hit(String resourceType, String key) {
    _slot(resourceType).hits++;
    _delegate.hit(resourceType, key);
  }

  @override
  void miss(String resourceType, String key) {
    _slot(resourceType).misses++;
    _delegate.miss(resourceType, key);
  }

  @override
  void stale(String resourceType, String key) {
    _slot(resourceType).staleHits++;
    _delegate.stale(resourceType, key);
  }

  @override
  void refreshSuccess(String resourceType, String key, Duration latency) {
    _slot(resourceType).refreshSuccesses++;
    _delegate.refreshSuccess(resourceType, key, latency);
  }

  @override
  void refreshError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) {
    _slot(resourceType).refreshErrors++;
    _delegate.refreshError(resourceType, key, error, stackTrace);
  }

  @override
  void dedupeStart(String resourceType, String key) {
    _slot(resourceType).dedupeStarts++;
    _delegate.dedupeStart(resourceType, key);
  }

  @override
  void dedupeJoin(String resourceType, String key) {
    _slot(resourceType).savedRemoteCalls++;
    _delegate.dedupeJoin(resourceType, key);
  }

  @override
  void dedupeComplete(String resourceType, String key, Duration latency) {
    _slot(resourceType).dedupeCompletes++;
    _delegate.dedupeComplete(resourceType, key, latency);
  }

  @override
  void dedupeError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) {
    _slot(resourceType).dedupeErrors++;
    _delegate.dedupeError(resourceType, key, error, stackTrace);
  }

  @override
  void eviction(String resourceType, String key) {
    _slot(resourceType).evictions++;
    _delegate.eviction(resourceType, key);
  }

  /// One-shot snapshot of the current counters. Returned object is
  /// immutable; the aggregator keeps mutating its own state independently.
  CacheMetricsSnapshot snapshot() {
    final view = <String, CacheResourceMetrics>{
      for (final entry in _byResource.entries)
        entry.key: entry.value.toMetrics(entry.key),
    };
    return CacheMetricsSnapshot(byResource: view, takenAt: _now());
  }

  /// Print the current snapshot to [debugPrint]. Convenience for the dev
  /// console; release builds typically don't call this. NOT invoked
  /// automatically — only when the developer explicitly asks.
  void printSummary() {
    debugPrint(snapshot().summaryText());
  }

  /// Drop all counters. Use to start a fresh measurement window.
  void reset() {
    _byResource.clear();
  }
}

/// Mutable counter cell. Lives only inside [AggregateCacheMetricsLogger];
/// never escapes (we copy into [CacheResourceMetrics] before exposing).
class _Counters {
  int hits = 0;
  int misses = 0;
  int staleHits = 0;
  int refreshSuccesses = 0;
  int refreshErrors = 0;
  int evictions = 0;
  int dedupeStarts = 0;
  int savedRemoteCalls = 0;
  int dedupeCompletes = 0;
  int dedupeErrors = 0;

  CacheResourceMetrics toMetrics(String resourceType) => CacheResourceMetrics(
    resourceType: resourceType,
    hits: hits,
    misses: misses,
    staleHits: staleHits,
    refreshSuccesses: refreshSuccesses,
    refreshErrors: refreshErrors,
    evictions: evictions,
    dedupeStarts: dedupeStarts,
    savedRemoteCalls: savedRemoteCalls,
    dedupeCompletes: dedupeCompletes,
    dedupeErrors: dedupeErrors,
  );
}
