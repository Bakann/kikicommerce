import '../../config/api_config.dart';
import '../../core/utils/pocketbase_filter_utils.dart';
import '../../core/utils/slug_utils.dart';
import 'admin_backoffice_repository.dart';

class AddProductGalleryMedia {
  final AdminBackofficeRepository repository;

  const AddProductGalleryMedia(this.repository);

  Future<void> call({
    required String authToken,
    required String productId,
    required String mediaId,
  }) async {
    final product = await _loadProduct(
      repository: repository,
      authToken: authToken,
      productId: productId,
    );
    final galleryContainerIds = _stringList(product['galleryImages']);

    if (galleryContainerIds.isEmpty) {
      final container = await _createGalleryContainer(
        authToken: authToken,
        product: product,
        mediaId: mediaId,
      );
      final containerId = container['id'] as String?;
      if (containerId == null || containerId.isEmpty) {
        throw StateError('PocketBase did not return a gallery container id.');
      }
      await repository.updateRecord(
        baseUrl: ApiConfig.apiBaseUrl,
        authToken: authToken,
        collection: 'products',
        recordId: productId,
        data: {
          'galleryImages': [containerId],
        },
      );
      return;
    }

    final containerId = galleryContainerIds.first;
    final container = await _loadMediaContainer(
      repository: repository,
      authToken: authToken,
      containerId: containerId,
    );
    final mediaIds = _stringList(container['medias']);
    if (mediaIds.contains(mediaId)) {
      return;
    }

    await repository.updateRecord(
      baseUrl: ApiConfig.apiBaseUrl,
      authToken: authToken,
      collection: 'mediaContainers',
      recordId: containerId,
      data: {
        'medias': [...mediaIds, mediaId],
      },
    );
  }

  Future<Map<String, dynamic>> _createGalleryContainer({
    required String authToken,
    required Map<String, dynamic> product,
    required String mediaId,
  }) {
    final productCode = (product['code'] as String?)?.trim();
    final productName = (product['name'] as String?)?.trim();
    final codeSource = productCode?.isNotEmpty == true
        ? productCode!
        : product['id'] as String? ?? 'product';
    final nameSource = productName?.isNotEmpty == true
        ? productName!
        : productCode ?? codeSource;

    return repository.createRecord(
      baseUrl: ApiConfig.apiBaseUrl,
      authToken: authToken,
      collection: 'mediaContainers',
      data: {
        'code': '${slugify(codeSource, fallback: 'product')}-gallery',
        'name': 'Galerie $nameSource',
        'medias': [mediaId],
        'isActive': true,
      },
    );
  }
}

class ReplaceProductGalleryMedia {
  final AdminBackofficeRepository repository;

  const ReplaceProductGalleryMedia(this.repository);

  Future<void> call({
    required String authToken,
    required String productId,
    required String currentMediaId,
    required String replacementMediaId,
  }) async {
    if (currentMediaId == replacementMediaId) {
      return;
    }

    final product = await _loadProduct(
      repository: repository,
      authToken: authToken,
      productId: productId,
    );
    final galleryContainerIds = _stringList(product['galleryImages']);

    for (final containerId in galleryContainerIds) {
      final container = await _loadMediaContainer(
        repository: repository,
        authToken: authToken,
        containerId: containerId,
      );
      final mediaIds = _stringList(container['medias']);
      final currentIndex = mediaIds.indexOf(currentMediaId);
      if (currentIndex < 0) {
        continue;
      }

      final nextMediaIds = <String>[];
      for (final mediaId in mediaIds) {
        final nextMediaId = mediaId == currentMediaId
            ? replacementMediaId
            : mediaId;
        if (!nextMediaIds.contains(nextMediaId)) {
          nextMediaIds.add(nextMediaId);
        }
      }

      await repository.updateRecord(
        baseUrl: ApiConfig.apiBaseUrl,
        authToken: authToken,
        collection: 'mediaContainers',
        recordId: containerId,
        data: {'medias': nextMediaIds},
      );
      return;
    }

    throw StateError('Media $currentMediaId not found in product gallery.');
  }
}

class RemoveProductGalleryMedia {
  final AdminBackofficeRepository repository;

  const RemoveProductGalleryMedia(this.repository);

  Future<void> call({
    required String authToken,
    required String productId,
    required String mediaId,
  }) async {
    final product = await _loadProduct(
      repository: repository,
      authToken: authToken,
      productId: productId,
    );
    final galleryContainerIds = _stringList(product['galleryImages']);

    for (final containerId in galleryContainerIds) {
      final container = await _loadMediaContainer(
        repository: repository,
        authToken: authToken,
        containerId: containerId,
      );
      final mediaIds = _stringList(container['medias']);
      if (!mediaIds.contains(mediaId)) {
        continue;
      }

      await repository.updateRecord(
        baseUrl: ApiConfig.apiBaseUrl,
        authToken: authToken,
        collection: 'mediaContainers',
        recordId: containerId,
        data: {'medias': mediaIds.where((id) => id != mediaId).toList()},
      );
      return;
    }

    throw StateError('Media $mediaId not found in product gallery.');
  }
}

