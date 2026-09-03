/// Immutable per-resource roll-up of cache events. Produced by
/// [AggregateCacheMetricsLogger.snapshot]; consumed by debug overlays,
/// tests, and any future telemetry export.
///
/// `totalReads` is the denominator for the two ratios:
/// - [hitRate]: strict cache hits over reads — what the cache fully avoided
///   serving from network.
/// - [cacheServeRate]: hits + stale hits over reads — the **user-perceived**
///   reactivity. Under SWR, a stale value is still served from local
///   memory (the network refresh runs in background), so it counts as a
///   reactivity win even though a refresh fires.
class CacheResourceMetrics {
  const CacheResourceMetrics({
    required this.resourceType,
    this.hits = 0,
    this.misses = 0,
    this.staleHits = 0,
    this.refreshSuccesses = 0,
    this.refreshErrors = 0,
    this.evictions = 0,
    this.dedupeStarts = 0,
    this.savedRemoteCalls = 0,
    this.dedupeCompletes = 0,
    this.dedupeErrors = 0,
  });

  final String resourceType;
  final int hits;
  final int misses;
  final int staleHits;
  final int refreshSuccesses;
  final int refreshErrors;
  final int evictions;

  /// Number of times the deduplicator started a new in-flight loader.
  final int dedupeStarts;

  /// Number of remote round-trips saved by deduplication
  /// (= number of `dedupeJoin` events).
  final int savedRemoteCalls;

  final int dedupeCompletes;
  final int dedupeErrors;

  int get totalReads => hits + misses + staleHits;

  /// Strict hit ratio: how often we returned a fresh cached value without
  /// touching the network or serving stale data. Returns 0.0 when no reads
  /// have been recorded.
  double get hitRate {
    final total = totalReads;
    return total == 0 ? 0.0 : hits / total;
  }

  /// User-perceived reactivity: hits + stale hits over reads. Returns 0.0
  /// when no reads have been recorded.
  double get cacheServeRate {
    final total = totalReads;
    return total == 0 ? 0.0 : (hits + staleHits) / total;
  }

  /// Add two metrics objects component-wise. Used to build the global
  /// aggregate inside [CacheMetricsSnapshot]. The resulting [resourceType]
  /// is the receiver's — callers wanting a "global" label pass `'*'`.
  CacheResourceMetrics operator +(CacheResourceMetrics other) {
    return CacheResourceMetrics(
      resourceType: resourceType,
      hits: hits + other.hits,
      misses: misses + other.misses,
      staleHits: staleHits + other.staleHits,
      refreshSuccesses: refreshSuccesses + other.refreshSuccesses,
      refreshErrors: refreshErrors + other.refreshErrors,
      evictions: evictions + other.evictions,
      dedupeStarts: dedupeStarts + other.dedupeStarts,
      savedRemoteCalls: savedRemoteCalls + other.savedRemoteCalls,
      dedupeCompletes: dedupeCompletes + other.dedupeCompletes,
      dedupeErrors: dedupeErrors + other.dedupeErrors,
    );
  }

  /// One-line summary of this resource's metrics. Field names match the
  /// snapshot model so console output and test assertions stay in sync.
  String toLine() {
    return '$resourceType '
        'reads=$totalReads '
        'hits=$hits '
        'misses=$misses '
        'stale=$staleHits '
        'hitRate=${_pct(hitRate)} '
        'cacheServeRate=${_pct(cacheServeRate)} '
        'savedRemoteCalls=$savedRemoteCalls '
        'evictions=$evictions '
        'refreshOk=$refreshSuccesses '
        'refreshErr=$refreshErrors';
  }

  static String _pct(double v) {
    final pct = v * 100;
    final rounded = (pct * 10).roundToDouble() / 10;
    return '${rounded.toStringAsFixed(1)}%';
  }
}

/// Point-in-time snapshot of the aggregator's state.
///
/// One-shot semantics: reading `cacheMetricsSnapshotProvider` (or calling
/// `AggregateCacheMetricsLogger.snapshot()`) returns the counters **as
/// they were at that instant**. The snapshot does not update on its own.
/// Widgets that want a live view must re-read on a timer or rebuild on
/// user action. For V1 this is a debug-only feature, so the manual
/// re-read is intentional. For a fresh snapshot per call, prefer
/// `cacheMetricsSnapshotReaderProvider` (returns a function) over the
/// plain `cacheMetricsSnapshotProvider` (cached by Riverpod).
///
/// Concurrency model (Dart single-isolate):
/// - Counters are updated synchronously on the Dart event loop.
/// - The logger does not `await` inside event handlers, so individual
///   increments cannot be interleaved within the same isolate.
/// - Snapshots remain best-effort because they can be taken **between**
///   two events; the snapshot is consistent at the moment it is built
///   but the underlying counters keep moving immediately afterwards.
/// - This is suitable for dev telemetry, not for correctness-critical
///   assertions.
///
/// Immutability: [byResource] is wrapped in [Map.unmodifiable] inside the
/// constructor. Mutating the map passed in afterwards does NOT affect the
/// snapshot, and consumers attempting to mutate `snapshot.byResource`
/// receive [UnsupportedError]. [CacheResourceMetrics] is itself final and
/// const-constructible, so values are safe to share across the app.
class CacheMetricsSnapshot {
  CacheMetricsSnapshot({
    required Map<String, CacheResourceMetrics> byResource,
    required this.takenAt,
  }) : byResource = Map.unmodifiable(byResource),
       aggregate = _computeAggregate(byResource);

  /// Per-resource metrics keyed by resource type (e.g. `drawer`, `plp`,
  /// `categories`). Empty when no events have been recorded. The map is
  /// unmodifiable — calls like `clear()` or `[] =` throw
  /// [UnsupportedError].
  final Map<String, CacheResourceMetrics> byResource;

  /// Aggregate over all resources. `resourceType` is the literal string
  /// `'*'` so it is unambiguous in logs.
  final CacheResourceMetrics aggregate;

  final DateTime takenAt;

  /// True when no events have been recorded since the last reset.
  bool get isEmpty => byResource.isEmpty;

  /// Multi-line text summary suitable for console / debug overlays.
  /// Format: one line per resource (sorted), then a `total` line carrying
  /// the global aggregate. Both `hitRate` and `cacheServeRate` are shown
  /// so SWR's stale-served reactivity is visible separately from strict
  /// hits. Returns "(no cache events recorded)" when empty.
  String summaryText() {
    if (isEmpty) return '[cache] summary: (no cache events recorded)';
    final lines = <String>['[cache] summary @${takenAt.toIso8601String()}'];
    final keys = byResource.keys.toList()..sort();
    for (final key in keys) {
      lines.add('  ${byResource[key]!.toLine()}');
    }
    lines.add('  ${aggregate.toLine()}');
    return lines.join('\n');
  }

  static CacheResourceMetrics _computeAggregate(
    Map<String, CacheResourceMetrics> byResource,
  ) {
    if (byResource.isEmpty) {
      return const CacheResourceMetrics(resourceType: '*');
    }
    final values = byResource.values.toList(growable: false);
    var acc = const CacheResourceMetrics(resourceType: '*');
    for (final m in values) {
      acc = acc + m;
    }
    return acc;
  }
}
