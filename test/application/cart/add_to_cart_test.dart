import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cart/add_to_cart.dart';
import 'package:kiki_commerce/application/cart/cart_guest_session_store.dart';
import 'package:kiki_commerce/application/cart/cart_read_models.dart';
import 'package:kiki_commerce/application/cart/cart_repository.dart';
import 'package:kiki_commerce/domain/cart/cart_entities.dart';
import 'package:kiki_commerce/domain/cart/cart_exceptions.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

void main() {
  group('AddToCart', () {
    test('rejects a price without currency', () async {
      final useCase = AddToCart(
        _FakeCartRepository(),
        _FakeGuestSessionStore(),
      );

      await expectLater(
        useCase.ackMinimal(
          product: _product,
          price: _price(currencyCode: null),
        ),
        throwsA(isA<MissingCurrencyException>()),
      );
    });

    test(
      'delegates to repository with guest cache hints and idempotency key',
      () async {
        final repository = _FakeCartRepository();
        final guestSessionStore = _FakeGuestSessionStore(
          activeCart: const CachedActiveCart(
            cartId: 'cart-cached',
            currencyCode: 'EUR',
          ),
        );
        final useCase = AddToCart(
          repository,
          guestSessionStore,
          idempotencyKeyFactory: () => 'idem-123',
        );

        final ack = await useCase.ackMinimal(
          product: _product,
          price: _price(currencyCode: 'EUR'),
          quantity: 2,
        );

        expect(ack.cartId, 'cart-ack');
        expect(repository.lastGuestId, 'guest-1');
        expect(repository.lastIdempotencyKey, 'idem-123');
        expect(repository.lastCachedCartId, 'cart-cached');
        expect(repository.lastCachedCartCurrencyCode, 'EUR');
        expect(repository.lastQuantity, 2);
        expect(guestSessionStore.activeCart?.cartId, 'cart-ack');
        expect(guestSessionStore.activeCart?.currencyCode, 'EUR');
      },
    );

    test(
      'caches the returned cart id even without a prior cached cart',
      () async {
        final repository = _FakeCartRepository(
          ackToReturn: const CartAddAck(
            cartId: 'cart-fresh',
            entryProductId: 'prod-1',
            quantityDelta: 1,
            cartCreated: true,
          ),
        );
        final guestSessionStore = _FakeGuestSessionStore();
        final useCase = AddToCart(
          repository,
          guestSessionStore,
          idempotencyKeyFactory: () => 'idem-456',
        );

        await useCase.ackMinimal(product: _product, price: _price());

        expect(guestSessionStore.activeCart?.cartId, 'cart-fresh');
        expect(guestSessionStore.activeCart?.currencyCode, 'EUR');
        expect(repository.addToCartCalls, 1);
      },
    );

    test('propagates repository currency mismatch errors', () async {
      final repository = _FakeCartRepository(
        error: const CurrencyMismatchException(
          cartCurrencyCode: 'USD',
          priceCurrencyCode: 'EUR',
        ),
      );
      final useCase = AddToCart(
        repository,
        _FakeGuestSessionStore(),
        idempotencyKeyFactory: () => 'idem-789',
      );

      await expectLater(
        useCase.ackMinimal(product: _product, price: _price()),
        throwsA(isA<CurrencyMismatchException>()),
      );
    });
  });
}

const _product = CatalogProduct(
  id: 'prod-1',
  code: 'SKU-1',
  name: 'Sac Totoro',
);

CatalogPrice _price({String? currencyCode = 'EUR'}) {
  return CatalogPrice(
    id: 'price-1',
    productId: 'prod-1',
    price: 39,
    isDefault: true,
    currencySymbol: '€',
    currencyCode: currencyCode,
  );
}

class _FakeGuestSessionStore implements CartGuestSessionStore {
  CachedActiveCart? activeCart;

  _FakeGuestSessionStore({this.activeCart});

  @override
  Future<void> clearGuestId() async {}

  @override
  Future<String> ensureGuestId() async => 'guest-1';

  @override
  Future<String?> peekGuestId() async => 'guest-1';

  @override
  Future<CachedActiveCart?> peekActiveCart() async => activeCart;

  @override
  Future<void> cacheActiveCart({
    required String cartId,
    required String currencyCode,
  }) async {
    activeCart = CachedActiveCart(cartId: cartId, currencyCode: currencyCode);
  }

  @override
  Future<void> clearActiveCart() async {
    activeCart = null;
  }
}

class _FakeCartRepository implements CartRepository {
  final CartAddAck ackToReturn;
  final Object? error;

  int addToCartCalls = 0;
  String? lastGuestId;
  String? lastCachedCartId;
  String? lastCachedCartCurrencyCode;
  String? lastIdempotencyKey;
  int? lastQuantity;

  _FakeCartRepository({
    this.ackToReturn = const CartAddAck(
      cartId: 'cart-ack',
      entryProductId: 'prod-1',
      quantityDelta: 1,
      cartCreated: false,
    ),
    this.error,
  });

  @override
  Future<CartAddAck> addToCartAck({
    required String guestId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
    required String idempotencyKey,
    String? cachedCartId,
    String? cachedCartCurrencyCode,
  }) async {
    addToCartCalls += 1;
    lastGuestId = guestId;
    lastCachedCartId = cachedCartId;
    lastCachedCartCurrencyCode = cachedCartCurrencyCode;
    lastIdempotencyKey = idempotencyKey;
    lastQuantity = quantity;

    if (error != null) {
      throw error!;
    }

    return ackToReturn;
  }

  @override
  Future<Cart?> findActiveCartForGuest(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<Cart> createGuestCart({
    required String guestId,
    required String currencyCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CartView> getCartWithEntries(String cartId) {
    throw UnimplementedError();
  }

  @override
  Future<CartEntry?> findEntryForProduct({
    required String cartId,
    required String productId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CartEntry> addEntry({
    required String cartId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CartEntry> updateEntryQuantity({
    required CartEntry entry,
    required int quantity,
    double? unitPrice,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeEntry(String entryId) {
    throw UnimplementedError();
  }

  @override
  Future<CartView> clearCart(String cartId) {
    throw UnimplementedError();
  }

  @override
  Future<CartView> recomputeAndSaveTotals(String cartId) {
    throw UnimplementedError();
  }
}
