import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/error/app_exception.dart';
import 'package:kiki_commerce/data/api/pocketbase_client.dart';
import 'package:kiki_commerce/data/repositories/cart_repository_impl.dart';
import 'package:kiki_commerce/domain/cart/cart_exceptions.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PocketBaseCartRepository', () {
    test(
      'addToCartAck uses the custom endpoint and idempotency header when enabled',
      () async {
        late http.Request captured;
        final repository = _repository(
          MockClient((request) async {
            captured = request;
            return _jsonResponse(const {
              'cartId': 'cart-1',
              'entryProductId': 'prod-1',
              'quantityDelta': 2,
              'cartCreated': false,
            });
          }),
          useAddItemEndpoint: true,
        );

        final ack = await repository.addToCartAck(
          guestId: 'guest-1',
          product: _product,
          price: _price,
          quantity: 2,
          idempotencyKey: 'idem-1',
        );

        expect(ack.cartId, 'cart-1');
        expect(captured.method, 'POST');
        expect(captured.url.path, '/api/cart/add-item');
        expect(captured.headers['X-Cart-Guest-Id'], 'guest-1');
        expect(captured.headers['Idempotency-Key'], 'idem-1');
        expect(jsonDecode(captured.body), {
          'productId': 'prod-1',
          'priceId': 'price-1',
          'quantity': 2,
        });
      },
    );

    test('addToCartAck maps custom endpoint currency mismatches', () async {
      final repository = _repository(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'code': 'cart_currency_mismatch',
              'message': 'mismatch',
              'cartCurrencyCode': 'USD',
              'priceCurrencyCode': 'EUR',
            }),
            409,
            headers: const {'content-type': 'application/json'},
          );
        }),
        useAddItemEndpoint: true,
      );

      await expectLater(
        repository.addToCartAck(
          guestId: 'guest-1',
          product: _product,
          price: _price,
          quantity: 1,
          idempotencyKey: 'idem-2',
        ),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });

    test(
      'addToCartAck does not fall back on endpoint 404 business errors',
      () async {
        final requests = <String>[];
        final repository = _repository(
          MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.url.path == '/api/cart/add-item') {
              return http.Response(
                jsonEncode({
                  'code': 'product_not_found',
                  'message': 'Product not found',
                }),
                404,
                headers: const {'content-type': 'application/json'},
              );
            }
            return http.Response('Unexpected legacy call', 500);
          }),
          useAddItemEndpoint: true,
        );

        await expectLater(
          repository.addToCartAck(
            guestId: 'guest-1',
            product: _product,
            price: _price,
            quantity: 1,
            idempotencyKey: 'idem-404',
            cachedCartId: 'cart-cached',
            cachedCartCurrencyCode: 'EUR',
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              'product_not_found',
            ),
          ),
        );
        expect(requests, ['POST /api/cart/add-item']);
      },
    );

    test(
      'addToCartAck falls back to the legacy warm path when the endpoint is absent',
      () async {
        final requests = <String>[];
        final repository = _repository(
          MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.url.path == '/api/cart/add-item') {
              return http.Response('Not found', 404);
            }
            if (request.method == 'GET' &&
                request.url.path == '/api/collections/cart_entries/records') {
              return _jsonResponse(_pageJson(const []));
            }
            if (request.method == 'POST' &&
                request.url.path == '/api/collections/cart_entries/records') {
              return _jsonResponse(_entryJson(quantity: 1));
            }
            return http.Response('Not found', 404);
          }),
          useAddItemEndpoint: true,
        );

        final ack = await repository.addToCartAck(
          guestId: 'guest-1',
          product: _product,
          price: _price,
          quantity: 1,
          idempotencyKey: 'idem-3',
          cachedCartId: 'cart-cached',
          cachedCartCurrencyCode: 'EUR',
        );

        expect(ack.cartId, 'cart-cached');
        expect(requests, [
          'POST /api/cart/add-item',
          'GET /api/collections/cart_entries/records',
          'POST /api/collections/cart_entries/records',
        ]);
      },
    );

    test('creates a guest cart with the bearer header', () async {
      late http.Request captured;
      final repository = _repository(
        MockClient((request) async {
          captured = request;
          expect(request.method, 'POST');
          expect(request.headers['X-Cart-Guest-Id'], 'guest-1');
          return _jsonResponse(_cartJson());
        }),
      );

      final cart = await repository.createGuestCart(
        guestId: 'guest-1',
        currencyCode: 'EUR',
      );

      expect(cart.id, 'cart-1');
      expect(jsonDecode(captured.body)['guest_id'], 'guest-1');
    });

    test('translates 400 create responses to CartConflictException', () async {
      final repository = _repository(
        MockClient((request) async {
          return http.Response('{"message":"conflict"}', 400);
        }),
      );

      await expectLater(
        repository.createGuestCart(guestId: 'guest-1', currencyCode: 'EUR'),
        throwsA(isA<CartConflictException>()),
      );
    });

    test('finds an entry and propagates guest header on GET', () async {
      late http.Request captured;
      final repository = _repository(
        MockClient((request) async {
          captured = request;
          return _jsonResponse(_pageJson([_entryJson(quantity: 2)]));
        }),
      );

      final entry = await repository.findEntryForProduct(
        cartId: 'cart-1',
        productId: 'prod-1',
      );

      expect(entry?.quantity, 2);
      expect(captured.headers['X-Cart-Guest-Id'], 'guest-1');
      expect(captured.url.queryParameters['perPage'], '1');
    });

    test('clearCart uses the custom clear endpoint once', () async {
      late http.Request captured;
      final repository = _repository(
        MockClient((request) async {
          captured = request;
          return _jsonResponse({
            'cart': _cartJson(),
            'entries': const [],
            'deletedCount': 2,
          });
        }),
      );

      final view = await repository.clearCart('cart-1');

      expect(view.entries, isEmpty);
      expect(view.cart.id, 'cart-1');
      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/cart/clear');
      expect(captured.headers['X-Cart-Guest-Id'], 'guest-1');
      expect(jsonDecode(captured.body), {'cartId': 'cart-1'});
    });

    test(
      'clearCart legacy fallback recomputes once after deleting entries',
      () async {
        final requests = <String>[];
        final repository = _repository(
          MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'POST' &&
                request.url.path == '/api/cart/clear') {
              return http.Response('Not found', 404);
            }
            if (request.method == 'GET' &&
                request.url.path == '/api/collections/cart_entries/records') {
              final hasDeleted = requests.any(
                (request) =>
                    request ==
                    'DELETE /api/collections/cart_entries/records/entry-2',
              );
              return _jsonResponse(
                _pageJson(
                  hasDeleted
                      ? const []
                      : [_entryJson(id: 'entry-1'), _entryJson(id: 'entry-2')],
                ),
              );
            }
            if (request.method == 'DELETE' &&
                request.url.path.startsWith(
                  '/api/collections/cart_entries/records/entry-',
                )) {
              return http.Response('', 204);
            }
            if (request.method == 'GET' &&
                request.url.path == '/api/collections/carts/records/cart-1') {
              return _jsonResponse(_cartJson(subtotal: 78, grandTotal: 78));
            }
            if (request.method == 'PATCH' &&
                request.url.path == '/api/collections/carts/records/cart-1') {
              return _jsonResponse(_cartJson());
            }
            return http.Response('Unexpected request', 500);
          }),
        );

        final view = await repository.clearCart('cart-1');

        expect(view.entries, isEmpty);
        expect(requests, [
          'POST /api/cart/clear',
          'GET /api/collections/cart_entries/records',
          'DELETE /api/collections/cart_entries/records/entry-1',
          'DELETE /api/collections/cart_entries/records/entry-2',
          'GET /api/collections/carts/records/cart-1',
          'GET /api/collections/cart_entries/records',
          'PATCH /api/collections/carts/records/cart-1',
        ]);
      },
    );

    test('recomputes totals across multiple entry pages', () async {
      final requestedPages = <String?>[];
      late Map<String, dynamic> patchBody;
      final repository = _repository(
        MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/carts/records/cart-1')) {
            return _jsonResponse(_cartJson());
          }
          if (request.method == 'GET' &&
              request.url.path.contains('/cart_entries/records')) {
            requestedPages.add(request.url.queryParameters['page']);
            final page = request.url.queryParameters['page'];
            final count = page == '1' ? 200 : 1;
            return _jsonResponse(
              _pageJson(
                List.generate(
                  count,
                  (index) => _entryJson(id: 'entry-$page-$index', lineTotal: 1),
                ),
                page: int.parse(page ?? '1'),
                totalPages: 2,
              ),
            );
          }
          if (request.method == 'PATCH' &&
              request.url.path.endsWith('/carts/records/cart-1')) {
            patchBody = jsonDecode(request.body) as Map<String, dynamic>;
            expect(request.headers['X-Cart-Guest-Id'], 'guest-1');
            return _jsonResponse(_cartJson(subtotal: 201, grandTotal: 201));
          }
          return http.Response('Not found', 404);
        }),
      );

      final view = await repository.recomputeAndSaveTotals('cart-1');

      expect(requestedPages, ['1', '2']);
      expect(patchBody['subtotal'], 201);
      expect(patchBody['grand_total'], 201);
      expect(view.entries, hasLength(201));
      expect(view.cart.totals.subtotal, 201);
    });

    test('sends raw Authorization token without Bearer prefix', () async {
      final client = PocketBaseClient(
        httpClient: MockClient((request) async {
          expect(request.headers['Authorization'], 'raw-token');
          return _jsonResponse(_cartJson());
        }),
        baseUrl: 'https://example.test',
      );

      await client.createRecord(
        'carts',
        const {},
        authToken: 'raw-token',
        cartGuestId: 'guest-1',
      );
    });
  });
}

