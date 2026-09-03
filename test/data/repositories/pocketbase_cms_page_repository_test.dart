import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/cms/cms_page_repository.dart';
import 'package:kiki_commerce/data/api/pocketbase_client.dart';
import 'package:kiki_commerce/data/repositories/pocketbase_cms_page_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PocketBaseCmsPageRepository.fetchPage', () {
    test('returns CmsPageMissing and skips the sections call', () async {
      final requests = <http.Request>[];
      final repo = PocketBaseCmsPageRepository(
        client: PocketBaseClient(
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/pages/records')) {
              return _jsonResponse(_emptyPage());
            }
            return http.Response('Not found', 404);
          }),
          baseUrl: 'https://example.test',
        ),
      );

      final result = await repo.fetchPage(code: 'homepage', locale: 'fr');

      expect(result, isA<CmsPageMissing>());
      // No page → no point fetching sections.
      expect(
        requests.where((r) => r.url.path.endsWith('/page_sections/records')),
        isEmpty,
      );
      final pagesFilter = requests.single.url.queryParameters['filter'];
      expect(pagesFilter, contains('code="homepage"'));
      expect(pagesFilter, contains('locale="fr"'));
      expect(pagesFilter, contains('isActive=true'));
    });

    test('returns a bundle and runs the section parse pipeline', () async {
      final requests = <http.Request>[];
      final repo = PocketBaseCmsPageRepository(
        client: PocketBaseClient(
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/pages/records')) {
              return _jsonResponse(_onePage('page-1', 'homepage', 'fr'));
            }
            if (request.url.path.endsWith('/page_sections/records')) {
              return _jsonResponse(_sectionsPage());
            }
            return http.Response('Not found', 404);
          }),
          baseUrl: 'https://example.test',
        ),
      );

      final result = await repo.fetchPage(code: 'homepage', locale: 'fr');

      expect(result, isA<CmsPageFound>());
      final bundle = (result as CmsPageFound).bundle;
      expect(bundle.page.id, 'page-1');
      expect(bundle.page.code, 'homepage');
      // Each record runs through parseCmsSection; order is preserved.
      expect(bundle.sections, hasLength(2));
      // Unrecognised section types degrade to CmsUnknownSection instead of
      // failing the whole page.
      expect(bundle.sections.last, isA<CmsUnknownSection>());

      final sectionsRequest = requests.firstWhere(
        (r) => r.url.path.endsWith('/page_sections/records'),
      );
      expect(
        sectionsRequest.url.queryParameters['filter'],
        contains('page="page-1"'),
      );
      expect(sectionsRequest.url.queryParameters['sort'], 'position,created');
    });

    test('maps a thrown error to CmsPageFailure', () async {
      final repo = PocketBaseCmsPageRepository(
        client: PocketBaseClient(
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/pages/records')) {
              return http.Response('boom', 500);
            }
            return http.Response('Not found', 404);
          }),
          baseUrl: 'https://example.test',
        ),
      );

      final result = await repo.fetchPage(code: 'homepage', locale: 'fr');

      expect(result, isA<CmsPageFailure>());
    });
  });

  group('PocketBaseCmsPageRepository.fetchPlpForCategory', () {
    test('filters by plp page type and source category', () async {
      final requests = <http.Request>[];
      final repo = PocketBaseCmsPageRepository(
        client: PocketBaseClient(
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/pages/records')) {
              return _jsonResponse(_onePage('plp-1', 'plp_roses', 'fr'));
            }
            if (request.url.path.endsWith('/page_sections/records')) {
              return _jsonResponse(_emptyPage());
            }
            return http.Response('Not found', 404);
          }),
          baseUrl: 'https://example.test',
        ),
      );

      final result = await repo.fetchPlpForCategory(
        categoryId: 'cat-1',
        locale: 'fr',
      );

      expect(result, isA<CmsPageFound>());
      final pagesFilter = requests
          .firstWhere((r) => r.url.path.endsWith('/pages/records'))
          .url
          .queryParameters['filter'];
      expect(pagesFilter, contains('pageType="plp"'));
      expect(pagesFilter, contains('sourceCategory="cat-1"'));
      expect(pagesFilter, contains('locale="fr"'));
    });
  });
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _emptyPage() {
  return {
    'page': 1,
    'perPage': 1,
    'totalItems': 0,
    'totalPages': 0,
    'items': <Map<String, dynamic>>[],
  };
}

Map<String, dynamic> _onePage(String id, String code, String locale) {
  return {
    'page': 1,
    'perPage': 1,
    'totalItems': 1,
    'totalPages': 1,
    'items': [
      {
        'id': id,
        'code': code,
        'locale': locale,
        'title': 'Title $code',
        'isActive': true,
      },
    ],
  };
}

Map<String, dynamic> _sectionsPage() {
  return {
    'page': 1,
    'perPage': 200,
    'totalItems': 2,
    'totalPages': 1,
    'items': [
      {
        'id': 'sec-1',
        'page': 'page-1',
        'sectionId': 'hero',
        'sectionType': 'seo_text',
        'position': 1,
        'isActive': true,
        'config': {'title': 'SEO'},
      },
      {
        'id': 'sec-2',
        'page': 'page-1',
        'sectionId': 'mystery',
        'sectionType': 'totally_unknown_type',
        'position': 2,
        'isActive': true,
        'config': <String, dynamic>{},
      },
    ],
  };
}
