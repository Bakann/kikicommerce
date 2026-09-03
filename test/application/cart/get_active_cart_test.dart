import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cart/cart_guest_session_store.dart';
import 'package:kiki_commerce/application/cart/cart_read_models.dart';
import 'package:kiki_commerce/application/cart/cart_repository.dart';
import 'package:kiki_commerce/application/cart/get_active_cart.dart';
import 'package:kiki_commerce/domain/cart/cart_entities.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

void main() {
  group('GetActiveCart', () {
    test('uses the cached active cart id before guest cart lookup', () async {
      final repository = _FakeCartRepository();
      final guestSessionStore = _FakeGuestSessionStore(
        activeCart: const CachedActiveCart(
          cartId: 'cart-cached',
          currencyCode: 'EUR',
        ),
      );
      final useCase = GetActiveCart(repository, guestSessionStore);

      final view = await useCase();

      expect(view?.cart.id, 'cart-cached');
      expect(repository.findActiveCartCalls, 0);
      expect(repository.getCartWithEntriesCalls, ['cart-cached']);
    });

    test(
      'returns null without materializing a guest when nothing is cached',
      () async {
        final repository = _FakeCartRepository();
        final guestSessionStore = _FakeGuestSessionStore(
          persistedGuestId: null,
        );
        final useCase = GetActiveCart(repository, guestSessionStore);

        final view = await useCase();

        expect(view, isNull);
        expect(repository.findActiveCartCalls, 0);
        expect(guestSessionStore.ensureGuestIdCalls, 0);
      },
    );
  });
}

class _FakeGuestSessionStore implements CartGuestSessionStore {
  CachedActiveCart? activeCart;
  String? persistedGuestId;
  int ensureGuestIdCalls = 0;

  _FakeGuestSessionStore({this.activeCart, this.persistedGuestId = 'guest-1'});

  @override
  Future<void> clearGuestId() async {
    persistedGuestId = null;
  }

  @override
  Future<String> ensureGuestId() async {
    ensureGuestIdCalls += 1;
    return persistedGuestId ??= 'guest-1';
  }

  @override
  Future<String?> peekGuestId() async => persistedGuestId;

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
  int findActiveCartCalls = 0;
  final getCartWithEntriesCalls = <String>[];

  @override
  Future<CartAddAck> addToCartAck({
    required String guestId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
    required String idempotencyKey,
    String? cachedCartId,
    String? cachedCartCurrencyCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Cart?> findActiveCartForGuest(String guestId) async {
    findActiveCartCalls += 1;
    return const Cart(id: 'cart-1', guestId: 'guest-1', currencyCode: 'EUR');
  }

  @override
  Future<Cart> createGuestCart({
    required String guestId,
    required String currencyCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CartView> getCartWithEntries(String cartId) async {
    getCartWithEntriesCalls.add(cartId);
    return CartView(
      cart: Cart(id: cartId, guestId: 'guest-1', currencyCode: 'EUR'),
      entries: const [],
    );
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
