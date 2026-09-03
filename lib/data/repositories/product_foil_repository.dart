import '../api/pocketbase_client.dart';
import '../models/product_foil.dart';

/// Read side of the `product_foils` collection (public read; records are
/// written from the Foil studio, see the pokemon_cards_flutter repo).
class ProductFoilRepository {
  final PocketBaseClient client;

  const ProductFoilRepository({required this.client});

  static String _escapeFilterValue(String value) =>
      value.replaceAll("'", r"\'");

  /// Returns the foil saved for [productId], or null when the product has
  /// none. Errors (missing collection, transient network) also resolve to
  /// null: the overlay is decorative and the PDP must render unchanged.
  Future<ProductFoil?> fetchForProduct(String productId) async {
    try {
      final page = await client.listRecords<ProductFoil>(
        'product_foils',
        filter: "product_id='${_escapeFilterValue(productId)}'",
        perPage: 1,
        fromJson: ProductFoil.fromJson,
      );
      return page.items.isEmpty ? null : page.items.first;
    } catch (_) {
      return null;
    }
  }
}
