enum CartStatus {
  active('active'),
  converted('converted'),
  abandoned('abandoned');

  final String value;

  const CartStatus(this.value);

  static CartStatus fromValue(String? value) {
    return CartStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => CartStatus.active,
    );
  }
}

class CartTotals {
  final double subtotal;
  final double discountTotal;
  final double shippingTotal;
  final double taxTotal;
  final double grandTotal;

  const CartTotals({
    this.subtotal = 0,
    this.discountTotal = 0,
    this.shippingTotal = 0,
    this.taxTotal = 0,
    this.grandTotal = 0,
  });

  CartTotals copyWith({
    double? subtotal,
    double? discountTotal,
    double? shippingTotal,
    double? taxTotal,
    double? grandTotal,
  }) {
    return CartTotals(
      subtotal: subtotal ?? this.subtotal,
      discountTotal: discountTotal ?? this.discountTotal,
      shippingTotal: shippingTotal ?? this.shippingTotal,
      taxTotal: taxTotal ?? this.taxTotal,
      grandTotal: grandTotal ?? this.grandTotal,
    );
  }
}

class Cart {
  final String id;
  final String? userId;
  final String? guestId;
  final CartStatus status;
  final String currencyCode;
  final CartTotals totals;
  final DateTime? created;
  final DateTime? updated;

  const Cart({
    required this.id,
    required this.currencyCode,
    this.userId,
    this.guestId,
    this.status = CartStatus.active,
    this.totals = const CartTotals(),
    this.created,
    this.updated,
  });

  Cart copyWith({
    String? id,
    String? userId,
    String? guestId,
    CartStatus? status,
    String? currencyCode,
    CartTotals? totals,
    DateTime? created,
    DateTime? updated,
  }) {
    return Cart(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      guestId: guestId ?? this.guestId,
      status: status ?? this.status,
      currencyCode: currencyCode ?? this.currencyCode,
      totals: totals ?? this.totals,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }
}

class CartEntry {
  final String id;
  final String cartId;
  final String productId;
  final String? skuSnapshot;
  final String productNameSnapshot;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final DateTime? created;
  final DateTime? updated;

  const CartEntry({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.productNameSnapshot,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.skuSnapshot,
    this.created,
    this.updated,
  });
}
