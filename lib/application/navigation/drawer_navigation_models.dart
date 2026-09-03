import '../../config/api_config.dart';
import '../../core/utils/media_url_builder.dart';
import '../../domain/catalog/catalog_entities.dart';
import 'drawer_editorial_tiles.dart';

enum DrawerLiveSource { navigation, categories }

enum DrawerNavigationItemType { category, product, page, external, unknown }

enum DrawerNavigationPlacement { nav, promo, unknown }

enum DrawerNavigationDesktopTemplate {
  listOnly,
  heroSingle,
  promoGrid2x2,
  promoStack2,
}

enum DrawerNavigationFallbackReason {
  menuMissing,
  menuInactive,
  fetchError,
  noValidRoots,
  treeInvalid,
}

class DrawerNavigationMenuData {
  final String id;
  final String name;
  final String code;
  final String displayMode;
  final bool isActive;

  const DrawerNavigationMenuData({
    required this.id,
    required this.name,
    required this.code,
    required this.displayMode,
    required this.isActive,
  });

  factory DrawerNavigationMenuData.fromJson(Map<String, dynamic> json) {
    return DrawerNavigationMenuData(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      displayMode: json['displayMode'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  DrawerLiveSource get liveSource =>
      drawerLiveSourceFromDisplayMode(displayMode);
}

DrawerLiveSource drawerLiveSourceFromDisplayMode(String? displayMode) {
  return switch (displayMode?.trim()) {
    'category' || 'categories' => DrawerLiveSource.categories,
    _ => DrawerLiveSource.navigation,
  };
}

String displayModeForDrawerLiveSource(DrawerLiveSource source) {
  return switch (source) {
    DrawerLiveSource.navigation => 'drawer',
    DrawerLiveSource.categories => 'categories',
  };
}

class DrawerNavigationItemData {
  final String id;
  final String menuId;
  final String? parentId;
  final int position;
  final String label;
  final DrawerNavigationItemType itemType;
  final String? categoryId;
  final String? productId;
  final String? pageKey;
  final String? url;
  final String? promoMediaId;
  final DrawerNavigationPlacement placement;
  final DrawerNavigationDesktopTemplate? desktopDrawerTemplate;
  final bool isActive;
  final bool isHidden;
  final Map<String, dynamic> config;
  final DrawerEditorialTilesConfig editorialTiles;
  final CatalogCategory? category;
  final CatalogProduct? product;
  final CatalogMedia? promoMedia;

  const DrawerNavigationItemData({
    required this.id,
    required this.menuId,
    required this.position,
    required this.label,
    required this.itemType,
    required this.placement,
    required this.isActive,
    required this.isHidden,
    this.config = const {},
    this.editorialTiles = const DrawerEditorialTilesConfig(),
    this.parentId,
    this.categoryId,
    this.productId,
    this.pageKey,
    this.url,
    this.promoMediaId,
    this.desktopDrawerTemplate,
    this.category,
    this.product,
    this.promoMedia,
  });

  factory DrawerNavigationItemData.fromJson(
    Map<String, dynamic> json, {
    String? baseUrl,
  }) {
    final expand = json['expand'] as Map<String, dynamic>? ?? const {};
    final config = _parseConfig(json['config']);

    return DrawerNavigationItemData(
      id: json['id'] as String? ?? '',
      menuId: _readSingleRelationId(json['menu']) ?? '',
      parentId: _readSingleRelationId(json['parent']),
      position: (json['position'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      itemType: _parseItemType(json['itemType'] as String?),
      categoryId: _readSingleRelationId(json['category']),
      productId: _readSingleRelationId(json['product']),
      pageKey: json['pageKey'] as String?,
      url: json['url'] as String?,
      promoMediaId: _readSingleRelationId(json['promoMedia']),
      placement: _parsePlacement(json['placement'] as String?),
      desktopDrawerTemplate: _parseDesktopTemplate(
        json['desktopDrawerTemplate'] as String?,
      ),
      isActive: json['isActive'] as bool? ?? true,
      isHidden: json['isHidden'] as bool? ?? false,
      config: config,
      editorialTiles: DrawerEditorialTilesConfig.fromJson(
        config[drawerEditorialTilesConfigKey],
      ),
      category: _parseCategory(expand['category'] as Map<String, dynamic>?),
      product: _parseProduct(expand['product'] as Map<String, dynamic>?),
      promoMedia: _parseMedia(
        expand['promoMedia'] as Map<String, dynamic>?,
        baseUrl: baseUrl,
      ),
    );
  }
}

class DrawerNavigationNode {
  final DrawerNavigationItemData item;
  final List<DrawerNavigationNode> children;

  const DrawerNavigationNode({required this.item, this.children = const []});
}

class DrawerNavigationIgnoredIssue {
  final String itemId;
  final String reason;

  const DrawerNavigationIgnoredIssue({
    required this.itemId,
    required this.reason,
  });
}

class DrawerNavigationNormalizedResult {
  final List<DrawerNavigationNode> roots;
  final List<DrawerNavigationIgnoredIssue> ignoredIssues;
  final DrawerNavigationFallbackReason? fallbackReason;

  const DrawerNavigationNormalizedResult._({
    required this.roots,
    required this.ignoredIssues,
    required this.fallbackReason,
  });

  const DrawerNavigationNormalizedResult.usable({
    required List<DrawerNavigationNode> roots,
    List<DrawerNavigationIgnoredIssue> ignoredIssues = const [],
  }) : this._(roots: roots, ignoredIssues: ignoredIssues, fallbackReason: null);

  const DrawerNavigationNormalizedResult.unusable({
    required DrawerNavigationFallbackReason fallbackReason,
    List<DrawerNavigationIgnoredIssue> ignoredIssues = const [],
  }) : this._(
         roots: const [],
         ignoredIssues: ignoredIssues,
         fallbackReason: fallbackReason,
       );

  bool get isUsable => fallbackReason == null && roots.isNotEmpty;
}

class DrawerNavigationLoadResult {
  final DrawerNavigationMenuData? menu;
  final DrawerNavigationNormalizedResult? normalized;
  final DrawerNavigationFallbackReason? fallbackReason;

  const DrawerNavigationLoadResult._({
    required this.menu,
    required this.normalized,
    required this.fallbackReason,
  });

  const DrawerNavigationLoadResult.success({
    required DrawerNavigationMenuData menu,
    required DrawerNavigationNormalizedResult normalized,
  }) : this._(menu: menu, normalized: normalized, fallbackReason: null);

  const DrawerNavigationLoadResult.fallback({
    required DrawerNavigationFallbackReason fallbackReason,
    DrawerNavigationMenuData? menu,
    DrawerNavigationNormalizedResult? normalized,
  }) : this._(
         menu: menu,
         normalized: normalized,
         fallbackReason: fallbackReason,
       );

  bool get isUsable => menu != null && normalized?.isUsable == true;
}

String? _readSingleRelationId(dynamic rawValue) {
  if (rawValue is String) {
    final trimmed = rawValue.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  if (rawValue is List && rawValue.isNotEmpty) {
    final first = rawValue.first?.toString().trim();
    if (first == null || first.isEmpty) {
      return null;
    }
    return first;
  }

  return null;
}

Map<String, dynamic> _parseConfig(Object? raw) {
  if (raw is! Map) {
    return const {};
  }
  return Map<String, dynamic>.from(raw);
}

DrawerNavigationItemType _parseItemType(String? rawValue) {
  return switch (rawValue?.trim()) {
    'category' => DrawerNavigationItemType.category,
    'product' => DrawerNavigationItemType.product,
    'page' => DrawerNavigationItemType.page,
    'external' => DrawerNavigationItemType.external,
    _ => DrawerNavigationItemType.unknown,
  };
}

DrawerNavigationPlacement _parsePlacement(String? rawValue) {
  return switch (rawValue?.trim()) {
    'nav' => DrawerNavigationPlacement.nav,
    'promo' => DrawerNavigationPlacement.promo,
    _ => DrawerNavigationPlacement.unknown,
  };
}

DrawerNavigationDesktopTemplate? _parseDesktopTemplate(String? rawValue) {
  return switch (rawValue?.trim()) {
    'list_only' => DrawerNavigationDesktopTemplate.listOnly,
    'hero_single' => DrawerNavigationDesktopTemplate.heroSingle,
    'promo_grid_2x2' => DrawerNavigationDesktopTemplate.promoGrid2x2,
    'promo_stack_2' => DrawerNavigationDesktopTemplate.promoStack2,
    _ => null,
  };
}

CatalogCategory? _parseCategory(Map<String, dynamic>? json) {
  if (json == null || json.isEmpty) {
    return null;
  }

  final id = json['id'] as String?;
  if (id == null || id.isEmpty) {
    return null;
  }

  return CatalogCategory(
    id: id,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String?,
    description: json['description'] as String?,
    isActive: json['isActive'] as bool? ?? true,
    parentId: _readSingleRelationId(json['parent']),
  );
}

CatalogProduct? _parseProduct(Map<String, dynamic>? json) {
  if (json == null || json.isEmpty) {
    return null;
  }

  final id = json['id'] as String?;
  if (id == null || id.isEmpty) {
    return null;
  }

  return CatalogProduct(
    id: id,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    slug: json['slug'] as String?,
    summary: json['summary'] as String?,
    description: json['description'] as String?,
    isActive: json['isActive'] as bool? ?? true,
  );
}

CatalogMedia? _parseMedia(Map<String, dynamic>? json, {String? baseUrl}) {
  if (json == null || json.isEmpty) {
    return null;
  }

  final id = json['id'] as String?;
  final file = json['file'] as String?;
  final collectionId = json['collectionId'] as String?;
  if (id == null ||
      id.isEmpty ||
      file == null ||
      file.isEmpty ||
      collectionId == null ||
      collectionId.isEmpty) {
    return null;
  }

  final version = _parseDateTime(
    json['updated'],
  )?.toUtc().millisecondsSinceEpoch.toString();
  final resolvedBaseUrl = baseUrl ?? ApiConfig.mediaBaseUrl;
  final fileUrl = MediaUrlBuilder.fileUrl(
    collectionId: collectionId,
    recordId: id,
    filename: file,
    version: version,
    baseUrl: resolvedBaseUrl,
  );
  final originalFile = json['originalFile'] as String?;
  final originalUrl = originalFile == null || originalFile.isEmpty
      ? null
      : MediaUrlBuilder.fileUrl(
          collectionId: collectionId,
          recordId: id,
          filename: originalFile,
          version: version,
          baseUrl: resolvedBaseUrl,
        );

  return CatalogMedia(
    id: id,
    url: fileUrl,
    originalUrl: originalUrl,
    previewUrl: MediaUrlBuilder.thumbUrl(
      collectionId: collectionId,
      recordId: id,
      filename: file,
      size: CatalogMedia.defaultPreviewThumbSize,
      version: version,
      baseUrl: resolvedBaseUrl,
    ),
    altText: json['altText'] as String?,
    title: json['title'] as String?,
    cropPreset: json['cropPreset'] as String?,
    cropX: (json['cropX'] as num?)?.toDouble(),
    cropY: (json['cropY'] as num?)?.toDouble(),
    cropWidth: (json['cropWidth'] as num?)?.toDouble(),
    cropHeight: (json['cropHeight'] as num?)?.toDouble(),
  );
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}
