import '../../config/api_config.dart';
import '../../core/utils/media_url_builder.dart';
import '../storefront/storefront_theme.dart';

class CmsMediaRef {
  final String recordId;
  final String collectionId;
  final String filename;
  final String? alt;

  const CmsMediaRef({
    required this.recordId,
    required this.collectionId,
    required this.filename,
    this.alt,
  });

  bool get isUsable =>
      recordId.isNotEmpty && collectionId.isNotEmpty && filename.isNotEmpty;

  String fileUrl({String? baseUrl}) => MediaUrlBuilder.fileUrl(
    collectionId: collectionId,
    recordId: recordId,
    filename: filename,
    baseUrl: baseUrl ?? ApiConfig.mediaBaseUrl,
  );

  String thumbUrl({String size = '1200x900', String? baseUrl}) =>
      MediaUrlBuilder.thumbUrl(
        collectionId: collectionId,
        recordId: recordId,
        filename: filename,
        size: size,
        baseUrl: baseUrl ?? ApiConfig.mediaBaseUrl,
      );

  bool get isVideo => isVideoFilename(filename);

  static CmsMediaRef? maybeFromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final recordId = (json['recordId'] as String?)?.trim() ?? '';
    final collectionId = (json['collectionId'] as String?)?.trim() ?? '';
    final filename = (json['filename'] as String?)?.trim() ?? '';
    if (recordId.isEmpty || collectionId.isEmpty || filename.isEmpty) {
      return null;
    }
    return CmsMediaRef(
      recordId: recordId,
      collectionId: collectionId,
      filename: filename,
      alt: (json['alt'] as String?)?.trim().isEmpty == true
          ? null
          : json['alt'] as String?,
    );
  }
}

class CmsCta {
  final String label;
  final String href;

  const CmsCta({required this.label, required this.href});

  bool get isUsable => label.trim().isNotEmpty && href.trim().isNotEmpty;

  bool get isExternal {
    final h = href.trim().toLowerCase();
    return h.startsWith('http://') || h.startsWith('https://');
  }

  static CmsCta? maybeFromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final label = (json['label'] as String?)?.trim() ?? '';
    final href = (json['href'] as String?)?.trim() ?? '';
    if (label.isEmpty || href.isEmpty) return null;
    return CmsCta(label: label, href: href);
  }
}

class FeaturedProductPlaceholder {
  final String title;
  final String? price;
  final String href;
  final CmsMediaRef? media;

  const FeaturedProductPlaceholder({
    required this.title,
    this.price,
    required this.href,
    this.media,
  });

  bool get isUsable => title.isNotEmpty;

  factory FeaturedProductPlaceholder.fromJson(Map<String, dynamic> json) {
    return FeaturedProductPlaceholder(
      title: (json['title'] as String?)?.trim() ?? '',
      price: _trimNullable(json['price']),
      href: (json['href'] as String?)?.trim() ?? '',
      media: CmsMediaRef.maybeFromJson(json['media']),
    );
  }
}

const Set<String> _videoExtensions = {
  'mp4',
  'm4v',
  'webm',
  'mov',
  'avi',
  'mkv',
};

bool isVideoFilename(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return false;
  final ext = filename.substring(dot + 1).toLowerCase();
  return _videoExtensions.contains(ext);
}

enum CmsSectionType {
  heroCampaign('hero_campaign'),
  editorialStory('editorial_story'),
  categoryTiles('category_tiles'),
  featuredProducts('featured_products'),
  serviceCards('service_cards'),
  collectionHero('collection_hero'),
  editorialIntro('editorial_intro'),
  mixedProductGrid('mixed_product_grid'),
  seoText('seo_text'),
  discoverLinks('discover_links'),
  horizontalTileCarousel('horizontal_tile_carousel'),
  brandSegment('brand_segment'),
  categorySplitTabs('category_split_tabs'),
  categoryBannerStrip('category_banner_strip');

  final String wireName;

  const CmsSectionType(this.wireName);

  static CmsSectionType? fromWireName(String? value) {
    if (value == null) return null;
    for (final t in CmsSectionType.values) {
      if (t.wireName == value) return t;
    }
    return null;
  }
}

enum CmsPageType {
  home('home'),
  plp('plp'),
  content('content');

  final String wireName;

  const CmsPageType(this.wireName);

  static CmsPageType fromWireName(String? value) {
    if (value == null) return CmsPageType.home;
    for (final t in CmsPageType.values) {
      if (t.wireName == value) return t;
    }
    return CmsPageType.home;
  }
}

class CmsPageRecord {
  final String id;
  final String code;
  final String locale;
  final String title;
  final bool isActive;
  final CmsPageType pageType;
  final String? sourceCategoryId;
  final String? seoTitle;
  final String? seoDescription;

  const CmsPageRecord({
    required this.id,
    required this.code,
    required this.locale,
    required this.title,
    required this.isActive,
    this.pageType = CmsPageType.home,
    this.sourceCategoryId,
    this.seoTitle,
    this.seoDescription,
  });

  factory CmsPageRecord.fromJson(Map<String, dynamic> json) {
    return CmsPageRecord(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      locale: json['locale'] as String? ?? '',
      title: json['title'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      pageType: CmsPageType.fromWireName(json['pageType'] as String?),
      sourceCategoryId: _readSingleRelationId(json['sourceCategory']),
      seoTitle: _trimNullable(json['seoTitle']),
      seoDescription: _trimNullable(json['seoDescription']),
    );
  }
}

class CmsSectionRecord {
  final String id;
  final String pageId;
  final String sectionId;
  final CmsSectionType? sectionType;
  final String rawSectionType;
  final int position;
  final bool isActive;
  final Map<String, dynamic> config;

  const CmsSectionRecord({
    required this.id,
    required this.pageId,
    required this.sectionId,
    required this.sectionType,
    required this.rawSectionType,
    required this.position,
    required this.isActive,
    required this.config,
  });

