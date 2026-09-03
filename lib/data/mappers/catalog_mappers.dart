import '../../application/catalog/catalog_read_models.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../models/category.dart';
import '../models/category_product.dart';
import '../models/category_translation.dart';
import '../models/media.dart';
import '../models/narrative_chapter.dart';
import '../models/narrative_chapter_translation.dart';
import '../models/price_row.dart';
import '../models/product.dart';
import '../models/product_translation.dart';

CatalogCategory toCatalogCategory(
  Category category, {
  CategoryTranslation? translation,
}) {
  return CatalogCategory(
    id: category.id,
    code: category.code,
    // Translated display strings fall back to the base (default-locale) value.
    name: translation?.name ?? category.name,
    description: translation?.description ?? category.description,
    // `slug` stays the base value: routes must be locale-invariant.
    slug: category.slug,
    isActive: category.isActive,
    isHidden: category.isHidden,
    position: category.position,
    parentId: category.parentId,
  );
}

CatalogMedia toCatalogMedia(Media media) {
  return CatalogMedia(
    id: media.id,
    url: media.fileUrl,
    originalUrl: media.originalFileUrl,
    previewUrl: media.thumbUrl(size: CatalogMedia.defaultPreviewThumbSize),
    altText: media.altText,
    title: media.title,
    cropPreset: media.cropPreset,
    cropX: media.cropX,
    cropY: media.cropY,
    cropWidth: media.cropWidth,
    cropHeight: media.cropHeight,
  );
}

CatalogProduct toCatalogProduct(
  Product product, {
  ProductTranslation? translation,
}) {
  return CatalogProduct(
    id: product.id,
    code: product.code,
    // Translated display strings fall back to the base (default-locale) value.
    name: translation?.name ?? product.name,
    // `slug` stays the base value: routes must be locale-invariant. Never pass
    // a translated product into the slug utilities.
    slug: product.slug,
    summary: translation?.summary ?? product.summary,
    description: translation?.description ?? product.description,
    ean: product.ean,
    gender: product.gender,
    productType: product.productType,
    brand: product.brand,
    isActive: product.isActive,
    onlineDate: product.onlineDate,
    offlineDate: product.offlineDate,
    picture: product.picture == null ? null : toCatalogMedia(product.picture!),
    thumbnail: product.thumbnail == null
        ? null
        : toCatalogMedia(product.thumbnail!),
    gallery: [
      for (final container in product.galleryImages)
        for (final media in container.medias) toCatalogMedia(media),
    ],
  );
}

CatalogPrice toCatalogPrice(PriceRow priceRow) {
  return CatalogPrice(
    id: priceRow.id,
    productId: priceRow.productId,
    price: priceRow.price,
    unitId: priceRow.unitId,
    minQuantity: priceRow.minqtd,
    net: priceRow.net,
    startTime: priceRow.startTime,
    endTime: priceRow.endTime,
    channel: priceRow.channel,
    isDefault: priceRow.isDefault,
    isActive: priceRow.isActive,
    currencySymbol: priceRow.currencySymbol,
    currencyCode: priceRow.currencyIsocode,
  );
}

NarrativeChapter toNarrativeChapter(
  NarrativeChapterRecord record, {
  NarrativeChapterTranslation? translation,
}) {
  return NarrativeChapter(
    id: record.id,
    mediaId: record.mediaId,
    position: record.position,
    headline: translation?.headline ?? record.headline,
    story: translation?.story ?? record.story,
    ctaLabel: translation?.ctaLabel ?? record.ctaLabel,
    ctaAction: switch (record.ctaAction) {
      'zoom' => NarrativeCtaAction.zoom,
      'sizeGuide' => NarrativeCtaAction.sizeGuide,
      'materialDetail' => NarrativeCtaAction.materialDetail,
      _ => NarrativeCtaAction.none,
    },
  );
}

CatalogListingItem toCatalogListingItem(
  CategoryProduct categoryProduct,
  List<CatalogPrice> prices, {
  String? productRouteSlug,
  ProductTranslation? productTranslation,
  CategoryTranslation? categoryTranslation,
}) {
  final product = categoryProduct.product;
  if (product == null) {
    throw StateError('CategoryProduct ${categoryProduct.id} has no product.');
  }

  return CatalogListingItem(
    id: categoryProduct.id,
    categoryId: categoryProduct.categoryId,
    productId: categoryProduct.productId,
    // `productRouteSlug` is computed by the caller from the BASE product so it
    // stays locale-invariant; only the displayed product/category are localized.
    productRouteSlug: productRouteSlug,
    position: categoryProduct.position,
    isPrimary: categoryProduct.isPrimary,
    isActive: categoryProduct.isActive,
    category: categoryProduct.category == null
        ? null
        : toCatalogCategory(
            categoryProduct.category!,
            translation: categoryTranslation,
          ),
    product: toCatalogProduct(product, translation: productTranslation),
    prices: prices,
  );
}

CatalogPageData toCatalogPageData({
  required String categoryId,
  required int page,
  required int perPage,
  required int totalItems,
  required int totalPages,
  required List<CatalogListingItem> items,
}) {
  return CatalogPageData(
    page: page,
    perPage: perPage,
    totalItems: totalItems,
    totalPages: totalPages,
    categoryId: categoryId,
    categoryName: items.firstOrNull?.category?.name,
    category: items.firstOrNull?.category,
    items: items,
  );
}
