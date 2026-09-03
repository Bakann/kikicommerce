import 'package:uuid/uuid.dart';

import '../../domain/cart/cart_exceptions.dart';
import '../../domain/catalog/catalog_entities.dart';
import 'cart_guest_session_store.dart';
import 'cart_read_models.dart';
import 'cart_repository.dart';

typedef IdempotencyKeyFactory = String Function();

class AddToCart {
  final CartRepository repository;
  final CartGuestSessionStore guestSessionStore;
  final IdempotencyKeyFactory idempotencyKeyFactory;

  AddToCart(
    this.repository,
    this.guestSessionStore, {
    IdempotencyKeyFactory? idempotencyKeyFactory,
  }) : idempotencyKeyFactory =
           idempotencyKeyFactory ?? _defaultIdempotencyKeyFactory;

  Future<CartAddAck> ackMinimal({
    required CatalogProduct product,
    required CatalogPrice price,
    int quantity = 1,
  }) async {
    final currencyCode = price.currencyCode;
    if (currencyCode == null || currencyCode.trim().isEmpty) {
      throw MissingCurrencyException(product.id);
    }

    final guestId = await guestSessionStore.ensureGuestId();
    final cachedCart = await guestSessionStore.peekActiveCart();

    final ack = await repository.addToCartAck(
      guestId: guestId,
      product: product,
      price: price,
      quantity: quantity,
      idempotencyKey: idempotencyKeyFactory(),
      cachedCartId: cachedCart?.cartId,
      cachedCartCurrencyCode: cachedCart?.currencyCode,
    );

    await guestSessionStore.cacheActiveCart(
      cartId: ack.cartId,
      currencyCode: currencyCode,
    );
    return ack;
  }

  static String _defaultIdempotencyKeyFactory() => const Uuid().v4();
}
