class PriceRow {
  final String id;
  final String productId;
  final String currencyId;
  final double price;
  final String? unitId;
  final int? minqtd;
  final bool? net;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? channel;
  final bool isDefault;
  final bool isActive;

  // Expanded currency
  final String? currencySymbol;
  final String? currencyIsocode;

  PriceRow({
    required this.id,
    required this.productId,
    required this.currencyId,
    required this.price,
    this.unitId,
    this.minqtd,
    this.net,
    this.startTime,
    this.endTime,
    this.channel,
    this.isDefault = false,
    this.isActive = true,
    this.currencySymbol,
    this.currencyIsocode,
  });

  factory PriceRow.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? {};
    final currency = expand['currency'] as Map<String, dynamic>?;

    return PriceRow(
      id: json['id'] as String,
      productId: json['product'] as String,
      currencyId: json['currency'] as String,
      price: (json['price'] as num).toDouble(),
      unitId: json['unit'] as String?,
      minqtd: (json['minqtd'] as num?)?.toInt(),
      net: json['net'] as bool?,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'] as String)
          : null,
      channel: json['channel'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      currencySymbol: currency?['symbol'] as String?,
      currencyIsocode: currency?['isocode'] as String?,
    );
  }
}
