import '../../core/utils/pocketbase_filter_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../api/pocketbase_client.dart';
import '../mappers/catalog_mappers.dart';
import '../models/price_row.dart';

Future<Map<String, List<CatalogPrice>>> fetchPricesByProductIds(
  PocketBaseClient client,
  Iterable<String> productIds,
) async {
  final pricesByProduct = <String, List<CatalogPrice>>{};
  if (productIds.isEmpty) return pricesByProduct;

  final priceFilter = productIds
      .map((id) => 'product="${escapeFilterValue(id)}"')
      .join(' || ');

  final priceData = await client.listRecords<PriceRow>(
    'priceRows',
    filter: '($priceFilter) && isActive=true',
    expand: 'currency',
    perPage: 200,
    fromJson: PriceRow.fromJson,
  );

  for (final pr in priceData.items) {
    pricesByProduct.putIfAbsent(pr.productId, () => []).add(toCatalogPrice(pr));
  }
  return pricesByProduct;
}
