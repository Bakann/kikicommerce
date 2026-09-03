import '../../../../app/catalog_routes.dart';
import '../../../../application/cms/cms_models.dart';
import '../../../../application/navigation/drawer_navigation_models.dart';
import '../../../../domain/catalog/catalog_entities.dart';
import '../../drawer/managed_drawer_widgets.dart'
    show resolveAction, findRootIdForCategory;

/// Resolves the banner items rendered by a `category_banner_strip` section.
///
/// Pure, side-effect-free. The host widget owns the wiring (Riverpod, etc.);
/// this function only consumes the data and turns it into a list of items
/// the visual section widget can render as-is. The section always mirrors
/// the live drawer — and the drawer's `displayMode` drives which backing
/// collection feeds the list:
///
/// - `displayMode = drawer` → navigation_items (via [drawerResult]).
/// - `displayMode = categories` → categories collection (via [categories]).
List<CategoryBannerItem> resolveCategoryBannerItems({
  required DrawerNavigationLoadResult? drawerResult,
  required List<CatalogCategory>? categories,
  required bool includeHidden,
  Map<String, CategoryBannerAppearance> appearanceById = const {},
}) {
  return resolveCategoryBannerEntries(
    drawerResult: drawerResult,
    categories: categories,
    includeHidden: includeHidden,
    appearanceById: appearanceById,
  ).map((e) => e.bannerItem).toList(growable: false);
}

List<CategoryBannerItem> resolveCategoryChildrenBannerItems({
  required List<CatalogCategory>? categories,
  required String parentId,
  required bool includeHidden,
  Map<String, CategoryBannerAppearance> appearanceById = const {},
}) {
  return resolveCategoryChildrenBannerEntries(
    categories: categories,
    parentId: parentId,
    includeHidden: includeHidden,
    appearanceById: appearanceById,
  ).map((e) => e.bannerItem).toList(growable: false);
}

