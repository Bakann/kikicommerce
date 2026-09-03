import 'dart:collection';

import '../admin/catalog_import_report.dart';

sealed class CatalogInvalidationTarget {
  const CatalogInvalidationTarget();
}

abstract class _SingletonInvalidationTarget extends CatalogInvalidationTarget {
  const _SingletonInvalidationTarget();

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => '$runtimeType()';
}

abstract class _StringInvalidationTarget extends CatalogInvalidationTarget {
  final String value;

  const _StringInvalidationTarget(this.value);

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType &&
        other is _StringInvalidationTarget &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => '$runtimeType($value)';
}

final class ProductDetailInvalidation extends _StringInvalidationTarget {
  const ProductDetailInvalidation(super.value);

  String get productId => value;
}

final class CategoryPlpInvalidation extends _StringInvalidationTarget {
  const CategoryPlpInvalidation(super.value);

  String get categoryId => value;
}

final class CategoryBySlugInvalidation extends _StringInvalidationTarget {
  const CategoryBySlugInvalidation(super.value);

  String get slug => value;
}

final class CategoryTreeInvalidation extends _SingletonInvalidationTarget {
  const CategoryTreeInvalidation();
}

final class AllProductListsInvalidation extends _SingletonInvalidationTarget {
  const AllProductListsInvalidation();
}

final class AllProductDetailsInvalidation extends _SingletonInvalidationTarget {
  const AllProductDetailsInvalidation();
}

final class AllProductRoutesInvalidation extends _SingletonInvalidationTarget {
  const AllProductRoutesInvalidation();
}

final class AllSearchResultsInvalidation extends _SingletonInvalidationTarget {
  const AllSearchResultsInvalidation();
}

final class DrawerNavigationInvalidation extends _SingletonInvalidationTarget {
  const DrawerNavigationInvalidation();
}

final class MediaLibraryInvalidation extends _SingletonInvalidationTarget {
  const MediaLibraryInvalidation();
}

/// Invalidates the CMS page/section reads (homepage, segment homepages, generic
/// pages, CMS PLPs). Sweeps the `cms:` prefix in the `LocalReadCache`/dedup
/// layer (where CMS reads are now cached) and invalidates the matching Riverpod
/// providers.
final class CmsPagesInvalidation extends _SingletonInvalidationTarget {
  const CmsPagesInvalidation();
}

List<CatalogInvalidationTarget> invalidationsForCatalogImportReport(
  CatalogImportReport report,
) {
  final changedCollections = <String>{
    for (final entry in report.createdByCollection.entries)
      if (entry.value > 0) entry.key,
    for (final entry in report.updatedByCollection.entries)
      if (entry.value > 0) entry.key,
  };

  return _dedupe([
    for (final collection in changedCollections)
      ..._broadInvalidationsForCollection(collection),
  ]);
}

List<CatalogInvalidationTarget> invalidationsForAdminSave({
  required String collection,
  required Map<String, dynamic> data,
  String? recordId,
}) {
  return _dedupe(
    _invalidationsForChangedRecord(
      collection: collection,
      recordId: recordId,
      data: data,
    ),
  );
}

List<CatalogInvalidationTarget> invalidationsForAdminDelete({
  required String collection,
  required String recordId,
}) {
  return _dedupe(
    _invalidationsForChangedRecord(collection: collection, recordId: recordId),
  );
}

List<CatalogInvalidationTarget> invalidationsForCreatedProductInCategory({
  required String categoryId,
  required String productId,
}) {
  return _dedupe([
    CategoryPlpInvalidation(categoryId),
    ProductDetailInvalidation(productId),
    const AllSearchResultsInvalidation(),
    const AllProductRoutesInvalidation(),
  ]);
}

List<CatalogInvalidationTarget> invalidationsForSavedProductText(
  String productId,
) {
  return _dedupe([
    ProductDetailInvalidation(productId),
    const AllProductListsInvalidation(),
    const AllSearchResultsInvalidation(),
    const AllProductRoutesInvalidation(),
  ]);
}

List<CatalogInvalidationTarget> invalidationsForSavedProductPrice(
  String productId,
) {
  return _dedupe([
    ProductDetailInvalidation(productId),
    const AllProductListsInvalidation(),
    const AllSearchResultsInvalidation(),
  ]);
}

List<CatalogInvalidationTarget> invalidationsForAssignedProductMedia({
  required String productId,
}) {
  return _dedupe([
    ProductDetailInvalidation(productId),
    const AllProductListsInvalidation(),
    const AllSearchResultsInvalidation(),
  ]);
}

List<CatalogInvalidationTarget> invalidationsForAddedProductGalleryMedia({
  required String productId,
}) {
  return _dedupe([
    ProductDetailInvalidation(productId),
    const AllProductListsInvalidation(),
  ]);
}

List<CatalogInvalidationTarget> invalidationsForReplacedProductMedia({
  required String productId,
}) {
  return _dedupe([
    ProductDetailInvalidation(productId),
    const AllProductListsInvalidation(),
    const AllSearchResultsInvalidation(),
    const DrawerNavigationInvalidation(),
    const MediaLibraryInvalidation(),
  ]);
}

