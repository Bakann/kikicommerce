import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/utils/slug_utils.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

void main() {
  group('slugify', () {
    test('normalizes accents and punctuation to ASCII slugs', () {
      expect(slugify("L'œuf & l'été"), 'loeuf-and-lete');
      expect(slugify('Robe bébé en coton'), 'robe-bebe-en-coton');
    });

    test('falls back when the source is empty', () {
      expect(slugify('   ', fallback: 'PROD-001'), 'prod-001');
    });
  });

  group('canonicalProductSlug', () {
    test('uses the persisted slug when it is unique', () {
      const product = CatalogProduct(
        id: 'prod-1',
        code: 'PROD-001',
        name: 'Sac Totoro Nuage',
        slug: 'sac-totoro-premium',
      );

      expect(
        canonicalProductSlug(
          product: product,
          siblingProducts: const [product],
        ),
        'sac-totoro-premium',
      );
    });

    test('adds a stable code suffix when siblings collide', () {
      const first = CatalogProduct(
        id: 'prod-1',
        code: 'PROD-001',
        name: 'Robe bébé en coton',
      );
      const second = CatalogProduct(
        id: 'prod-2',
        code: 'PROD-002',
        name: 'Robe bébé en coton',
      );

      expect(
        canonicalProductSlug(
          product: first,
          siblingProducts: const [first, second],
        ),
        'robe-bebe-en-coton--prod-001',
      );
      expect(
        canonicalProductSlug(
          product: second,
          siblingProducts: const [first, second],
        ),
        'robe-bebe-en-coton--prod-002',
      );
    });
  });
}
