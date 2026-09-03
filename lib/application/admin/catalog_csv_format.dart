import 'package:csv/csv.dart';

final class CatalogCsvFormat {
  static const String fieldDelimiter = ';';
  static const String listDelimiter = '|';

  static const List<String> headers = [
    'category_code',
    'category_name',
    'category_description',
    'category_slug',
    'category_is_active',
    'category_parent_code',
    'category_position',
    'category_is_primary',
    'product_code',
    'product_name',
    'product_slug',
    'product_summary',
    'product_description',
    'product_ean',
    'product_gender',
    'product_type',
    'product_brand',
    'product_is_active',
    'product_online_date',
    'product_offline_date',
    'thumbnail_code',
    'thumbnail_title',
    'thumbnail_alt_text',
    'thumbnail_source',
    'thumbnail_mime_type',
    'thumbnail_is_active',
    'picture_code',
    'picture_title',
    'picture_alt_text',
    'picture_source',
    'picture_mime_type',
    'picture_is_active',
    'gallery_container_code',
    'gallery_container_name',
    'gallery_container_is_active',
    'gallery_media_codes',
    'gallery_media_titles',
    'gallery_media_alt_texts',
    'gallery_media_sources',
    'gallery_media_mime_types',
    'gallery_media_is_active',
    'chapter_positions',
    'chapter_media_codes',
    'chapter_headlines',
    'chapter_stories',
    'chapter_cta_labels',
    'chapter_cta_actions',
    'chapter_is_active',
    'currency_isocode',
    'currency_symbol',
    'currency_name',
    'currency_digits',
    'currency_is_active',
    'unit_code',
    'unit_name',
    'unit_symbol',
    'unit_is_active',
    'price',
    'price_minqtd',
    'price_net',
    'price_start_time',
    'price_end_time',
    'price_channel',
    'price_is_default',
    'price_is_active',
  ];

  static List<List<dynamic>> decode(String csvContent) {
    return CsvDecoder(fieldDelimiter: fieldDelimiter).convert(csvContent);
  }

  static String encodeRows(Iterable<Map<String, Object?>> rows) {
    final csvRows = <List<dynamic>>[
      headers,
      for (final row in rows)
        [for (final header in headers) stringify(row[header])],
    ];

    return const CsvEncoder(
      fieldDelimiter: fieldDelimiter,
      lineDelimiter: '\n',
    ).convert(csvRows);
  }

  static List<String> splitList(String value) {
    if (value.trim().isEmpty) {
      return const [];
    }

    return value
        .split(listDelimiter)
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<String> splitListPreserveEmpty(String value) {
    if (value.isEmpty) {
      return const [];
    }

    return value.split(listDelimiter).map((item) => item.trim()).toList();
  }

  static String joinList(Iterable<Object?> values) {
    return values
        .map(stringify)
        .where((value) => value.isNotEmpty)
        .join(listDelimiter);
  }

  static String joinListPreserveEmpty(Iterable<Object?> values) {
    return values.map(stringify).join(listDelimiter);
  }

  static String stringify(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is bool) {
      return value ? 'true' : 'false';
    }
    return '$value';
  }
}