List<CatalogInvalidationTarget> _invalidationsForChangedRecord({
  required String collection,
  String? recordId,
  Map<String, dynamic>? data,
}) {
  final categoryId = _stringValue(data?['category']);
  final productId = _stringValue(data?['product']) ?? _stringValue(data?['id']);
  final slug = _stringValue(data?['slug']);

  switch (collection) {
    case 'categories':
      return [
        const CategoryTreeInvalidation(),
        if (recordId != null) CategoryPlpInvalidation(recordId),
        if (slug != null) CategoryBySlugInvalidation(slug),
        const AllProductListsInvalidation(),
        const AllProductRoutesInvalidation(),
        const DrawerNavigationInvalidation(),
      ];
    case 'products':
    case 'product_translations':
      return [
        if (collection == 'products' && recordId != null)
          ProductDetailInvalidation(recordId)
        else if (productId != null)
          ProductDetailInvalidation(productId)
        else
          const AllProductDetailsInvalidation(),
        const AllProductListsInvalidation(),
        const AllSearchResultsInvalidation(),
        const AllProductRoutesInvalidation(),
        const DrawerNavigationInvalidation(),
      ];
    case 'categoryProducts':
      return [
        if (categoryId != null)
          CategoryPlpInvalidation(categoryId)
        else
          const AllProductListsInvalidation(),
        if (productId != null) ProductDetailInvalidation(productId),
        const AllProductRoutesInvalidation(),
      ];
    case 'priceRows':
      return [
        if (productId != null)
          ProductDetailInvalidation(productId)
        else
          const AllProductDetailsInvalidation(),
        const AllProductListsInvalidation(),
        const AllSearchResultsInvalidation(),
      ];
    case 'narrativeChapters':
      return [
        if (productId != null)
          ProductDetailInvalidation(productId)
        else
          const AllProductDetailsInvalidation(),
      ];
    case 'narrative_chapter_translations':
      // A chapter-translation record relates to `chapter`, not `product`, so
      // `data['id']` is the translation row's own id — never a product id.
      // Only trust an explicit `product` relation; otherwise invalidate every
      // PDP surface rather than a bogus per-product key.
      final chapterTranslationProductId = _stringValue(data?['product']);
      return [
        if (chapterTranslationProductId != null)
          ProductDetailInvalidation(chapterTranslationProductId)
        else
          const AllProductDetailsInvalidation(),
      ];
    case 'medias':
      return const [
        MediaLibraryInvalidation(),
        AllProductDetailsInvalidation(),
        AllProductListsInvalidation(),
        AllSearchResultsInvalidation(),
        DrawerNavigationInvalidation(),
      ];
    case 'mediaContainers':
      return const [
        AllProductDetailsInvalidation(),
        AllProductListsInvalidation(),
      ];
    case 'navigation_menus':
    case 'navigation_items':
      return const [DrawerNavigationInvalidation()];
    case 'cms_pages':
    case 'page_sections':
      return const [CmsPagesInvalidation()];
    case 'currencies':
    case 'units':
      return const [
        AllProductDetailsInvalidation(),
        AllProductListsInvalidation(),
        AllSearchResultsInvalidation(),
      ];
  }

  return const [];
}

List<CatalogInvalidationTarget> _broadInvalidationsForCollection(
  String collection,
) {
  switch (collection) {
    case 'categories':
      return const [
        CategoryTreeInvalidation(),
        AllProductListsInvalidation(),
        AllProductRoutesInvalidation(),
        DrawerNavigationInvalidation(),
      ];
    case 'products':
    case 'product_translations':
      return const [
        AllProductDetailsInvalidation(),
        AllProductListsInvalidation(),
        AllSearchResultsInvalidation(),
        AllProductRoutesInvalidation(),
        DrawerNavigationInvalidation(),
      ];
    case 'categoryProducts':
      return const [
        AllProductListsInvalidation(),
        AllProductRoutesInvalidation(),
      ];
    case 'priceRows':
    case 'currencies':
    case 'units':
      return const [
        AllProductDetailsInvalidation(),
        AllProductListsInvalidation(),
        AllSearchResultsInvalidation(),
      ];
    case 'narrativeChapters':
    case 'narrative_chapter_translations':
    case 'mediaContainers':
      return const [
        AllProductDetailsInvalidation(),
        AllProductListsInvalidation(),
      ];
    case 'medias':
      return const [
        MediaLibraryInvalidation(),
        AllProductDetailsInvalidation(),
        AllProductListsInvalidation(),
        AllSearchResultsInvalidation(),
        DrawerNavigationInvalidation(),
      ];
    case 'navigation_menus':
    case 'navigation_items':
      return const [DrawerNavigationInvalidation()];
    case 'cms_pages':
    case 'page_sections':
      return const [CmsPagesInvalidation()];
  }

  return const [];
}

String? _stringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<CatalogInvalidationTarget> _dedupe(
  Iterable<CatalogInvalidationTarget> targets,
) {
  return LinkedHashSet<CatalogInvalidationTarget>.of(targets).toList();
}
