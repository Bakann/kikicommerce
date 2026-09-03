import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../app/app_providers.dart';
import '../../application/cart/cart_read_models.dart';
import '../../data/local/cart_count_cache.dart';
import '../../domain/cart/cart_entities.dart';
import '../../domain/catalog/catalog_entities.dart';

final cartControllerProvider = AsyncNotifierProvider<CartController, CartView?>(
  CartController.new,
);

final _cartSyncingStateProvider = StateProvider<bool>((ref) => false);

final cartIsSyncingProvider = Provider<bool>((ref) {
  return ref.watch(_cartSyncingStateProvider);
});

final cartTopSheetOpenProvider = StateProvider<bool>((ref) => false);

final cartBackgroundSyncErrorProvider = StateProvider<CartBackgroundSyncError?>(
  (ref) => null,
);

final cartCountCacheProvider = Provider<CartCountCache>(
  (ref) => CartCountCache(),
);

final liveCartItemCountProvider = Provider<int?>((ref) {
  final cart = ref.watch(cartControllerProvider);
  // The count is "unknown" (null) only while the cart has never resolved —
  // the cached count may briefly cover that gap. Once it has resolved, the
  // value is authoritative even when it is null: an absent or empty cart
  // means zero items. Returning null here for a resolved-but-empty cart was
  // the bug behind a stale "1" badge persisting on a verified-empty cart at
  // startup. A foreground refresh keeps its previous value (hasValue), so the
  // badge doesn't flicker to unknown mid-sync.
  if (cart.isLoading && !cart.hasValue) {
    return null;
  }
  final view = cart.value;
  if (view == null) {
    return 0;
  }
  return view.entries.fold<int>(0, (total, entry) => total + entry.quantity);
});

class CartItemCountNotifier extends Notifier<int> {
  @override
  int build() {
    // Mirror the live cart count via `ref.watch` + `return`, NOT
    // `ref.listen` + `state = next`. The listener form mutated state
    // synchronously while the provider graph flushed during a first-time
    // `watch` inside a widget build — e.g. the nav cart badge mounting
    // (`top_navigation_bar` / account modal) — which threw "Tried to modify
    // a provider while the widget tree was building". Rebuilding this
    // notifier and returning the value is the safe, idiomatic path: when the
    // live count changes, build() re-runs and returns the new value instead
    // of poking state mid-flush.
    final liveCount = ref.watch(liveCartItemCountProvider);
    if (liveCount != null) {
      unawaited(ref.read(cartCountCacheProvider).write(liveCount));
      return liveCount;
    }

    // No live cart yet (cold start): fall back to the previous session's
    // cached count. Applied via a microtask so it never runs during build.
    Future.microtask(() async {
      if (ref.read(liveCartItemCountProvider) != null) return;
      final cached = await ref.read(cartCountCacheProvider).read();
      if (cached > 0 &&
          state == 0 &&
          ref.read(liveCartItemCountProvider) == null) {
        state = cached;
      }
    });

    return 0;
  }
}

final cartItemCountProvider = NotifierProvider<CartItemCountNotifier, int>(
  CartItemCountNotifier.new,
);

class CartBackgroundSyncError {
  final int id;
  final Object error;
  final StackTrace stackTrace;

  const CartBackgroundSyncError({
    required this.id,
    required this.error,
    required this.stackTrace,
  });
}

class CartController extends AsyncNotifier<CartView?> {
  Future<void> _operation = Future<void>.value();
  Future<void>? _prefetchOperation;
  final Set<int> _pendingSyncGenerations = <int>{};
  final Set<int> _activeForegroundTokens = <int>{};
  int _mutationGeneration = 0;
  int _errorEventId = 0;
  int _foregroundSyncToken = 0;

  @override
  Future<CartView?> build() async {
    ref.read(_cartSyncingStateProvider.notifier).state = false;
    ref.read(cartBackgroundSyncErrorProvider.notifier).state = null;
    return null;
  }

