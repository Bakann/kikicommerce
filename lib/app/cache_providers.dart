import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cache/aggregate_cache_metrics_logger.dart';
import '../core/cache/cache_metrics_logger.dart';
import '../core/cache/cache_metrics_snapshot.dart';
import '../core/cache/cached_remote_reader.dart';
import '../core/cache/local_read_cache.dart';
import '../core/cache/memory_local_read_cache.dart';
import '../core/cache/request_deduplicator.dart';

/// Riverpod plumbing for the Local Read Cache V1.
///
/// The cache, deduplicator and reader are all Provider singletons so the
/// whole app shares one instance per [ProviderContainer]. Tests get isolation
/// for free: each test creates its own container and therefore its own cache.

/// Single clock source used by both [localReadCacheProvider] and
/// [cachedRemoteReaderProvider]. Tests override this once and the cache /
/// reader stay in sync — otherwise the reader's "is this entry expired?"
/// check would compare a test-clock timestamp against real wall-clock time
/// and treat every entry as stale.
final cacheClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// In dev/test the metrics sink is wrapped with [AggregateCacheMetricsLogger]
/// so per-resource roll-ups are observable via [cacheMetricsSnapshotProvider]
/// without losing the per-event console lines. In release everything stays
/// silent — telemetry is opt-in.
final aggregateCacheMetricsLoggerProvider =
    Provider<AggregateCacheMetricsLogger?>((ref) {
      if (kReleaseMode) return null;
      return AggregateCacheMetricsLogger(
        delegate: const ConsoleCacheMetricsLogger(),
        now: ref.watch(cacheClockProvider),
      );
    });

final cacheMetricsLoggerProvider = Provider<CacheMetricsLogger>((ref) {
  if (kReleaseMode) return const NoopCacheMetricsLogger();
  // Aggregator decorates the console logger — both still receive every
  // event, so existing per-event log lines are preserved.
  return ref.watch(aggregateCacheMetricsLoggerProvider)!;
});

/// Cached one-shot snapshot of cache metrics.
///
/// Riverpod **caches** the value of this Provider for the lifetime of its
/// dependencies, so `ref.read(cacheMetricsSnapshotProvider)` may return
/// the snapshot taken the **first** time it was read, not a fresh one.
/// To force a recompute, call `ref.refresh(cacheMetricsSnapshotProvider)`.
///
/// For ad-hoc fresh reads (debug overlay, dev console), prefer
/// [cacheMetricsSnapshotReaderProvider] which returns a function whose
/// every invocation produces a brand-new snapshot.
///
/// Returns null in release builds (no aggregator wired up).
final cacheMetricsSnapshotProvider = Provider<CacheMetricsSnapshot?>((ref) {
  return ref.watch(aggregateCacheMetricsLoggerProvider)?.snapshot();
});

/// Returns a function that produces a **fresh** [CacheMetricsSnapshot] on
/// every call. Use this when you need an on-demand snapshot — e.g. from a
/// `onPressed` handler in a debug overlay — without depending on
/// Riverpod's value caching.
///
/// Returns a function that returns null in release builds (no aggregator).
///
/// Example:
/// ```dart
/// final readSnapshot = ref.read(cacheMetricsSnapshotReaderProvider);
/// final s1 = readSnapshot();   // snapshot at t1
/// // … some events fire …
/// final s2 = readSnapshot();   // distinct, fresh snapshot at t2
/// ```
final cacheMetricsSnapshotReaderProvider =
    Provider<CacheMetricsSnapshot? Function()>((ref) {
      final logger = ref.watch(aggregateCacheMetricsLoggerProvider);
      return () => logger?.snapshot();
    });

/// Convenience: takes a fresh snapshot and prints its `summaryText()` via
/// [debugPrint]. Wire this into a dev-only button or a hotkey handler to
/// dump the current state of the cache. No-op in release builds (the
/// aggregator is null).
void debugPrintCacheMetricsSummary(WidgetRef ref) {
  final snapshot = ref.read(cacheMetricsSnapshotReaderProvider)();
  if (snapshot == null) return;
  debugPrint(snapshot.summaryText());
}

final localReadCacheProvider = Provider<LocalReadCache>((ref) {
  return MemoryLocalReadCache(
    metricsLogger: ref.watch(cacheMetricsLoggerProvider),
    now: ref.watch(cacheClockProvider),
  );
});

final requestDeduplicatorProvider = Provider<RequestDeduplicator>((ref) {
  return RequestDeduplicator(
    metricsLogger: ref.watch(cacheMetricsLoggerProvider),
    now: ref.watch(cacheClockProvider),
  );
});

final cachedRemoteReaderProvider = Provider<CachedRemoteReader>((ref) {
  return CachedRemoteReader(
    cache: ref.watch(localReadCacheProvider),
    deduplicator: ref.watch(requestDeduplicatorProvider),
    metricsLogger: ref.watch(cacheMetricsLoggerProvider),
    now: ref.watch(cacheClockProvider),
  );
});
