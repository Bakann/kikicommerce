import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/data/mappers/catalog_mappers.dart';
import 'package:kiki_commerce/data/models/narrative_chapter.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

void main() {
  group('toNarrativeChapter', () {
    test('maps known CTA actions to domain enums', () {
      const record = NarrativeChapterRecord(
        id: 'chapter-1',
        productId: 'product-1',
        mediaId: 'media-1',
        position: 1,
        headline: 'Kiki prend son elan',
        story: 'Une silhouette qui s anime avec le vent.',
        ctaLabel: 'Zoomer',
        ctaAction: 'zoom',
      );

      final chapter = toNarrativeChapter(record);

      expect(chapter.id, 'chapter-1');
      expect(chapter.mediaId, 'media-1');
      expect(chapter.position, 1);
      expect(chapter.headline, 'Kiki prend son elan');
      expect(chapter.story, 'Une silhouette qui s anime avec le vent.');
      expect(chapter.ctaLabel, 'Zoomer');
      expect(chapter.ctaAction, NarrativeCtaAction.zoom);
    });

    test('falls back to none for unknown or missing CTA action values', () {
      const record = NarrativeChapterRecord(
        id: 'chapter-2',
        productId: 'product-1',
        mediaId: 'media-2',
        position: 2,
        headline: 'Plan detail',
        ctaAction: 'surprise',
      );

      final chapter = toNarrativeChapter(record);

      expect(chapter.story, isNull);
      expect(chapter.ctaLabel, isNull);
      expect(chapter.ctaAction, NarrativeCtaAction.none);
    });
  });
}