  factory CmsSectionRecord.fromJson(Map<String, dynamic> json) {
    final raw = json['sectionType'] as String? ?? '';
    Map<String, dynamic> config;
    final rawConfig = json['config'];
    if (rawConfig is Map) {
      config = Map<String, dynamic>.from(rawConfig);
    } else {
      config = const {};
    }

    return CmsSectionRecord(
      id: json['id'] as String? ?? '',
      pageId: _readSingleRelationId(json['page']) ?? '',
      sectionId: json['sectionId'] as String? ?? '',
      sectionType: CmsSectionType.fromWireName(raw),
      rawSectionType: raw,
      position: (json['position'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      config: config,
    );
  }
}

String? _readSingleRelationId(Object? raw) {
  if (raw is String) {
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }
  if (raw is List && raw.isNotEmpty) {
    final first = raw.first?.toString().trim();
    if (first == null || first.isEmpty) return null;
    return first;
  }
  return null;
}

class HeroCampaignConfig {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final String? body;
  final CmsCta? primaryCta;
  final CmsMediaRef? mediaDesktop;
  final CmsMediaRef? mediaMobile;
  final String mediaType;
  final String textAlign;
  final String heightMode;

  const HeroCampaignConfig({
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.body,
    this.primaryCta,
    this.mediaDesktop,
    this.mediaMobile,
    this.mediaType = 'image',
    this.textAlign = 'center',
    this.heightMode = 'xl',
  });

  factory HeroCampaignConfig.fromJson(Map<String, dynamic> json) {
    return HeroCampaignConfig(
      eyebrow: _trimNullable(json['eyebrow']),
      title: (json['title'] as String?)?.trim() ?? '',
      subtitle: _trimNullable(json['subtitle']),
      body: _trimNullable(json['body']),
      primaryCta: CmsCta.maybeFromJson(json['primaryCta']),
      mediaDesktop: CmsMediaRef.maybeFromJson(json['mediaDesktop']),
      mediaMobile: CmsMediaRef.maybeFromJson(json['mediaMobile']),
      mediaType:
          (json['mediaType'] as String?)?.trim().toLowerCase().nonEmpty ??
          'image',
      textAlign:
          (json['textAlign'] as String?)?.trim().toLowerCase().nonEmpty ??
          'center',
      heightMode:
          (json['heightMode'] as String?)?.trim().toLowerCase().nonEmpty ??
          'xl',
    );
  }
}

class EditorialStoryConfig {
  final String? eyebrow;
  final String title;
  final String? body;
  final CmsCta? primaryCta;
  final CmsMediaRef? mediaDesktop;
  final CmsMediaRef? mediaMobile;
  final String mediaType;
  final String layoutVariant;
  final String backgroundTone;

  const EditorialStoryConfig({
    this.eyebrow,
    required this.title,
    this.body,
    this.primaryCta,
    this.mediaDesktop,
    this.mediaMobile,
    this.mediaType = 'image',
    this.layoutVariant = 'mediaTop',
    this.backgroundTone = 'light',
  });

  factory EditorialStoryConfig.fromJson(Map<String, dynamic> json) {
    return EditorialStoryConfig(
      eyebrow: _trimNullable(json['eyebrow']),
      title: (json['title'] as String?)?.trim() ?? '',
      body: _trimNullable(json['body']),
      primaryCta: CmsCta.maybeFromJson(json['primaryCta']),
      mediaDesktop: CmsMediaRef.maybeFromJson(json['mediaDesktop']),
      mediaMobile: CmsMediaRef.maybeFromJson(json['mediaMobile']),
      mediaType:
          (json['mediaType'] as String?)?.trim().toLowerCase().nonEmpty ??
          'image',
      layoutVariant:
          (json['layoutVariant'] as String?)?.trim().nonEmpty ?? 'mediaTop',
      backgroundTone:
          (json['backgroundTone'] as String?)?.trim().toLowerCase().nonEmpty ??
          'light',
    );
  }
}

class CategoryTileItem {
  final String? eyebrow;
  final String label;
  final String href;
  final CmsMediaRef? media;

  const CategoryTileItem({
    this.eyebrow,
    required this.label,
    required this.href,
    this.media,
  });

  bool get isUsable => label.isNotEmpty && href.isNotEmpty;

  factory CategoryTileItem.fromJson(Map<String, dynamic> json) {
    return CategoryTileItem(
      eyebrow: _trimNullable(json['eyebrow']),
      label: (json['label'] as String?)?.trim() ?? '',
      href: (json['href'] as String?)?.trim() ?? '',
      media: CmsMediaRef.maybeFromJson(json['media']),
    );
  }
}

class CategoryTilesConfig {
  final String? title;
  final String? subtitle;
  final int columnsMobile;
  final int columnsDesktop;
  final List<CategoryTileItem> tiles;

  const CategoryTilesConfig({
    this.title,
    this.subtitle,
    this.columnsMobile = 2,
    this.columnsDesktop = 4,
    this.tiles = const [],
  });

  factory CategoryTilesConfig.fromJson(Map<String, dynamic> json) {
    final rawTiles = (json['tiles'] as List?) ?? const [];
    return CategoryTilesConfig(
      title: _trimNullable(json['title']),
      subtitle: _trimNullable(json['subtitle']),
      columnsMobile: _clampColumns(json['columnsMobile'], fallback: 2),
      columnsDesktop: _clampColumns(json['columnsDesktop'], fallback: 4),
      tiles: rawTiles
          .whereType<Map>()
          .map((e) => CategoryTileItem.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.isUsable)
          .toList(),
    );
  }
}

class FeaturedProductsConfig {
  final String? eyebrow;
  final String? title;
  final String? subtitle;
  final CmsCta? primaryCta;
  final List<String> productIds;
  final List<FeaturedProductPlaceholder> placeholderProducts;
  final String layout;
  final bool showPrices;

  const FeaturedProductsConfig({
    this.eyebrow,
    this.title,
    this.subtitle,
    this.primaryCta,
    this.productIds = const [],
    this.placeholderProducts = const [],
    this.layout = 'grid4',
    this.showPrices = true,
  });

  factory FeaturedProductsConfig.fromJson(Map<String, dynamic> json) {
    final ids = (json['productIds'] as List?) ?? const [];
    final rawPlaceholders = (json['placeholderProducts'] as List?) ?? const [];
    return FeaturedProductsConfig(
      eyebrow: _trimNullable(json['eyebrow']),
      title: _trimNullable(json['title']),
      subtitle: _trimNullable(json['subtitle']),
      primaryCta: CmsCta.maybeFromJson(json['primaryCta']),
      productIds: ids
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(),
      placeholderProducts: rawPlaceholders
          .whereType<Map>()
          .map(
            (e) => FeaturedProductPlaceholder.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .where((p) => p.isUsable)
          .toList(growable: false),
      layout: (json['layout'] as String?)?.trim().nonEmpty ?? 'grid4',
      showPrices: json['showPrices'] as bool? ?? true,
    );
  }
}

class ServiceCardItem {
  final String title;
  final String? body;
  final String href;
  final String? ctaLabel;

  const ServiceCardItem({
    required this.title,
    this.body,
    required this.href,
    this.ctaLabel,
  });

  bool get isUsable => title.isNotEmpty && href.isNotEmpty;

  factory ServiceCardItem.fromJson(Map<String, dynamic> json) {
    return ServiceCardItem(
      title: (json['title'] as String?)?.trim() ?? '',
      body: _trimNullable(json['body']),
      href: (json['href'] as String?)?.trim() ?? '',
      ctaLabel: _trimNullable(json['ctaLabel']),
    );
  }
}

class ServiceCardsConfig {
  final String? title;
  final List<ServiceCardItem> cards;

  const ServiceCardsConfig({this.title, this.cards = const []});

  factory ServiceCardsConfig.fromJson(Map<String, dynamic> json) {
    final rawCards = (json['cards'] as List?) ?? const [];
    return ServiceCardsConfig(
      title: _trimNullable(json['title']),
      cards: rawCards
          .whereType<Map>()
          .map((e) => ServiceCardItem.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.isUsable)
          .toList(),
    );
  }
}

class CollectionHeroConfig {
  final int schemaVersion;
  final String title;
  final String? intro;
  final CmsMediaRef? imageMobile;
  final CmsMediaRef? imageDesktop;
  final String mobileLayout;
  final String desktopLayout;
  final String aspectRatio;

  const CollectionHeroConfig({
    this.schemaVersion = 1,
    required this.title,
    this.intro,
    this.imageMobile,
    this.imageDesktop,
    this.mobileLayout = 'imageTop',
    this.desktopLayout = 'split',
    this.aspectRatio = '4/5',
  });

  factory CollectionHeroConfig.fromJson(Map<String, dynamic> json) {
    return CollectionHeroConfig(
      schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
      title: (json['title'] as String?)?.trim() ?? '',
      intro: _trimNullable(json['intro']) ?? _trimNullable(json['body']),
      imageMobile: CmsMediaRef.maybeFromJson(
        json['imageMobile'] ?? json['mediaMobile'],
      ),
      imageDesktop: CmsMediaRef.maybeFromJson(
        json['imageDesktop'] ?? json['mediaDesktop'],
      ),
      mobileLayout:
          (json['mobileLayout'] as String?)?.trim().nonEmpty ?? 'imageTop',
      desktopLayout:
          (json['desktopLayout'] as String?)?.trim().nonEmpty ?? 'split',
      aspectRatio: (json['aspectRatio'] as String?)?.trim().nonEmpty ?? '4/5',
    );
  }
}

class EditorialIntroConfig {
  final int schemaVersion;
  final String? eyebrow;
  final String title;
  final String? body;
  final String mobileLayout;
  final String desktopLayout;

  const EditorialIntroConfig({
    this.schemaVersion = 1,
    this.eyebrow,
    required this.title,
    this.body,
    this.mobileLayout = 'textOnly',
    this.desktopLayout = 'centered',
  });

  factory EditorialIntroConfig.fromJson(Map<String, dynamic> json) {
    return EditorialIntroConfig(
      schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
      eyebrow: _trimNullable(json['eyebrow']),
      title: (json['title'] as String?)?.trim() ?? '',
      body: _trimNullable(json['body']),
      mobileLayout:
          (json['mobileLayout'] as String?)?.trim().nonEmpty ?? 'textOnly',
      desktopLayout:
          (json['desktopLayout'] as String?)?.trim().nonEmpty ?? 'centered',
    );
  }
}

class GridSourceConfig {
  final String type;
  final int limit;
  final String sort;
  final String? categoryId;

  const GridSourceConfig({
    this.type = 'routeCategory',
    this.limit = 48,
    this.sort = 'manual',
    this.categoryId,
  });

  factory GridSourceConfig.fromJson(Object? raw) {
    final json = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    return GridSourceConfig(
      type: (json['type'] as String?)?.trim().nonEmpty ?? 'routeCategory',
      limit: _clampInt(json['limit'], min: 1, max: 200, fallback: 48),
      sort: (json['sort'] as String?)?.trim().nonEmpty ?? 'manual',
      categoryId: _trimNullable(json['categoryId']),
    );
  }
}

class GridToolbarConfig {
  final bool enabled;
  final bool stickyToolbar;
  final bool showSort;
  final bool showFilter;
  final String defaultSort;
  final List<String> sortOptions;

  const GridToolbarConfig({
    this.enabled = true,
    this.stickyToolbar = true,
    this.showSort = true,
    this.showFilter = false,
    this.defaultSort = 'manual',
    this.sortOptions = const ['manual', 'newest', 'price_asc', 'price_desc'],
  });

  factory GridToolbarConfig.fromJson(Object? raw) {
    final json = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    final options = _stringList(
      json['sortOptions'],
    ).where(_isKnownGridSort).toList(growable: false);
    final defaultSort =
        (json['defaultSort'] as String?)?.trim().nonEmpty ?? 'manual';
    return GridToolbarConfig(
      enabled: _boolValue(json['enabled'], fallback: true),
      stickyToolbar: _boolValue(json['stickyToolbar'], fallback: true),
      showSort: _boolValue(json['showSort'], fallback: true),
      showFilter: _boolValue(json['showFilter'], fallback: false),
      defaultSort: _isKnownGridSort(defaultSort) ? defaultSort : 'manual',
      sortOptions: options.isEmpty
          ? const ['manual', 'newest', 'price_asc', 'price_desc']
          : options,
    );
  }
}

class ProductCardConfig {
  final bool showWishlist;
  final bool showSummary;
  final bool showBadges;
  final bool showQuickAdd;
  final bool showPrices;

  const ProductCardConfig({
    this.showWishlist = true,
    this.showSummary = true,
    this.showBadges = true,
    this.showQuickAdd = true,
    this.showPrices = true,
  });

  factory ProductCardConfig.fromJson(Object? raw) {
    final json = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    return ProductCardConfig(
      showWishlist: _boolValue(json['showWishlist'], fallback: true),
      showSummary: _boolValue(json['showSummary'], fallback: true),
      showBadges: _boolValue(json['showBadges'], fallback: true),
      showQuickAdd: _boolValue(json['showQuickAdd'], fallback: true),
      showPrices: _boolValue(json['showPrices'], fallback: true),
    );
  }
}

class PinnedProductConfig {
  final String productId;
  final int slotPosition;

  const PinnedProductConfig({
    required this.productId,
    required this.slotPosition,
  });

  bool get isUsable => productId.isNotEmpty && slotPosition >= 0;

  factory PinnedProductConfig.fromJson(Map<String, dynamic> json) {
    return PinnedProductConfig(
      productId: (json['productId'] as String?)?.trim() ?? '',
      slotPosition: _clampInt(json['slotPosition'], min: 0, max: 10000),
    );
  }
}

sealed class GridInsertConfig {
  final int slotPosition;
  final String displaySize;
  final String aspectRatio;

  const GridInsertConfig({
    required this.slotPosition,
    required this.displaySize,
    required this.aspectRatio,
  });

  static GridInsertConfig fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?)?.trim();
    final slotPosition = _clampInt(json['slotPosition'], min: 0, max: 10000);
    final displaySize =
        (json['displaySize'] as String?)?.trim().nonEmpty ?? 'small';
    final aspectRatio =
        (json['aspectRatio'] as String?)?.trim().nonEmpty ?? '1/1';
    return switch (type) {
      'category_tile' => CategoryTileInsert.fromJson(
        json,
        slotPosition: slotPosition,
        displaySize: displaySize,
        aspectRatio: aspectRatio,
      ),
      'editorial_campaign_tile' => EditorialCampaignInsert.fromJson(
        json,
        slotPosition: slotPosition,
        displaySize: displaySize,
        aspectRatio: aspectRatio,
      ),
      'universe_tile' => UniverseInsert.fromJson(
        json,
        slotPosition: slotPosition,
        displaySize: displaySize,
        aspectRatio: aspectRatio,
      ),
      _ => UnknownGridInsert(
        rawType: type ?? '',
        slotPosition: slotPosition,
        displaySize: displaySize,
        aspectRatio: aspectRatio,
      ),
    };
  }
}

class CategoryTileInsert extends GridInsertConfig {
  final String title;
  final String? eyebrow;
  final String href;
  final CmsMediaRef? imageMobile;
  final CmsMediaRef? imageDesktop;

