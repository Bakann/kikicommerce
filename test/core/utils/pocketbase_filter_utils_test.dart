import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/utils/pocketbase_filter_utils.dart';

void main() {
  group('escapeFilterValue', () {
    test('escapes double quotes', () {
      expect(escapeFilterValue('hello "world"'), r'hello \"world\"');
    });

    test('escapes backslashes', () {
      expect(escapeFilterValue(r'back\slash'), r'back\\slash');
    });

    test('escapes both in correct order', () {
      expect(escapeFilterValue(r'a\b"c'), r'a\\b\"c');
    });

    test('passes through clean strings unchanged', () {
      expect(escapeFilterValue('hello'), 'hello');
    });
  });

  group('buildSearchFilter', () {
    test('returns null for null query', () {
      expect(buildSearchFilter(fieldName: 'searchIndex', query: null), isNull);
    });

    test('returns null for empty query', () {
      expect(buildSearchFilter(fieldName: 'searchIndex', query: '   '), isNull);
    });

    test('builds single-token filter', () {
      expect(
        buildSearchFilter(fieldName: 'searchIndex', query: 'robe'),
        'searchIndex ~ "robe"',
      );
    });

    test('builds multi-token AND filter', () {
      expect(
        buildSearchFilter(fieldName: 'searchIndex', query: 'robe été'),
        'searchIndex ~ "robe" && searchIndex ~ "ete"',
      );
    });

    test('normalizes accents in query tokens', () {
      expect(
        buildSearchFilter(fieldName: 'searchIndex', query: 'Château'),
        'searchIndex ~ "chateau"',
      );
    });

    test('escapes special characters in tokens', () {
      expect(
        buildSearchFilter(fieldName: 'searchIndex', query: 'a"b'),
        r'searchIndex ~ "a\"b"',
      );
    });

    test('returns null for query that normalizes to empty', () {
      // Only separators, no real content
      expect(buildSearchFilter(fieldName: 'searchIndex', query: '---'), isNull);
    });
  });

  group('combineFilters', () {
    test('combines multiple filters with &&', () {
      expect(
        combineFilters(['isActive=true', 'name ~ "robe"']),
        'isActive=true && name ~ "robe"',
      );
    });

    test('skips null filters', () {
      expect(
        combineFilters(['isActive=true', null, 'name ~ "robe"']),
        'isActive=true && name ~ "robe"',
      );
    });

    test('returns null when all filters are null', () {
      expect(combineFilters([null, null]), isNull);
    });

    test('returns single filter as-is', () {
      expect(combineFilters(['isActive=true']), 'isActive=true');
    });
  });
}