  Future<CartAddAck> addProduct({
    required CatalogProduct product,
    required CatalogPrice price,
    int quantity = 1,
  }) {
    return _runSerialized(() async {
      // Claim the mutation generation synchronously, before any await, so the
      // stale-write guard in [_backgroundResync] behaves consistently with
      // updateQuantity/removeEntry/refresh. Bumping after the ACK left a window
      // where a prior mutation's in-flight resync could still match the current
      // generation and overwrite this add.
      final generation = ++_mutationGeneration;
      try {
        final ack = await ref
            .read(addToCartProvider)
            .ackMinimal(product: product, price: price, quantity: quantity);
        state = AsyncValue.data(
          _applyOptimisticAdd(
            current: state.value,
            ack: ack,
            product: product,
            price: price,
          ),
        );
        ref.read(cartBackgroundSyncErrorProvider.notifier).state = null;
        unawaited(
          _backgroundResync(cartId: ack.cartId, generation: generation),
        );
        return ack;
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  Future<CartView> updateQuantity({
    required CartEntry entry,
    required int quantity,
  }) {
    return _runSerialized(() async {
      _mutationGeneration += 1;
      final token = _enterForegroundSync();
      try {
        final view = await ref.read(updateEntryQuantityProvider)(
          entry: entry,
          quantity: quantity,
        );
        state = AsyncValue.data(view);
        return view;
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(error, stackTrace);
      } finally {
        _exitForegroundSync(token);
      }
    });
  }

  Future<CartView> removeEntry(CartEntry entry) {
    return _runSerialized(() async {
      _mutationGeneration += 1;
      final token = _enterForegroundSync();
      try {
        final view = await ref.read(removeEntryProvider)(entry);
        state = AsyncValue.data(view);
        return view;
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(error, stackTrace);
      } finally {
        _exitForegroundSync(token);
      }
    });
  }

  Future<CartView?> clearCart() {
    return _runSerialized(() async {
      final current = state.value;
      if (current == null || current.entries.isEmpty) {
        return current;
      }

      _mutationGeneration += 1;
      final token = _enterForegroundSync();
      try {
        final view = await ref.read(clearCartProvider)(current);
        state = AsyncValue.data(view);
        return view;
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(error, stackTrace);
      } finally {
        _exitForegroundSync(token);
      }
    });
  }

  Future<CartView?> refresh() {
    return _runSerialized(() async {
      _mutationGeneration += 1;
      final token = _enterForegroundSync();
      try {
        final view = await ref.read(getActiveCartProvider)();
        state = AsyncValue.data(view);
        ref.read(cartBackgroundSyncErrorProvider.notifier).state = null;
        return view;
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(error, stackTrace);
      } finally {
        _exitForegroundSync(token);
      }
    });
  }

  int _enterForegroundSync() {
    // Surface the in-flight mutation via the syncing flag without wiping
    // the cart view, so consumers keep rendering the last known data.
    final token = ++_foregroundSyncToken;
    _activeForegroundTokens.add(token);
    _setSyncing(true);
    return token;
  }

  void _exitForegroundSync(int token) {
    _activeForegroundTokens.remove(token);
    if (_activeForegroundTokens.isEmpty && _pendingSyncGenerations.isEmpty) {
      _setSyncing(false);
    }
  }

  Future<void> prefetchActiveCart() {
    if (_prefetchOperation case final operation?) {
      return operation;
    }
    if (state.value != null || _pendingSyncGenerations.isNotEmpty) {
      return Future<void>.value();
    }

    final generation = _mutationGeneration;
    final operation = () async {
      try {
        final view = await ref.read(getActiveCartProvider)();
        if (view != null &&
            generation == _mutationGeneration &&
            state.value == null &&
            _pendingSyncGenerations.isEmpty) {
          state = AsyncValue.data(view);
        }
      } catch (_) {
        // Prefetch is best-effort. Keep the PDP interactive.
      } finally {
        _prefetchOperation = null;
      }
    }();

    _prefetchOperation = operation;
    return operation;
  }

  Future<T> _runSerialized<T>(Future<T> Function() action) {
    final run = _operation.then((_) => action());
    _operation = run.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return run;
  }

  CartView _applyOptimisticAdd({
    required CartView? current,
    required CartAddAck ack,
    required CatalogProduct product,
    required CatalogPrice price,
  }) {
    // When the server resolves a different cart than the one held locally
    // (e.g. a freshly created cart), the previous cart's entries do not
    // belong to it. Start from an empty list so the optimistic view only
    // contains the new line; the background resync then replaces this view
    // with authoritative server data.
    final isSameCart = current?.cart.id == ack.cartId;
    final currentEntries = List<CartEntry>.from(
      isSameCart ? (current?.entries ?? const []) : const <CartEntry>[],
    );
    final currentEntryIndex = currentEntries.indexWhere(
      (entry) => entry.productId == ack.entryProductId,
    );
    if (currentEntryIndex >= 0) {
      final existing = currentEntries[currentEntryIndex];
      final nextQuantity = existing.quantity + ack.quantityDelta;
      currentEntries[currentEntryIndex] = CartEntry(
        id: existing.id,
        cartId: existing.cartId,
        productId: existing.productId,
        productNameSnapshot: existing.productNameSnapshot,
        quantity: nextQuantity,
        unitPrice: price.price,
        lineTotal: price.price * nextQuantity,
        skuSnapshot: existing.skuSnapshot,
        created: existing.created,
        updated: existing.updated,
      );
    } else {
      currentEntries.add(
        CartEntry(
          id: 'optimistic-${ack.cartId}-${ack.entryProductId}',
          cartId: ack.cartId,
          productId: ack.entryProductId,
          productNameSnapshot: product.name,
          quantity: ack.quantityDelta,
          unitPrice: price.price,
          lineTotal: price.price * ack.quantityDelta,
          skuSnapshot: product.code,
        ),
      );
    }

    // Likewise, only the session-scoped guest/user identity carries over to
    // a different cart. Totals, status and timestamps belong to the previous
    // cart and must not leak into the new one.
    final cart = isSameCart
        ? current!.cart
        : Cart(
            id: ack.cartId,
            guestId: current?.cart.guestId,
            userId: current?.cart.userId,
            status: CartStatus.active,
            currencyCode:
                price.currencyCode ?? current?.cart.currencyCode ?? 'EUR',
          );

    return CartView(cart: cart, entries: currentEntries);
  }

  Future<void> _backgroundResync({
    required String cartId,
    required int generation,
  }) async {
    _pendingSyncGenerations.add(generation);
    _setSyncing(true);
    try {
      final view = await ref
          .read(cartRepositoryProvider)
          .recomputeAndSaveTotals(cartId);
      if (generation == _mutationGeneration) {
        state = AsyncValue.data(view);
      }
    } catch (error, stackTrace) {
      if (generation == _mutationGeneration) {
        ref
            .read(cartBackgroundSyncErrorProvider.notifier)
            .state = CartBackgroundSyncError(
          id: ++_errorEventId,
          error: error,
          stackTrace: stackTrace,
        );
      }
    } finally {
      _pendingSyncGenerations.remove(generation);
      if (_pendingSyncGenerations.isEmpty && _activeForegroundTokens.isEmpty) {
        _setSyncing(false);
      }
    }
  }

  void _setSyncing(bool isSyncing) {
    ref.read(_cartSyncingStateProvider.notifier).state = isSyncing;
  }
}