enum ProductGalleryMoveDirection { previous, next }

class MoveProductGalleryMedia {
  final AdminBackofficeRepository repository;

  const MoveProductGalleryMedia(this.repository);

  Future<void> call({
    required String authToken,
    required String productId,
    required String mediaId,
    required ProductGalleryMoveDirection direction,
  }) async {
    final product = await _loadProduct(
      repository: repository,
      authToken: authToken,
      productId: productId,
    );
    final galleryContainerIds = _stringList(product['galleryImages']);

    for (final containerId in galleryContainerIds) {
      final container = await _loadMediaContainer(
        repository: repository,
        authToken: authToken,
        containerId: containerId,
      );
      final mediaIds = _stringList(container['medias']);
      final currentIndex = mediaIds.indexOf(mediaId);
      if (currentIndex < 0) {
        continue;
      }

      final targetIndex = switch (direction) {
        ProductGalleryMoveDirection.previous => currentIndex - 1,
        ProductGalleryMoveDirection.next => currentIndex + 1,
      };
      if (targetIndex < 0 || targetIndex >= mediaIds.length) {
        return;
      }

      final nextMediaIds = [...mediaIds];
      final moved = nextMediaIds.removeAt(currentIndex);
      nextMediaIds.insert(targetIndex, moved);

      await repository.updateRecord(
        baseUrl: ApiConfig.apiBaseUrl,
        authToken: authToken,
        collection: 'mediaContainers',
        recordId: containerId,
        data: {'medias': nextMediaIds},
      );
      return;
    }

    throw StateError('Media $mediaId not found in product gallery.');
  }
}

class SetProductPrimaryMedia {
  final AdminBackofficeRepository repository;

  const SetProductPrimaryMedia(this.repository);

  Future<void> call({
    required String authToken,
    required String productId,
    required String mediaId,
  }) async {
    final product = await _loadProduct(
      repository: repository,
      authToken: authToken,
      productId: productId,
    );
    final currentPictureId = _stringValue(product['picture']);
    if (currentPictureId == mediaId) {
      return;
    }

    final galleryContainerIds = _stringList(product['galleryImages']);
    MapEntry<String, List<String>>? firstGalleryContainer;
    MapEntry<String, List<String>>? selectedGalleryContainer;
    for (final containerId in galleryContainerIds) {
      final container = await _loadMediaContainer(
        repository: repository,
        authToken: authToken,
        containerId: containerId,
      );
      final mediaIds = _stringList(container['medias']);
      firstGalleryContainer ??= MapEntry(containerId, mediaIds);
      if (mediaIds.contains(mediaId)) {
        selectedGalleryContainer = MapEntry(containerId, mediaIds);
        break;
      }
    }

    final targetGalleryContainer =
        selectedGalleryContainer ?? firstGalleryContainer;
    if (targetGalleryContainer != null) {
      final containerId = targetGalleryContainer.key;
      final mediaIds = targetGalleryContainer.value;

      final nextMediaIds = <String>[
        if (currentPictureId != null && currentPictureId != mediaId)
          currentPictureId,
        for (final id in mediaIds)
          if (id != mediaId && id != currentPictureId) id,
      ];

      if (!_hasSameOrder(mediaIds, nextMediaIds)) {
        await repository.updateRecord(
          baseUrl: ApiConfig.apiBaseUrl,
          authToken: authToken,
          collection: 'mediaContainers',
          recordId: containerId,
          data: {'medias': nextMediaIds},
        );
      }
    }

    await repository.updateRecord(
      baseUrl: ApiConfig.apiBaseUrl,
      authToken: authToken,
      collection: 'products',
      recordId: productId,
      data: {'picture': mediaId},
    );
  }
}

Future<Map<String, dynamic>> _loadProduct({
  required AdminBackofficeRepository repository,
  required String authToken,
  required String productId,
}) async {
  final products = await repository.listRecords(
    baseUrl: ApiConfig.apiBaseUrl,
    authToken: authToken,
    collection: 'products',
    filter: 'id = "${escapeFilterValue(productId)}"',
    perPage: 1,
  );
  if (products.isEmpty) {
    throw StateError('Product $productId not found.');
  }
  return products.first;
}

Future<Map<String, dynamic>> _loadMediaContainer({
  required AdminBackofficeRepository repository,
  required String authToken,
  required String containerId,
}) async {
  final containers = await repository.listRecords(
    baseUrl: ApiConfig.apiBaseUrl,
    authToken: authToken,
    collection: 'mediaContainers',
    filter: 'id = "${escapeFilterValue(containerId)}"',
    perPage: 1,
  );
  if (containers.isEmpty) {
    throw StateError('Media container $containerId not found.');
  }
  return containers.first;
}

List<String> _stringList(Object? value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _stringValue(Object? value) {
  final string = value?.toString().trim();
  return string == null || string.isEmpty ? null : string;
}

bool _hasSameOrder(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