  const CategoryTileInsert({
    required super.slotPosition,
    required super.displaySize,
    required super.aspectRatio,
    required this.title,
    this.eyebrow,
    required this.href,
    this.imageMobile,
    this.imageDesktop,
  });

  bool get isUsable {
    final isLegacyPlaceholder =
        title == 'Nouvelle insertion' &&
        href == '/catalog' &&
        imageMobile == null &&
        imageDesktop == null;
    return title.isNotEmpty && href.isNotEmpty && !isLegacyPlaceholder;
  }

  factory CategoryTileInsert.fromJson(
    Map<String, dynamic> json, {
    required int slotPosition,
    required String displaySize,
    required String aspectRatio,
  }) {
    return CategoryTileInsert(
      slotPosition: slotPosition,
      displaySize: displaySize,
      aspectRatio: aspectRatio,
      title: (json['title'] as String?)?.trim() ?? '',
      eyebrow: _trimNullable(json['eyebrow']),
      href: (json['href'] as String?)?.trim() ?? '',
      imageMobile: CmsMediaRef.maybeFromJson(
        json['imageMobile'] ?? json['mediaMobile'],
      ),
      imageDesktop: CmsMediaRef.maybeFromJson(
        json['imageDesktop'] ?? json['mediaDesktop'],
      ),
    );
  }
}

class EditorialCampaignInsert extends GridInsertConfig {
  final String title;
  final String? body;
  final CmsCta? cta;
  final CmsMediaRef? imageMobile;
  final CmsMediaRef? imageDesktop;

