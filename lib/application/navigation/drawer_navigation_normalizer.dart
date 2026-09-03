import 'drawer_navigation_models.dart';

class DrawerNavigationNormalizer {
  const DrawerNavigationNormalizer();

  DrawerNavigationNormalizedResult normalize({
    required DrawerNavigationMenuData menu,
    required List<DrawerNavigationItemData> items,
  }) {
    final ignoredIssues = <DrawerNavigationIgnoredIssue>[];
    final validItems = <DrawerNavigationItemData>[];

    for (final item in items) {
      final validationIssue = _validateItem(item, menuId: menu.id);
      if (validationIssue != null) {
        ignoredIssues.add(validationIssue);
        continue;
      }
      validItems.add(item);
    }

    if (validItems.isEmpty) {
      return DrawerNavigationNormalizedResult.unusable(
        fallbackReason: DrawerNavigationFallbackReason.noValidRoots,
        ignoredIssues: ignoredIssues,
      );
    }

    final itemsById = <String, DrawerNavigationItemData>{
      for (final item in validItems) item.id: item,
    };
    final childrenByParentId = <String?, List<DrawerNavigationItemData>>{};

    for (final item in validItems) {
      final parentId = item.parentId;
      if (parentId == null || parentId.isEmpty) {
        childrenByParentId.putIfAbsent(null, () => []).add(item);
        continue;
      }

      final parent = itemsById[parentId];
      if (parent == null) {
        ignoredIssues.add(
          DrawerNavigationIgnoredIssue(itemId: item.id, reason: 'orphan'),
        );
        continue;
      }

      if (parent.menuId != item.menuId) {
        ignoredIssues.add(
          DrawerNavigationIgnoredIssue(
            itemId: item.id,
            reason: 'cross_menu_parent',
          ),
        );
        continue;
      }

      childrenByParentId.putIfAbsent(parentId, () => []).add(item);
    }

    final rootItems = childrenByParentId[null] ?? const [];
    if (rootItems.isEmpty) {
      return DrawerNavigationNormalizedResult.unusable(
        fallbackReason: DrawerNavigationFallbackReason.treeInvalid,
        ignoredIssues: ignoredIssues,
      );
    }

    final roots = <DrawerNavigationNode>[];
    for (final root in rootItems) {
      final node = _buildNode(
        root,
        childrenByParentId: childrenByParentId,
        depth: 0,
        visiting: <String>{},
        ignoredIssues: ignoredIssues,
      );
      if (node != null) {
        roots.add(node);
      }
    }

    if (roots.isEmpty) {
      return DrawerNavigationNormalizedResult.unusable(
        fallbackReason: DrawerNavigationFallbackReason.treeInvalid,
        ignoredIssues: ignoredIssues,
      );
    }

    return DrawerNavigationNormalizedResult.usable(
      roots: roots,
      ignoredIssues: ignoredIssues,
    );
  }

  DrawerNavigationIgnoredIssue? _validateItem(
    DrawerNavigationItemData item, {
    required String menuId,
  }) {
    if (item.id.isEmpty) {
      return const DrawerNavigationIgnoredIssue(
        itemId: '',
        reason: 'missing_id',
      );
    }

    if (item.menuId != menuId) {
      return DrawerNavigationIgnoredIssue(
        itemId: item.id,
        reason: 'wrong_menu',
      );
    }

    if (item.label.trim().isEmpty) {
      return DrawerNavigationIgnoredIssue(
        itemId: item.id,
        reason: 'missing_label',
      );
    }

    if (item.itemType == DrawerNavigationItemType.unknown) {
      return DrawerNavigationIgnoredIssue(
        itemId: item.id,
        reason: 'unknown_item_type',
      );
    }

    if (item.placement == DrawerNavigationPlacement.unknown) {
      return DrawerNavigationIgnoredIssue(
        itemId: item.id,
        reason: 'unknown_placement',
      );
    }

    final hasCategory = item.categoryId != null && item.categoryId!.isNotEmpty;
    final hasProduct = item.productId != null && item.productId!.isNotEmpty;
    final hasPageKey = item.pageKey != null && item.pageKey!.trim().isNotEmpty;
    final hasUrl = item.url != null && item.url!.trim().isNotEmpty;

    return switch (item.itemType) {
      DrawerNavigationItemType.category =>
        hasCategory && !hasProduct && !hasPageKey && !hasUrl
            ? null
            : DrawerNavigationIgnoredIssue(
                itemId: item.id,
                reason: 'invalid_category_target',
              ),
      DrawerNavigationItemType.product =>
        hasProduct && !hasCategory && !hasPageKey && !hasUrl
            ? null
            : DrawerNavigationIgnoredIssue(
                itemId: item.id,
                reason: 'invalid_product_target',
              ),
      DrawerNavigationItemType.page =>
        hasPageKey && !hasCategory && !hasProduct && !hasUrl
            ? null
            : DrawerNavigationIgnoredIssue(
                itemId: item.id,
                reason: 'invalid_page_target',
              ),
      DrawerNavigationItemType.external =>
        hasUrl && !hasCategory && !hasProduct && !hasPageKey
            ? null
            : DrawerNavigationIgnoredIssue(
                itemId: item.id,
                reason: 'invalid_external_target',
              ),
      DrawerNavigationItemType.unknown => DrawerNavigationIgnoredIssue(
        itemId: item.id,
        reason: 'unknown_item_type',
      ),
    };
  }

  DrawerNavigationNode? _buildNode(
    DrawerNavigationItemData item, {
    required Map<String?, List<DrawerNavigationItemData>> childrenByParentId,
    required int depth,
    required Set<String> visiting,
    required List<DrawerNavigationIgnoredIssue> ignoredIssues,
  }) {
    if (visiting.contains(item.id)) {
      ignoredIssues.add(
        DrawerNavigationIgnoredIssue(itemId: item.id, reason: 'cycle'),
      );
      return null;
    }

    final nextVisiting = <String>{...visiting, item.id};
    final rawChildren = childrenByParentId[item.id] ?? const [];

    if (depth >= 1) {
      for (final child in rawChildren) {
        ignoredIssues.add(
          DrawerNavigationIgnoredIssue(
            itemId: child.id,
            reason: 'depth_truncated',
          ),
        );
      }
      return DrawerNavigationNode(item: item);
    }

    final builtChildren = <DrawerNavigationNode>[];
    for (final child in rawChildren) {
      final builtChild = _buildNode(
        child,
        childrenByParentId: childrenByParentId,
        depth: depth + 1,
        visiting: nextVisiting,
        ignoredIssues: ignoredIssues,
      );
      if (builtChild != null) {
        builtChildren.add(builtChild);
      }
    }

    return DrawerNavigationNode(item: item, children: builtChildren);
  }
}
