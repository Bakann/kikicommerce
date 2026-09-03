/// A per-locale row from the `product_translations` collection. Holds only the
/// visitor-facing strings; everything locale-invariant stays on the base
/// `products` record. Empty strings are normalized to `null` so the mapper's
/// `translation?.field ?? base.field` fallback treats a blank override as
/// "not translated" and uses the base (default-locale) value.
class ProductTranslation {
  final String productId;
  final String locale;
  final String name;
  final String? summary;
  final String? description;

  const ProductTranslation({
    required this.productId,
    required this.locale,
    required this.name,
    this.summary,
    this.description,
  });

  factory ProductTranslation.fromJson(Map<String, dynamic> json) {
    return ProductTranslation(
      productId: json['product'] as String? ?? '',
      locale: json['locale'] as String? ?? '',
      name: (json['name'] as String?) ?? '',
      summary: _nullIfBlank(json['summary'] as String?),
      description: _nullIfBlank(json['description'] as String?),
    );
  }
}

String? _nullIfBlank(String? value) {
  if (value == null) return null;
  return value.trim().isEmpty ? null : value;
}
