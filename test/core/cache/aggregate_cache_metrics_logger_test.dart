import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/cache_providers.dart';
import 'package:kiki_commerce/core/cache/aggregate_cache_metrics_logger.dart';
import 'package:kiki_commerce/core/cache/cache_metrics_logger.dart';
import 'package:kiki_commerce/core/cache/cache_metrics_snapshot.dart';

class _RecordingDelegate implements CacheMetricsLogger {
  final List<String> events = [];

  @override
  void hit(String resourceType, String key) =>
      events.add('hit:$resourceType:$key');
  @override
  void miss(String resourceType, String key) =>
      events.add('miss:$resourceType:$key');
  @override
  void stale(String resourceType, String key) =>
      events.add('stale:$resourceType:$key');
  @override
  void refreshSuccess(String resourceType, String key, Duration latency) =>
      events.add('refreshOk:$resourceType:$key:${latency.inMilliseconds}');
  @override
  void refreshError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) => events.add('refreshErr:$resourceType:$key:$error');
  @override
  void dedupeStart(String resourceType, String key) =>
      events.add('dedupeStart:$resourceType:$key');
  @override
  void dedupeJoin(String resourceType, String key) =>
      events.add('dedupeJoin:$resourceType:$key');
  @override
  void dedupeComplete(String resourceType, String key, Duration latency) =>
      events.add('dedupeOk:$resourceType:$key');
  @override
  void dedupeError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) => events.add('dedupeErr:$resourceType:$key');
  @override
  void eviction(String resourceType, String key) =>
      events.add('evict:$resourceType:$key');
}

class _MutableClock {
  _MutableClock(this.value);
  DateTime value;
  DateTime call() => value;
}

