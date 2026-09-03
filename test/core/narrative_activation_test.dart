import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_narrative_logic.dart';

void main() {
  CatalogMedia media(String id) => CatalogMedia(
    id: id,
    url: 'https://example.com/$id.jpg',
    previewUrl: 'https://example.com/$id-preview.jpg',
  );

  NarrativeChapter chapter(String id, String mediaId) => NarrativeChapter(
    id: id,
    mediaId: mediaId,
    position: 1,
    headline: 'Headline $id',
  );

  group('dedupeCatalogMediaById', () {
    test('keeps first occurrence order', () {
      final deduped = dedupeCatalogMediaById([
        media('m-1'),
        media('m-2'),
        media('m-1'),
        media('m-3'),
      ]);

      expect(deduped.map((item) => item.id), ['m-1', 'm-2', 'm-3']);
    });
  });

  group('shouldEnableNarrative', () {
    test('returns true for full coverage across all unique media', () {
      final uniqueMedia = [media('m-1'), media('m-2')];
      final chapters = [
        chapter('chapter-1', 'm-1'),
        chapter('chapter-2', 'm-2'),
      ];

      expect(
        shouldEnableNarrative(uniqueMedia: uniqueMedia, chapters: chapters),
        isTrue,
      );
    });

    test('returns false when a visible image has no chapter', () {
      final uniqueMedia = [media('m-1'), media('m-2'), media('m-3')];
      final chapters = [
        chapter('chapter-1', 'm-1'),
        chapter('chapter-2', 'm-2'),
      ];

      expect(
        shouldEnableNarrative(uniqueMedia: uniqueMedia, chapters: chapters),
        isFalse,
      );
    });

    test('returns false when two chapters target the same media', () {
      final uniqueMedia = [media('m-1'), media('m-2')];
      final chapters = [
        chapter('chapter-1', 'm-1'),
        chapter('chapter-2', 'm-1'),
        chapter('chapter-3', 'm-2'),
      ];

      expect(
        shouldEnableNarrative(uniqueMedia: uniqueMedia, chapters: chapters),
        isFalse,
      );
    });

    test('returns false when fewer than two unique media remain', () {
      final uniqueMedia = dedupeCatalogMediaById([media('m-1'), media('m-1')]);
      final chapters = [chapter('chapter-1', 'm-1')];

      expect(
        shouldEnableNarrative(uniqueMedia: uniqueMedia, chapters: chapters),
        isFalse,
      );
    });
  });

  group('resolveNarrativeActiveIndex', () {
    test('prefers the image containing the viewport anchor', () {
      final index = resolveNarrativeActiveIndex(
        samples: const [
          NarrativeViewportSample(index: 0, top: 40, bottom: 360),
          NarrativeViewportSample(index: 1, top: 380, bottom: 700),
        ],
        anchorY: 420,
      );

      expect(index, 1);
    });

    test('falls back to the image whose center is closest to the anchor', () {
      final index = resolveNarrativeActiveIndex(
        samples: const [
          NarrativeViewportSample(index: 0, top: -420, bottom: -40),
          NarrativeViewportSample(index: 1, top: 480, bottom: 860),
        ],
        anchorY: 220,
      );

      expect(index, 1);
    });

    test('converges on the anchored image after a rapid forward jump', () {
      // After a large scroll jump (e.g., progress-bar tap), the previously
      // active image (index 0) is far above the anchor. The iterative
      // forward sweep in _syncCurrentIndexToVisibleImage hands the resolver
      // a samples list ending on the first image whose bottom crosses the
      // anchor. The resolver must pick that image, not the stale current.
      final index = resolveNarrativeActiveIndex(
        samples: const [
          NarrativeViewportSample(index: 0, top: -1800, bottom: -1400),
          NarrativeViewportSample(index: 1, top: -1400, bottom: -1000),
          NarrativeViewportSample(index: 5, top: 120, bottom: 520),
        ],
        anchorY: 300,
      );

      expect(index, 5);
    });

    test('converges on the anchored image after a rapid backward jump', () {
      final index = resolveNarrativeActiveIndex(
        samples: const [
          NarrativeViewportSample(index: 7, top: 1600, bottom: 2000),
          NarrativeViewportSample(index: 6, top: 1200, bottom: 1600),
          NarrativeViewportSample(index: 2, top: 80, bottom: 480),
        ],
        anchorY: 300,
      );

      expect(index, 2);
    });
  });
}
