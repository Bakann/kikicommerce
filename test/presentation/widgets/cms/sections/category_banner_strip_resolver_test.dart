import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_normalizer.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/category_banner_strip_resolver.dart';

DrawerNavigationItemData _treeItem({
  required String id,
  String? parentId,
  String? categoryId,
  int position = 10,
}) {
  return DrawerNavigationItemData(
    id: id,
    menuId: 'menu-1',
    parentId: parentId,
    position: position,
    label: id,
    itemType: DrawerNavigationItemType.category,
    placement: DrawerNavigationPlacement.nav,
    isActive: true,
    isHidden: false,
    categoryId: categoryId,
    category: categoryId == null
        ? null
        : CatalogCategory(id: categoryId, code: id, name: id, slug: id),
  );
}

DrawerNavigationItemData _navItem({
  required String id,
  required String label,
  required int position,
  bool isHidden = false,
}) {
  final categoryId = 'cat-$id';
  return DrawerNavigationItemData(
    id: id,
    menuId: 'menu-1',
    position: position,
    label: label,
    itemType: DrawerNavigationItemType.category,
    placement: DrawerNavigationPlacement.nav,
    isActive: true,
    isHidden: isHidden,
    categoryId: categoryId,
    category: CatalogCategory(id: categoryId, code: id, name: label, slug: id),
  );
}

DrawerNavigationLoadResult _drawer({
  required String displayMode,
  required List<DrawerNavigationItemData> items,
}) {
  final menu = DrawerNavigationMenuData(
    id: 'menu-1',
    name: 'Main',
    code: 'main_drawer',
    displayMode: displayMode,
    isActive: true,
  );
  final normalized = const DrawerNavigationNormalizer().normalize(
    menu: menu,
    items: items,
  );
  return DrawerNavigationLoadResult.success(menu: menu, normalized: normalized);
}

CatalogCategory _category({
  required String id,
  required String name,
  bool isHidden = false,
  String? parentId,
  int position = 0,
}) {
  return CatalogCategory(
    id: id,
    code: id.toUpperCase(),
    name: name,
    slug: id,
    isActive: true,
    isHidden: isHidden,
    parentId: parentId,
    position: position,
  );
}

