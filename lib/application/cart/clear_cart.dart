import 'cart_read_models.dart';
import 'cart_repository.dart';

class ClearCart {
  final CartRepository repository;

  const ClearCart(this.repository);

  Future<CartView> call(CartView cart) {
    return repository.clearCart(cart.cart.id);
  }
}