  const EditorialCampaignInsert({
    required super.slotPosition,
    required super.displaySize,
    required super.aspectRatio,
    required this.title,
    this.body,
    this.cta,
    this.imageMobile,
    this.imageDesktop,
  });

  bool get isUsable => title.isNotEmpty;

  factory EditorialCampaignInsert.fromJson(
    Map<String, dynamic> json, {
    required int slotPosition,
    required String displaySize,
    required String aspectRatio,
  }) {
    return EditorialCampaignInsert(
      slotPosition: slotPosition,
      displaySize: displaySize,
      aspectRatio: aspectRatio,
      title: (json['title'] as String?)?.trim() ?? '',
      body: _trimNullable(json['body']),
      cta: CmsCta.maybeFromJson(json['cta']),
      imageMobile: CmsMediaRef.maybeFromJson(
        json['imageMobile'] ?? json['mediaMobile'],
      ),
      imageDesktop: CmsMediaRef.maybeFromJson(
        json['imageDesktop'] ?? json['mediaDesktop'],
      ),
    );
  }
}

class UniverseInsert extends GridInsertConfig {
  final String title;
  final String? body;
  final String href;
  final CmsMediaRef? imageMobile;
  final CmsMediaRef? imageDesktop;

  const UniverseInsert({
    required super.slotPosition,
    required super.displaySize,
    required super.aspectRatio,
    required this.title,
    this.body,
    required this.href,
    this.imageMobile,
    this.imageDesktop,
  });

  bool get isUsable => title.isNotEmpty && href.isNotEmpty;

