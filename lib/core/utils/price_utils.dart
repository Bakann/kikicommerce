import '../../domain/catalog/catalog_entities.dart';

CatalogPrice? getDefaultPrice(List<CatalogPrice> prices) {
  if (prices.isEmpty) return null;
  final defaults = prices.where((p) => p.isDefault);
  if (defaults.isNotEmpty) return defaults.first;
  return prices.reduce((a, b) => a.price < b.price ? a : b);
}

double? getOriginalPrice(List<CatalogPrice> prices) {
  if (prices.length <= 1) return null;
  final sorted = [...prices]..sort((a, b) => b.price.compareTo(a.price));
  final def = getDefaultPrice(prices);
  if (def != null && sorted.first.price > def.price) {
    return sorted.first.price;
  }
  return null;
}

int? computeDiscount(CatalogPrice? defaultPrice, double? originalPrice) {
  if (defaultPrice != null &&
      originalPrice != null &&
      originalPrice > defaultPrice.price) {
    return (((originalPrice - defaultPrice.price) / originalPrice) * 100)
        .round();
  }
  return null;
}

String formatPrice(double price, String symbol) =>
    '${price.toStringAsFixed(2).replaceAll('.', ',')}$symbol';

bool isNewProduct(DateTime? onlineDate) {
  if (onlineDate == null) return false;
  return DateTime.now().difference(onlineDate).inDays < 30;
}
