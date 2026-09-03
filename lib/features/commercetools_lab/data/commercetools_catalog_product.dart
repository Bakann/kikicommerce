/// Minimal Dart models for the experimental commercetools catalog lab page.
///
/// These mirror the JSON contract returned by the public Cloudflare Worker
/// (`kiki-ct-catalog-proxy`) and are intentionally decoupled from the
/// PocketBase catalog models — the lab page is isolated and reversible.
///
/// Worker item shape:
/// ```json
/// {
///   "id": "d2748de5-...",
///   "key": "bruno-chair",
///   "slug": "bruno-chair",
///   "name": "Bruno Chair",
///   "description": "...",
///   "imageUrl": "https://.../Bruno_Chair-1.1.jpeg",
///   "price": { "centAmount": 1299, "currencyCode": "EUR" }
/// }
/// ```
/// `price` may be `null` (no projected price), and every field except `id`
/// is nullable.
library;

class CommercetoolsCatalogPrice {
  final int centAmount;
  final String currencyCode;

  const CommercetoolsCatalogPrice({
    required this.centAmount,
    required this.currencyCode,
  });

  factory CommercetoolsCatalogPrice.fromJson(Map<String, dynamic> json) {
    return CommercetoolsCatalogPrice(
      centAmount: (json['centAmount'] as num).toInt(),
      currencyCode: json['currencyCode'] as String,
    );
  }
}

class CommercetoolsCatalogProduct {
  final String id;
  final String? key;
  final String? slug;
  final String? name;
  final String? description;
  final String? imageUrl;
  final CommercetoolsCatalogPrice? price;

  const CommercetoolsCatalogProduct({
    required this.id,
    this.key,
    this.slug,
    this.name,
    this.description,
    this.imageUrl,
    this.price,
  });

  factory CommercetoolsCatalogProduct.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    return CommercetoolsCatalogProduct(
      id: json['id'] as String,
      key: json['key'] as String?,
      slug: json['slug'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      price: rawPrice is Map<String, dynamic>
          ? CommercetoolsCatalogPrice.fromJson(rawPrice)
          : null,
    );
  }
}
