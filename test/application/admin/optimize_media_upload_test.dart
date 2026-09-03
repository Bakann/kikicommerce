import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/optimize_media_upload.dart';
import 'package:kiki_commerce/core/utils/media_upload_guidance.dart';
import 'package:image/image.dart' as img;

void main() {
  group('OptimizeMediaUpload', () {
    const optimizer = OptimizeMediaUpload();

    test('keeps a small jpeg unchanged', () {
      final source = img.Image(width: 800, height: 600);
      final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 82));

      final result = optimizer(fileBytes: bytes, filename: 'product.jpg');

      expect(result.wasOptimized, isFalse);
      expect(result.fileBytes, bytes);
      expect(result.filename, 'product.jpg');
      expect(result.mimeType, 'image/jpeg');
    });

    test('resizes a large jpeg down to the recommended long edge', () {
      final source = img.Image(width: 2400, height: 1800);
      final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 90));

      final result = optimizer(fileBytes: bytes, filename: 'hero.jpeg');
      final decoded = img.decodeImage(result.fileBytes);

      expect(result.wasOptimized, isTrue);
      expect(result.filename, 'hero.jpg');
      expect(result.mimeType, 'image/jpeg');
      expect(decoded, isNotNull);
      expect(
        math.max(decoded!.width, decoded.height),
        mediaUploadRecommendedLongEdge,
      );
    });

    test('keeps png output when the image has transparency', () {
      final source = img.Image(width: 2200, height: 1200, numChannels: 4);
      final bytes = Uint8List.fromList(img.encodePng(source, level: 6));

      final result = optimizer(fileBytes: bytes, filename: 'alpha.png');

      expect(result.wasOptimized, isTrue);
      expect(result.filename, 'alpha.png');
      expect(result.mimeType, 'image/png');
    });

    test('forceOpaque drops alpha and emits JPEG even for RGBA input', () {
      final source = img.Image(width: 2200, height: 1200, numChannels: 4);
      final bytes = Uint8List.fromList(img.encodePng(source, level: 6));

      final result = optimizer(
        fileBytes: bytes,
        filename: 'hero.png',
        forceOpaque: true,
      );

      expect(result.wasOptimized, isTrue);
      expect(result.mimeType, 'image/jpeg');
      expect(result.filename, 'hero.jpg');
    });

    test(
      'forceOpaque resizes large RGBA source down to recommended long edge',
      () {
        final source = img.Image(width: 4000, height: 3000, numChannels: 4);
        final bytes = Uint8List.fromList(img.encodePng(source, level: 6));

        final result = optimizer(
          fileBytes: bytes,
          filename: 'huge.png',
          forceOpaque: true,
        );
        final decoded = img.decodeImage(result.fileBytes);

        expect(result.mimeType, 'image/jpeg');
        expect(decoded, isNotNull);
        expect(
          math.max(decoded!.width, decoded.height),
          lessThanOrEqualTo(mediaUploadRecommendedLongEdge),
        );
      },
    );

    test('keeps mp4 uploads as video payloads', () {
      final bytes = Uint8List.fromList([0, 0, 0, 24, 102, 116, 121, 112]);

      final result = optimizer(fileBytes: bytes, filename: 'landing.mp4');

      expect(result.wasOptimized, isFalse);
      expect(result.fileBytes, bytes);
      expect(result.filename, 'landing.mp4');
      expect(result.mimeType, 'video/mp4');
    });
  });
}
