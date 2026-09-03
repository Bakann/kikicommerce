import '../../application/admin/catalog_csv_format.dart';
import '../../application/admin/catalog_import_report.dart';

class CsvRow {
  final int lineNumber;
  final Map<String, String> values;

  const CsvRow({required this.lineNumber, required this.values});

  String value(String key) => values[key] ?? '';

  String? valueOrNull(String key) {
    final resolved = value(key).trim();
    return resolved.isEmpty ? null : resolved;
  }

  int? intValue(String key) {
    final resolved = valueOrNull(key);
    return resolved == null ? null : int.tryParse(resolved);
  }

  double? doubleValue(String key) {
    final resolved = valueOrNull(key);
    return resolved == null
        ? null
        : double.tryParse(resolved.replaceAll(',', '.'));
  }

  bool boolValue(String key, {required bool defaultValue}) {
    return parseCsvBool(value(key), defaultValue: defaultValue);
  }

  List<String> pipeValues(String key) {
    return CatalogCsvFormat.splitList(value(key));
  }

  List<String> pipeValuesPreserveEmpty(String key) {
    return CatalogCsvFormat.splitListPreserveEmpty(value(key));
  }
}

List<CsvRow> parseCsvRows(String csvContent) {
  final rows = CatalogCsvFormat.decode(csvContent);

  if (rows.isEmpty) {
    return const [];
  }

  final headers = rows.first.map((cell) => cell.toString().trim()).toList();
  final result = <CsvRow>[];

  for (var index = 1; index < rows.length; index += 1) {
    final rawRow = rows[index];
    if (rawRow.every((cell) => cell.toString().trim().isEmpty)) {
      continue;
    }

    final values = <String, String>{};
    for (var cellIndex = 0; cellIndex < headers.length; cellIndex += 1) {
      final value = cellIndex < rawRow.length ? rawRow[cellIndex] : '';
      values[headers[cellIndex]] = value.toString().trim();
    }
    result.add(CsvRow(lineNumber: index + 1, values: values));
  }

  return result;
}

bool parseCsvBool(String rawValue, {required bool defaultValue}) {
  final value = rawValue.trim().toLowerCase();
  if (value.isEmpty) {
    return defaultValue;
  }
  if (const {'true', '1', 'yes', 'oui', 'vrai'}.contains(value)) {
    return true;
  }
  if (const {'false', '0', 'no', 'non', 'faux'}.contains(value)) {
    return false;
  }
  throw FormatException('Booléen CSV invalide: "$rawValue".');
}

bool hasNarrativeData(CsvRow row) {
  for (final key in const [
    'chapter_positions',
    'chapter_media_codes',
    'chapter_headlines',
    'chapter_stories',
    'chapter_cta_labels',
    'chapter_cta_actions',
    'chapter_is_active',
  ]) {
    if (row.value(key).trim().isNotEmpty) {
      return true;
    }
  }
  return false;
}

class NarrativeCsvBlock {
  final int lineNumber;
  final String productCode;
  final Map<String, String> rawValues;

  const NarrativeCsvBlock({
    required this.lineNumber,
    required this.productCode,
    required this.rawValues,
  });

  factory NarrativeCsvBlock.fromRow(CsvRow row) {
    return NarrativeCsvBlock(
      lineNumber: row.lineNumber,
      productCode: row.value('product_code'),
      rawValues: {
        for (final key in const [
          'chapter_positions',
          'chapter_media_codes',
          'chapter_headlines',
          'chapter_stories',
          'chapter_cta_labels',
          'chapter_cta_actions',
          'chapter_is_active',
        ])
          key: row.value(key),
      },
    );
  }

  bool hasSameRawValues(NarrativeCsvBlock other) {
    for (final key in _narrativeRawValueKeys) {
      if ((rawValues[key] ?? '') != (other.rawValues[key] ?? '')) {
        return false;
      }
    }
    return true;
  }

