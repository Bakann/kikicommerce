class CatalogCategory {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String? slug;
  final bool isActive;
  final bool isHidden;
  final int position;
  final String? parentId;

  const CatalogCategory({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.slug,
    this.isActive = true,
    this.isHidden = false,
    this.position = 0,
    this.parentId,
  });
}

class CatalogMedia {
  static const String defaultPreviewThumbSize = '600x600';
  static const String listingThumbSize = '600x800f';
  static const String swatchThumbSize = '120x120';
  static const String galleryThumbnailThumbSize = '160x210f';
  static const String productDetailMobileThumbSize = '800x1100f';
  static const String productDetailTabletThumbSize = '960x1320f';
  static const String productDetailDesktopThumbSize = '1280x1720f';

  final String id;
  final String url;
  final String? originalUrl;
  final String previewUrl;
  final String? altText;
  final String? title;
  final String? cropPreset;
  final double? cropX;
  final double? cropY;
  final double? cropWidth;
  final double? cropHeight;

  const CatalogMedia({
    required this.id,
    required this.url,
    this.originalUrl,
    required this.previewUrl,
    this.altText,
    this.title,
    this.cropPreset,
    this.cropX,
    this.cropY,
    this.cropWidth,
    this.cropHeight,
  });

  String thumbUrl(String size) {
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}thumb=$size';
  }

  String get listingUrl => thumbUrl(listingThumbSize);

  String get swatchUrl => thumbUrl(swatchThumbSize);

  String get galleryThumbnailUrl => thumbUrl(galleryThumbnailThumbSize);

  String get productDetailMobileUrl => thumbUrl(productDetailMobileThumbSize);

  String get productDetailTabletUrl => thumbUrl(productDetailTabletThumbSize);

  String get productDetailDesktopUrl => thumbUrl(productDetailDesktopThumbSize);
}

class CatalogProduct {
  final String id;
  final String code;
  final String name;
  final String? slug;
  final String? summary;
  final String? description;
  final String? ean;
  final String? gender;
  final String? productType;
  final String? brand;
  final bool isActive;
  final DateTime? onlineDate;
  final DateTime? offlineDate;
  final CatalogMedia? picture;
  final CatalogMedia? thumbnail;
  final List<CatalogMedia> gallery;

  const CatalogProduct({
    required this.id,
    required this.code,
    required this.name,
    this.slug,
    this.summary,
    this.description,
    this.ean,
    this.gender,
    this.productType,
    this.brand,
    this.isActive = true,
    this.onlineDate,
    this.offlineDate,
    this.picture,
    this.thumbnail,
    this.gallery = const [],
  });

  CatalogMedia? get listingMedia =>
      picture ?? thumbnail ?? (gallery.isEmpty ? null : gallery.first);
}

class CatalogPrice {
  final String id;
  final String productId;
  final double price;
  final String? unitId;
  final int? minQuantity;
  final bool? net;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? channel;
  final bool isDefault;
  final bool isActive;
  final String? currencySymbol;
  final String? currencyCode;

  const CatalogPrice({
    required this.id,
    required this.productId,
    required this.price,
    this.unitId,
    this.minQuantity,
    this.net,
    this.startTime,
    this.endTime,
    this.channel,
    this.isDefault = false,
    this.isActive = true,
    this.currencySymbol,
    this.currencyCode,
  });
}

enum NarrativeCtaAction { zoom, sizeGuide, materialDetail, none }

class NarrativeChapter {
  final String id;
  final String mediaId;
  final int position;
  final String headline;
  final String? story;
  final String? ctaLabel;
  final NarrativeCtaAction ctaAction;

  const NarrativeChapter({
    required this.id,
    required this.mediaId,
    required this.position,
    required this.headline,
    this.story,
    this.ctaLabel,
    this.ctaAction = NarrativeCtaAction.none,
  });
}

class CatalogListingItem {
  final String id;
  final String categoryId;
  final String productId;
  final String? productRouteSlug;
  final int? position;
  final bool isPrimary;
  final bool isActive;
  final CatalogCategory? category;
  final CatalogProduct product;
  final List<CatalogPrice> prices;

  const CatalogListingItem({
    required this.id,
    required this.categoryId,
    required this.productId,
    required this.product,
    this.productRouteSlug,
    this.position,
    this.isPrimary = false,
    this.isActive = true,
    this.category,
    this.prices = const [],
  });
}
