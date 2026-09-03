import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/utils/media_image_support.dart';

void main() {
  group('isKnownUnsupportedImageFormat', () {
    test('rejects Android-hostile image extensions before decoding', () {
      expect(
        isKnownUnsupportedImageFormat(
          url: 'https://example.com/file.tiff?thumb=600x600',
        ),
        isTrue,
      );
      expect(isKnownUnsupportedImageFormat(url: '/media/photo.heic'), isTrue);
      expect(isKnownUnsupportedImageFormat(url: '/media/art.avif'), isTrue);
    });

    test('rejects video URLs before they reach image widgets', () {
      expect(
        isKnownUnsupportedImageFormat(
          url: 'https://example.com/hero.mp4?thumb=1800x1200f',
        ),
        isTrue,
      );
      expect(isKnownUnsupportedImageFormat(url: '/media/clip.webm'), isTrue);
    });

    test('rejects unsupported mime types with parameters', () {
      expect(
        isKnownUnsupportedImageFormat(mimeType: 'image/tiff; charset=binary'),
        isTrue,
      );
      expect(isKnownUnsupportedImageFormat(mimeType: 'video/mp4'), isTrue);
    });

    test('allows common raster image URLs', () {
      expect(isKnownUnsupportedImageFormat(url: '/media/photo.jpg'), isFalse);
      expect(isKnownUnsupportedImageFormat(url: '/media/photo.png'), isFalse);
      expect(isKnownUnsupportedImageFormat(url: '/media/photo.webp'), isFalse);
    });
  });
}