void main() {
  group('AggregateCacheMetricsLogger - aggregation', () {
    test('counts hits / misses / stale per resource', () {
      final agg = AggregateCacheMetricsLogger();
      agg.hit('drawer', 'k1');
      agg.hit('drawer', 'k1');
      agg.miss('drawer', 'k2');
      agg.stale('drawer', 'k1');
      agg.hit('plp', 'kPlp');

      final snap = agg.snapshot();
      final drawer = snap.byResource['drawer']!;
      expect(drawer.hits, 2);
      expect(drawer.misses, 1);
      expect(drawer.staleHits, 1);
      expect(drawer.totalReads, 4);

      final plp = snap.byResource['plp']!;
      expect(plp.hits, 1);
      expect(plp.totalReads, 1);
    });

    test('counts refresh / dedupe / eviction events', () {
      final agg = AggregateCacheMetricsLogger();
      agg.refreshSuccess('drawer', 'k', const Duration(milliseconds: 250));
      agg.refreshError('drawer', 'k', 'err', StackTrace.current);
      agg.dedupeStart('drawer', 'k');
      agg.dedupeJoin('drawer', 'k');
      agg.dedupeJoin('drawer', 'k');
      agg.dedupeComplete('drawer', 'k', const Duration(milliseconds: 100));
      agg.dedupeError('drawer', 'k', 'boom', StackTrace.current);
      agg.eviction('drawer', 'k');

      final m = agg.snapshot().byResource['drawer']!;
      expect(m.refreshSuccesses, 1);
      expect(m.refreshErrors, 1);
      expect(m.dedupeStarts, 1);
      expect(
        m.savedRemoteCalls,
        2,
        reason: 'two dedupeJoin events = two saved remote round-trips',
      );
      expect(m.dedupeCompletes, 1);
      expect(m.dedupeErrors, 1);
      expect(m.evictions, 1);
    });

    test('every event still reaches the underlying delegate (decorator)', () {
      final delegate = _RecordingDelegate();
      final agg = AggregateCacheMetricsLogger(delegate: delegate);

      agg.hit('r', 'k');
      agg.miss('r', 'k');
      agg.stale('r', 'k');
      agg.refreshSuccess('r', 'k', const Duration(milliseconds: 1));
      agg.refreshError('r', 'k', 'err', StackTrace.current);
      agg.dedupeStart('r', 'k');
      agg.dedupeJoin('r', 'k');
      agg.dedupeComplete('r', 'k', const Duration(milliseconds: 1));
      agg.dedupeError('r', 'k', 'err', StackTrace.current);
      agg.eviction('r', 'k');

      expect(
        delegate.events.length,
        10,
        reason: 'decorator must forward every event without filtering',
      );
    });

    test('reset() drops all counters but keeps the logger usable', () {
      final agg = AggregateCacheMetricsLogger();
      agg.hit('r', 'k');
      agg.hit('r', 'k');
      expect(agg.snapshot().byResource['r']!.hits, 2);

      agg.reset();
      expect(agg.snapshot().isEmpty, isTrue);

      agg.hit('r', 'k');
      expect(agg.snapshot().byResource['r']!.hits, 1);
    });
  });

  group('CacheResourceMetrics - rates', () {
    test('hitRate = hits / totalReads (excludes stale)', () {
      const m = CacheResourceMetrics(
        resourceType: 'r',
        hits: 7,
        misses: 2,
        staleHits: 1,
      );
      // totalReads = 10; strict hits = 7
      expect(m.hitRate, 0.7);
    });

    test('cacheServeRate = (hits + staleHits) / totalReads', () {
      const m = CacheResourceMetrics(
        resourceType: 'r',
        hits: 7,
        misses: 2,
        staleHits: 1,
      );
      // SWR-served reactivity: 7 + 1 = 8 / 10
      expect(m.cacheServeRate, 0.8);
    });

    test('division-by-zero is safe — both rates return 0.0 when no reads', () {
      const m = CacheResourceMetrics(resourceType: 'r');
      expect(m.totalReads, 0);
      expect(m.hitRate, 0.0);
      expect(m.cacheServeRate, 0.0);
    });
  });

  group('CacheMetricsSnapshot - aggregate + summaryText', () {
    test('aggregate sums all per-resource counters under "*"', () {
      final agg = AggregateCacheMetricsLogger();
      agg.hit('drawer', 'k1');
      agg.miss('drawer', 'k2');
      agg.hit('plp', 'kPlp');
      agg.dedupeJoin('plp', 'kPlp');

      final snap = agg.snapshot();
      expect(snap.aggregate.resourceType, '*');
      expect(snap.aggregate.hits, 2);
      expect(snap.aggregate.misses, 1);
      expect(snap.aggregate.savedRemoteCalls, 1);
      expect(snap.aggregate.totalReads, 3);
    });

    test('summaryText shows both hitRate and cacheServeRate per line', () {
      final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
      final agg = AggregateCacheMetricsLogger(now: clock.call);
      agg.hit('drawer', 'k');
      agg.stale('drawer', 'k');
      agg.miss('drawer', 'k');

      final text = agg.snapshot().summaryText();
      expect(text, contains('hitRate=33.3%'));
      expect(text, contains('cacheServeRate=66.7%'));
      expect(text, contains('savedRemoteCalls=0'));
      // global aggregate line
      expect(text, contains('* '));
    });

    test('empty snapshot has a friendly placeholder', () {
      final agg = AggregateCacheMetricsLogger();
      final text = agg.snapshot().summaryText();
      expect(text, '[cache] summary: (no cache events recorded)');
    });

    test('takenAt reflects the injected clock', () {
      final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
      final agg = AggregateCacheMetricsLogger(now: clock.call);
      final snap = agg.snapshot();
      expect(snap.takenAt, clock.value);

      clock.value = clock.value.add(const Duration(minutes: 5));
      expect(agg.snapshot().takenAt, clock.value);
    });
  });

  group('CacheMetricsSnapshot - immutability', () {
    test('byResource is unmodifiable: clear() throws UnsupportedError', () {
      final snapshot = CacheMetricsSnapshot(
        byResource: <String, CacheResourceMetrics>{
          'drawer': const CacheResourceMetrics(resourceType: 'drawer', hits: 1),
        },
        takenAt: DateTime.utc(2026, 5, 1),
      );
      expect(snapshot.byResource['drawer']!.hits, 1);
      expect(snapshot.byResource.clear, throwsUnsupportedError);
      expect(
        () => snapshot.byResource['x'] = const CacheResourceMetrics(
          resourceType: 'x',
        ),
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.byResource.remove('drawer'),
        throwsUnsupportedError,
      );
    });

    test('snapshot is isolated from the original mutable map', () {
      final source = <String, CacheResourceMetrics>{
        'drawer': const CacheResourceMetrics(resourceType: 'drawer', hits: 1),
      };
      final snapshot = CacheMetricsSnapshot(
        byResource: source,
        takenAt: DateTime.utc(2026, 5, 1),
      );

      // Mutate the original after construction.
      source['plp'] = const CacheResourceMetrics(resourceType: 'plp', hits: 9);
      source['drawer'] = const CacheResourceMetrics(
        resourceType: 'drawer',
        hits: 999,
      );

      // The snapshot reflects the state at construction, not the source.
      expect(snapshot.byResource.containsKey('plp'), isFalse);
      expect(snapshot.byResource['drawer']!.hits, 1);
    });

    test('CacheResourceMetrics is const-constructible and exposes only final '
        'fields', () {
      // Compile-time guarantee that the type is immutable: const ctor.
      const a = CacheResourceMetrics(
        resourceType: 'r',
        hits: 1,
        misses: 2,
        staleHits: 3,
        refreshSuccesses: 4,
        refreshErrors: 5,
        evictions: 6,
        dedupeStarts: 7,
        savedRemoteCalls: 8,
        dedupeCompletes: 9,
        dedupeErrors: 10,
      );
      // Sanity: identical const instances reuse the same object.
      const b = CacheResourceMetrics(
        resourceType: 'r',
        hits: 1,
        misses: 2,
        staleHits: 3,
        refreshSuccesses: 4,
        refreshErrors: 5,
        evictions: 6,
        dedupeStarts: 7,
        savedRemoteCalls: 8,
        dedupeCompletes: 9,
        dedupeErrors: 10,
      );
      expect(identical(a, b), isTrue);
    });
  });

  group('cacheMetricsSnapshotReaderProvider', () {
    test(
      'every call returns a fresh snapshot reflecting recent events',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final logger = container.read(cacheMetricsLoggerProvider);
        final readSnapshot = container.read(cacheMetricsSnapshotReaderProvider);

        logger.hit('drawer', 'k1');
        final s1 = readSnapshot();
        expect(
          s1,
          isNotNull,
          reason: 'aggregator is wired up in dev/test builds',
        );
        expect(s1!.byResource['drawer']!.hits, 1);

        logger.hit('drawer', 'k2');
        final s2 = readSnapshot();
        expect(
          s2!.byResource['drawer']!.hits,
          2,
          reason: 'reader produces a fresh snapshot per call',
        );

        // The two snapshots are distinct instances so consumers cannot
        // be misled by accidental aliasing.
        expect(identical(s1, s2), isFalse);
        // And the earlier snapshot is unaffected by later events.
        expect(s1.byResource['drawer']!.hits, 1);
      },
    );

    test('reader returns null in absence of an aggregator', () {
      final container = ProviderContainer(
        overrides: [
          aggregateCacheMetricsLoggerProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      final readSnapshot = container.read(cacheMetricsSnapshotReaderProvider);
      expect(readSnapshot(), isNull);
    });
  });

  group('cacheMetricsSnapshotProvider (cached) — refresh behaviour', () {
    test('value is cached until container.refresh is called', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final logger = container.read(cacheMetricsLoggerProvider);

      logger.hit('drawer', 'k1');
      final cached1 = container.read(cacheMetricsSnapshotProvider);
      expect(cached1!.byResource['drawer']!.hits, 1);

      // New event AFTER the cached read — but read again without refresh.
      logger.hit('drawer', 'k2');
      final cachedAgain = container.read(cacheMetricsSnapshotProvider);
      expect(
        cachedAgain!.byResource['drawer']!.hits,
        1,
        reason: 'cached value, not fresh',
      );

      // Explicit refresh produces a new snapshot.
      final refreshed = container.refresh(cacheMetricsSnapshotProvider);
      expect(refreshed!.byResource['drawer']!.hits, 2);
    });
  });

  group('AggregateCacheMetricsLogger - printSummary opt-in', () {
    test('printSummary is not invoked automatically on each event', () {
      // Counters track but no console output beyond the delegate's own
      // per-event lines. We can't easily intercept debugPrint here, but
      // we can at least ensure printSummary is callable without throwing
      // and that snapshot is independent of it.
      final agg = AggregateCacheMetricsLogger();
      agg.hit('r', 'k');
      // Multiple printSummary calls are safe and don't reset state.
      agg.printSummary();
      agg.printSummary();
      expect(agg.snapshot().byResource['r']!.hits, 1);
    });
  });
}
