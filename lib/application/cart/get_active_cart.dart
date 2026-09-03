import '../../core/error/app_exception.dart';
import 'cart_guest_session_store.dart';
import 'cart_read_models.dart';
import 'cart_repository.dart';

class GetActiveCart {
  final CartRepository repository;
  final CartGuestSessionStore guestSessionStore;

  const GetActiveCart(this.repository, this.guestSessionStore);

  Future<CartView?> call() async {
    final cachedCart = await guestSessionStore.peekActiveCart();
    if (cachedCart != null) {
      try {
        return await repository.getCartWithEntries(cachedCart.cartId);
      } on ApiException catch (error) {
        if (error.statusCode == 400 || error.statusCode == 404) {
          await guestSessionStore.clearActiveCart();
        } else {
          rethrow;
        }
      }
    }

    final guestId = await guestSessionStore.peekGuestId();
    if (guestId == null || guestId.isEmpty) {
      return null;
    }

    final cart = await repository.findActiveCartForGuest(guestId);
    if (cart == null) {
      await guestSessionStore.clearActiveCart();
      return null;
    }

    await guestSessionStore.cacheActiveCart(
      cartId: cart.id,
      currencyCode: cart.currencyCode,
    );
    return repository.getCartWithEntries(cart.id);
  }
}
