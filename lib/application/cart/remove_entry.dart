import '../../domain/cart/cart_entities.dart';
import 'cart_read_models.dart';
import 'cart_repository.dart';

class RemoveEntry {
  final CartRepository repository;

  const RemoveEntry(this.repository);

  Future<CartView> call(CartEntry entry) async {
    await repository.removeEntry(entry.id);
    return repository.recomputeAndSaveTotals(entry.cartId);
  }
}