const _product = CatalogProduct(
  id: 'prod-1',
  code: 'SKU-1',
  name: 'Sac Totoro',
);

const _price = CatalogPrice(
  id: 'price-1',
  productId: 'prod-1',
  price: 39,
  isDefault: true,
  currencySymbol: '€',
  currencyCode: 'EUR',
);

PocketBaseCartRepository _repository(
  http.Client httpClient, {
  bool useAddItemEndpoint = false,
}) {
  return PocketBaseCartRepository(
    client: PocketBaseClient(
      httpClient: httpClient,
      baseUrl: 'https://example.test',
    ),
    guestIdProvider: () async => 'guest-1',
    useAddItemEndpoint: useAddItemEndpoint,
  );
}

http.Response _jsonResponse(Map<String, dynamic> body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _pageJson(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int totalPages = 1,
}) {
  return {
    'page': page,
    'perPage': 200,
    'totalItems': items.length,
    'totalPages': totalPages,
    'items': items,
  };
}

Map<String, dynamic> _cartJson({double subtotal = 0, double grandTotal = 0}) {
  return {
    'id': 'cart-1',
    'guest_id': 'guest-1',
    'status': 'active',
    'currency_code': 'EUR',
    'subtotal': subtotal,
    'discount_total': 0,
    'shipping_total': 0,
    'tax_total': 0,
    'grand_total': grandTotal,
  };
}

Map<String, dynamic> _entryJson({
  String id = 'entry-1',
  int quantity = 1,
  double lineTotal = 39,
}) {
  return {
    'id': id,
    'cart': 'cart-1',
    'product': 'prod-1',
    'sku_snapshot': 'SKU-1',
    'product_name_snapshot': 'Sac Totoro',
    'quantity': quantity,
    'unit_price': lineTotal / quantity,
    'line_total': lineTotal,
  };
}
