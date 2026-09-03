import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_normalizer.dart';

void main() {
  const menu = DrawerNavigationMenuData(
    id: 'menu-1',
    name: 'Main drawer',
    code: 'main_drawer',
    displayMode: 'drawer',
    isActive: true,
  );
  const normalizer = DrawerNavigationNormalizer();

  test('builds a usable two-level tree and truncates deeper descendants', () {
    const root = DrawerNavigationItemData(
      id: 'root-1',
      menuId: 'menu-1',
      position: 10,
      label: 'Cadeaux',
      itemType: DrawerNavigationItemType.page,
      pageKey: 'gifts',
      placement: DrawerNavigationPlacement.nav,
      desktopDrawerTemplate: DrawerNavigationDesktopTemplate.promoGrid2x2,
      isActive: true,
      isHidden: false,
    );
    const child = DrawerNavigationItemData(
      id: 'child-1',
      menuId: 'menu-1',
      parentId: 'root-1',
      position: 10,
      label: 'Découvrez les cadeaux',
      itemType: DrawerNavigationItemType.page,
      pageKey: 'gifts_discover',
      placement: DrawerNavigationPlacement.nav,
      isActive: true,
      isHidden: false,
    );
    const grandChild = DrawerNavigationItemData(
      id: 'grandchild-1',
      menuId: 'menu-1',
      parentId: 'child-1',
      position: 10,
      label: 'Profondeur 3',
      itemType: DrawerNavigationItemType.page,
      pageKey: 'depth_3',
      placement: DrawerNavigationPlacement.nav,
      isActive: true,
      isHidden: false,
    );

    final result = normalizer.normalize(
      menu: menu,
      items: const [root, child, grandChild],
    );

    expect(result.isUsable, isTrue);
    expect(result.roots, hasLength(1));
    expect(result.roots.single.children, hasLength(1));
    expect(result.roots.single.children.single.children, isEmpty);
    expect(
      result.ignoredIssues.any((issue) => issue.reason == 'depth_truncated'),
      isTrue,
    );
  });

  test('ignores orphan and cross-menu items without global fallback', () {
    const root = DrawerNavigationItemData(
      id: 'root-1',
      menuId: 'menu-1',
      position: 10,
      label: 'Mode femme',
      itemType: DrawerNavigationItemType.page,
      pageKey: 'women',
      placement: DrawerNavigationPlacement.nav,
      isActive: true,
      isHidden: false,
    );
    const orphan = DrawerNavigationItemData(
      id: 'orphan-1',
      menuId: 'menu-1',
      parentId: 'missing-parent',
      position: 20,
      label: 'Orphelin',
      itemType: DrawerNavigationItemType.page,
      pageKey: 'orphan',
      placement: DrawerNavigationPlacement.nav,
      isActive: true,
      isHidden: false,
    );
    const wrongMenu = DrawerNavigationItemData(
      id: 'wrong-menu',
      menuId: 'menu-2',
      position: 30,
      label: 'Autre menu',
      itemType: DrawerNavigationItemType.page,
      pageKey: 'other',
      placement: DrawerNavigationPlacement.nav,
      isActive: true,
      isHidden: false,
    );

    final result = normalizer.normalize(
      menu: menu,
      items: const [root, orphan, wrongMenu],
    );

    expect(result.isUsable, isTrue);
    expect(result.roots, hasLength(1));
    expect(
      result.ignoredIssues.map((issue) => issue.reason),
      containsAll(<String>['orphan', 'wrong_menu']),
    );
  });

  test('falls back with treeInvalid when no root can be reconstructed', () {
    const a = DrawerNavigationItemData(
      id: 'a',
      menuId: 'menu-1',
      parentId: 'b',
      position: 10,
      label: 'A',
      itemType: DrawerNavigationItemType.page,
      pageKey: 'a',
      placement: DrawerNavigationPlacement.nav,
      isActive: true,
      isHidden: false,
    );
    const b = DrawerNavigationItemData(
      id: 'b',
      menuId: 'menu-1',
      parentId: 'a',
      position: 20,
      label: 'B',
      itemType: DrawerNavigationItemType.page,
      pageKey: 'b',
      placement: DrawerNavigationPlacement.nav,
      isActive: true,
      isHidden: false,
    );

    final result = normalizer.normalize(menu: menu, items: const [a, b]);

    expect(result.isUsable, isFalse);
    expect(result.fallbackReason, DrawerNavigationFallbackReason.treeInvalid);
  });
}
