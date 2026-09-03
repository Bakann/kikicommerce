import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/utils/search_index_utils.dart';

void main() {
  group('normalizeForSearch', () {
    test('returns empty string for null', () {
      expect(normalizeForSearch(null), '');
    });

    test('returns empty string for empty input', () {
      expect(normalizeForSearch(''), '');
    });

    test('lowercases and strips accents', () {
      expect(normalizeForSearch('Été'), 'ete');
      expect(normalizeForSearch('Robe Bébé'), 'robe bebe');
    });

    test('replaces apostrophes with spaces', () {
      expect(normalizeForSearch("d'Été"), 'd ete');
      expect(normalizeForSearch('l\u2019hiver'), 'l hiver');
    });

    test('replaces dashes and em-dashes with spaces', () {
      expect(normalizeForSearch('Lin—Bleu'), 'lin bleu');
      expect(normalizeForSearch('bleu-nuit'), 'bleu nuit');
    });

    test('replaces commas, dots, underscores, slashes with spaces', () {
      expect(normalizeForSearch('a,b.c_d/e'), 'a b c d e');
    });

    test('collapses multiple separators into single space', () {
      expect(normalizeForSearch("Kiki's — Lin/Coton"), 'kiki s lin coton');
    });

    test('trims leading and trailing whitespace', () {
      expect(normalizeForSearch('  hello  '), 'hello');
    });

    test('handles complex French product name', () {
      expect(
        normalizeForSearch("Robe d'Été Kiki — Lin Bleu"),
        'robe d ete kiki lin bleu',
      );
    });
  });

  group('buildProductSearchIndex', () {
    test('concatenates all fields in order', () {
      final data = {
        'name': 'Sac Totoro',
        'slug': 'sac-totoro',
        'summary': 'Un sac magique',
        'description': 'Le célèbre sac',
        'brand': 'Kiki',
        'productType': 'Accessoire',
        'ean': '1234567890123',
        'code': 'SAC-001',
      };

      final index = buildProductSearchIndex(data);
      expect(index, contains('sac totoro'));
      expect(index, contains('un sac magique'));
      expect(index, contains('kiki'));
      expect(index, contains('1234567890123'));
      expect(index, contains('sac 001'));
    });

    test('skips null and empty fields', () {
      final data = {
        'name': 'Robe',
        'slug': null,
        'summary': '',
        'description': null,
        'brand': null,
        'productType': null,
        'ean': null,
        'code': 'ROB-01',
      };

      final index = buildProductSearchIndex(data);
      expect(index, 'robe rob 01');
    });

    test('normalizes accents in all fields', () {
      final data = {'name': 'Château', 'brand': 'Café', 'code': ''};

      final index = buildProductSearchIndex(data);
      expect(index, contains('chateau'));
      expect(index, contains('cafe'));
    });
  });
}