  factory UniverseInsert.fromJson(
    Map<String, dynamic> json, {
    required int slotPosition,
    required String displaySize,
    required String aspectRatio,
  }) {
    return UniverseInsert(
      slotPosition: slotPosition,
      displaySize: displaySize,
      aspectRatio: aspectRatio,
      title: (json['title'] as String?)?.trim() ?? '',
      body: _trimNullable(json['body']),
      href: (json['href'] as String?)?.trim() ?? '',
      imageMobile: CmsMediaRef.maybeFromJson(
        json['imageMobile'] ?? json['mediaMobile'],
      ),
      imageDesktop: CmsMediaRef.maybeFromJson(
        json['imageDesktop'] ?? json['mediaDesktop'],
      ),
    );
  }
}

class UnknownGridInsert extends GridInsertConfig {
  final String rawType;

  const UnknownGridInsert({
    required this.rawType,
    required super.slotPosition,
    required super.displaySize,
    required super.aspectRatio,
  });
}

class MixedProductGridConfig {
  final int schemaVersion;
  final GridSourceConfig source;
  final int columnsMobile;
  final int columnsTablet;
  final int columnsDesktop;
  final String aspectRatio;
  final GridToolbarConfig toolbar;
  final ProductCardConfig productCard;
  final List<PinnedProductConfig> pinnedProducts;
  final List<String> excludedProductIds;
  final List<GridInsertConfig> inserts;

  const MixedProductGridConfig({
    this.schemaVersion = 1,
    this.source = const GridSourceConfig(),
    this.columnsMobile = 2,
    this.columnsTablet = 3,
    this.columnsDesktop = 4,
    this.aspectRatio = '0.64',
    this.toolbar = const GridToolbarConfig(),
    this.productCard = const ProductCardConfig(),
    this.pinnedProducts = const [],
    this.excludedProductIds = const [],
    this.inserts = const [],
  });

