import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/application/catalog/plp_parent_routing.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

CatalogCategory _category({
  required String id,
  String? slug,
  String? parentId,
}) {
  return CatalogCategory(
    id: id,
    code: id.toUpperCase(),
    name: id,
    slug: slug,
    parentId: parentId,
  );
}

void main() {
  group('PlpParentRouting.resolveParentLocation', () {
    const catalogBase = CatalogRoutes.catalogBase;

    test('resolves the real parent category from parentId', () {
      final shirts = _category(
        id: 'shirts',
        slug: 'shirts',
        parentId: 'summer',
      );
      final summer = _category(id: 'summer', slug: 'summer');

      final location = PlpParentRouting.resolveParentLocation(
        currentUri: Uri.parse('/catalog/shirts'),
        catalogBaseLocation: catalogBase,
        currentCategory: shirts,
        availableCategories: [shirts, summer],
      );

      expect(location, '/catalog/summer');
    });

    test('business parent wins over the URL-only fallback on a deep route', () {
      // The URL parent segment ("winter") differs from the real business parent
      // ("summer"). The catalog parent page must come from the category data.
      final shirts = _category(
        id: 'shirts',
        slug: 'shirts',
        parentId: 'summer',
      );
      final summer = _category(id: 'summer', slug: 'summer');

      final location = PlpParentRouting.resolveParentLocation(
        currentUri: Uri.parse('/catalog/winter/shirts'),
        catalogBaseLocation: catalogBase,
        currentCategory: shirts,
        availableCategories: [shirts, summer],
      );

      expect(location, '/catalog/summer');
    });

    test('resolves the parent of an empty category via currentCategoryId', () {
      // Empty PLP: no product item to derive the current category from. The
      // resolver must still find it (and its parent) among the categories.
      final shirts = _category(
        id: 'shirts',
        slug: 'shirts',
        parentId: 'summer',
      );
      final summer = _category(id: 'summer', slug: 'summer');

      final location = PlpParentRouting.resolveParentLocation(
        currentUri: Uri.parse('/catalog/shirts'),
        catalogBaseLocation: catalogBase,
        currentCategory: null,
        currentCategoryId: 'shirts',
        availableCategories: [shirts, summer],
      );

      expect(location, '/catalog/summer');
    });

    test('feed category wins over the currentCategoryId lookup', () {
      // When both are available the feed category is authoritative.
      final feedCurrent = _category(
        id: 'shirts',
        slug: 'shirts',
        parentId: 'summer',
      );
      final staleCurrent = _category(
        id: 'shirts',
        slug: 'shirts',
        parentId: 'winter',
      );
      final summer = _category(id: 'summer', slug: 'summer');
      final winter = _category(id: 'winter', slug: 'winter');

      final location = PlpParentRouting.resolveParentLocation(
        currentUri: Uri.parse('/catalog/shirts'),
        catalogBaseLocation: catalogBase,
        currentCategory: feedCurrent,
        currentCategoryId: 'shirts',
        availableCategories: [staleCurrent, summer, winter],
      );

      expect(location, '/catalog/summer');
    });

    test('preserves a multi-segment catalog base prefix', () {
      final shirts = _category(
        id: 'shirts',
        slug: 'shirts',
        parentId: 'summer',
      );
      final summer = _category(id: 'summer', slug: 'summer');

      final location = PlpParentRouting.resolveParentLocation(
        currentUri: Uri.parse('/shop/catalog/shirts'),
        catalogBaseLocation: '/shop/catalog',
        currentCategory: shirts,
        availableCategories: [shirts, summer],
      );

      expect(location, '/shop/catalog/summer');
    });

    test('falls back to URL-only parent when no business parent exists', () {
      // Category has no parentId, so there is nothing reliable to resolve.
      final shirts = _category(id: 'shirts', slug: 'shirts');

      final location = PlpParentRouting.resolveParentLocation(
        currentUri: Uri.parse('/catalog/summer/shirts'),
        catalogBaseLocation: catalogBase,
        currentCategory: shirts,
        availableCategories: [shirts],
      );

      expect(location, '/catalog/summer');
    });

    test('falls back to URL-only when the parent is not among categories', () {
      final shirts = _category(
        id: 'shirts',
        slug: 'shirts',
        parentId: 'summer',
      );

      final location = PlpParentRouting.resolveParentLocation(
        currentUri: Uri.parse('/catalog/summer/shirts'),
        catalogBaseLocation: catalogBase,
        currentCategory: shirts,
        availableCategories: [shirts],
      );

      expect(location, '/catalog/summer');
    });

    test(
      'sport routes stay on the URL-only fallback, never a catalog page',
      () {
        // Even with a resolvable business parent, the segment-driven sport tree
        // walks up the URL rather than jumping into the /catalog namespace.
        final boots = _category(
          id: 'boots',
          slug: 'boots',
          parentId: 'footwear',
        );
        final footwear = _category(id: 'footwear', slug: 'footwear');

        final location = PlpParentRouting.resolveParentLocation(
          currentUri: Uri.parse('/sport/homme/boots'),
          catalogBaseLocation: catalogBase,
          currentCategory: boots,
          availableCategories: [boots, footwear],
        );

        expect(location, '/sport/homme');
      },
    );

    test('single-segment route falls back to the catalog base', () {
      final location = PlpParentRouting.resolveParentLocation(
        currentUri: Uri.parse('/sport'),
        catalogBaseLocation: catalogBase,
        currentCategory: null,
        availableCategories: const [],
      );

      expect(location, catalogBase);
    });

    test('keeps only portable query params on the business parent', () {
      final shirts = _category(
        id: 'shirts',
        slug: 'shirts',
        parentId: 'summer',
      );
      final summer = _category(id: 'summer', slug: 'summer');

      final location = PlpParentRouting.resolveParentLocation(
        currentUri: Uri.parse(
          '/catalog/shirts?sort=price&view=grid&size=42&surface=fg',
        ),
        catalogBaseLocation: catalogBase,
        currentCategory: shirts,
        availableCategories: [shirts, summer],
      );

      final uri = Uri.parse(location);
      expect(uri.path, '/catalog/summer');
      expect(uri.queryParameters, {'sort': 'price', 'view': 'grid'});
    });

    test('encodes the resolved parent slug', () {
      final running = _category(
        id: 'running',
        slug: 'running',
        parentId: 'cafe',
      );
      final cafe = _category(id: 'cafe', slug: 'café');

      final location = PlpParentRouting.resolveParentLocation(
        currentUri: Uri.parse('/catalog/running'),
        catalogBaseLocation: catalogBase,
        currentCategory: running,
        availableCategories: [running, cafe],
      );

      expect(location, '/catalog/caf%C3%A9');
    });
  });
}
