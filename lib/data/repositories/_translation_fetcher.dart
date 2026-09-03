import '../../core/utils/pocketbase_filter_utils.dart';
import '../api/pocketbase_client.dart';
import '../models/category_translation.dart';
import '../models/narrative_chapter_translation.dart';
import '../models/product_translation.dart';

/// Default catalog locale. Base `products`/`categories` columns hold this
/// language, so a request for it needs no translation lookup at all.
const String defaultCatalogLocale = 'fr';

/// Fetches the active-locale [ProductTranslation] for each id, keyed by product
/// id. Returns empty for the default locale (the base columns already hold it)
/// and swallows errors — a missing `product_translations` collection or a
/// failed read must degrade to base (default-locale) content, never break the
/// page. Mirrors the parallel-secondary-fetch shape of [fetchPricesByProductIds].
Future<Map<String, ProductTranslation>> fetchProductTranslations(
  PocketBaseClient client,
  Iterable<String> productIds, {
  required String locale,
}) async {
  final ids = productIds.toSet();
  if (ids.isEmpty || locale == defaultCatalogLocale) return const {};

  final filter =
      '(${ids.map((id) => 'product="${escapeFilterValue(id)}"').join(' || ')})'
      ' && locale="${escapeFilterValue(locale)}"';
  try {
    final data = await client.listRecords<ProductTranslation>(
      'product_translations',
      filter: filter,
      perPage: ids.length,
      fromJson: ProductTranslation.fromJson,
    );
    return {for (final t in data.items) t.productId: t};
  } catch (_) {
    return const {};
  }
}

/// Like [fetchProductTranslations] but for `category_translations`, keyed by
/// category id.
Future<Map<String, CategoryTranslation>> fetchCategoryTranslations(
  PocketBaseClient client,
  Iterable<String> categoryIds, {
  required String locale,
}) async {
  final ids = categoryIds.toSet();
  if (ids.isEmpty || locale == defaultCatalogLocale) return const {};

  final filter =
      '(${ids.map((id) => 'category="${escapeFilterValue(id)}"').join(' || ')})'
      ' && locale="${escapeFilterValue(locale)}"';
  try {
    final data = await client.listRecords<CategoryTranslation>(
      'category_translations',
      filter: filter,
      perPage: ids.length,
      fromJson: CategoryTranslation.fromJson,
    );
    return {for (final t in data.items) t.categoryId: t};
  } catch (_) {
    return const {};
  }
}

/// Like [fetchProductTranslations] but for `narrative_chapter_translations`,
/// keyed by chapter id.
Future<Map<String, NarrativeChapterTranslation>>
fetchNarrativeChapterTranslations(
  PocketBaseClient client,
  Iterable<String> chapterIds, {
  required String locale,
}) async {
  final ids = chapterIds.toSet();
  if (ids.isEmpty || locale == defaultCatalogLocale) return const {};

  final filter =
      '(${ids.map((id) => 'chapter="${escapeFilterValue(id)}"').join(' || ')})'
      ' && locale="${escapeFilterValue(locale)}"';
  try {
    final data = await client.listRecords<NarrativeChapterTranslation>(
      'narrative_chapter_translations',
      filter: filter,
      perPage: ids.length,
      fromJson: NarrativeChapterTranslation.fromJson,
    );
    return {for (final t in data.items) t.chapterId: t};
  } catch (_) {
    return const {};
  }
}

/// Active-locale navigation-item labels, keyed by item id. Only the label is
/// translated, so this returns the raw string (empty/blank rows are dropped so
/// the caller falls back to the base label). Same default-locale skip + error
/// swallow as the other fetchers.
Future<Map<String, String>> fetchNavigationItemLabels(
  PocketBaseClient client,
  Iterable<String> itemIds, {
  required String locale,
}) async {
  final ids = itemIds.toSet();
  if (ids.isEmpty || locale == defaultCatalogLocale) return const {};

  final filter =
      '(${ids.map((id) => 'item="${escapeFilterValue(id)}"').join(' || ')})'
      ' && locale="${escapeFilterValue(locale)}"';
  try {
    final data = await client.listRecords<Map<String, dynamic>>(
      'navigation_item_translations',
      filter: filter,
      perPage: ids.length,
      fields: 'item,label',
      fromJson: (json) => json,
    );
    final labels = <String, String>{};
    for (final row in data.items) {
      final id = row['item'] as String?;
      final label = (row['label'] as String?)?.trim();
      if (id != null && label != null && label.isNotEmpty) {
        labels[id] = label;
      }
    }
    return labels;
  } catch (_) {
    return const {};
  }
}
