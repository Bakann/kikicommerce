import 'dart:async';

import 'cache_entry.dart';
import 'cache_metrics_logger.dart';
import 'cache_policy.dart';
import 'cache_refresh_strategy.dart';
import 'local_read_cache.dart';
import 'request_deduplicator.dart';

/// Composes [LocalReadCache] + [RequestDeduplicator] to apply a
/// [CachePolicy]'s [CacheRefreshStrategy] around a remote loader.
///
/// Important: callers sharing a [key] must provide an equivalent
/// [remoteLoader]. If the expected response differs, the repository must
/// produce a different key — the deduplicator will collapse identical-key
/// concurrent calls onto the first loader received.
///
/// Read-only contract: as the class name implies, this reader is for
/// **read-side** operations only. [CacheRefreshStrategy.networkOnly] is the
/// right policy for transactional reads (cart/checkout/payment/order, final
/// price, real stock) that must always hit the server, but it is NOT a
/// substitute for a mutation API. Two concurrent mutations sharing a key
/// would be coalesced by the deduplicator — never call [read] for write
/// operations. Mutations must go through their dedicated repository methods,
/// outside the cache layer.
class CachedRemoteReader {
  CachedRemoteReader({
    required this.cache,
    required this.deduplicator,
    required this.metricsLogger,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final LocalReadCache cache;
  final RequestDeduplicator deduplicator;
  final CacheMetricsLogger metricsLogger;
  final DateTime Function() now;

  /// Reads a value following [policy].
  ///
  /// - [onStaleData]: invoked synchronously with the stale value before it is
  ///   returned (SWR only).
  /// - [onFreshData]: invoked when a background SWR refresh succeeds.
  /// - [onRefreshError]: invoked when a background SWR refresh fails. The
  ///   stale value is preserved in cache.
  /// - [cachePredicate]: optional gate run on every successfully-loaded
  ///   value. When it returns false, the value is still returned to the
  ///   caller but is **not** written to the cache. Useful when the loader
  ///   yields a "soft failure" sentinel (e.g. a fallback object on transient
  ///   network errors) that we don't want stuck in the cache for the TTL
  ///   window.
  /// - [dedupe]: when false, bypass the request deduplicator and run the
  ///   remote loader directly. Useful when the surrounding system (e.g. a
  ///   Riverpod provider) already serialises concurrent reads, OR when a
  ///   forced post-mutation refresh must not be coalesced with a stale
  ///   in-flight request.
  Future<T> read<T>({
    required String key,
    required String resourceType,
    required CachePolicy policy,
    required Future<T> Function() remoteLoader,
    void Function(T stale)? onStaleData,
    void Function(T fresh)? onFreshData,
    void Function(Object error, StackTrace stackTrace)? onRefreshError,
    bool Function(T value)? cachePredicate,
    bool dedupe = true,
  }) {
    switch (policy.strategy) {
      case CacheRefreshStrategy.networkOnly:
        return _networkOnly<T>(
          key: key,
          resourceType: resourceType,
          remoteLoader: remoteLoader,
          dedupe: dedupe,
        );
      case CacheRefreshStrategy.cacheFirst:
        return _cacheFirst<T>(
          key: key,
          resourceType: resourceType,
          policy: policy,
          remoteLoader: remoteLoader,
          cachePredicate: cachePredicate,
          dedupe: dedupe,
        );
      case CacheRefreshStrategy.networkFirst:
        return _networkFirst<T>(
          key: key,
          resourceType: resourceType,
          policy: policy,
          remoteLoader: remoteLoader,
          cachePredicate: cachePredicate,
          dedupe: dedupe,
        );
      case CacheRefreshStrategy.staleWhileRevalidate:
        return _staleWhileRevalidate<T>(
          key: key,
          resourceType: resourceType,
          policy: policy,
          remoteLoader: remoteLoader,
          onStaleData: onStaleData,
          onFreshData: onFreshData,
          onRefreshError: onRefreshError,
          cachePredicate: cachePredicate,
          dedupe: dedupe,
        );
    }
  }

  Future<T> _networkOnly<T>({
    required String key,
    required String resourceType,
    required Future<T> Function() remoteLoader,
    bool dedupe = true,
  }) {
    if (!dedupe) return remoteLoader();
    return deduplicator.run<T>(key, remoteLoader, resourceType: resourceType);
  }

  Future<T> _cacheFirst<T>({
    required String key,
    required String resourceType,
    required CachePolicy policy,
    required Future<T> Function() remoteLoader,
    bool Function(T value)? cachePredicate,
    bool dedupe = true,
  }) async {
    final cached = await cache.get<T>(key);
    if (cached != null) {
      metricsLogger.hit(resourceType, key);
      return cached.data;
    }
    metricsLogger.miss(resourceType, key);

    return _loadAndCache<T>(
      key: key,
      resourceType: resourceType,
      policy: policy,
      remoteLoader: remoteLoader,
      cachePredicate: cachePredicate,
      dedupe: dedupe,
    );
  }

  Future<T> _networkFirst<T>({
    required String key,
    required String resourceType,
    required CachePolicy policy,
    required Future<T> Function() remoteLoader,
    bool Function(T value)? cachePredicate,
    bool dedupe = true,
  }) async {
    try {
      return await _loadAndCache<T>(
        key: key,
        resourceType: resourceType,
        policy: policy,
        remoteLoader: remoteLoader,
        cachePredicate: cachePredicate,
        dedupe: dedupe,
      );
    } catch (error, stackTrace) {
      final cached = await cache.peek<T>(key);
      if (cached != null) {
        metricsLogger.hit(resourceType, key);
        return cached.data;
      }
      metricsLogger.miss(resourceType, key);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<T> _staleWhileRevalidate<T>({
    required String key,
    required String resourceType,
    required CachePolicy policy,
    required Future<T> Function() remoteLoader,
    void Function(T stale)? onStaleData,
    void Function(T fresh)? onFreshData,
    void Function(Object error, StackTrace stackTrace)? onRefreshError,
    bool Function(T value)? cachePredicate,
    bool dedupe = true,
  }) async {
    final currentTime = now();
    final CacheEntry<T>? snapshot = await cache.peek<T>(key);

    if (snapshot != null && !snapshot.isExpired(currentTime)) {
      // Fresh hit. peek() did not touch LRU position, so promote the entry
      // explicitly — otherwise an SWR resource read on every frame would
      // still look "cold" to the LRU and could be evicted unfairly.
      await cache.touch(key);
      metricsLogger.hit(resourceType, key);
      return snapshot.data;
    }

    if (snapshot != null) {
      // Stale hit: return immediately, refresh in background.
      metricsLogger.stale(resourceType, key);
      onStaleData?.call(snapshot.data);

      unawaited(
        _backgroundRefresh<T>(
          key: key,
          resourceType: resourceType,
          policy: policy,
          remoteLoader: remoteLoader,
          onFreshData: onFreshData,
          onRefreshError: onRefreshError,
          cachePredicate: cachePredicate,
          dedupe: dedupe,
        ),
      );

      return snapshot.data;
    }

    // No entry at all: behave like cacheFirst — load and cache.
    metricsLogger.miss(resourceType, key);
    return _loadAndCache<T>(
      key: key,
      resourceType: resourceType,
      policy: policy,
      remoteLoader: remoteLoader,
      cachePredicate: cachePredicate,
      dedupe: dedupe,
    );
  }

  Future<void> _backgroundRefresh<T>({
    required String key,
    required String resourceType,
    required CachePolicy policy,
    required Future<T> Function() remoteLoader,
    void Function(T fresh)? onFreshData,
    void Function(Object error, StackTrace stackTrace)? onRefreshError,
    bool Function(T value)? cachePredicate,
    bool dedupe = true,
  }) async {
    final start = now();
    // Capture the invalidation generation before the refresh runs. If the key
    // is invalidated while this background refresh is in flight, the fresh
    // value is already stale relative to the invalidation, so we must not push
    // it to listeners — the invalidation path drives its own re-read.
    final generation = cache.generation(key);
    try {
      final fresh = await _runLoader<T>(
        key: key,
        resourceType: resourceType,
        policy: policy,
        remoteLoader: remoteLoader,
        cachePredicate: cachePredicate,
        dedupe: dedupe,
      );
      final latency = now().difference(start);
      metricsLogger.refreshSuccess(resourceType, key, latency);
      if (cache.generation(key) == generation) {
        onFreshData?.call(fresh);
      }
    } catch (error, stackTrace) {
      metricsLogger.refreshError(resourceType, key, error, stackTrace);
      onRefreshError?.call(error, stackTrace);
    }
  }

  Future<T> _loadAndCache<T>({
    required String key,
    required String resourceType,
    required CachePolicy policy,
    required Future<T> Function() remoteLoader,
    bool Function(T value)? cachePredicate,
    bool dedupe = true,
  }) {
    return _runLoader<T>(
      key: key,
      resourceType: resourceType,
      policy: policy,
      remoteLoader: remoteLoader,
      cachePredicate: cachePredicate,
      dedupe: dedupe,
    );
  }

  Future<T> _runLoader<T>({
    required String key,
    required String resourceType,
    required CachePolicy policy,
    required Future<T> Function() remoteLoader,
    bool Function(T value)? cachePredicate,
    bool dedupe = true,
  }) {
    Future<T> wrapped() async {
      // Snapshot the generation at load start so an invalidation that lands
      // while the network call is in flight discards this write (see
      // LocalReadCache.put / generation).
      final expectedGeneration = cache.generation(key);
      final value = await remoteLoader();
      if (policy.allowsWrite && (cachePredicate?.call(value) ?? true)) {
        await cache.put<T>(
          key,
          value,
          policy,
          expectedGeneration: expectedGeneration,
        );
      }
      return value;
    }

    if (!dedupe) return wrapped();
    return deduplicator.run<T>(key, wrapped, resourceType: resourceType);
  }
}
