import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/storefront/storefront_navigation_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/data/api/pocketbase_client.dart';
import 'package:kiki_commerce/data/repositories/pocketbase_storefront_settings_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'getNavigationSettings returns fallback when record is absent',
    () async {
      final repository = PocketBaseStorefrontSettingsRepository(
        client: PocketBaseClient(
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'page': 1,
                'perPage': 1,
                'totalItems': 0,
                'totalPages': 0,
                'items': [],
              }),
              200,
            );
          }),
          baseUrl: 'https://example.test',
        ),
      );

      final settings = await repository.getNavigationSettings();

      expect(settings.mobileMenuStyle, MobileMenuStyle.drawer);
    },
  );

  test('getNavigationSettings returns fallback on fetch error', () async {
    final repository = PocketBaseStorefrontSettingsRepository(
      client: PocketBaseClient(
        httpClient: MockClient((request) async {
          return http.Response('nope', 500);
        }),
        baseUrl: 'https://example.test',
      ),
    );

    final settings = await repository.getNavigationSettings();

    expect(settings.mobileMenuStyle, MobileMenuStyle.drawer);
  });

  test('getNavigationSettings reads the navigation singleton', () async {
    Uri? capturedUri;
    final repository = PocketBaseStorefrontSettingsRepository(
      client: PocketBaseClient(
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({
              'page': 1,
              'perPage': 1,
              'totalItems': 1,
              'totalPages': 1,
              'items': [
                {'id': 'navigation-id', 'mobileMenuStyle': 'fullscreenReveal'},
              ],
            }),
            200,
          );
        }),
        baseUrl: 'https://example.test',
      ),
    );

    final settings = await repository.getNavigationSettings();

    expect(settings.id, 'navigation-id');
    expect(settings.mobileMenuStyle, MobileMenuStyle.fullscreenReveal);
    expect(
      capturedUri?.queryParameters['filter'],
      'key = "$storefrontNavigationSettingsKey"',
    );
  });

  test('getActiveTheme reads the first active_theme record by +id', () async {
    Uri? capturedUri;
    final repository = PocketBaseStorefrontSettingsRepository(
      client: PocketBaseClient(
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({
              'page': 1,
              'perPage': 1,
              'totalItems': 2,
              'totalPages': 1,
              'items': [
                {'id': 'new-theme', 'theme': 'nike'},
              ],
            }),
            200,
          );
        }),
        baseUrl: 'https://example.test',
      ),
    );

    final activeTheme = await repository.getActiveTheme();

    expect(activeTheme.id, 'new-theme');
    expect(activeTheme.theme, StorefrontTheme.nike);
    // The collection has no `updated` field, so we sort by `+id` for a
    // deterministic read order in case the unique-key migration hasn't
    // yet collapsed the duplicates.
    expect(capturedUri?.queryParameters['sort'], '+id');
    expect(
      capturedUri?.queryParameters['filter'],
      'key = "$storefrontActiveThemeKey"',
    );
  });

  test(
    'saveActiveTheme patches the first record by +id and removes duplicates',
    () async {
      final requests = <String>[];
      final repository = PocketBaseStorefrontSettingsRepository(
        client: PocketBaseClient(
          httpClient: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'GET') {
              expect(request.url.queryParameters['sort'], '+id');
              expect(request.url.queryParameters['perPage'], '200');
              return http.Response(
                jsonEncode({
                  'page': 1,
                  'perPage': 200,
                  'totalItems': 2,
                  'totalPages': 1,
                  'items': [
                    {'id': 'new-theme', 'theme': 'dior'},
                    {'id': 'old-theme', 'theme': 'nike'},
                  ],
                }),
                200,
              );
            }
            if (request.method == 'PATCH' &&
                request.url.path.endsWith('/records/new-theme')) {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['key'], storefrontActiveThemeKey);
              expect(body['theme'], 'nike');
              return http.Response(
                jsonEncode({'id': 'new-theme', ...body}),
                200,
              );
            }
            if (request.method == 'DELETE' &&
                request.url.path.endsWith('/records/old-theme')) {
              return http.Response('', 204);
            }
            return http.Response(
              'unexpected ${request.method} ${request.url}',
              500,
            );
          }),
          baseUrl: 'https://example.test',
        ),
      );

      await repository.saveActiveTheme(
        authToken: 'admin-token',
        theme: StorefrontTheme.nike,
      );

      expect(
        requests,
        containsAllInOrder([
          'GET /api/collections/storefront_settings/records',
          'PATCH /api/collections/storefront_settings/records/new-theme',
          'DELETE /api/collections/storefront_settings/records/old-theme',
        ]),
      );
    },
  );
}
