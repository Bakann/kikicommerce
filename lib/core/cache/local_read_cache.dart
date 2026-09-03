import 'cache_entry.dart';
import 'cache_policy.dart';

/// Abstract contract for the Local Read Cache V1.
///
/// V1 ships with a single in-memory implementation. The interface is kept
/// async-compatible so a future persistent backend (e.g. Drift, IndexedDB)
/// can replace it without touching callers.
abstract class LocalReadCache {
  /// Returns a non-expired entry for [key], or null if absent / expired.
  ///
  /// Implementations may also evict an expired entry encountered here as a
  /// lazy cleanup pass.
  Future<CacheEntry<T>?> get<T>(String key);

  /// Returns whatever entry is stored under [key] (even if expired) without
  /// touching freshness or LRU position. Used by SWR strategies that need to
  /// detect a stale-but-present value.
  Future<CacheEntry<T>?> peek<T>(String key);

  /// Marks [key] as most-recently-used without changing its value or its
  /// expiry. Use after a [peek]-based fresh hit (e.g. SWR) so the entry is
  /// not unfairly evicted as if it had been cold. No-op if the key is
  /// absent.
  Future<void> touch(String key);

  /// Writes [value] under [key] following [policy].
  ///
  /// When [expectedGeneration] is provided, the write is skipped if [key] has
  /// been invalidated since that generation was captured (see [generation]).
  /// This lets a slow background refresh avoid resurrecting an entry that was
  /// invalidated while its loader was in flight.
  Future<void> put<T>(
    String key,
    T value,
    CachePolicy policy, {
    int? expectedGeneration,
  });

  /// Current invalidation generation for [key]. Increments every time [key]
  /// is invalidated (directly or via a matching prefix). Capture this before
  /// a load and pass it back to [put] as `expectedGeneration` to discard a
  /// write that an intervening invalidation has made stale.
  int generation(String key);

  Future<void> invalidate(String key);

  Future<void> invalidateByPrefix(String prefix);

  Future<void> clear();
}
