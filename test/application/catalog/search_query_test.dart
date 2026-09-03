import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/catalog/search_query.dart';

void main() {
  group('SearchSort', () {
    test('toPocketBaseSort maps correctly', () {
      expect(SearchSort.newest.toPocketBaseSort(), '-created');
      expect(SearchSort.nameAsc.toPocketBaseSort(), 'name');
      expect(SearchSort.nameDesc.toPocketBaseSort(), '-name');
    });

    test('fromName returns correct enum value', () {
      expect(SearchSort.fromName('newest'), SearchSort.newest);
      expect(SearchSort.fromName('nameAsc'), SearchSort.nameAsc);
      expect(SearchSort.fromName('nameDesc'), SearchSort.nameDesc);
    });

    test('fromName returns newest for null or unknown', () {
      expect(SearchSort.fromName(null), SearchSort.newest);
      expect(SearchSort.fromName('invalid'), SearchSort.newest);
    });
  });

  group('searchQueryFromUri / searchQueryToParams round-trip', () {
    test('parses full query params', () {
      final uri = Uri.parse('/search?q=robe&sort=nameAsc&page=2&perPage=10');
      final query = searchQueryFromUri(uri);
      expect(query.query, 'robe');
      expect(query.sort, SearchSort.nameAsc);
      expect(query.page, 2);
      expect(query.perPage, 10);
    });

    test('uses defaults for missing params', () {
      final uri = Uri.parse('/search');
      final query = searchQueryFromUri(uri);
      expect(query.query, isNull);
      expect(query.sort, SearchSort.newest);
      expect(query.page, 1);
      expect(query.perPage, 20);
    });

    test('round-trips through toParams and fromUri', () {
      const SearchQuery original = (
        query: 'sac été',
        sort: SearchSort.nameDesc,
        page: 3,
        perPage: 20,
      );

      final params = searchQueryToParams(original);
      final uri = Uri(path: '/search', queryParameters: params);
      final restored = searchQueryFromUri(uri);

      expect(restored.query, original.query);
      expect(restored.sort, original.sort);
      expect(restored.page, original.page);
      expect(restored.perPage, original.perPage);
    });

    test('toParams omits defaults', () {
      const SearchQuery query = (
        query: 'robe',
        sort: SearchSort.newest,
        page: 1,
        perPage: 20,
      );

      final params = searchQueryToParams(query);
      expect(params, {'q': 'robe'});
      expect(params.containsKey('sort'), isFalse);
      expect(params.containsKey('page'), isFalse);
      expect(params.containsKey('perPage'), isFalse);
    });

    test('toParams includes non-defaults', () {
      const SearchQuery query = (
        query: 'robe',
        sort: SearchSort.nameAsc,
        page: 2,
        perPage: 20,
      );

      final params = searchQueryToParams(query);
      expect(params['q'], 'robe');
      expect(params['sort'], 'nameAsc');
      expect(params['page'], '2');
    });

    test('toParams omits null/empty query', () {
      const SearchQuery query = (
        query: null,
        sort: SearchSort.newest,
        page: 1,
        perPage: 20,
      );

      expect(searchQueryToParams(query), isEmpty);
    });
  });

  group('SearchQuery structural equality', () {
    test('identical queries are equal', () {
      const SearchQuery a = (
        query: 'robe',
        sort: SearchSort.newest,
        page: 1,
        perPage: 20,
      );
      const SearchQuery b = (
        query: 'robe',
        sort: SearchSort.newest,
        page: 1,
        perPage: 20,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different queries are not equal', () {
      const SearchQuery a = (
        query: 'robe',
        sort: SearchSort.newest,
        page: 1,
        perPage: 20,
      );
      const SearchQuery b = (
        query: 'sac',
        sort: SearchSort.newest,
        page: 1,
        perPage: 20,
      );

      expect(a, isNot(equals(b)));
    });
  });
}