List<CategoryBannerEntry> resolveCategoryChildrenBannerEntries({
  required List<CatalogCategory>? categories,
  required String parentId,
  required bool includeHidden,
  Map<String, CategoryBannerAppearance> appearanceById = const {},
}) {
  final normalizedParentId = parentId.trim();
  if (normalizedParentId.isEmpty || categories == null || categories.isEmpty) {
    return const [];
  }

  final children =
      categories
          .where((category) => category.parentId?.trim() == normalizedParentId)
          .where((category) => includeHidden || !category.isHidden)
          .toList(growable: false)
        ..sort((a, b) {
          final positionCompare = a.position.compareTo(b.position);
          if (positionCompare != 0) return positionCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

  return children
      .map(
        (category) => CategoryBannerEntry(
          id: category.id,
          label: category.name,
          isHidden: category.isHidden,
          bannerItem: _bannerItemFromCategory(
            category,
          ).withAppearance(appearanceById[category.id]),
        ),
      )
      .toList(growable: false);
}

/// Resolver entry that preserves the source-side metadata so the admin
/// preview can render visibility/order hints next to each row.
class CategoryBannerEntry {
  final String id;
  final String label;
  final bool isHidden;
  final CategoryBannerItem bannerItem;

  const CategoryBannerEntry({
    required this.id,
    required this.label,
    required this.isHidden,
    required this.bannerItem,
  });
}

List<CategoryBannerEntry> resolveCategoryBannerEntries({
  required DrawerNavigationLoadResult? drawerResult,
  required List<CatalogCategory>? categories,
  required bool includeHidden,
  Map<String, CategoryBannerAppearance> appearanceById = const {},
}) {
  final liveSource = drawerResult?.menu?.liveSource;
  if (liveSource == DrawerLiveSource.categories) {
    return _categoryEntries(
      categories: categories,
      includeHidden: includeHidden,
      appearanceById: appearanceById,
    );
  }
  return _navigationEntries(
    drawerResult: drawerResult,
    includeHidden: includeHidden,
    appearanceById: appearanceById,
  );
}

List<CategoryBannerEntry> _navigationEntries({
  required DrawerNavigationLoadResult? drawerResult,
  required bool includeHidden,
  required Map<String, CategoryBannerAppearance> appearanceById,
}) {
  if (drawerResult == null) return const [];
  final normalized = drawerResult.normalized;
  if (normalized == null) return const [];

  final entries = <CategoryBannerEntry>[];
  for (final root in normalized.roots) {
    final item = root.item;
    if (!includeHidden && item.isHidden) continue;
    entries.add(
      CategoryBannerEntry(
        id: item.id,
        label: item.label,
        isHidden: item.isHidden,
        bannerItem: _bannerItemFromDrawer(
          item,
        ).withAppearance(appearanceById[item.id]),
      ),
    );
  }
  return entries;
}

List<CategoryBannerEntry> _categoryEntries({
  required List<CatalogCategory>? categories,
  required bool includeHidden,
  required Map<String, CategoryBannerAppearance> appearanceById,
}) {
  if (categories == null || categories.isEmpty) return const [];

  // Only top-level categories feed the banner strip: nested categories
  // surface inside the drawer's second column, not as standalone banners.
  final categoriesById = <String, CatalogCategory>{
    for (final category in categories) category.id: category,
  };
  final entries = <CategoryBannerEntry>[];
  for (final category in categories) {
    final parentId = category.parentId?.trim();
    final hasParent =
        parentId != null &&
        parentId.isNotEmpty &&
        categoriesById.containsKey(parentId);
    if (hasParent) continue;
    if (!includeHidden && category.isHidden) continue;
    entries.add(
      CategoryBannerEntry(
        id: category.id,
        label: category.name,
        isHidden: category.isHidden,
        bannerItem: _bannerItemFromCategory(
          category,
        ).withAppearance(appearanceById[category.id]),
      ),
    );
  }
  return entries;
}

CategoryBannerItem _bannerItemFromDrawer(DrawerNavigationItemData item) {
  final action = resolveAction(item);
  final href = action.routeName ?? action.externalUrl ?? '';
  return CategoryBannerItem(
    code: item.id,
    title: item.label,
    href: href,
    nodeId: item.id,
    categoryId: item.categoryId,
  );
}

CategoryBannerItem _bannerItemFromCategory(CatalogCategory category) {
  return CategoryBannerItem(
    code: category.id,
    title: category.name,
    href: CatalogRoutes.categoryLocation(category),
    categoryId: category.id,
  );
}

/// Whether tapping [item] should open the drawer drilled into its children,
/// rather than navigating to its PLP.
///
/// Mirrors the active drawer mode so the decision matches what the drawer
/// would actually show:
/// - managed navigation: resolves the target root (by node id, then category
///   id) and checks it has children;
/// - category fallback: checks the target category has sub-categories.
///
/// Returns `false` only when the target can be confirmed to have no drillable
/// children (so the caller falls back to PLP navigation). When the backing
/// data is not loaded yet, returns `true` and lets the drawer's own consume
/// step guard the no-children case.
bool categoryBannerDrillHasChildren({
  required CategoryBannerItem item,
  required DrawerNavigationLoadResult? drawerResult,
  required List<CatalogCategory>? categories,
}) {
  if (item.categoryId == null && item.nodeId == null) {
    return false;
  }
  if (drawerResult == null) {
    return true; // drawer data not loaded yet → stay optimistic
  }

  final isManaged =
      drawerResult.menu?.liveSource != DrawerLiveSource.categories &&
      drawerResult.isUsable;
  if (isManaged) {
    final roots =
        drawerResult.normalized?.roots ?? const <DrawerNavigationNode>[];
    final nodeId = item.nodeId;
    final rootId = (nodeId != null && roots.any((r) => r.item.id == nodeId))
        ? nodeId
        : findRootIdForCategory(roots, item.categoryId);
    if (rootId == null) {
      return false;
    }
    final matching = roots.where((root) => root.item.id == rootId);
    return matching.isNotEmpty && matching.first.children.isNotEmpty;
  }

  final categoryId = item.categoryId;
  if (categoryId == null) {
    return false;
  }
  if (categories == null) {
    return true; // categories not loaded yet → stay optimistic
  }
  return categories.any((category) => category.parentId?.trim() == categoryId);
}