void main() {
  group('resolveCategoryBannerItems (navigation mode)', () {
    test('mirrors visible drawer root items in order', () {
      final result = _drawer(
        displayMode: 'drawer',
        items: [
          _navItem(id: 'a', label: 'Mode homme', position: 10),
          _navItem(id: 'b', label: 'Mode fille', position: 20),
          _navItem(id: 'c', label: 'Caché', position: 30, isHidden: true),
        ],
      );

      final items = resolveCategoryBannerItems(
        drawerResult: result,
        categories: null,
        includeHidden: false,
      );

      expect(items.map((e) => e.title), ['Mode homme', 'Mode fille']);
    });

    test('null drawer result yields empty items', () {
      final items = resolveCategoryBannerItems(
        drawerResult: null,
        categories: null,
        includeHidden: false,
      );
      expect(items, isEmpty);
    });
  });

  group('resolveCategoryBannerItems (categories mode)', () {
    test('mirrors visible top-level categories', () {
      final result = _drawer(displayMode: 'categories', items: const []);
      final categories = [
        _category(id: 'jean', name: 'Jean De Nîmes'),
        _category(id: 'fleurs', name: 'Les fleurs'),
        _category(id: 'cadeaux', name: 'Cadeaux', isHidden: true),
      ];

      final items = resolveCategoryBannerItems(
        drawerResult: result,
        categories: categories,
        includeHidden: false,
      );

      expect(items.map((e) => e.title), ['Jean De Nîmes', 'Les fleurs']);
      expect(items.first.href, contains('jean'));
    });

    test('excludes nested children even when includeHidden=true', () {
      final result = _drawer(displayMode: 'categories', items: const []);
      final categories = [
        _category(id: 'jean', name: 'Jean De Nîmes'),
        _category(id: 'jean-slim', name: 'Slim', parentId: 'jean'),
      ];

      final items = resolveCategoryBannerItems(
        drawerResult: result,
        categories: categories,
        includeHidden: true,
      );

      expect(items.map((e) => e.title), ['Jean De Nîmes']);
    });

    test('includeHidden=true keeps hidden top-level categories', () {
      final result = _drawer(displayMode: 'categories', items: const []);
      final categories = [
        _category(id: 'jean', name: 'Jean De Nîmes'),
        _category(id: 'cadeaux', name: 'Cadeaux', isHidden: true),
      ];

      final items = resolveCategoryBannerItems(
        drawerResult: result,
        categories: categories,
        includeHidden: true,
      );

      expect(items.map((e) => e.title), ['Jean De Nîmes', 'Cadeaux']);
    });

    test('null categories list yields empty items', () {
      final result = _drawer(displayMode: 'categories', items: const []);
      final items = resolveCategoryBannerItems(
        drawerResult: result,
        categories: null,
        includeHidden: false,
      );
      expect(items, isEmpty);
    });
  });

  group('resolveCategoryChildrenBannerItems', () {
    test(
      'returns visible children for the configured parent in position order',
      () {
        final categories = [
          _category(id: 'homme', name: 'Homme'),
          _category(
            id: 'running',
            name: 'Running',
            parentId: 'homme',
            position: 20,
          ),
          _category(
            id: 'training',
            name: 'Training',
            parentId: 'homme',
            position: 10,
          ),
          _category(
            id: 'cache',
            name: 'Caché',
            parentId: 'homme',
            position: 30,
            isHidden: true,
          ),
          _category(
            id: 'femme-running',
            name: 'Running femme',
            parentId: 'femme',
          ),
        ];

        final items = resolveCategoryChildrenBannerItems(
          categories: categories,
          parentId: 'homme',
          includeHidden: false,
        );

        expect(items.map((e) => e.title), ['Training', 'Running']);
        expect(items.first.href, contains('training'));
      },
    );

    test('includeHidden=true keeps hidden children', () {
      final categories = [
        _category(id: 'homme', name: 'Homme'),
        _category(
          id: 'cache',
          name: 'Caché',
          parentId: 'homme',
          isHidden: true,
        ),
      ];

      final items = resolveCategoryChildrenBannerItems(
        categories: categories,
        parentId: 'homme',
        includeHidden: true,
      );

      expect(items.map((e) => e.title), ['Caché']);
    });

    test('blank or unknown parent yields empty items', () {
      final categories = [_category(id: 'homme', name: 'Homme')];

      expect(
        resolveCategoryChildrenBannerItems(
          categories: categories,
          parentId: '',
          includeHidden: false,
        ),
        isEmpty,
      );
      expect(
        resolveCategoryChildrenBannerItems(
          categories: categories,
          parentId: 'missing',
          includeHidden: false,
        ),
        isEmpty,
      );
    });
  });

  group('resolveCategoryBannerEntries', () {
    test('preserves isHidden metadata on each entry (navigation)', () {
      final result = _drawer(
        displayMode: 'drawer',
        items: [
          _navItem(id: 'a', label: 'Visible', position: 10),
          _navItem(id: 'b', label: 'Masquée', position: 20, isHidden: true),
        ],
      );

      final entries = resolveCategoryBannerEntries(
        drawerResult: result,
        categories: null,
        includeHidden: true,
      );

      expect(entries, hasLength(2));
      expect(entries[0].isHidden, isFalse);
      expect(entries[1].isHidden, isTrue);
    });

    test('preserves isHidden metadata on each entry (categories)', () {
      final result = _drawer(displayMode: 'categories', items: const []);
      final categories = [
        _category(id: 'jean', name: 'Jean De Nîmes'),
        _category(id: 'cadeaux', name: 'Cadeaux', isHidden: true),
      ];

      final entries = resolveCategoryBannerEntries(
        drawerResult: result,
        categories: categories,
        includeHidden: true,
      );

      expect(entries.map((e) => e.label), ['Jean De Nîmes', 'Cadeaux']);
      expect(entries[1].isHidden, isTrue);
    });
  });

  group('appearance overrides', () {
    const appearance = CategoryBannerAppearance(
      media: CmsMediaRef(
        recordId: 'rec1',
        collectionId: 'col1',
        filename: 'shoe.jpg',
      ),
      gradientStartHex: '#2A3038',
      gradientEndHex: '#5A6470',
    );

    test('navigation mode: applies overrides keyed by nav item id', () {
      final result = _drawer(
        displayMode: 'drawer',
        items: [
          _navItem(id: 'a', label: 'Chaussures', position: 10),
          _navItem(id: 'b', label: 'Vêtements', position: 20),
        ],
      );

      final items = resolveCategoryBannerItems(
        drawerResult: result,
        categories: null,
        includeHidden: false,
        appearanceById: const {'a': appearance},
      );

      expect(items[0].media?.filename, 'shoe.jpg');
      expect(items[0].gradientStartHex, '#2A3038');
      expect(items[0].gradientEndHex, '#5A6470');
      expect(items[1].media, isNull);
      expect(items[1].gradientStartHex, isNull);
    });

    test('categories mode: applies overrides keyed by category id', () {
      final result = _drawer(displayMode: 'categories', items: const []);
      final categories = [
        _category(id: 'jean', name: 'Jean De Nîmes'),
        _category(id: 'fleurs', name: 'Les fleurs'),
      ];

      final items = resolveCategoryBannerItems(
        drawerResult: result,
        categories: categories,
        includeHidden: false,
        appearanceById: const {'fleurs': appearance},
      );

      expect(items[0].media, isNull);
      expect(items[1].media?.filename, 'shoe.jpg');
      expect(items[1].gradientEndHex, '#5A6470');
    });

    test('children mode: applies overrides keyed by child category id', () {
      final categories = [
        _category(id: 'homme', name: 'Homme'),
        _category(
          id: 'running',
          name: 'Running',
          parentId: 'homme',
          position: 10,
        ),
      ];

      final items = resolveCategoryChildrenBannerItems(
        categories: categories,
        parentId: 'homme',
        includeHidden: false,
        appearanceById: const {'running': appearance},
      );

      expect(items.single.gradientStartHex, '#2A3038');
      expect(items.single.media?.filename, 'shoe.jpg');
    });

    test('empty appearance override leaves the item untouched', () {
      final result = _drawer(
        displayMode: 'drawer',
        items: [_navItem(id: 'a', label: 'Chaussures', position: 10)],
      );

      final items = resolveCategoryBannerItems(
        drawerResult: result,
        categories: null,
        includeHidden: false,
        appearanceById: const {'a': CategoryBannerAppearance()},
      );

      expect(items.single.media, isNull);
      expect(items.single.gradientStartHex, isNull);
    });
  });

  group('categoryBannerDrillHasChildren', () {
    DrawerNavigationLoadResult managedDrawer() {
      // root1 has a child, root2 has none.
      return _drawer(
        displayMode: 'drawer',
        items: [
          _treeItem(id: 'root1', categoryId: 'cat-root1', position: 10),
          _treeItem(
            id: 'child1',
            parentId: 'root1',
            categoryId: 'cat-child1',
            position: 10,
          ),
          _treeItem(id: 'root2', categoryId: 'cat-root2', position: 20),
        ],
      );
    }

    test('returns false when the item has no category or node id', () {
      expect(
        categoryBannerDrillHasChildren(
          item: const CategoryBannerItem(title: 'X', href: '/x'),
          drawerResult: managedDrawer(),
          categories: null,
        ),
        isFalse,
      );
    });

    test('stays optimistic (true) while drawer data is not loaded', () {
      expect(
        categoryBannerDrillHasChildren(
          item: const CategoryBannerItem(
            title: 'X',
            href: '/x',
            categoryId: 'cat-root1',
          ),
          drawerResult: null,
          categories: null,
        ),
        isTrue,
      );
    });

    group('managed navigation', () {
      test('true when node id resolves to a root with children', () {
        expect(
          categoryBannerDrillHasChildren(
            item: const CategoryBannerItem(
              title: 'Root1',
              href: '/x',
              nodeId: 'root1',
            ),
            drawerResult: managedDrawer(),
            categories: null,
          ),
          isTrue,
        );
      });

      test('false when node id resolves to a root without children', () {
        expect(
          categoryBannerDrillHasChildren(
            item: const CategoryBannerItem(
              title: 'Root2',
              href: '/x',
              nodeId: 'root2',
            ),
            drawerResult: managedDrawer(),
            categories: null,
          ),
          isFalse,
        );
      });

      test('true when category id resolves to a root with children', () {
        expect(
          categoryBannerDrillHasChildren(
            item: const CategoryBannerItem(
              title: 'Root1',
              href: '/x',
              categoryId: 'cat-root1',
            ),
            drawerResult: managedDrawer(),
            categories: null,
          ),
          isTrue,
        );
      });

      test('false when the target is not in the navigation tree', () {
        expect(
          categoryBannerDrillHasChildren(
            item: const CategoryBannerItem(
              title: 'Ghost',
              href: '/x',
              categoryId: 'cat-missing',
            ),
            drawerResult: managedDrawer(),
            categories: null,
          ),
          isFalse,
        );
      });
    });

    group('category fallback', () {
      final categoriesDrawer = _drawer(
        displayMode: 'categories',
        items: const [],
      );

      test('true when the category has sub-categories', () {
        expect(
          categoryBannerDrillHasChildren(
            item: const CategoryBannerItem(
              title: 'Parent',
              href: '/x',
              categoryId: 'parent',
            ),
            drawerResult: categoriesDrawer,
            categories: [
              _category(id: 'parent', name: 'Parent'),
              _category(id: 'child', name: 'Child', parentId: 'parent'),
            ],
          ),
          isTrue,
        );
      });

      test('false when the category has no sub-categories', () {
        expect(
          categoryBannerDrillHasChildren(
            item: const CategoryBannerItem(
              title: 'Lonely',
              href: '/x',
              categoryId: 'lonely',
            ),
            drawerResult: categoriesDrawer,
            categories: [_category(id: 'lonely', name: 'Lonely')],
          ),
          isFalse,
        );
      });

      test('stays optimistic (true) while categories are not loaded', () {
        expect(
          categoryBannerDrillHasChildren(
            item: const CategoryBannerItem(
              title: 'Parent',
              href: '/x',
              categoryId: 'parent',
            ),
            drawerResult: categoriesDrawer,
            categories: null,
          ),
          isTrue,
        );
      });
    });
  });
}
