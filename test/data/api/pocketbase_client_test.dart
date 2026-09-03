import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/error/app_exception.dart';
import 'package:kiki_commerce/data/api/pocketbase_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PocketBaseClient', () {
    test('retries GET timeouts and surfaces a NetworkException', () async {
      var attempts = 0;
      final client = PocketBaseClient(
        httpClient: MockClient((request) async {
          attempts += 1;
          throw TimeoutException('slow response');
        }),
        baseUrl: 'https://example.test',
      );

      await expectLater(
        client.getRecord('products', 'prod-1'),
        throwsA(
          isA<NetworkException>().having(
            (error) => error.message,
            'message',
            contains('slow response'),
          ),
        ),
      );
      expect(attempts, 3);
    });

    test(
      'omits Content-Type on GET to keep public reads CORS-simple',
      () async {
        late Map<String, String> headers;
        final client = PocketBaseClient(
          httpClient: MockClient((request) async {
            headers = request.headers;
            return http.Response('{}', 200);
          }),
          baseUrl: 'https://example.test',
        );

        await client.getRecord('products', 'prod-1');

        expect(headers['Accept'], 'application/json');
        expect(headers.containsKey('Content-Type'), isFalse);
      },
    );

    test('retries GET 429 responses before succeeding', () async {
      var attempts = 0;
      final client = PocketBaseClient(
        httpClient: MockClient((request) async {
          attempts += 1;
          if (attempts == 1) {
            return http.Response('{"message":"rate limited"}', 429);
          }
          return http.Response('{"id":"prod-1"}', 200);
        }),
        baseUrl: 'https://example.test',
        delay: (_) async {},
      );

      final record = await client.getRecord('products', 'prod-1');

      expect(record['id'], 'prod-1');
      expect(attempts, 2);
    });

    test('limits concurrent GETs', () async {
      var active = 0;
      var maxActive = 0;
      final client = PocketBaseClient(
        httpClient: MockClient((request) async {
          active += 1;
          if (active > maxActive) {
            maxActive = active;
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
          active -= 1;
          return http.Response('{}', 200);
        }),
        baseUrl: 'https://example.test',
        maxConcurrentGets: 2,
      );

      await Future.wait([
        for (var index = 0; index < 5; index += 1)
          client.getRecord('products', 'prod-$index'),
      ]);

      expect(maxActive, lessThanOrEqualTo(2));
    });
  });
}
