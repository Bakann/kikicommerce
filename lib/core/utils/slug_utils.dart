import '../../domain/catalog/catalog_entities.dart';

const Map<String, String> _slugCharReplacements = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'æ': 'ae',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'ď': 'd',
  'đ': 'd',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ė': 'e',
  'ę': 'e',
  'î': 'i',
  'ï': 'i',
  'í': 'i',
  'ì': 'i',
  'ī': 'i',
  'į': 'i',
  'ł': 'l',
  'ñ': 'n',
  'ń': 'n',
  'ô': 'o',
  'ö': 'o',
  'ò': 'o',
  'ó': 'o',
  'õ': 'o',
  'ø': 'o',
  'ō': 'o',
  'œ': 'oe',
  'ß': 'ss',
  'ś': 's',
  'š': 's',
  'û': 'u',
  'ü': 'u',
  'ù': 'u',
  'ú': 'u',
  'ū': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ž': 'z',
  'ź': 'z',
  'ż': 'z',
};

/// Lowercases and replaces accented/diacritical characters with their
/// ASCII equivalents. Does not strip punctuation or replace spaces.
String stripAccents(String input) {
  final lowercased = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lowercased.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(_slugCharReplacements[character] ?? character);
  }
  return buffer.toString();
}

String slugify(String? input, {String fallback = 'item'}) {
  final normalized = _normalizeSlugSource(input);
  if (normalized.isNotEmpty) {
    return normalized;
  }

  final fallbackSlug = _normalizeSlugSource(fallback);
  return fallbackSlug.isNotEmpty ? fallbackSlug : 'item';
}

String preferredProductSlug(CatalogProduct product) {
  final persistedSlug = product.slug?.trim();
  if (persistedSlug != null && persistedSlug.isNotEmpty) {
    return slugify(persistedSlug, fallback: product.code);
  }

  return slugify(product.name, fallback: product.code);
}

String canonicalProductSlug({
  required CatalogProduct product,
  required Iterable<CatalogProduct> siblingProducts,
}) {
  final preferredSlug = preferredProductSlug(product);
  final collisions = siblingProducts
      .where((sibling) => preferredProductSlug(sibling) == preferredSlug)
      .length;

  if (collisions <= 1) {
    return preferredSlug;
  }

  final codeSlug = slugify(product.code, fallback: product.id);
  return '$preferredSlug--$codeSlug';
}

String _normalizeSlugSource(String? input) {
  if (input == null) {
    return '';
  }

  final lowercased = input.trim().toLowerCase();
  if (lowercased.isEmpty) {
    return '';
  }

  final buffer = StringBuffer();
  for (final rune in lowercased.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(_slugCharReplacements[character] ?? character);
  }

  return buffer
      .toString()
      .replaceAll(RegExp(r"[’'`]+"), '')
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
