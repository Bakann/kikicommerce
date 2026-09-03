class MissingCurrencyException implements Exception {
  final String productId;

  const MissingCurrencyException(this.productId);

  @override
  String toString() => 'Missing currency for product $productId.';
}

class CurrencyMismatchException implements Exception {
  final String cartCurrencyCode;
  final String priceCurrencyCode;

  const CurrencyMismatchException({
    required this.cartCurrencyCode,
    required this.priceCurrencyCode,
  });

  @override
  String toString() {
    return 'Cart currency $cartCurrencyCode does not match price currency $priceCurrencyCode.';
  }
}

class CartConflictException implements Exception {
  final Object cause;
  final StackTrace? stackTrace;

  const CartConflictException(this.cause, [this.stackTrace]);

  @override
  String toString() => 'Cart conflict: $cause';
}
