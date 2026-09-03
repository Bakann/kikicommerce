import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/kiki_image.dart';

void main() {
  group('KikiImage.cachedProviderFor', () {
    test('is stable for identical inputs (same ImageCache key)', () {
      final a = KikiImage.cachedProviderFor(
        imageUrl: 'https://example.com/a.jpg',
        renderSize: const Size(120, 120),
        devicePixelRatio: 2,
      );
      final b = KikiImage.cachedProviderFor(
        imageUrl: 'https://example.com/a.jpg',
        renderSize: const Size(120, 120),
        devicePixelRatio: 2,
      );
      expect(a, b);
    });

    test('disk bounds are part of the key (regression: dropped maxWidth)', () {
      // A provider built without the KikiImage disk bounds keys differently
      // and would miss the card's warm decode — the bug this guards against.
      final aligned = KikiImage.cachedProviderFor(
        imageUrl: 'https://example.com/a.jpg',
        renderSize: const Size(120, 120),
        devicePixelRatio: 2,
      );
      final smallerBounds = KikiImage.cachedProviderFor(
        imageUrl: 'https://example.com/a.jpg',
        renderSize: const Size(120, 120),
        devicePixelRatio: 2,
        maxWidthDiskCache: 512,
        maxHeightDiskCache: 512,
      );
      expect(aligned, isNot(smallerBounds));
    });

    test('different render sizes decode to different entries', () {
      final small = KikiImage.cachedProviderFor(
        imageUrl: 'https://example.com/a.jpg',
        renderSize: const Size(60, 60),
        devicePixelRatio: 2,
      );
      final large = KikiImage.cachedProviderFor(
        imageUrl: 'https://example.com/a.jpg',
        renderSize: const Size(240, 240),
        devicePixelRatio: 2,
      );
      expect(small, isNot(large));
    });
  });
}
