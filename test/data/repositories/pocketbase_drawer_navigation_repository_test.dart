import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/data/api/pocketbase_client.dart';
import 'package:kiki_commerce/data/repositories/pocketbase_drawer_navigation_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PocketBaseDrawerNavigationRepository', () {
    test('missing menu falls back without fetching items', () async {
      final requests = <http.Request>[];
      final repo = _repo((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/navigation_menus/records')) {
          return _jsonResponse(_emptyPage());
        }
        return http.Response('Not found', 404);
      });

      final result = await repo.fetchMainDrawer(locale: 'fr');

      expect(result.fallbackReason, DrawerNavigationFallbackReason.menuMissing);
      expect(
        requests.where((r) => r.url.path.endsWith('/navigation_items/records')),
        isEmpty,
      );
    });

    test('inactive menu falls back without fetching items', () async {
      final requests = <http.Request>[];
      final repo = _repo((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/navigation_menus/records')) {
          return _jsonResponse(_menusPage(isActive: false));
        }
        return http.Response('Not found', 404);
      });

      final result = await repo.fetchMainDrawer(locale: 'fr');

      expect(
        result.fallbackReason,
        DrawerNavigationFallbackReason.menuInactive,
      );
      expect(
        requests.where((r) => r.url.path.endsWith('/navigation_items/records')),
        isEmpty,
      );
    });

    test('active menu with a valid root yields a usable tree', () async {
      final requests = <http.Request>[];
      final repo = _repo((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/navigation_menus/records')) {
          return _jsonResponse(_menusPage());
        }
        if (request.url.path.endsWith('/navigation_items/records')) {
          return _jsonResponse(_itemsPage());
        }
        return http.Response('Not found', 404);
      });

      final result = await repo.fetchMainDrawer(locale: 'fr');

      expect(result.fallbackReason, isNull);
      expect(result.isUsable, isTrue);
      expect(result.menu?.id, 'menu-1');

      final itemsRequest = requests.firstWhere(
        (r) => r.url.path.endsWith('/navigation_items/records'),
      );
      final filter = itemsRequest.url.queryParameters['filter'];
      expect(filter, contains('menu="menu-1"'));
      expect(filter, contains('isActive=true'));
      expect(filter, contains('isHidden=false'));
      expect(
        itemsRequest.url.queryParameters['expand'],
        'category,product,promoMedia',
      );
      expect(itemsRequest.url.queryParameters['sort'], 'position,created');
    });

    test('includeHidden drops the isHidden filter clause', () async {
      final requests = <http.Request>[];
      final repo = _repo((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/navigation_menus/records')) {
          return _jsonResponse(_menusPage());
        }
        if (request.url.path.endsWith('/navigation_items/records')) {
          return _jsonResponse(_itemsPage());
        }
        return http.Response('Not found', 404);
      });

      await repo.fetchMainDrawer(locale: 'fr', includeHidden: true);

      final itemsRequest = requests.firstWhere(
        (r) => r.url.path.endsWith('/navigation_items/records'),
      );
      final filter = itemsRequest.url.queryParameters['filter'];
      expect(filter, contains('isActive=true'));
      expect(filter, isNot(contains('isHidden')));
    });

    test('a network error falls back with fetchError', () async {
      final repo = _repo((request) async {
        if (request.url.path.endsWith('/navigation_menus/records')) {
          return http.Response('boom', 500);
        }
        return http.Response('Not found', 404);
      });

      final result = await repo.fetchMainDrawer(locale: 'fr');

      expect(result.fallbackReason, DrawerNavigationFallbackReason.fetchError);
    });
  });
}

PocketBaseDrawerNavigationRepository _repo(MockClientHandler handler) {
  return PocketBaseDrawerNavigationRepository(
    client: PocketBaseClient(
      httpClient: MockClient(handler),
      baseUrl: 'https://example.test',
    ),
  );
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _menusPage({bool isActive = true}) {
  return {
    'page': 1,
    'perPage': 1,
    'totalItems': 1,
    'totalPages': 1,
    'items': [
      {
        'id': 'menu-1',
        'name': 'Main drawer',
        'code': 'main_drawer',
        'displayMode': 'drawer',
        'isActive': isActive,
      },
    ],
  };
}

Map<String, dynamic> _itemsPage() {
  return {
    'page': 1,
    'perPage': 200,
    'totalItems': 1,
    'totalPages': 1,
    'items': [
      {
        'id': 'root-1',
        'menu': 'menu-1',
        'position': 10,
        'label': 'Cadeaux',
        'itemType': 'page',
        'pageKey': 'gifts',
        'placement': 'nav',
        'isActive': true,
        'isHidden': false,
      },
    ],
  };
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
