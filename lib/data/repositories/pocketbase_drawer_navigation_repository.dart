import 'package:flutter/foundation.dart';

import '../../application/navigation/drawer_navigation_models.dart';
import '../../application/navigation/drawer_navigation_normalizer.dart';
import '../../application/navigation/drawer_navigation_repository.dart';
import '../../core/utils/pocketbase_filter_utils.dart';
import '../api/pocketbase_client.dart';
import '_translation_fetcher.dart';

class PocketBaseDrawerNavigationRepository
    implements DrawerNavigationRepository {
  final PocketBaseClient client;
  final DrawerNavigationNormalizer normalizer;

  const PocketBaseDrawerNavigationRepository({
    required this.client,
    this.normalizer = const DrawerNavigationNormalizer(),
  });

  @override
  Future<DrawerNavigationLoadResult> fetchMainDrawer({
    required String locale,
    bool includeHidden = false,
  }) async {
    try {
      final menuResponse = await client.listRecords<Map<String, dynamic>>(
        'navigation_menus',
        filter: 'code="${escapeFilterValue('main_drawer')}"',
        sort: 'created',
        page: 1,
        perPage: 1,
        fields: 'id,name,code,displayMode,isActive',
        fromJson: (json) => json,
      );

      if (menuResponse.items.isEmpty) {
        _logUnavailable(DrawerNavigationFallbackReason.menuMissing);
        return const DrawerNavigationLoadResult.fallback(
          fallbackReason: DrawerNavigationFallbackReason.menuMissing,
        );
      }

      final menu = DrawerNavigationMenuData.fromJson(menuResponse.items.first);
      if (!menu.isActive) {
        _logUnavailable(DrawerNavigationFallbackReason.menuInactive);
        return DrawerNavigationLoadResult.fallback(
          fallbackReason: DrawerNavigationFallbackReason.menuInactive,
          menu: menu,
        );
      }

      final itemsResponse = await client.listRecords<Map<String, dynamic>>(
        'navigation_items',
        filter: [
          'menu="${escapeFilterValue(menu.id)}"',
          'isActive=true',
          if (!includeHidden) 'isHidden=false',
        ].join(' && '),
        sort: 'position,created',
        expand: 'category,product,promoMedia',
        page: 1,
        perPage: 200,
        fields: _navigationItemFields,
        fromJson: (json) => json,
      );

      // Override the base label with the active-locale translation (if any)
      // before parsing — a missing/blank row leaves the base (FR) label.
      final itemLabels = await fetchNavigationItemLabels(client, [
        for (final json in itemsResponse.items)
          if (json['id'] case final String id) id,
      ], locale: locale);
      final items = itemsResponse.items
          .map((json) {
            final id = json['id'] as String?;
            final label = id == null ? null : itemLabels[id];
            return DrawerNavigationItemData.fromJson(
              label == null ? json : {...json, 'label': label},
            );
          })
          .toList(growable: false);

      final normalized = normalizer.normalize(menu: menu, items: items);
      for (final issue in normalized.ignoredIssues) {
        debugPrint(
          '[drawer-navigation] Ignored item '
          '${issue.itemId.isEmpty ? '<missing-id>' : issue.itemId}: '
          '${issue.reason}',
        );
      }

      if (!normalized.isUsable) {
        final reason =
            normalized.fallbackReason ??
            DrawerNavigationFallbackReason.treeInvalid;
        _logUnavailable(reason);
        return DrawerNavigationLoadResult.fallback(
          fallbackReason: reason,
          menu: menu,
          normalized: normalized,
        );
      }

      return DrawerNavigationLoadResult.success(
        menu: menu,
        normalized: normalized,
      );
    } catch (error, stackTrace) {
      _logUnavailable(
        DrawerNavigationFallbackReason.fetchError,
        error: error,
        stackTrace: stackTrace,
      );
      return const DrawerNavigationLoadResult.fallback(
        fallbackReason: DrawerNavigationFallbackReason.fetchError,
      );
    }
  }

  void _logUnavailable(
    DrawerNavigationFallbackReason reason, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    debugPrint('[drawer-navigation] Managed drawer unavailable: $reason');
    if (error != null) {
      debugPrint('[drawer-navigation] Error: $error');
    }
    if (stackTrace != null && kDebugMode) {
      debugPrint('$stackTrace');
    }
  }
}

final String _navigationItemFields = [
  'id',
  'menu',
  'parent',
  'position',
  'label',
  'itemType',
  'category',
  'product',
  'pageKey',
  'url',
  'promoMedia',
  'placement',
  'desktopDrawerTemplate',
  'config',
  'isActive',
  'isHidden',
  'expand.category.id',
  'expand.category.code',
  'expand.category.name',
  'expand.category.slug',
  'expand.category.description',
  'expand.category.isActive',
  'expand.category.parent',
  'expand.product.id',
  'expand.product.code',
  'expand.product.name',
  'expand.product.slug',
  'expand.product.summary',
  'expand.product.description',
  'expand.product.isActive',
  'expand.promoMedia.id',
  'expand.promoMedia.collectionId',
  'expand.promoMedia.file',
  'expand.promoMedia.originalFile',
  'expand.promoMedia.title',
  'expand.promoMedia.altText',
  'expand.promoMedia.cropPreset',
  'expand.promoMedia.cropX',
  'expand.promoMedia.cropY',
  'expand.promoMedia.cropWidth',
  'expand.promoMedia.cropHeight',
].join(',');
