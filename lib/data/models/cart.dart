import '../../domain/cart/cart_entities.dart';

class CartRecord {
  final String id;
  final String? userId;
  final String? guestId;
  final String status;
  final String currencyCode;
  final double subtotal;
  final double discountTotal;
  final double shippingTotal;
  final double taxTotal;
  final double grandTotal;
  final DateTime? created;
  final DateTime? updated;

  const CartRecord({
    required this.id,
    required this.currencyCode,
    this.userId,
    this.guestId,
    this.status = 'active',
    this.subtotal = 0,
    this.discountTotal = 0,
    this.shippingTotal = 0,
    this.taxTotal = 0,
    this.grandTotal = 0,
    this.created,
    this.updated,
  });

  factory CartRecord.fromJson(Map<String, dynamic> json) {
    return CartRecord(
      id: json['id'] as String,
      userId: _stringOrNull(json['user']),
      guestId: _stringOrNull(json['guest_id']),
      status: json['status'] as String? ?? 'active',
      currencyCode: json['currency_code'] as String? ?? 'EUR',
      subtotal: _doubleValue(json['subtotal']),
      discountTotal: _doubleValue(json['discount_total']),
      shippingTotal: _doubleValue(json['shipping_total']),
      taxTotal: _doubleValue(json['tax_total']),
      grandTotal: _doubleValue(json['grand_total']),
      created: _dateValue(json['created']),
      updated: _dateValue(json['updated']),
    );
  }

  Cart toDomain() {
    return Cart(
      id: id,
      userId: userId,
      guestId: guestId,
      status: CartStatus.fromValue(status),
      currencyCode: currencyCode,
      totals: CartTotals(
        subtotal: subtotal,
        discountTotal: discountTotal,
        shippingTotal: shippingTotal,
        taxTotal: taxTotal,
        grandTotal: grandTotal,
      ),
      created: created,
      updated: updated,
    );
  }
}

String? _stringOrNull(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

double _doubleValue(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return 0;
}

DateTime? _dateValue(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
