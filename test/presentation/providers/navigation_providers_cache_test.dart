import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/app/cache_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_invalidations.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/core/cache/cache_policy.dart';
import 'package:kiki_commerce/core/cache/cache_refresh_strategy.dart';
import 'package:kiki_commerce/core/cache/memory_local_read_cache.dart';
import 'package:kiki_commerce/presentation/providers/catalog_invalidator_provider.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/providers/navigation_providers.dart';

class _CountingRepo implements DrawerNavigationRepository {
  _CountingRepo(this._results);
  final List<DrawerNavigationLoadResult> _results;
  int callCount = 0;
  final includeHiddenCalls = <bool>[];

  @override
  Future<DrawerNavigationLoadResult> fetchMainDrawer({
    required String locale,
    bool includeHidden = false,
  }) async {
    includeHiddenCalls.add(includeHidden);
    final value = _results[callCount.clamp(0, _results.length - 1)];
    callCount++;
    return value;
  }
}

DrawerNavigationLoadResult _success({String menuId = 'menu-1'}) {
  return DrawerNavigationLoadResult.success(
    menu: DrawerNavigationMenuData(
      id: menuId,
      name: 'Main',
      code: 'main_drawer',
      displayMode: 'drawer',
      isActive: true,
    ),
    normalized: const DrawerNavigationNormalizedResult.usable(roots: []),
  );
}

class _MutableClock {
  _MutableClock(this.value);
  DateTime value;
  DateTime call() => value;
}

