import 'slug_utils.dart';

final _separatorPattern = RegExp(r"['\u2018\u2019\x60\-\u2014\u2013,._/\\]+");
final _multiSpacePattern = RegExp(r'\s{2,}');

/// Normalizes text for search indexing or query tokenization.
///
/// Applies: lowercase, accent stripping, punctuation/separator → space,
/// whitespace collapse, trim.
String normalizeForSearch(String? input) {
  if (input == null || input.isEmpty) return '';
  return stripAccents(input)
      .replaceAll(_separatorPattern, ' ')
      .replaceAll(_multiSpacePattern, ' ')
      .trim();
}

/// Builds a searchIndex string for a product record.
///
/// Concatenates key text fields, separated by spaces, then normalizes.
String buildProductSearchIndex(Map<String, dynamic> data) {
  final parts = <String>[
    _str(data['name']),
    _str(data['slug']),
    _str(data['summary']),
    _str(data['description']),
    _str(data['brand']),
    _str(data['productType']),
    _str(data['ean']),
    _str(data['code']),
  ];
  return normalizeForSearch(parts.where((s) => s.isNotEmpty).join(' '));
}

String _str(dynamic value) {
  if (value == null) return '';
  final s = '$value'.trim();
  return s;
}
