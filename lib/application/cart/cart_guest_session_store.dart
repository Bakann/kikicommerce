class CachedActiveCart {
  final String cartId;
  final String currencyCode;

  const CachedActiveCart({required this.cartId, required this.currencyCode});
}

abstract class CartGuestSessionStore {
  Future<String> ensureGuestId();

  Future<String?> peekGuestId();

  Future<CachedActiveCart?> peekActiveCart();

  Future<void> cacheActiveCart({
    required String cartId,
    required String currencyCode,
  });

  Future<void> clearActiveCart();

  Future<void> clearGuestId();
}
