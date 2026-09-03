import '../../domain/cart/cart_entities.dart';

class CartEntryRecord {
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

  const CartEntryRecord({
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

  factory CartEntryRecord.fromJson(Map<String, dynamic> json) {
    return CartEntryRecord(
      id: json['id'] as String,
      cartId: json['cart'] as String,
      productId: json['product'] as String,
      skuSnapshot: _stringOrNull(json['sku_snapshot']),
      productNameSnapshot: json['product_name_snapshot'] as String? ?? '',
      quantity: _intValue(json['quantity']),
      unitPrice: _doubleValue(json['unit_price']),
      lineTotal: _doubleValue(json['line_total']),
      created: _dateValue(json['created']),
      updated: _dateValue(json['updated']),
    );
  }

  CartEntry toDomain() {
    return CartEntry(
      id: id,
      cartId: cartId,
      productId: productId,
      skuSnapshot: skuSnapshot,
      productNameSnapshot: productNameSnapshot,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
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

int _intValue(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return 0;
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
