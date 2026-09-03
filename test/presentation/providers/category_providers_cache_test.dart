import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_invalidations.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/catalog_invalidator_provider.dart';
import 'package:kiki_commerce/presentation/providers/category_providers.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';

class _CountingCategoryRepo implements CategoryCatalogRepository {
  int activeCalls = 0;
  int defaultCalls = 0;
  final List<bool> activeIncludeHidden = [];
  final List<String> slugCalls = [];

  CatalogCategory _cat(String id, {String? slug}) =>
      CatalogCategory(id: id, code: id, name: id, slug: slug ?? id);

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async {
    activeCalls++;
    activeIncludeHidden.add(includeHidden);
    return [_cat('a'), _cat('b')];
  }

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async {
    defaultCalls++;
    return _cat('default');
  }

  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async {
    slugCalls.add(slug);
    return _cat('id-$slug', slug: slug);
  }

  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async => throw UnimplementedError();

  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String locale,
    required String categorySlug,
    required String productSlug,
  }) async => throw UnimplementedError();
}

ProviderContainer _makeContainer(_CountingCategoryRepo repo) {
  final container = ProviderContainer(
    overrides: [categoryCatalogRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('activeCategoriesProvider caching', () {
    test('second read after Riverpod invalidate hits the cache', () async {
      final repo = _CountingCategoryRepo();
      final container = _makeContainer(repo);

      await container.read(activeCategoriesProvider.future);
      expect(repo.activeCalls, 1);

      // Invalidate Riverpod only — the cache still holds the value.
      container.invalidate(activeCategoriesProvider);
      await container.read(activeCategoriesProvider.future);

      // No additional repo call: served from CachedRemoteReader's cache.
      expect(repo.activeCalls, 1);
    });

    test('CategoryTreeInvalidation forces a fresh fetch', () async {
      final repo = _CountingCategoryRepo();
      final container = _makeContainer(repo);

      await container.read(activeCategoriesProvider.future);
      expect(repo.activeCalls, 1);

      container.read(catalogInvalidatorProvider).applyToContainer(
        container,
        const [CategoryTreeInvalidation()],
      );
      await container.read(activeCategoriesProvider.future);
      expect(repo.activeCalls, 2);
    });
  });

  group('defaultCategoryProvider caching', () {
    test('cached after first read', () async {
      final repo = _CountingCategoryRepo();
      final container = _makeContainer(repo);

      await container.read(defaultCategoryProvider.future);
      expect(repo.defaultCalls, 1);

      container.invalidate(defaultCategoryProvider);
      await container.read(defaultCategoryProvider.future);
      expect(repo.defaultCalls, 1);
    });

    test('CategoryTreeInvalidation refetches', () async {
      final repo = _CountingCategoryRepo();
      final container = _makeContainer(repo);

      await container.read(defaultCategoryProvider.future);
      container.read(catalogInvalidatorProvider).applyToContainer(
        container,
        const [CategoryTreeInvalidation()],
      );
      await container.read(defaultCategoryProvider.future);
      expect(repo.defaultCalls, 2);
    });
  });

  group('drawerCategoriesProvider caching with includeHidden axis', () {
    test('visible-only and all-items have separate cache slots; flipping back '
        'to visible reuses the cache', () async {
      final repo = _CountingCategoryRepo();
      final container = _makeContainer(repo);

      // visible (includeHidden = false)
      await container.read(drawerCategoriesProvider.future);
      expect(repo.activeCalls, 1);
      expect(repo.activeIncludeHidden, [false]);

      // flip to all (includeHidden = true) → fresh fetch
      container.read(editModeProvider.notifier).state = true;
      await container.read(drawerCategoriesProvider.future);
      expect(repo.activeCalls, 2);
      expect(repo.activeIncludeHidden, [false, true]);

      // flip back to visible → cached, no extra fetch
      container.read(editModeProvider.notifier).state = false;
      await container.read(drawerCategoriesProvider.future);
      expect(repo.activeCalls, 2);
    });

    test(
      'CategoryTreeInvalidation clears both visible and all variants',
      () async {
        final repo = _CountingCategoryRepo();
        final container = _makeContainer(repo);

        // Seed both variants.
        await container.read(drawerCategoriesProvider.future);
        container.read(editModeProvider.notifier).state = true;
        await container.read(drawerCategoriesProvider.future);
        container.read(editModeProvider.notifier).state = false;
        await container.read(drawerCategoriesProvider.future);
        expect(repo.activeCalls, 2);

        // Tree invalidation: both prefixes wiped.
        container.read(catalogInvalidatorProvider).applyToContainer(
          container,
          const [CategoryTreeInvalidation()],
        );
        await container.read(drawerCategoriesProvider.future);
        container.read(editModeProvider.notifier).state = true;
        await container.read(drawerCategoriesProvider.future);
        expect(repo.activeCalls, 4);
      },
    );
  });

  group('categoryBySlugProvider caching', () {
    test(
      'per-slug cache; CategoryBySlugInvalidation clears only that slug',
      () async {
        final repo = _CountingCategoryRepo();
        final container = _makeContainer(repo);

        await container.read(categoryBySlugProvider('shoes').future);
        await container.read(categoryBySlugProvider('hats').future);
        expect(repo.slugCalls, ['shoes', 'hats']);

        // Re-read both — should be cache hits.
        container.invalidate(categoryBySlugProvider('shoes'));
        container.invalidate(categoryBySlugProvider('hats'));
        await container.read(categoryBySlugProvider('shoes').future);
        await container.read(categoryBySlugProvider('hats').future);
        expect(repo.slugCalls, ['shoes', 'hats']);

        // Invalidate only "shoes"; "hats" stays cached.
        container.read(catalogInvalidatorProvider).applyToContainer(
          container,
          const [CategoryBySlugInvalidation('shoes')],
        );
        await container.read(categoryBySlugProvider('shoes').future);
        await container.read(categoryBySlugProvider('hats').future);
        expect(repo.slugCalls, ['shoes', 'hats', 'shoes']);
      },
    );

    test(
      'CategoryTreeInvalidation also clears categoryBySlug entries',
      () async {
        final repo = _CountingCategoryRepo();
        final container = _makeContainer(repo);

        await container.read(categoryBySlugProvider('shoes').future);
        expect(repo.slugCalls, ['shoes']);

        container.read(catalogInvalidatorProvider).applyToContainer(
          container,
          const [CategoryTreeInvalidation()],
        );
        await container.read(categoryBySlugProvider('shoes').future);
        expect(repo.slugCalls, ['shoes', 'shoes']);
      },
    );
  });
}
