/// A per-locale row from the `category_translations` collection. Holds only the
/// visitor-facing strings; the base `categories` record keeps everything
/// locale-invariant (code, slug, position, parent, flags). Blank overrides are
/// normalized to `null` so the mapper falls back to the base value.
class CategoryTranslation {
  final String categoryId;
  final String locale;
  final String name;
  final String? description;

  const CategoryTranslation({
    required this.categoryId,
    required this.locale,
    required this.name,
    this.description,
  });

  factory CategoryTranslation.fromJson(Map<String, dynamic> json) {
    return CategoryTranslation(
      categoryId: json['category'] as String? ?? '',
      locale: json['locale'] as String? ?? '',
      name: (json['name'] as String?) ?? '',
      description: _nullIfBlank(json['description'] as String?),
    );
  }
}

String? _nullIfBlank(String? value) {
  if (value == null) return null;
  return value.trim().isEmpty ? null : value;
}