  ParsedNarrativeCsvBlock? parse(CatalogImportReport report) {
    final positions = CatalogCsvFormat.splitListPreserveEmpty(
      rawValues['chapter_positions'] ?? '',
    );
    final mediaCodes = CatalogCsvFormat.splitListPreserveEmpty(
      rawValues['chapter_media_codes'] ?? '',
    );
    final headlines = CatalogCsvFormat.splitListPreserveEmpty(
      rawValues['chapter_headlines'] ?? '',
    );
    final baseLength = mediaCodes.length;

    if (baseLength == 0 ||
        positions.length != baseLength ||
        headlines.length != baseLength) {
      report.errors.add(
        'Produit $productCode: arité narrative invalide à la ligne $lineNumber.',
      );
      return null;
    }

    final stories = _normalizeOptionalList(
      rawValues['chapter_stories'] ?? '',
      expectedLength: baseLength,
      productCode: productCode,
      lineNumber: lineNumber,
      fieldName: 'chapter_stories',
      report: report,
    );
    final ctaLabels = _normalizeOptionalList(
      rawValues['chapter_cta_labels'] ?? '',
      expectedLength: baseLength,
      productCode: productCode,
      lineNumber: lineNumber,
      fieldName: 'chapter_cta_labels',
      report: report,
    );
    final ctaActions = _normalizeOptionalList(
      rawValues['chapter_cta_actions'] ?? '',
      expectedLength: baseLength,
      productCode: productCode,
      lineNumber: lineNumber,
      fieldName: 'chapter_cta_actions',
      report: report,
    );
    final isActiveRaw = _normalizeOptionalList(
      rawValues['chapter_is_active'] ?? '',
      expectedLength: baseLength,
      productCode: productCode,
      lineNumber: lineNumber,
      fieldName: 'chapter_is_active',
      report: report,
    );
    if (stories == null ||
        ctaLabels == null ||
        ctaActions == null ||
        isActiveRaw == null) {
      return null;
    }

    final parsedPositions = <int>[];
    for (final value in positions) {
      final parsed = int.tryParse(value);
      if (parsed == null) {
        report.errors.add(
          'Produit $productCode: position narrative invalide "$value" à la ligne $lineNumber.',
        );
        return null;
      }
      parsedPositions.add(parsed);
    }

    final parsedIsActive = <bool>[];
    for (final value in isActiveRaw) {
      if (value.isEmpty) {
        parsedIsActive.add(true);
        continue;
      }
      try {
        parsedIsActive.add(parseCsvBool(value, defaultValue: true));
      } on FormatException {
        report.errors.add(
          'Produit $productCode: booléen narrative invalide "$value" à la ligne $lineNumber.',
        );
        return null;
      }
    }

    return ParsedNarrativeCsvBlock(
      positions: parsedPositions,
      mediaCodes: mediaCodes,
      headlines: headlines,
      stories: stories,
      ctaLabels: ctaLabels,
      ctaActions: ctaActions,
      isActive: parsedIsActive,
    );
  }

  List<String>? _normalizeOptionalList(
    String rawValue, {
    required int expectedLength,
    required String productCode,
    required int lineNumber,
    required String fieldName,
    required CatalogImportReport report,
  }) {
    if (rawValue.isEmpty) {
      return List<String>.filled(expectedLength, '');
    }

    final values = CatalogCsvFormat.splitListPreserveEmpty(rawValue);
    if (values.length != expectedLength) {
      report.errors.add(
        'Produit $productCode: arité narrative incohérente pour $fieldName à la ligne $lineNumber.',
      );
      return null;
    }
    return values;
  }
}

const _narrativeRawValueKeys = [
  'chapter_positions',
  'chapter_media_codes',
  'chapter_headlines',
  'chapter_stories',
  'chapter_cta_labels',
  'chapter_cta_actions',
  'chapter_is_active',
];

class ParsedNarrativeCsvBlock {
  final List<int> positions;
  final List<String> mediaCodes;
  final List<String> headlines;
  final List<String> stories;
  final List<String> ctaLabels;
  final List<String> ctaActions;
  final List<bool> isActive;

  const ParsedNarrativeCsvBlock({
    required this.positions,
    required this.mediaCodes,
    required this.headlines,
    required this.stories,
    required this.ctaLabels,
    required this.ctaActions,
    required this.isActive,
  });
}

class MediaSeed {
  final String code;
  final String title;
  final String altText;
  final String source;
  final String mimeType;
  final bool isActive;

  const MediaSeed({
    required this.code,
    required this.title,
    required this.altText,
    required this.source,
    required this.mimeType,
    required this.isActive,
  });
}
