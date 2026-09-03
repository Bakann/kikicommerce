import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/admin_media_repository.dart';
import 'package:kiki_commerce/application/admin/media_crop_data.dart';
import 'package:kiki_commerce/application/admin/optimize_media_upload.dart';
import 'package:kiki_commerce/application/admin/replace_media_asset.dart';

void main() {
  group('ReplaceMediaAsset', () {
    test(
      'uploadOnly delegates the optimized payload to the repository',
      () async {
        final repository = _FakeAdminMediaRepository();
        final useCase = ReplaceMediaAsset(repository);
        final optimized = OptimizedMediaUpload(
          fileBytes: Uint8List.fromList([1, 2, 3]),
          filename: 'cropped.jpg',
          mimeType: 'image/jpeg',
          originalBytes: 12,
          wasOptimized: true,
        );
        const cropData = MediaCropData(
          presetKey: 'pdp',
          x: 0.1,
          y: 0.2,
          width: 0.3,
          height: 0.4,
        );

        await useCase.uploadOnly(
          authToken: 'token',
          mediaId: 'media-1',
          optimized: optimized,
          originalFileBytes: Uint8List.fromList([9, 9]),
          originalFilename: 'original.png',
          cropData: cropData,
        );

        expect(repository.callCount, 1);
        expect(repository.lastAuthToken, 'token');
        expect(repository.lastMediaId, 'media-1');
        expect(repository.lastFilename, 'cropped.jpg');
        expect(repository.lastMimeType, 'image/jpeg');
        expect(repository.lastFileBytes, optimized.fileBytes);
        expect(repository.lastOriginalFilename, 'original.png');
        expect(repository.lastCropData, cropData);
      },
    );
  });
}

class _FakeAdminMediaRepository implements AdminMediaRepository {
  int callCount = 0;
  String? lastAuthToken;
  String? lastMediaId;
  Uint8List? lastFileBytes;
  String? lastFilename;
  String? lastMimeType;
  Uint8List? lastOriginalFileBytes;
  String? lastOriginalFilename;
  MediaCropData? lastCropData;

  @override
  Future<void> replaceMedia({
    required String authToken,
    required String mediaId,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
    Uint8List? originalFileBytes,
    String? originalFilename,
    MediaCropData? cropData,
  }) async {
    callCount += 1;
    lastAuthToken = authToken;
    lastMediaId = mediaId;
    lastFileBytes = fileBytes;
    lastFilename = filename;
    lastMimeType = mimeType;
    lastOriginalFileBytes = originalFileBytes;
    lastOriginalFilename = originalFilename;
    lastCropData = cropData;
  }

  @override
  Future<Uint8List> fetchBytes(String url) async => throw UnimplementedError();
}
