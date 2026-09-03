import '../../core/utils/pocketbase_filter_utils.dart';
import '../api/pocketbase_client.dart';
import '../models/media_container.dart';
import '../models/product.dart';

Future<Map<String, List<MediaContainer>>> fetchListingGalleryFallbacks(
  PocketBaseClient client,
  Iterable<Product> products,
) async {
  final productsNeedingFallback = products
      .where(_needsListingGalleryFallback)
      .toList(growable: false);
  if (productsNeedingFallback.isEmpty) {
    return const {};
  }

  final containerIds = productsNeedingFallback
      .expand((product) => product.galleryImageIds)
      .toSet();
  if (containerIds.isEmpty) {
    return const {};
  }

  final filter = containerIds
      .map((id) => 'id="${escapeFilterValue(id)}"')
      .join(' || ');
  final response = await client.listRecords<MediaContainer>(
    'mediaContainers',
    filter: '($filter) && isActive=true',
    expand: 'medias',
    perPage: containerIds.length,
    fromJson: MediaContainer.fromJson,
  );

  final containersById = {
    for (final container in response.items) container.id: container,
  };

  return {
    for (final product in productsNeedingFallback)
      product.id: [
        for (final containerId in product.galleryImageIds)
          if (containersById[containerId] != null) containersById[containerId]!,
      ],
  };
}

bool _needsListingGalleryFallback(Product product) {
  return product.picture == null &&
      product.thumbnail == null &&
      product.galleryImages.isEmpty &&
      product.galleryImageIds.isNotEmpty;
}
