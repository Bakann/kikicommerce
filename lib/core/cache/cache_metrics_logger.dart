import 'package:flutter/foundation.dart';

/// Sink for cache observability events.
///
/// V1 only emits events; we deliberately do not wire up Firebase, Sentry or
/// OpenTelemetry yet — the interface is enough to keep callers stable when
/// real backends are introduced.
///
/// Dedupe lifecycle (read these together):
/// - [dedupeStart]: a fresh remote loader was kicked off for this key.
/// - [dedupeJoin]: a concurrent caller joined an in-flight loader. **Each
///   join represents one remote round-trip saved.**
/// - [dedupeComplete]: the in-flight loader resolved successfully.
/// - [dedupeError]: the in-flight loader failed.
///
/// `dedupeJoin` count over a time window is a direct measure of the
/// deduplicator's runtime gain.
abstract class CacheMetricsLogger {
  void hit(String resourceType, String key);

  void miss(String resourceType, String key);

  void stale(String resourceType, String key);

  void refreshSuccess(String resourceType, String key, Duration latency);

  void refreshError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  );

  /// A new in-flight loader was started for [key] (no prior request was
  /// already in flight).
  void dedupeStart(String resourceType, String key);

  /// A concurrent caller joined an existing in-flight loader for [key].
  /// Each call here corresponds to one saved remote round-trip.
  void dedupeJoin(String resourceType, String key);

  /// The in-flight loader for [key] resolved successfully after [latency].
  void dedupeComplete(String resourceType, String key, Duration latency);

  /// The in-flight loader for [key] failed.
  void dedupeError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  );

  void eviction(String resourceType, String key);
}

/// Default development logger writing to [debugPrint].
class ConsoleCacheMetricsLogger implements CacheMetricsLogger {
  const ConsoleCacheMetricsLogger();

  @override
  void hit(String resourceType, String key) {
    debugPrint('[cache] HIT $resourceType $key');
  }

  @override
  void miss(String resourceType, String key) {
    debugPrint('[cache] MISS $resourceType $key');
  }

  @override
  void stale(String resourceType, String key) {
    debugPrint('[cache] STALE $resourceType $key');
  }

  @override
  void refreshSuccess(String resourceType, String key, Duration latency) {
    debugPrint(
      '[cache] REFRESH_OK $resourceType $key ${latency.inMilliseconds}ms',
    );
  }

  @override
  void refreshError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) {
    debugPrint('[cache] REFRESH_ERR $resourceType $key $error');
  }

  @override
  void dedupeStart(String resourceType, String key) {
    debugPrint('[cache] DEDUPE_START $resourceType $key');
  }

  @override
  void dedupeJoin(String resourceType, String key) {
    debugPrint('[cache] DEDUPE_JOIN $resourceType $key saved_remote_call=true');
  }

  @override
  void dedupeComplete(String resourceType, String key, Duration latency) {
    debugPrint(
      '[cache] DEDUPE_OK $resourceType $key ${latency.inMilliseconds}ms',
    );
  }

  @override
  void dedupeError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) {
    debugPrint('[cache] DEDUPE_ERR $resourceType $key $error');
  }

  @override
  void eviction(String resourceType, String key) {
    debugPrint('[cache] EVICT $resourceType $key');
  }
}

/// No-op logger; useful as a default in tests or in code paths where metrics
/// would only add noise.
class NoopCacheMetricsLogger implements CacheMetricsLogger {
  const NoopCacheMetricsLogger();

  @override
  void hit(String resourceType, String key) {}

  @override
  void miss(String resourceType, String key) {}

  @override
  void stale(String resourceType, String key) {}

  @override
  void refreshSuccess(String resourceType, String key, Duration latency) {}

  @override
  void refreshError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) {}

  @override
  void dedupeStart(String resourceType, String key) {}

  @override
  void dedupeJoin(String resourceType, String key) {}

  @override
  void dedupeComplete(String resourceType, String key, Duration latency) {}

  @override
  void dedupeError(
    String resourceType,
    String key,
    Object error,
    StackTrace? stackTrace,
  ) {}

  @override
  void eviction(String resourceType, String key) {}
}