  factory MixedProductGridConfig.fromJson(Map<String, dynamic> json) {
    final rawPins = (json['pinnedProducts'] as List?) ?? const [];
    final rawInserts =
        (json['inserts'] as List?) ?? (json['slots'] as List?) ?? const [];
    return MixedProductGridConfig(
      schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
      source: GridSourceConfig.fromJson(json['source']),
      columnsMobile: _clampColumns(json['columnsMobile'], fallback: 2),
      columnsTablet: _clampColumns(json['columnsTablet'], fallback: 3),
      columnsDesktop: _clampColumns(json['columnsDesktop'], fallback: 4),
      aspectRatio: (json['aspectRatio'] as String?)?.trim().nonEmpty ?? '0.64',
      toolbar: GridToolbarConfig.fromJson(json['toolbar']),
      productCard: ProductCardConfig.fromJson(json['productCard']),
      pinnedProducts: rawPins
          .whereType<Map>()
          .map(
            (e) => PinnedProductConfig.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((p) => p.isUsable)
          .toList(growable: false),
      excludedProductIds: _stringList(json['excludedProductIds']),
      inserts: rawInserts
          .whereType<Map>()
          .map((e) => GridInsertConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

class SeoTextConfig {
  final int schemaVersion;
  final String? title;
  final String? body;
  final String mobileLayout;
  final String desktopLayout;

  const SeoTextConfig({
    this.schemaVersion = 1,
    this.title,
    this.body,
    this.mobileLayout = 'collapsed',
    this.desktopLayout = 'expanded',
  });

  factory SeoTextConfig.fromJson(Map<String, dynamic> json) {
    return SeoTextConfig(
      schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
      title: _trimNullable(json['title']),
      body: _trimNullable(json['body']),
      mobileLayout:
          (json['mobileLayout'] as String?)?.trim().nonEmpty ?? 'collapsed',
      desktopLayout:
          (json['desktopLayout'] as String?)?.trim().nonEmpty ?? 'expanded',
    );
  }
}

class DiscoverLinkItem {
  final String label;
  final String href;

  const DiscoverLinkItem({required this.label, required this.href});

  bool get isUsable => label.isNotEmpty && href.isNotEmpty;

  factory DiscoverLinkItem.fromJson(Map<String, dynamic> json) {
    return DiscoverLinkItem(
      label: (json['label'] as String?)?.trim() ?? '',
      href: (json['href'] as String?)?.trim() ?? '',
    );
  }
}

class DiscoverLinksConfig {
  final int schemaVersion;
  final String? title;
  final int columnsMobile;
  final int columnsDesktop;
  final List<DiscoverLinkItem> links;

  const DiscoverLinksConfig({
    this.schemaVersion = 1,
    this.title,
    this.columnsMobile = 1,
    this.columnsDesktop = 4,
    this.links = const [],
  });

  factory DiscoverLinksConfig.fromJson(Map<String, dynamic> json) {
    final rawLinks = (json['links'] as List?) ?? const [];
    return DiscoverLinksConfig(
      schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
      title: _trimNullable(json['title']),
      columnsMobile: _clampColumns(json['columnsMobile'], fallback: 1),
      columnsDesktop: _clampColumns(json['columnsDesktop'], fallback: 4),
      links: rawLinks
          .whereType<Map>()
          .map((e) => DiscoverLinkItem.fromJson(Map<String, dynamic>.from(e)))
          .where((l) => l.isUsable)
          .toList(growable: false),
    );
  }
}

class HorizontalTileItem {
  final String label;
  final String href;
  final CmsMediaRef? media;

  const HorizontalTileItem({
    required this.label,
    required this.href,
    this.media,
  });

  bool get isUsable => label.isNotEmpty;

  factory HorizontalTileItem.fromJson(Map<String, dynamic> json) {
    return HorizontalTileItem(
      label: (json['label'] as String?)?.trim() ?? '',
      href: (json['href'] as String?)?.trim() ?? '',
      media: CmsMediaRef.maybeFromJson(json['media']),
    );
  }
}

class HorizontalTileCarouselConfig {
  final int schemaVersion;
  final String? title;

  /// Display style for the carousel:
  ///   - `'tiles'` (default): small square tiles with the label below.
  ///   - `'feature'`: large swipeable cards with the label overlaid on the
  ///     image and a dot pager underneath.
  final String layout;
  final List<HorizontalTileItem> items;

  const HorizontalTileCarouselConfig({
    this.schemaVersion = 1,
    this.title,
    this.layout = 'tiles',
    this.items = const [],
  });

  factory HorizontalTileCarouselConfig.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final rawLayout = (json['layout'] as String?)?.trim().toLowerCase();
    return HorizontalTileCarouselConfig(
      schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
      title: _trimNullable(json['title']),
      layout: rawLayout == 'feature' ? 'feature' : 'tiles',
      items: rawItems
          .whereType<Map>()
          .map((e) => HorizontalTileItem.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.isUsable)
          .toList(growable: false),
    );
  }
}

class BrandSegmentItem {
  final String label;
  final String href;
  final StorefrontTheme? theme;
  final CmsMediaRef? media;

  const BrandSegmentItem({
    required this.label,
    required this.href,
    this.theme,
    this.media,
  });

  bool get isUsable => label.isNotEmpty || media != null;

  factory BrandSegmentItem.fromJson(Map<String, dynamic> json) {
    return BrandSegmentItem(
      label: (json['label'] as String?)?.trim() ?? '',
      href: (json['href'] as String?)?.trim() ?? '',
      theme: StorefrontTheme.tryFromWireName(json['theme'] as String?),
      media: CmsMediaRef.maybeFromJson(json['media']),
    );
  }
}

enum BrandSegmentMode {
  links('links'),
  themeSwitcher('themeSwitcher');

  final String wireName;

  const BrandSegmentMode(this.wireName);

  static BrandSegmentMode fromWireName(String? value) {
    final normalized = value?.trim();
    for (final mode in BrandSegmentMode.values) {
      if (mode.wireName == normalized) return mode;
    }
    return BrandSegmentMode.links;
  }
}

class BrandSegmentConfig {
  final int schemaVersion;
  final BrandSegmentMode mode;
  final List<BrandSegmentItem> items;
  final int activeIndex;

  const BrandSegmentConfig({
    this.schemaVersion = 1,
    this.mode = BrandSegmentMode.links,
    this.items = const [],
    this.activeIndex = 0,
  });

  factory BrandSegmentConfig.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => BrandSegmentItem.fromJson(Map<String, dynamic>.from(e)))
        .where((i) => i.isUsable)
        .toList(growable: false);
    final active = _clampInt(json['activeIndex'], min: 0);
    final mode = BrandSegmentMode.fromWireName(json['mode'] as String?);
    if (mode == BrandSegmentMode.links && _isLegacyNikeJordanSeed(items)) {
      return BrandSegmentConfig(
        schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
        mode: BrandSegmentMode.themeSwitcher,
        items: [
          BrandSegmentItem(
            label: 'Sport',
            href: '',
            theme: StorefrontTheme.nike,
            media: items[0].media,
          ),
          BrandSegmentItem(
            label: 'Luxe',
            href: '',
            theme: StorefrontTheme.dior,
            media: items[1].media,
          ),
        ],
        activeIndex: 0,
      );
    }
    return BrandSegmentConfig(
      schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
      mode: mode,
      items: items,
      activeIndex: items.isEmpty ? 0 : (active >= items.length ? 0 : active),
    );
  }
}

bool _isLegacyNikeJordanSeed(List<BrandSegmentItem> items) {
  if (items.length != 2) return false;
  final first = items[0];
  final second = items[1];
  return first.label == 'Nike' &&
      first.href == '/' &&
      first.theme == null &&
      second.label == 'Jordan' &&
      second.href == '/catalog' &&
      second.theme == null;
}

class CategorySplitTabItem {
  final String label;
  final String href;
  final String? segment;

  const CategorySplitTabItem({
    required this.label,
    required this.href,
    this.segment,
  });

  bool get isUsable => label.isNotEmpty;

  factory CategorySplitTabItem.fromJson(Map<String, dynamic> json) {
    return CategorySplitTabItem(
      label: (json['label'] as String?)?.trim() ?? '',
      href: (json['href'] as String?)?.trim() ?? '',
      segment: _trimNullable(json['segment'])?.toLowerCase(),
    );
  }
}

class CategorySplitTabsConfig {
  final int schemaVersion;
  final List<CategorySplitTabItem> items;
  final int defaultActiveIndex;
  final String? displayMode;

  /// Optional header label for the expansible design (the tabs ↔ expansible
  /// choice itself is a global navigation setting, see CategorySplitDisplayMode).
  final String? expansibleTitle;

  const CategorySplitTabsConfig({
    this.schemaVersion = 1,
    this.items = const [],
    this.defaultActiveIndex = 0,
    this.displayMode,
    this.expansibleTitle,
  });

  factory CategorySplitTabsConfig.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => CategorySplitTabItem.fromJson(Map<String, dynamic>.from(e)))
        .where((i) => i.isUsable)
        .toList(growable: false);
    final active = _clampInt(json['defaultActiveIndex'], min: 0);
    final displayMode = switch ((json['displayMode'] as String?)
        ?.trim()
        .toLowerCase()) {
      'tabs' => 'tabs',
      'expansible' => 'expansible',
      _ => null,
    };
    return CategorySplitTabsConfig(
      schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
      items: items,
      defaultActiveIndex: items.isEmpty
          ? 0
          : (active >= items.length ? 0 : active),
      displayMode: displayMode,
      expansibleTitle: _trimNullable(json['expansibleTitle']),
    );
  }
}

class CategoryBannerItem {
  final String? code;
  final String title;
  final String href;
  final CmsMediaRef? media;
  final String backgroundTone;

  /// Optional custom gradient background, as `#RRGGBB` hex strings. When both
  /// are set the banner paints a gradient instead of the flat tone color.
  final String? gradientStartHex;
  final String? gradientEndHex;

  /// Catalog category id this banner maps to, when known. Lets a tap open the
  /// category-fallback drawer drilled into this category's children.
  final String? categoryId;

  /// Managed-navigation root node id this banner maps to, when known. Lets a
  /// tap open the managed-navigation drawer drilled into this node.
  final String? nodeId;

