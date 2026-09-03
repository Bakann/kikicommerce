import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/data/csv/catalog_csv_parser.dart';

void main() {
  group('parseCsvRows', () {
    test('returns empty list for empty input', () {
      expect(parseCsvRows(''), isEmpty);
    });

    test('trims headers and cells and starts line numbers at 2', () {
      const csv =
          'product_code;product_name\n'
          'SKU-1; Widget \n'
          '  ; \n'
          'SKU-2;Gadget';
      final rows = parseCsvRows(csv);
      expect(rows, hasLength(2));
      expect(rows.first.lineNumber, 2);
      expect(rows.first.value('product_code'), 'SKU-1');
      expect(rows.first.value('product_name'), 'Widget');
      expect(rows.last.lineNumber, 4);
      expect(rows.last.value('product_code'), 'SKU-2');
    });

    test('fills missing cells with empty string', () {
      const csv = 'a;b;c\n1;2';
      final rows = parseCsvRows(csv);
      expect(rows.single.value('c'), '');
    });
  });

  group('parseCsvBool', () {
    test('returns default when empty', () {
      expect(parseCsvBool('', defaultValue: true), isTrue);
      expect(parseCsvBool('   ', defaultValue: false), isFalse);
    });

    test('recognises truthy variants case-insensitively', () {
      for (final truthy in const ['true', 'TRUE', '1', 'yes', 'Oui', 'vrai']) {
        expect(
          parseCsvBool(truthy, defaultValue: false),
          isTrue,
          reason: truthy,
        );
      }
    });

    test('recognises falsy variants case-insensitively', () {
      for (final falsy in const ['false', 'FALSE', '0', 'no', 'Non', 'faux']) {
        expect(parseCsvBool(falsy, defaultValue: true), isFalse, reason: falsy);
      }
    });

    test('throws on unknown non-empty values', () {
      expect(
        () => parseCsvBool('bogus', defaultValue: true),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CsvRow helpers', () {
    final row = CsvRow(
      lineNumber: 2,
      values: const {
        'name': '  Alice  ',
        'empty': '   ',
        'int': '42',
        'intBad': 'abc',
        'float': '3,14',
        'floatBad': 'nope',
        'bool': 'oui',
        'list': 'a|b||c',
      },
    );

    test('valueOrNull trims and returns null for blank', () {
      expect(row.valueOrNull('name'), 'Alice');
      expect(row.valueOrNull('empty'), isNull);
      expect(row.valueOrNull('missing'), isNull);
    });

    test('intValue parses or returns null', () {
      expect(row.intValue('int'), 42);
      expect(row.intValue('intBad'), isNull);
      expect(row.intValue('empty'), isNull);
    });

    test('doubleValue tolerates comma decimals', () {
      expect(row.doubleValue('float'), closeTo(3.14, 0.0001));
      expect(row.doubleValue('floatBad'), isNull);
    });

    test('boolValue falls back to default', () {
      expect(row.boolValue('bool', defaultValue: false), isTrue);
      expect(row.boolValue('missing', defaultValue: true), isTrue);
    });

    test(
      'pipeValues drops empties while pipeValuesPreserveEmpty keeps them',
      () {
        expect(row.pipeValues('list'), ['a', 'b', 'c']);
        expect(row.pipeValuesPreserveEmpty('list'), ['a', 'b', '', 'c']);
      },
    );
  });

  group('hasNarrativeData', () {
    test('returns false when all narrative cells are blank', () {
      final row = CsvRow(
        lineNumber: 2,
        values: const {
          'chapter_positions': '  ',
          'chapter_media_codes': '',
          'chapter_headlines': '',
          'chapter_stories': '',
          'chapter_cta_labels': '',
          'chapter_cta_actions': '',
          'chapter_is_active': '',
        },
      );
      expect(hasNarrativeData(row), isFalse);
    });

    test('returns true if any narrative cell is non-empty', () {
      final row = CsvRow(
        lineNumber: 2,
        values: const {'chapter_headlines': 'Hello'},
      );
      expect(hasNarrativeData(row), isTrue);
    });
  });

  group('NarrativeCsvBlock.parse', () {
    CsvRow rowFor({
      String positions = '1|2',
      String mediaCodes = 'm1|m2',
      String headlines = 'H1|H2',
      String stories = '',
      String ctaLabels = '',
      String ctaActions = '',
      String isActive = '',
    }) {
      return CsvRow(
        lineNumber: 7,
        values: {
          'product_code': 'P1',
          'chapter_positions': positions,
          'chapter_media_codes': mediaCodes,
          'chapter_headlines': headlines,
          'chapter_stories': stories,
          'chapter_cta_labels': ctaLabels,
          'chapter_cta_actions': ctaActions,
          'chapter_is_active': isActive,
        },
      );
    }

    test('parses a valid block with default optional fields', () {
      final block = NarrativeCsvBlock.fromRow(rowFor());
      final report = CatalogImportReport(totalRows: 1);
      final parsed = block.parse(report);
      expect(parsed, isNotNull);
      expect(report.errors, isEmpty);
      expect(parsed!.positions, [1, 2]);
      expect(parsed.mediaCodes, ['m1', 'm2']);
      expect(parsed.headlines, ['H1', 'H2']);
      expect(parsed.stories, ['', '']);
      expect(parsed.ctaLabels, ['', '']);
      expect(parsed.ctaActions, ['', '']);
      expect(parsed.isActive, [true, true]);
    });

    test(
      'flags arité invalide when positions length mismatches media codes',
      () {
        final block = NarrativeCsvBlock.fromRow(rowFor(positions: '1'));
        final report = CatalogImportReport(totalRows: 1);
        expect(block.parse(report), isNull);
        expect(report.errors.single, contains('arité narrative invalide'));
      },
    );

    test('flags arité incohérente for an optional field mismatch', () {
      final block = NarrativeCsvBlock.fromRow(rowFor(stories: 'only-one'));
      final report = CatalogImportReport(totalRows: 1);
      expect(block.parse(report), isNull);
      expect(report.errors.single, contains('chapter_stories'));
    });

    test('flags invalid position values', () {
      final block = NarrativeCsvBlock.fromRow(rowFor(positions: 'abc|2'));
      final report = CatalogImportReport(totalRows: 1);
      expect(block.parse(report), isNull);
      expect(report.errors.single, contains('position narrative invalide'));
    });

    test('parses explicit isActive flags', () {
      final block = NarrativeCsvBlock.fromRow(rowFor(isActive: 'true|no'));
      final report = CatalogImportReport(totalRows: 1);
      final parsed = block.parse(report)!;
      expect(parsed.isActive, [true, false]);
    });

    test('reports invalid isActive values', () {
      final block = NarrativeCsvBlock.fromRow(rowFor(isActive: 'true|treu'));
      final report = CatalogImportReport(totalRows: 1);
      expect(block.parse(report), isNull);
      expect(report.errors.single, contains('booléen narrative invalide'));
      expect(report.errors.single, contains('treu'));
    });

    test('hasSameRawValues compares payload maps', () {
      final a = NarrativeCsvBlock.fromRow(rowFor());
      final b = NarrativeCsvBlock.fromRow(rowFor());
      final c = NarrativeCsvBlock.fromRow(rowFor(headlines: 'X|Y'));
      expect(a.hasSameRawValues(b), isTrue);
      expect(a.hasSameRawValues(c), isFalse);
    });

    test('hasSameRawValues ignores unrelated map keys', () {
      final a = NarrativeCsvBlock.fromRow(rowFor());
      final b = NarrativeCsvBlock(
        lineNumber: 7,
        productCode: 'P1',
        rawValues: {...a.rawValues, 'unrelated': 'changed'},
      );
      expect(a.hasSameRawValues(b), isTrue);
    });
  });
}
