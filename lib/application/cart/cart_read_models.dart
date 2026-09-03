import '../../domain/cart/cart_entities.dart';

class CartAddAck {
  final String cartId;
  final String entryProductId;
  final int quantityDelta;
  final bool cartCreated;

  const CartAddAck({
    required this.cartId,
    required this.entryProductId,
    required this.quantityDelta,
    required this.cartCreated,
  });
}

class CartView {
  final Cart cart;
  final List<CartEntry> entries;

  const CartView({required this.cart, required this.entries});
}
