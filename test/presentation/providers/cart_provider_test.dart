import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/cart/cart_guest_session_store.dart';
import 'package:kiki_commerce/application/cart/cart_read_models.dart';
import 'package:kiki_commerce/application/cart/cart_repository.dart';
import 'package:kiki_commerce/domain/cart/cart_entities.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/cart_provider.dart';

void main() {
  group('cartControllerProvider', () {
    test(
      'serializes concurrent addProduct calls without blocking loading state',
      () async {
        final repository = _RecordingCartRepository();
        final container = ProviderContainer(
          overrides: [
            cartRepositoryProvider.overrideWithValue(repository),
            guestSessionStoreProvider.overrideWithValue(
              _FakeGuestSessionStore(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final states = <AsyncValue<CartView?>>[];
        final subscription = container.listen(cartControllerProvider, (
          _,
          next,
        ) {
          states.add(next);
        });
        addTearDown(subscription.close);

        final controller = container.read(cartControllerProvider.notifier);
        await Future.wait([
          controller.addProduct(product: _product, price: _price),
          controller.addProduct(product: _product, price: _price),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 5));

        final state = container.read(cartControllerProvider).value!;
        expect(state.entries.single.quantity, 2);
        expect(states.any((state) => state.isLoading), isFalse);
        expect(repository.maxConcurrentAddWrites, 1);
        expect(repository.writeLog, ['add', 'update']);
        expect(container.read(cartItemCountProvider), 2);
      },
    );

    test('ignores a stale background resync result', () async {
      final repository = _RecordingCartRepository(deferRecompute: true);
      final container = ProviderContainer(
        overrides: [
          cartRepositoryProvider.overrideWithValue(repository),
          guestSessionStoreProvider.overrideWithValue(_FakeGuestSessionStore()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(cartControllerProvider.notifier);
      await controller.addProduct(product: _product, price: _price);
      expect(container.read(cartIsSyncingProvider), isTrue);
      expect(
        container.read(cartControllerProvider).value!.entries.single.quantity,
        1,
      );

      await controller.addProduct(product: _product, price: _price);
      expect(
        container.read(cartControllerProvider).value!.entries.single.quantity,
        2,
      );

      repository.completeRecompute(
        0,
        CartView(cart: _cart, entries: [_entry(quantity: 1)]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(
        container.read(cartControllerProvider).value!.entries.single.quantity,
        2,
      );
      expect(container.read(cartIsSyncingProvider), isTrue);

      repository.completeRecompute(
        1,
        CartView(cart: _cart, entries: [_entry(quantity: 2)]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(
        container.read(cartControllerProvider).value!.entries.single.quantity,
        2,
      );
      expect(container.read(cartIsSyncingProvider), isFalse);
    });

    test(
      'a failed background resync surfaces an error and keeps optimistic state',
      () async {
        final repository = _RecordingCartRepository(deferRecompute: true);
        final container = ProviderContainer(
          overrides: [
            cartRepositoryProvider.overrideWithValue(repository),
            guestSessionStoreProvider.overrideWithValue(
              _FakeGuestSessionStore(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(cartControllerProvider.notifier);
        await controller.addProduct(product: _product, price: _price);

        // Optimistic line is in place; the resync is still in flight.
        expect(
          container.read(cartControllerProvider).value!.entries.single.quantity,
          1,
        );
        expect(container.read(cartIsSyncingProvider), isTrue);
        expect(container.read(cartBackgroundSyncErrorProvider), isNull);

        final failure = Exception('resync boom');
        repository.failRecompute(0, failure);
        await Future<void>.delayed(const Duration(milliseconds: 1));

        // The failure is surfaced as a consumable event, not swallowed.
        final syncError = container.read(cartBackgroundSyncErrorProvider);
        expect(syncError, isNotNull);
        expect(syncError!.error, same(failure));
        // The syncing flag clears so the UI is not stuck in a spinner.
        expect(container.read(cartIsSyncingProvider), isFalse);
        // The optimistic line is preserved — a failed resync must not wipe it.
        expect(
          container.read(cartControllerProvider).value!.entries.single.quantity,
          1,
        );
      },
    );

    test(
      'a prior resync cannot overwrite a newer add still awaiting its ACK',
      () async {
        // Regression for the P0 race: _mutationGeneration must be claimed
        // synchronously at the start of addProduct, before awaiting the ACK.
        // Otherwise, while a second add is suspended inside ackMinimal (gen not
        // yet bumped), a first add's in-flight resync still matches the current
        // generation and clobbers the optimistic state with stale server data.
        final repository = _SuspendableCartRepository();
        final container = ProviderContainer(
          overrides: [
            cartRepositoryProvider.overrideWithValue(repository),
            guestSessionStoreProvider.overrideWithValue(
              _FakeGuestSessionStore(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(cartControllerProvider.notifier);

        // 1) First add starts and suspends on its ACK.
        final first = controller.addProduct(product: _product, price: _price);
        await _tick();
        expect(repository.ackCompleters, hasLength(1));

        // ACK resolves → optimistic line (qty 1) + background resync suspended.
        repository.completeAck(0, quantityDelta: 1);
        await first;
        expect(repository.recomputeCompleters, hasLength(1));
        expect(
          container.read(cartControllerProvider).value!.entries.single.quantity,
          1,
        );

        // 2) Second add starts (serialized) and suspends on its ACK. With the
        // fix, the generation is already bumped at this point.
        final second = controller.addProduct(product: _product, price: _price);
        await _tick();
        expect(repository.ackCompleters, hasLength(2));

        // 3) While the second ACK is still suspended, the first resync resolves
        // with a stale view (sentinel qty 99).
        repository.completeRecompute(
          0,
          CartView(cart: _cart, entries: [_entry(quantity: 99)]),
        );
        await _tick();

        // 4) The stale view must NOT overwrite the current optimistic state.
        expect(
          container.read(cartControllerProvider).value!.entries.single.quantity,
          1,
        );

        // 5) Release the second ACK and its resync; the final state reflects
        // the second add reconciled against authoritative server totals.
        repository.completeAck(1, quantityDelta: 1);
        await second;
        expect(
          container.read(cartControllerProvider).value!.entries.single.quantity,
          2,
        );
        repository.completeRecompute(
          1,
          CartView(cart: _cart, entries: [_entry(quantity: 2)]),
        );
        await _tick();
        expect(
          container.read(cartControllerProvider).value!.entries.single.quantity,
          2,
        );
      },
    );

    test(
      'optimistic add to a different cart does not inherit stale cart fields',
      () async {
        final repository = _SwitchingCartRepository();
        final container = ProviderContainer(
          overrides: [
            cartRepositoryProvider.overrideWithValue(repository),
            guestSessionStoreProvider.overrideWithValue(
              _FakeGuestSessionStore(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(cartControllerProvider.notifier);

        // Prime the controller with a pre-existing cart that carries
        // converted status, a non-EUR currency and non-zero totals.
        await controller.refresh();
        expect(container.read(cartControllerProvider).value!.cart.id, 'old');

        // The server resolves a freshly created cart. recomputeAndSaveTotals
        // never completes, so the optimistic view stays observable.
        await controller.addProduct(product: _product, price: _price);

        final optimistic = container.read(cartControllerProvider).value!;
        expect(optimistic.cart.id, 'new');
        expect(optimistic.cart.status, CartStatus.active);
        expect(optimistic.cart.currencyCode, 'EUR');
        expect(optimistic.cart.totals.grandTotal, 0);
        expect(optimistic.cart.created, isNull);
        // Session-scoped identity still carries over.
        expect(optimistic.cart.guestId, 'guest-1');
        // The previous cart's entries must not leak into the new cart: only
        // the freshly added optimistic line should be present.
        expect(optimistic.entries, hasLength(1));
        expect(optimistic.entries.single.productId, _product.id);
        expect(optimistic.entries.single.cartId, 'new');
      },
    );

    test(
      'clearCart removes the current entries and resets the item count',
      () async {
        final repository = _RecordingCartRepository();
        final container = ProviderContainer(
          overrides: [
            cartRepositoryProvider.overrideWithValue(repository),
            guestSessionStoreProvider.overrideWithValue(
              _FakeGuestSessionStore(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(cartControllerProvider.notifier);
        await controller.addProduct(product: _product, price: _price);
        expect(container.read(cartItemCountProvider), 1);

        await controller.clearCart();

        expect(container.read(cartControllerProvider).value!.entries, isEmpty);
        expect(container.read(cartItemCountProvider), 0);
        expect(container.read(cartIsSyncingProvider), isFalse);
        expect(repository.writeLog, ['add', 'clear']);
      },
    );
  });

  group('cartItemCountProvider', () {
    // Guards the `ref.watch` + `return` mirror (vs the old `ref.listen` +
    // `state =` form that threw "Tried to modify a provider while the widget
    // tree was building" when the nav cart badge first-watched this provider
    // during its build). Here we assert the resulting contract: the count
    // tracks the live cart, rebuilding rather than poking state.
    test('mirrors the live cart count and follows its changes', () async {
      final liveSeed = StateProvider<int?>((ref) => null);
      final container = ProviderContainer(
        overrides: [
          liveCartItemCountProvider.overrideWith((ref) => ref.watch(liveSeed)),
        ],
      );
      addTearDown(container.dispose);

      // No live cart yet → 0 (cache fallback resolves to 0 in tests).
      expect(container.read(cartItemCountProvider), 0);

      container.read(liveSeed.notifier).state = 2;
      await container.pump();
      expect(container.read(cartItemCountProvider), 2);

      container.read(liveSeed.notifier).state = 5;
      await container.pump();
      expect(container.read(cartItemCountProvider), 5);
    });

    test(
      'a resolved no-cart controller yields a count of 0, not null',
      () async {
        // Regression for the stale "1" badge at startup: the default controller
        // resolves to `null` (no active cart). A resolved empty/absent cart must
        // read as 0 so a previous session's cached count can't keep showing.
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container.read(cartControllerProvider.future);

        expect(container.read(liveCartItemCountProvider), 0);
        expect(container.read(cartItemCountProvider), 0);
      },
    );
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

class _FakeGuestSessionStore implements CartGuestSessionStore {
  CachedActiveCart? activeCart;

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

class _RecordingCartRepository implements CartRepository {
  CartEntry? entry;
  final bool deferRecompute;
  int _activeAddWrites = 0;
  int maxConcurrentAddWrites = 0;
  final writeLog = <String>[];
  final recomputeCompleters = <Completer<CartView>>[];

  _RecordingCartRepository({this.deferRecompute = false});

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
    final nextQuantity = (entry?.quantity ?? 0) + quantity;
    writeLog.add(entry == null ? 'add' : 'update');
    await _trackWrite(() async {
      entry = _entry(quantity: nextQuantity);
    });
    return CartAddAck(
      cartId: _cart.id,
      entryProductId: product.id,
      quantityDelta: quantity,
      cartCreated: false,
    );
  }

  @override
  Future<CartView> recomputeAndSaveTotals(String cartId) {
    if (!deferRecompute) {
      return Future<CartView>.value(CartView(cart: _cart, entries: [?entry]));
    }

    final completer = Completer<CartView>();
    recomputeCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<CartView> getCartWithEntries(String cartId) {
    throw UnimplementedError();
  }

  @override
  Future<Cart?> findActiveCartForGuest(String guestId) async => _cart;

  @override
  Future<Cart> createGuestCart({
    required String guestId,
    required String currencyCode,
  }) {
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
  Future<void> removeEntry(String entryId) async {
    writeLog.add('remove');
    await _trackWrite(() async {
      if (entry?.id == entryId) {
        entry = null;
      }
    });
  }

  @override
  Future<CartView> clearCart(String cartId) async {
    writeLog.add('clear');
    await _trackWrite(() async {
      entry = null;
    });
    return CartView(cart: _cart, entries: const []);
  }

  void completeRecompute(int index, CartView view) {
    final completer = recomputeCompleters[index];
    if (!completer.isCompleted) {
      completer.complete(view);
    }
  }

  void failRecompute(int index, Object error, [StackTrace? stackTrace]) {
    final completer = recomputeCompleters[index];
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace ?? StackTrace.current);
    }
  }

  Future<void> _trackWrite(Future<void> Function() write) async {
    _activeAddWrites += 1;
    if (_activeAddWrites > maxConcurrentAddWrites) {
      maxConcurrentAddWrites = _activeAddWrites;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await write();
    _activeAddWrites -= 1;
  }
}

const _cart = Cart(id: 'cart-1', guestId: 'guest-1', currencyCode: 'EUR');

const _staleCart = Cart(
  id: 'old',
  guestId: 'guest-1',
  currencyCode: 'USD',
  status: CartStatus.converted,
  totals: CartTotals(subtotal: 99, grandTotal: 99),
);

class _SwitchingCartRepository implements CartRepository {
  final recomputeCompleters = <Completer<CartView>>[];

  @override
  Future<Cart?> findActiveCartForGuest(String guestId) async => _staleCart;

  @override
  Future<CartView> getCartWithEntries(String cartId) async => const CartView(
    cart: _staleCart,
    entries: [
      CartEntry(
        id: 'stale-entry',
        cartId: 'old',
        productId: 'old-prod',
        productNameSnapshot: 'Ancien article',
        quantity: 3,
        unitPrice: 10,
        lineTotal: 30,
      ),
    ],
  );

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
    return CartAddAck(
      cartId: 'new',
      entryProductId: product.id,
      quantityDelta: quantity,
      cartCreated: true,
    );
  }

  @override
  Future<CartView> recomputeAndSaveTotals(String cartId) {
    final completer = Completer<CartView>();
    recomputeCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<Cart> createGuestCart({
    required String guestId,
    required String currencyCode,
  }) => throw UnimplementedError();

  @override
  Future<CartEntry?> findEntryForProduct({
    required String cartId,
    required String productId,
  }) => throw UnimplementedError();

  @override
  Future<CartEntry> addEntry({
    required String cartId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
  }) => throw UnimplementedError();

  @override
  Future<CartEntry> updateEntryQuantity({
    required CartEntry entry,
    required int quantity,
    double? unitPrice,
  }) => throw UnimplementedError();

  @override
  Future<void> removeEntry(String entryId) => throw UnimplementedError();

  @override
  Future<CartView> clearCart(String cartId) => throw UnimplementedError();
}

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 1));

/// Cart repository whose ACK and resync calls are both individually
/// suspendable, so a test can hold a second add inside ackMinimal while an
/// earlier resync resolves.
class _SuspendableCartRepository implements CartRepository {
  final ackCompleters = <Completer<CartAddAck>>[];
  final recomputeCompleters = <Completer<CartView>>[];

  void completeAck(int index, {required int quantityDelta}) {
    final completer = ackCompleters[index];
    if (!completer.isCompleted) {
      completer.complete(
        CartAddAck(
          cartId: _cart.id,
          entryProductId: _product.id,
          quantityDelta: quantityDelta,
          cartCreated: false,
        ),
      );
    }
  }

  void completeRecompute(int index, CartView view) {
    final completer = recomputeCompleters[index];
    if (!completer.isCompleted) {
      completer.complete(view);
    }
  }

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
    final completer = Completer<CartAddAck>();
    ackCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<CartView> recomputeAndSaveTotals(String cartId) {
    final completer = Completer<CartView>();
    recomputeCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<Cart?> findActiveCartForGuest(String guestId) async => _cart;

  @override
  Future<CartView> getCartWithEntries(String cartId) =>
      throw UnimplementedError();

  @override
  Future<Cart> createGuestCart({
    required String guestId,
    required String currencyCode,
  }) => throw UnimplementedError();

  @override
  Future<CartEntry?> findEntryForProduct({
    required String cartId,
    required String productId,
  }) => throw UnimplementedError();

  @override
  Future<CartEntry> addEntry({
    required String cartId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
  }) => throw UnimplementedError();

  @override
  Future<CartEntry> updateEntryQuantity({
    required CartEntry entry,
    required int quantity,
    double? unitPrice,
  }) => throw UnimplementedError();

  @override
  Future<void> removeEntry(String entryId) => throw UnimplementedError();

  @override
  Future<CartView> clearCart(String cartId) => throw UnimplementedError();
}

CartEntry _entry({required int quantity}) {
  return CartEntry(
    id: 'entry-1',
    cartId: 'cart-1',
    productId: 'prod-1',
    productNameSnapshot: 'Sac Totoro',
    quantity: quantity,
    unitPrice: 39,
    lineTotal: 39.0 * quantity,
  );
}