  const CategoryBannerItem({
    this.code,
    required this.title,
    required this.href,
    this.media,
    this.backgroundTone = 'dark',
    this.gradientStartHex,
    this.gradientEndHex,
    this.categoryId,
    this.nodeId,
  });

  bool get isUsable => title.isNotEmpty;

  factory CategoryBannerItem.fromJson(Map<String, dynamic> json) {
    return CategoryBannerItem(
      code: _trimNullable(json['code']),
      title: (json['title'] as String?)?.trim() ?? '',
      href: (json['href'] as String?)?.trim() ?? '',
      media: CmsMediaRef.maybeFromJson(json['media']),
      backgroundTone:
          (json['backgroundTone'] as String?)?.trim().toLowerCase().nonEmpty ??
          'dark',
      gradientStartHex: _trimNullable(json['gradientStart']),
      gradientEndHex: _trimNullable(json['gradientEnd']),
      categoryId: _trimNullable(json['categoryId']),
      nodeId: _trimNullable(json['nodeId']),
    );
  }

  /// Returns a copy with [appearance]'s media/gradient applied on top of the
  /// item's own values. Used by the resolver to decorate live-drawer items
  /// with the section-local appearance overrides.
  CategoryBannerItem withAppearance(CategoryBannerAppearance? appearance) {
    if (appearance == null || appearance.isEmpty) return this;
    return CategoryBannerItem(
      code: code,
      title: title,
      href: href,
      media: appearance.media ?? media,
      backgroundTone: backgroundTone,
      gradientStartHex: appearance.gradientStartHex ?? gradientStartHex,
      gradientEndHex: appearance.gradientEndHex ?? gradientEndHex,
      categoryId: categoryId,
      nodeId: nodeId,
    );
  }
}

/// Section-local appearance override for one banner of a
/// `category_banner_strip` mirroring the live drawer. Keyed by the source
/// entry id (navigation item id or category id) in the section config, so the
/// drawer stays the single source of truth for labels/order/visibility while
/// the section owns the imagery.
class CategoryBannerAppearance {
  final CmsMediaRef? media;
  final String? gradientStartHex;
  final String? gradientEndHex;

  const CategoryBannerAppearance({
    this.media,
    this.gradientStartHex,
    this.gradientEndHex,
  });

  bool get isEmpty =>
      media == null && gradientStartHex == null && gradientEndHex == null;

  static CategoryBannerAppearance? maybeFromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final appearance = CategoryBannerAppearance(
      media: CmsMediaRef.maybeFromJson(json['media']),
      gradientStartHex: _trimNullable(json['gradientStart']),
      gradientEndHex: _trimNullable(json['gradientEnd']),
    );
    return appearance.isEmpty ? null : appearance;
  }
}

/// Config payload for the `category_banner_strip` section.
///
/// By default the section mirrors the live drawer (`main_drawer`) so existing
/// Dior/Luxe/Nike sections keep their behaviour. Sport segment pages can opt
/// into section-local configured banners when the CMS page itself needs
/// segment-specific imagery.
const defaultCategoryBannerStripSkeletonItemCount = 3;

enum CategoryBannerStripSourceMode {
  drawerRoots('drawerRoots'),
  categoryChildren('categoryChildren'),
  configuredBanners('configuredBanners');

  final String wireName;

  const CategoryBannerStripSourceMode(this.wireName);

  static CategoryBannerStripSourceMode fromWireName(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'categorychildren' || 'category_children' => categoryChildren,
      'configuredbanners' || 'configured_banners' => configuredBanners,
      _ => drawerRoots,
    };
  }
}

class CategoryBannerStripConfig {
  final int schemaVersion;
  final int skeletonItemCount;
  final CategoryBannerStripSourceMode sourceMode;
  final String? sourceCategoryId;
  final List<CategoryBannerItem> configuredBanners;
  final CmsMediaRef? sharedBackgroundMedia;

  /// Appearance overrides for live-drawer modes, keyed by the source entry id
  /// (navigation item id or category id).
  final Map<String, CategoryBannerAppearance> bannerAppearance;

  const CategoryBannerStripConfig({
    this.schemaVersion = 1,
    this.skeletonItemCount = defaultCategoryBannerStripSkeletonItemCount,
    this.sourceMode = CategoryBannerStripSourceMode.drawerRoots,
    this.sourceCategoryId,
    this.configuredBanners = const [],
    this.sharedBackgroundMedia,
    this.bannerAppearance = const {},
  });

  factory CategoryBannerStripConfig.fromJson(Map<String, dynamic> json) {
    final rawBanners = (json['banners'] as List?) ?? const [];
    final configuredBanners = rawBanners
        .whereType<Map>()
        .map((e) => CategoryBannerItem.fromJson(Map<String, dynamic>.from(e)))
        .where((item) => item.isUsable)
        .toList(growable: false);
    final rawAppearance = json['bannerAppearance'];
    final bannerAppearance = <String, CategoryBannerAppearance>{};
    if (rawAppearance is Map) {
      for (final entry in rawAppearance.entries) {
        final key = entry.key.toString().trim();
        final appearance = CategoryBannerAppearance.maybeFromJson(entry.value);
        if (key.isEmpty || appearance == null) continue;
        bannerAppearance[key] = appearance;
      }
    }
    final explicitSkeletonCount = _intValue(
      json['skeletonItemCount'],
      fallback: 0,
    );
    return CategoryBannerStripConfig(
      schemaVersion: _intValue(json['schemaVersion'], fallback: 1),
      skeletonItemCount: explicitSkeletonCount > 0
          ? explicitSkeletonCount
          : (configuredBanners.isNotEmpty
                ? configuredBanners.length
                : defaultCategoryBannerStripSkeletonItemCount),
      sourceMode: CategoryBannerStripSourceMode.fromWireName(
        json['sourceMode'] as String?,
      ),
      sourceCategoryId: _trimNullable(json['sourceCategoryId']),
      configuredBanners: configuredBanners,
      sharedBackgroundMedia: CmsMediaRef.maybeFromJson(
        json['sharedBackgroundMedia'],
      ),
      bannerAppearance: bannerAppearance,
    );
  }
}

