String? validateNarrativeChapterDraft({
  required Map<String, dynamic> data,
  required Map<String, List<Map<String, dynamic>>> relationData,
}) {
  final productId = data['product'] as String?;
  final mediaId = data['media'] as String?;
  if (productId == null ||
      productId.isEmpty ||
      mediaId == null ||
      mediaId.isEmpty) {
    return null;
  }

  final products = relationData['products'] ?? const [];
  final mediaContainers = relationData['mediaContainers'] ?? const [];
  final product = products.cast<Map<String, dynamic>>().firstWhere(
    (record) => record['id'] == productId,
    orElse: () => const <String, dynamic>{},
  );
  if (product.isEmpty) {
    return null;
  }

  final allowedMediaIds = <String>{};
  final pictureId = product['picture'] as String?;
  if (pictureId != null && pictureId.isNotEmpty) {
    allowedMediaIds.add(pictureId);
  }

  final galleryContainerIds =
      (product['galleryImages'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty);
  for (final containerId in galleryContainerIds) {
    final container = mediaContainers.cast<Map<String, dynamic>>().firstWhere(
      (record) => record['id'] == containerId,
      orElse: () => const <String, dynamic>{},
    );
    for (final relatedMediaId
        in (container['medias'] as List<dynamic>? ?? const [])) {
      final resolvedId = relatedMediaId.toString();
      if (resolvedId.isNotEmpty) {
        allowedMediaIds.add(resolvedId);
      }
    }
  }

  if (allowedMediaIds.isEmpty) {
    final thumbnailId = product['thumbnail'] as String?;
    if (thumbnailId != null && thumbnailId.isNotEmpty) {
      allowedMediaIds.add(thumbnailId);
    }
  }

  if (!allowedMediaIds.contains(mediaId)) {
    return 'Le média sélectionné n’appartient pas à la galerie visible de ce produit.';
  }

  return null;
}
