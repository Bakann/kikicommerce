import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'commercetools_catalog_product.dart';

/// Adapts the experimental [CommercetoolsCatalogProduct] into the app's catalog
/// UI models so commercetools products can be rendered by the existing Luxe
/// `ProductCard` / PLP widgets.
///
/// This is display-only glue for the lab page. Listing/media/price ids are
/// synthetic and prefixed `ct-`; `product.id` keeps the commercetools id for
/// routing/debug only and must NOT be treated as a PocketBase id. These items
/// must NOT be wired to the PocketBase PDP / cart / checkout.
class CommercetoolsCatalogAdapter {
  const CommercetoolsCatalogAdapter._();

  /// Sentinel category id for lab listing items (no real PocketBase category).
  static const String labCategoryId = 'commercetools-lab';

  static CatalogListingItem toListingItem(CommercetoolsCatalogProduct source) {
    final product = toCatalogProduct(source);
    return CatalogListingItem(
      id: 'ct-${source.id}',
      categoryId: labCategoryId,
      productId: product.id,
      productRouteSlug: source.slug ?? source.key,
      product: product,
      prices: toCatalogPrices(source),
    );
  }

  static CatalogProduct toCatalogProduct(CommercetoolsCatalogProduct source) {
    final name =
        _firstNonEmpty([source.name, source.key, source.slug]) ?? source.id;
    final media = _toMedia(source);
    return CatalogProduct(
      id: source.id,
      code: source.key ?? source.id,
      name: name,
      slug: source.slug ?? source.key,
      description: source.description,
      picture: media,
    );
  }

  static List<CatalogPrice> toCatalogPrices(
    CommercetoolsCatalogProduct source,
  ) {
    final price = source.price;
    if (price == null) return const [];
    return [
      CatalogPrice(
        id: 'ct-${source.id}-price',
        productId: source.id,
        price: price.centAmount / 100.0,
        currencyCode: price.currencyCode,
        currencySymbol: _currencySymbol(price.currencyCode),
        isDefault: true,
        isActive: true,
      ),
    ];
  }

  static CatalogMedia? _toMedia(CommercetoolsCatalogProduct source) {
    final url = source.imageUrl?.trim();
    if (url == null || url.isEmpty) return null;
    return CatalogMedia(
      id: 'ct-${source.id}-img',
      url: url,
      previewUrl: url,
      altText: source.name,
    );
  }

  static String _currencySymbol(String code) => switch (code) {
    'EUR' => '€',
    'USD' => r'$',
    'GBP' => '£',
    _ => code,
  };

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