sealed class CmsSectionConfig {
  final CmsSectionRecord record;
  const CmsSectionConfig(this.record);
}

class CmsHeroSection extends CmsSectionConfig {
  final HeroCampaignConfig data;
  const CmsHeroSection(super.record, this.data);
}

class CmsEditorialSection extends CmsSectionConfig {
  final EditorialStoryConfig data;
  const CmsEditorialSection(super.record, this.data);
}

class CmsCategoryTilesSection extends CmsSectionConfig {
  final CategoryTilesConfig data;
  const CmsCategoryTilesSection(super.record, this.data);
}

class CmsFeaturedProductsSection extends CmsSectionConfig {
  final FeaturedProductsConfig data;
  const CmsFeaturedProductsSection(super.record, this.data);
}

class CmsServiceCardsSection extends CmsSectionConfig {
  final ServiceCardsConfig data;
  const CmsServiceCardsSection(super.record, this.data);
}

class CmsCollectionHeroSection extends CmsSectionConfig {
  final CollectionHeroConfig data;
  const CmsCollectionHeroSection(super.record, this.data);
}

class CmsEditorialIntroSection extends CmsSectionConfig {
  final EditorialIntroConfig data;
  const CmsEditorialIntroSection(super.record, this.data);
}

class CmsMixedProductGridSection extends CmsSectionConfig {
  final MixedProductGridConfig data;
  const CmsMixedProductGridSection(super.record, this.data);
}

class CmsSeoTextSection extends CmsSectionConfig {
  final SeoTextConfig data;
  const CmsSeoTextSection(super.record, this.data);
}

class CmsDiscoverLinksSection extends CmsSectionConfig {
  final DiscoverLinksConfig data;
  const CmsDiscoverLinksSection(super.record, this.data);
}

class CmsHorizontalTileCarouselSection extends CmsSectionConfig {
  final HorizontalTileCarouselConfig data;
  const CmsHorizontalTileCarouselSection(super.record, this.data);
}

class CmsBrandSegmentSection extends CmsSectionConfig {
  final BrandSegmentConfig data;
  const CmsBrandSegmentSection(super.record, this.data);
}

class CmsCategorySplitTabsSection extends CmsSectionConfig {
  final CategorySplitTabsConfig data;
  const CmsCategorySplitTabsSection(super.record, this.data);
}

class CmsCategoryBannerStripSection extends CmsSectionConfig {
  final CategoryBannerStripConfig data;
  const CmsCategoryBannerStripSection(super.record, this.data);
}

class CmsUnknownSection extends CmsSectionConfig {
  final Object? parseError;
  const CmsUnknownSection(super.record, {this.parseError});
}

CmsSectionConfig parseCmsSection(CmsSectionRecord record) {
  try {
    switch (record.sectionType) {
      case CmsSectionType.heroCampaign:
        return CmsHeroSection(
          record,
          HeroCampaignConfig.fromJson(record.config),
        );
      case CmsSectionType.editorialStory:
        return CmsEditorialSection(
          record,
          EditorialStoryConfig.fromJson(record.config),
        );
      case CmsSectionType.categoryTiles:
        return CmsCategoryTilesSection(
          record,
          CategoryTilesConfig.fromJson(record.config),
        );
      case CmsSectionType.featuredProducts:
        return CmsFeaturedProductsSection(
          record,
          FeaturedProductsConfig.fromJson(record.config),
        );
      case CmsSectionType.serviceCards:
        return CmsServiceCardsSection(
          record,
          ServiceCardsConfig.fromJson(record.config),
        );
      case CmsSectionType.collectionHero:
        return CmsCollectionHeroSection(
          record,
          CollectionHeroConfig.fromJson(record.config),
        );
      case CmsSectionType.editorialIntro:
        return CmsEditorialIntroSection(
          record,
          EditorialIntroConfig.fromJson(record.config),
        );
      case CmsSectionType.mixedProductGrid:
        return CmsMixedProductGridSection(
          record,
          MixedProductGridConfig.fromJson(record.config),
        );
      case CmsSectionType.seoText:
        return CmsSeoTextSection(record, SeoTextConfig.fromJson(record.config));
      case CmsSectionType.discoverLinks:
        return CmsDiscoverLinksSection(
          record,
          DiscoverLinksConfig.fromJson(record.config),
        );
      case CmsSectionType.horizontalTileCarousel:
        return CmsHorizontalTileCarouselSection(
          record,
          HorizontalTileCarouselConfig.fromJson(record.config),
        );
      case CmsSectionType.brandSegment:
        return CmsBrandSegmentSection(
          record,
          BrandSegmentConfig.fromJson(record.config),
        );
      case CmsSectionType.categorySplitTabs:
        return CmsCategorySplitTabsSection(
          record,
          CategorySplitTabsConfig.fromJson(record.config),
        );
      case CmsSectionType.categoryBannerStrip:
        return CmsCategoryBannerStripSection(
          record,
          CategoryBannerStripConfig.fromJson(record.config),
        );
      case null:
        return CmsUnknownSection(record);
    }
  } catch (error) {
    return CmsUnknownSection(record, parseError: error);
  }
}

String? _trimNullable(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _clampColumns(Object? raw, {required int fallback}) {
  final value = (raw as num?)?.toInt() ?? fallback;
  if (value < 1) return 1;
  if (value > 6) return 6;
  return value;
}

int _intValue(Object? raw, {int fallback = 0}) {
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
  return fallback;
}

int _clampInt(Object? raw, {required int min, int? max, int fallback = 0}) {
  final value = _intValue(raw, fallback: fallback);
  if (value < min) return min;
  if (max != null && value > max) return max;
  return value;
}

bool _boolValue(Object? raw, {required bool fallback}) {
  if (raw is bool) return raw;
  if (raw is String) {
    final value = raw.trim().toLowerCase();
    if (value == 'true') return true;
    if (value == 'false') return false;
  }
  return fallback;
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

bool _isKnownGridSort(String value) {
  return switch (value) {
    'manual' || 'newest' || 'price_asc' || 'price_desc' => true,
    _ => false,
  };
}

extension on String {
  String? get nonEmpty => isEmpty ? null : this;
}
