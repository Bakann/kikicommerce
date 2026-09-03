import '../../domain/cart/cart_entities.dart';
import 'cart_read_models.dart';
import 'cart_repository.dart';

class UpdateEntryQuantity {
  final CartRepository repository;

  const UpdateEntryQuantity(this.repository);

  Future<CartView> call({
    required CartEntry entry,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      await repository.removeEntry(entry.id);
    } else {
      await repository.updateEntryQuantity(entry: entry, quantity: quantity);
    }

    return repository.recomputeAndSaveTotals(entry.cartId);
  }
}
