import 'dart:typed_data';

import 'admin_media_repository.dart';
import 'media_crop_data.dart';
import 'optimize_media_upload.dart';
import '../../core/utils/media_upload_guidance.dart';

class ReplaceMediaAsset {
  final AdminMediaRepository repository;
  final OptimizeMediaUpload optimizer;

  const ReplaceMediaAsset(
    this.repository, {
    this.optimizer = const OptimizeMediaUpload(),
  });

  OptimizedMediaUpload optimize({
    required Uint8List fileBytes,
    required String filename,
    bool forceOpaque = false,
  }) {
    final optimized = optimizer(
      fileBytes: fileBytes,
      filename: filename,
      forceOpaque: forceOpaque,
    );

    if (optimized.fileBytes.lengthInBytes > mediaUploadPocketBaseMaxBytes) {
      throw Exception(
        'Le fichier reste au-dessus de 8 Mo après optimisation. Réduisez-le avant l’upload: image WebP/JPEG autour de 1600 px de côté long, ou vidéo MP4 H.264/AAC plus courte et plus compressée.',
      );
    }

    return optimized;
  }

  Future<OptimizedMediaUpload> cropAndOptimize({
    required Uint8List sourceBytes,
    required String filename,
    required MediaCropData cropData,
    bool forceOpaque = false,
  }) async {
    final optimized = await optimizer.cropAndOptimize(
      sourceBytes: sourceBytes,
      filename: filename,
      cropData: cropData,
      forceOpaque: forceOpaque,
    );

    if (optimized.fileBytes.lengthInBytes > mediaUploadPocketBaseMaxBytes) {
      throw Exception(
        'Le fichier reste au-dessus de 8 Mo après optimisation. Réduisez-le avant l’upload: image WebP/JPEG autour de 1600 px de côté long, ou vidéo MP4 H.264/AAC plus courte et plus compressée.',
      );
    }

    return optimized;
  }

  Future<void> uploadOnly({
    required String authToken,
    required String mediaId,
    required OptimizedMediaUpload optimized,
    Uint8List? originalFileBytes,
    String? originalFilename,
    MediaCropData? cropData,
  }) async {
    await repository.replaceMedia(
      authToken: authToken,
      mediaId: mediaId,
      fileBytes: optimized.fileBytes,
      filename: optimized.filename,
      mimeType: optimized.mimeType,
      originalFileBytes: originalFileBytes,
      originalFilename: originalFilename,
      cropData: cropData,
    );
  }

  Future<OptimizedMediaUpload> call({
    required String authToken,
    required String mediaId,
    required Uint8List fileBytes,
    required String filename,
    Uint8List? originalFileBytes,
    String? originalFilename,
    MediaCropData? cropData,
  }) async {
    final optimized = optimize(fileBytes: fileBytes, filename: filename);

    await uploadOnly(
      authToken: authToken,
      mediaId: mediaId,
      optimized: optimized,
      originalFileBytes: originalFileBytes,
      originalFilename: originalFilename,
      cropData: cropData,
    );

    return optimized;
  }
}
