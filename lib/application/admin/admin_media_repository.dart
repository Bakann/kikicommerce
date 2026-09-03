import 'dart:typed_data';

import 'media_crop_data.dart';

abstract interface class AdminMediaRepository {
  Future<void> replaceMedia({
    required String authToken,
    required String mediaId,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
    Uint8List? originalFileBytes,
    String? originalFilename,
    MediaCropData? cropData,
  });

  Future<Uint8List> fetchBytes(String url);
}