ProviderContainer _makeContainer(DrawerNavigationRepository repo) {
  final container = ProviderContainer(
    overrides: [drawerNavigationRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('mainDrawerNavigationProvider caching', () {
    test(
      'second read within TTL hits the cache (no extra repo call)',
      () async {
        final repo = _CountingRepo([_success(), _success()]);
        final container = _makeContainer(repo);

        await container.read(mainDrawerNavigationProvider.future);
        // Force re-evaluation by re-reading the provider state.
        final asyncValue = container.read(mainDrawerNavigationProvider);
        expect(asyncValue.value, isNotNull);

        // The provider's keepAlive() means the value is reused — no second
        // repo call. This is the baseline; the cache hit kicks in after
        // explicit Riverpod invalidation.
        expect(repo.callCount, 1);
      },
    );

    test('after Riverpod invalidate (without cache invalidation), cache hit '
        'short-circuits the repo', () async {
      final repo = _CountingRepo([_success(), _success()]);
      final container = _makeContainer(repo);

      await container.read(mainDrawerNavigationProvider.future);
      expect(repo.callCount, 1);

      // Invalidate Riverpod only — the cache still holds the success.
      container.invalidate(mainDrawerNavigationProvider);
      await container.read(mainDrawerNavigationProvider.future);

      // The cache hit means the repo was NOT called again.
      expect(repo.callCount, 1);
    });

    test(
      'DrawerNavigationInvalidation clears cache and forces a fresh fetch',
      () async {
        final repo = _CountingRepo([_success(), _success()]);
        final container = _makeContainer(repo);

        await container.read(mainDrawerNavigationProvider.future);
        expect(repo.callCount, 1);

        container.read(catalogInvalidatorProvider).applyToContainer(
          container,
          const [DrawerNavigationInvalidation()],
        );
        await container.read(mainDrawerNavigationProvider.future);

        // Full invalidation flow: cache was cleared, repo was called again.
        expect(repo.callCount, 2);
      },
    );

    test('fallback results are NOT cached (predicate gate)', () async {
      final fallback = const DrawerNavigationLoadResult.fallback(
        fallbackReason: DrawerNavigationFallbackReason.menuMissing,
      );
      final repo = _CountingRepo([fallback, _success()]);
      final container = _makeContainer(repo);

      await container.read(mainDrawerNavigationProvider.future);
      expect(repo.callCount, 1);

      // Even without explicit cache invalidation, a Riverpod re-eval should
      // hit the repo again because the prior result was a fallback and
      // therefore was not cached.
      container.invalidate(mainDrawerNavigationProvider);
      final second = await container.read(mainDrawerNavigationProvider.future);
      expect(repo.callCount, 2);
      expect(second.fallbackReason, isNull);
    });

    test(
      'edit-mode toggle changes the cache key (separate cache slot)',
      () async {
        final repo = _CountingRepo([_success(), _success(), _success()]);
        final container = _makeContainer(repo);

        // First read: includeHidden=false (default)
        await container.read(mainDrawerNavigationProvider.future);
        expect(repo.callCount, 1);

        // Flip edit mode → includeHidden=true → different cache key → fetch.
        container.read(editModeProvider.notifier).state = true;
        await container.read(mainDrawerNavigationProvider.future);
        expect(repo.callCount, 2);
        expect(repo.includeHiddenCalls, [false, true]);

        // Flip back → cached visible variant should serve without a fetch.
        container.read(editModeProvider.notifier).state = false;
        await container.read(mainDrawerNavigationProvider.future);
        expect(repo.callCount, 2);
      },
    );
  });

  group('SWR stale → fresh UI sync', () {
    test('a stale cache hit returns stale immediately, the bg refresh updates '
        'the cache, and the next read returns fresh', () async {
      // Build a container whose cache is pre-seeded with a stale entry.
      // Both the cache and the reader share the same injected clock via
      // cacheClockProvider — otherwise the reader (real wall clock) would
      // see every test-clock-stamped entry as "expired" and re-fetch
      // each read.
      final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
      final cache = MemoryLocalReadCache(now: clock.call);

      final v1 = _success(menuId: 'old');
      final v2 = _success(menuId: 'new');

      // Seed the cache with v1 under the visible-only drawer key.
      await cache.put<DrawerNavigationLoadResult>(
        drawerCacheKey(locale: 'fr', includeHidden: false),
        v1,
        const CachePolicy(
          ttl: Duration(minutes: 10),
          strategy: CacheRefreshStrategy.staleWhileRevalidate,
        ),
      );

      // Move 11 minutes forward so the seeded entry is now stale.
      clock.value = clock.value.add(const Duration(minutes: 11));

      final repo = _CountingRepo([v2]);
      final container = ProviderContainer(
        overrides: [
          drawerNavigationRepositoryProvider.overrideWithValue(repo),
          cacheClockProvider.overrideWithValue(clock.call),
          localReadCacheProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);

      // First read: should return the stale v1 immediately and kick off
      // a background refresh.
      final stale = await container.read(mainDrawerNavigationProvider.future);
      expect(stale.menu?.id, 'old');

      // Let the background refresh + onFreshData → invalidateSelf settle.
      // Two microtask hops: one for the refresh, one for the re-eval.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // The bg refresh ran and we expect the provider to have been
      // re-evaluated; the next read returns the fresh v2.
      final fresh = await container.read(mainDrawerNavigationProvider.future);
      expect(fresh.menu?.id, 'new');
      expect(repo.callCount, 1);
    });

    test(
      'when bg refresh returns a fallback, no invalidation loop is triggered',
      () async {
        // Seed cache with stale success, configure repo to return fallback.
        // Without the loop guard, this would refire onFreshData → invalidate
        // → SWR → bg refresh → fallback ad infinitum.
        final clock = _MutableClock(DateTime.utc(2026, 5, 1, 10));
        final cache = MemoryLocalReadCache(now: clock.call);
        await cache.put<DrawerNavigationLoadResult>(
          drawerCacheKey(locale: 'fr', includeHidden: false),
          _success(),
          const CachePolicy(
            ttl: Duration(minutes: 10),
            strategy: CacheRefreshStrategy.staleWhileRevalidate,
          ),
        );
        clock.value = clock.value.add(const Duration(minutes: 11));

        const fallback = DrawerNavigationLoadResult.fallback(
          fallbackReason: DrawerNavigationFallbackReason.fetchError,
        );
        final repo = _CountingRepo([fallback, fallback, fallback, fallback]);
        final container = ProviderContainer(
          overrides: [
            drawerNavigationRepositoryProvider.overrideWithValue(repo),
            cacheClockProvider.overrideWithValue(clock.call),
            localReadCacheProvider.overrideWithValue(cache),
          ],
        );
        addTearDown(container.dispose);

        await container.read(mainDrawerNavigationProvider.future);

        // Pump several microtask hops to give a hypothetical loop chance
        // to fire repeatedly.
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        // The bg refresh ran exactly once; the loop guard prevented
        // repeated re-invalidation.
        expect(repo.callCount, 1);
      },
    );
  });

  group('sequential refresh ordering (dedupe: false)', () {
    test('two sequential refreshes complete in arrival order; cache holds the '
        'latter result', () async {
      // Sequence v1 → v2 → v3. Each refresh consumes the next item.
      final repo = _CountingRepo([
        _success(menuId: 'v1'),
        _success(menuId: 'v2'),
        _success(menuId: 'v3'),
      ]);
      final container = _makeContainer(repo);

      final r1 = await container.read(mainDrawerNavigationProvider.future);
      expect(r1.menu?.id, 'v1');

      container.read(catalogInvalidatorProvider).applyToContainer(
        container,
        const [DrawerNavigationInvalidation()],
      );
      final r2 = await container.read(mainDrawerNavigationProvider.future);
      expect(r2.menu?.id, 'v2');

      container.read(catalogInvalidatorProvider).applyToContainer(
        container,
        const [DrawerNavigationInvalidation()],
      );
      final r3 = await container.read(mainDrawerNavigationProvider.future);
      expect(r3.menu?.id, 'v3');

      expect(repo.callCount, 3);
    });
  });

  group('drawerCacheKey', () {
    test('keys differ by includeHidden axis', () {
      final visible = drawerCacheKey(locale: 'fr', includeHidden: false);
      final all = drawerCacheKey(locale: 'fr', includeHidden: true);
      expect(visible, isNot(all));
      expect(visible, contains('main_drawer:visible'));
      expect(all, contains('main_drawer:all'));
    });

    test(
      'cache provider singleton: same instance across reads in container',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final c1 = container.read(localReadCacheProvider);
        final c2 = container.read(localReadCacheProvider);
        expect(identical(c1, c2), isTrue);
      },
    );
  });
}
