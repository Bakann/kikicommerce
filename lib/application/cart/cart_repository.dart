import '../../domain/cart/cart_entities.dart';
import '../../domain/catalog/catalog_entities.dart';
import 'cart_read_models.dart';

abstract class CartRepository {
  Future<CartAddAck> addToCartAck({
    required String guestId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
    required String idempotencyKey,
    String? cachedCartId,
    String? cachedCartCurrencyCode,
  });

  Future<Cart?> findActiveCartForGuest(String guestId);

  Future<Cart> createGuestCart({
    required String guestId,
    required String currencyCode,
  });

  Future<CartView> getCartWithEntries(String cartId);

  Future<CartEntry?> findEntryForProduct({
    required String cartId,
    required String productId,
  });

  Future<CartEntry> addEntry({
    required String cartId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
  });

  Future<CartEntry> updateEntryQuantity({
    required CartEntry entry,
    required int quantity,
    double? unitPrice,
  });

  Future<void> removeEntry(String entryId);

  Future<CartView> clearCart(String cartId);

  Future<CartView> recomputeAndSaveTotals(String cartId);
}
