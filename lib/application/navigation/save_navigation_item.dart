import '../admin/save_admin_record.dart';
import 'drawer_navigation_models.dart';

class NavigationItemValidationException implements Exception {
  final String message;

  const NavigationItemValidationException(this.message);

  @override
  String toString() => 'NavigationItemValidationException: $message';
}

class SaveNavigationItemInput {
  final String menuId;
  final String? parentId;
  final int position;
  final int depth;
  final String label;
  final DrawerNavigationItemType itemType;
  final String? categoryId;
  final String? productId;
  final String? pageKey;
  final String? url;
  final String? promoMediaId;
  final DrawerNavigationPlacement placement;
  final DrawerNavigationDesktopTemplate desktopTemplate;
  final bool isActive;
  final bool isHidden;
  final Map<String, dynamic> config;
  final String? recordId;

  const SaveNavigationItemInput({
    required this.menuId,
    required this.position,
    required this.depth,
    required this.label,
    required this.itemType,
    required this.placement,
    required this.desktopTemplate,
    required this.isActive,
    required this.isHidden,
    this.config = const {},
    this.parentId,
    this.categoryId,
    this.productId,
    this.pageKey,
    this.url,
    this.promoMediaId,
    this.recordId,
  });
}

class SaveNavigationItem {
  final SaveAdminRecord saveAdminRecord;

  const SaveNavigationItem(this.saveAdminRecord);

  Future<void> call({
    required String baseUrl,
    required String authToken,
    required SaveNavigationItemInput input,
  }) async {
    _validate(input);

    await saveAdminRecord(
      baseUrl: baseUrl,
      authToken: authToken,
      collection: 'navigation_items',
      recordId: input.recordId,
      data: buildNavigationItemPayload(input),
    );
  }

  void _validate(SaveNavigationItemInput input) {
    if (input.label.trim().isEmpty) {
      throw const NavigationItemValidationException('Label required');
    }

    switch (input.itemType) {
      case DrawerNavigationItemType.category:
        if ((input.categoryId ?? '').isEmpty) {
          throw const NavigationItemValidationException(
            'category target required when itemType=category',
          );
        }
        break;
      case DrawerNavigationItemType.product:
        if ((input.productId ?? '').isEmpty) {
          throw const NavigationItemValidationException(
            'product target required when itemType=product',
          );
        }
        break;
      case DrawerNavigationItemType.page:
        final hasPageKey = (input.pageKey ?? '').trim().isNotEmpty;
        final hasUrl = (input.url ?? '').trim().isNotEmpty;
        if (!hasPageKey && !hasUrl) {
          throw const NavigationItemValidationException(
            'pageKey or url required when itemType=page',
          );
        }
        break;
      case DrawerNavigationItemType.external:
        if ((input.url ?? '').trim().isEmpty) {
          throw const NavigationItemValidationException(
            'url required when itemType=external',
          );
        }
        break;
      case DrawerNavigationItemType.unknown:
        throw const NavigationItemValidationException('itemType is unknown');
    }

    if (input.placement == DrawerNavigationPlacement.promo &&
        (input.promoMediaId ?? '').isEmpty) {
      throw const NavigationItemValidationException(
        'promoMedia required when placement=promo',
      );
    }
  }
}

Map<String, dynamic> buildNavigationItemPayload(SaveNavigationItemInput input) {
  return {
    'menu': input.menuId,
    'parent': input.parentId,
    'position': input.position,
    'label': input.label.trim(),
    'itemType': input.itemType.name,
    'category': input.itemType == DrawerNavigationItemType.category
        ? input.categoryId
        : null,
    'product': input.itemType == DrawerNavigationItemType.product
        ? input.productId
        : null,
    'pageKey': input.itemType == DrawerNavigationItemType.page
        ? (input.pageKey ?? '').trim()
        : null,
    'url': input.itemType == DrawerNavigationItemType.external
        ? (input.url ?? '').trim()
        : null,
    'promoMedia': input.promoMediaId,
    'placement': input.placement.name,
    'desktopDrawerTemplate': input.depth == 0
        ? desktopTemplateWireValue(input.desktopTemplate)
        : null,
    'config': input.config,
    'isActive': input.isActive,
    'isHidden': input.isHidden,
  };
}

String desktopTemplateWireValue(DrawerNavigationDesktopTemplate template) {
  return switch (template) {
    DrawerNavigationDesktopTemplate.listOnly => 'list_only',
    DrawerNavigationDesktopTemplate.heroSingle => 'hero_single',
    DrawerNavigationDesktopTemplate.promoGrid2x2 => 'promo_grid_2x2',
    DrawerNavigationDesktopTemplate.promoStack2 => 'promo_stack_2',
  };
}
