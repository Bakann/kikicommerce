import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/data/mappers/catalog_mappers.dart';
import 'package:kiki_commerce/data/models/category.dart';
import 'package:kiki_commerce/data/models/category_translation.dart';
import 'package:kiki_commerce/data/models/narrative_chapter.dart';
import 'package:kiki_commerce/data/models/narrative_chapter_translation.dart';
import 'package:kiki_commerce/data/models/product.dart';
import 'package:kiki_commerce/data/models/product_translation.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

Product _baseProduct() => Product(
  id: 'p1',
  collectionId: 'c',
  collectionName: 'products',
  code: 'CODE-1',
  name: 'Robe rouge',
  slug: 'robe-rouge',
  summary: 'Résumé FR',
  description: 'Description FR',
);

Category _baseCategory() => Category(
  id: 'cat1',
  collectionId: 'c',
  code: 'CAT',
  name: 'Chaussures',
  description: 'Desc FR',
  slug: 'chaussures',
);

void main() {
  group('toCatalogProduct translation merge', () {
    test('uses the translation when present and keeps the base slug', () {
      final mapped = toCatalogProduct(
        _baseProduct(),
        translation: const ProductTranslation(
          productId: 'p1',
          locale: 'en',
          name: 'Red dress',
          summary: 'EN summary',
          description: 'EN description',
        ),
      );

      expect(mapped.name, 'Red dress');
      expect(mapped.summary, 'EN summary');
      expect(mapped.description, 'EN description');
      // Slug must stay locale-invariant for route stability.
      expect(mapped.slug, 'robe-rouge');
    });

    test('falls back to the base values when there is no translation', () {
      final mapped = toCatalogProduct(_baseProduct());

      expect(mapped.name, 'Robe rouge');
      expect(mapped.summary, 'Résumé FR');
      expect(mapped.description, 'Description FR');
    });

    test('falls back per field when a translated field is blank', () {
      final mapped = toCatalogProduct(
        _baseProduct(),
        translation: const ProductTranslation(
          productId: 'p1',
          locale: 'en',
          name: 'Red dress',
          // summary/description omitted -> null -> base value used.
        ),
      );

      expect(mapped.name, 'Red dress');
      expect(mapped.summary, 'Résumé FR');
      expect(mapped.description, 'Description FR');
    });
  });

  group('toCatalogCategory translation merge', () {
    test('uses the translation when present and keeps the base slug', () {
      final mapped = toCatalogCategory(
        _baseCategory(),
        translation: const CategoryTranslation(
          categoryId: 'cat1',
          locale: 'en',
          name: 'Shoes',
          description: 'EN desc',
        ),
      );

      expect(mapped.name, 'Shoes');
      expect(mapped.description, 'EN desc');
      expect(mapped.slug, 'chaussures');
    });

    test('falls back to the base values when there is no translation', () {
      final mapped = toCatalogCategory(_baseCategory());

      expect(mapped.name, 'Chaussures');
      expect(mapped.description, 'Desc FR');
    });
  });

  group('toNarrativeChapter translation merge', () {
    NarrativeChapterRecord base() => const NarrativeChapterRecord(
      id: 'ch1',
      productId: 'p1',
      mediaId: 'm1',
      position: 0,
      headline: 'Chapitre un',
      story: 'Histoire FR',
      ctaLabel: 'Voir',
      ctaAction: 'zoom',
    );

    test('uses the translation and keeps the base ctaAction', () {
      final mapped = toNarrativeChapter(
        base(),
        translation: const NarrativeChapterTranslation(
          chapterId: 'ch1',
          locale: 'en',
          headline: 'Chapter one',
          story: 'EN story',
          ctaLabel: 'View',
        ),
      );

      expect(mapped.headline, 'Chapter one');
      expect(mapped.story, 'EN story');
      expect(mapped.ctaLabel, 'View');
      expect(mapped.ctaAction, NarrativeCtaAction.zoom);
    });

    test('falls back to the base values when there is no translation', () {
      final mapped = toNarrativeChapter(base());

      expect(mapped.headline, 'Chapitre un');
      expect(mapped.story, 'Histoire FR');
      expect(mapped.ctaLabel, 'Voir');
    });
  });

  group('ProductTranslation.fromJson', () {
    test('normalizes blank/whitespace overrides to null', () {
      final t = ProductTranslation.fromJson({
        'product': 'p1',
        'locale': 'en',
        'name': 'Red dress',
        'summary': '   ',
        'description': '',
      });

      expect(t.productId, 'p1');
      expect(t.name, 'Red dress');
      expect(t.summary, isNull);
      expect(t.description, isNull);
    });
  });
}
