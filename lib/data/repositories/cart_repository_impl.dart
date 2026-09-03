import '../../application/cart/cart_read_models.dart';
import '../../application/cart/cart_repository.dart';
import '../../core/error/app_exception.dart';
import '../../core/utils/pocketbase_filter_utils.dart';
import '../../domain/cart/cart_entities.dart';
import '../../domain/cart/cart_exceptions.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../api/pocketbase_client.dart';
import '../models/cart.dart';
import '../models/cart_entry.dart';

class PocketBaseCartRepository implements CartRepository {
  static const int entriesPerPage = 200;
  static const String _addItemPath = '/api/cart/add-item';
  static const String _clearCartPath = '/api/cart/clear';
  static const String _currencyMismatchCode = 'cart_currency_mismatch';
  static const Set<String> _routeMissingCodes = {
    'not_found',
    'route_not_found',
  };

  final PocketBaseClient client;
  final Future<String> Function() guestIdProvider;
  final bool useAddItemEndpoint;

  const PocketBaseCartRepository({
    required this.client,
    required this.guestIdProvider,
    this.useAddItemEndpoint = false,
  });

  @override
  Future<CartAddAck> addToCartAck({
    required String guestId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
    required String idempotencyKey,
    String? cachedCartId,
    String? cachedCartCurrencyCode,
  }) async {
    if (useAddItemEndpoint) {
      try {
        return await _addToCartAckEndpoint(
          guestId: guestId,
          product: product,
          price: price,
          quantity: quantity,
          idempotencyKey: idempotencyKey,
        );
      } on ApiException catch (error, stackTrace) {
        final mapped = _mapEndpointApiException(error, price);
        if (mapped != null) {
          Error.throwWithStackTrace(mapped, stackTrace);
        }
        if (!_shouldFallbackToLegacy(error)) {
          rethrow;
        }
      }
    }

    return _addToCartAckLegacy(
      guestId: guestId,
      product: product,
      price: price,
      quantity: quantity,
      cachedCartId: cachedCartId,
      cachedCartCurrencyCode: cachedCartCurrencyCode,
    );
  }

  @override
  Future<Cart?> findActiveCartForGuest(String guestId) async {
    final response = await client.listRecords<CartRecord>(
      'carts',
      filter: 'guest_id="${escapeFilterValue(guestId)}" && status="active"',
      page: 1,
      perPage: 1,
      cartGuestId: guestId,
      fromJson: CartRecord.fromJson,
    );

    if (response.items.isEmpty) {
      return null;
    }

    return response.items.first.toDomain();
  }

  @override
  Future<Cart> createGuestCart({
    required String guestId,
    required String currencyCode,
  }) async {
    try {
      final json = await client.createRecord('carts', {
        'guest_id': guestId,
        'status': CartStatus.active.value,
        'currency_code': currencyCode,
        'subtotal': 0,
        'discount_total': 0,
        'shipping_total': 0,
        'tax_total': 0,
        'grand_total': 0,
      }, cartGuestId: guestId);
      return CartRecord.fromJson(json).toDomain();
    } on ApiException catch (error, stackTrace) {
      if (error.statusCode == 400) {
        throw CartConflictException(error, stackTrace);
      }
      rethrow;
    }
  }

  @override
  Future<CartView> getCartWithEntries(String cartId) async {
    final guestId = await guestIdProvider();
    final cart = await _getCart(cartId, guestId: guestId);
    final entries = await _listAllEntries(cartId, guestId: guestId);
    return CartView(cart: cart, entries: entries);
  }

  @override
  Future<CartEntry?> findEntryForProduct({
    required String cartId,
    required String productId,
  }) async {
    final guestId = await guestIdProvider();
    final response = await client.listRecords<CartEntryRecord>(
      'cart_entries',
      filter:
          'cart="${escapeFilterValue(cartId)}" && product="${escapeFilterValue(productId)}"',
      page: 1,
      perPage: 1,
      cartGuestId: guestId,
      fromJson: CartEntryRecord.fromJson,
    );

    if (response.items.isEmpty) {
      return null;
    }

    return response.items.first.toDomain();
  }

  @override
  Future<CartEntry> addEntry({
    required String cartId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
  }) async {
    try {
      final json = await client.createRecord('cart_entries', {
        'cart': cartId,
        'product': product.id,
        'sku_snapshot': product.code,
        'product_name_snapshot': product.name,
        'quantity': quantity,
        'unit_price': price.price,
        'line_total': price.price * quantity,
      }, cartGuestId: await guestIdProvider());
      return CartEntryRecord.fromJson(json).toDomain();
    } on ApiException catch (error, stackTrace) {
      if (error.statusCode == 400) {
        throw CartConflictException(error, stackTrace);
      }
      rethrow;
    }
  }

  @override
  Future<CartEntry> updateEntryQuantity({
    required CartEntry entry,
    required int quantity,
    double? unitPrice,
  }) async {
    final resolvedUnitPrice = unitPrice ?? entry.unitPrice;
    final json = await client.updateRecord('cart_entries', entry.id, {
      'quantity': quantity,
      'unit_price': resolvedUnitPrice,
      'line_total': resolvedUnitPrice * quantity,
    }, cartGuestId: await guestIdProvider());
    return CartEntryRecord.fromJson(json).toDomain();
  }

  @override
  Future<void> removeEntry(String entryId) async {
    await client.deleteRecord(
      'cart_entries',
      entryId,
      cartGuestId: await guestIdProvider(),
    );
  }

  @override
  Future<CartView> clearCart(String cartId) async {
    final guestId = await guestIdProvider();
    try {
      return await _clearCartEndpoint(cartId: cartId, guestId: guestId);
    } on ApiException catch (error) {
      if (!_shouldFallbackToLegacy(error)) {
        rethrow;
      }
    }

    final entries = await _listAllEntries(cartId, guestId: guestId);
    for (final entry in entries) {
      await client.deleteRecord('cart_entries', entry.id, cartGuestId: guestId);
    }
    return recomputeAndSaveTotals(cartId);
  }

  @override
  Future<CartView> recomputeAndSaveTotals(String cartId) async {
    final guestId = await guestIdProvider();
    final currentCart = await _getCart(cartId, guestId: guestId);
    final entries = await _listAllEntries(cartId, guestId: guestId);
    final subtotal = entries.fold<double>(
      0,
      (total, entry) => total + entry.lineTotal,
    );
    final totals = currentCart.totals;
    final grandTotal =
        subtotal +
        totals.taxTotal +
        totals.shippingTotal -
        totals.discountTotal;

    final json = await client.updateRecord('carts', cartId, {
      'subtotal': subtotal,
      'grand_total': grandTotal,
    }, cartGuestId: guestId);
    return CartView(
      cart: CartRecord.fromJson(json).toDomain(),
      entries: entries,
    );
  }

  Future<CartAddAck> _addToCartAckEndpoint({
    required String guestId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
    required String idempotencyKey,
  }) async {
    final json = await client.sendJson(
      'POST',
      _addItemPath,
      body: {
        'productId': product.id,
        'priceId': price.id,
        'quantity': quantity,
      },
      cartGuestId: guestId,
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );

    return _parseAckJson(json);
  }

  Future<CartView> _clearCartEndpoint({
    required String cartId,
    required String guestId,
  }) async {
    final json = await client.sendJson(
      'POST',
      _clearCartPath,
      body: {'cartId': cartId},
      cartGuestId: guestId,
    );

    final cartJson = json['cart'];
    final entriesJson = json['entries'];
    if (cartJson is! Map<String, dynamic> || entriesJson is! List) {
      throw ApiException(
        'Invalid clear-cart response',
        statusCode: 500,
        data: json,
      );
    }

    final entries = entriesJson.map((entryJson) {
      if (entryJson is! Map<String, dynamic>) {
        throw ApiException(
          'Invalid clear-cart entry response',
          statusCode: 500,
          data: json,
        );
      }
      return CartEntryRecord.fromJson(entryJson).toDomain();
    }).toList();

    return CartView(
      cart: CartRecord.fromJson(cartJson).toDomain(),
      entries: entries,
    );
  }

  Future<CartAddAck> _addToCartAckLegacy({
    required String guestId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
    String? cachedCartId,
    String? cachedCartCurrencyCode,
  }) async {
    final currencyCode = price.currencyCode!;
    final cachedAck = await _tryAckFromCachedCart(
      product: product,
      price: price,
      quantity: quantity,
      currencyCode: currencyCode,
      cachedCartId: cachedCartId,
      cachedCartCurrencyCode: cachedCartCurrencyCode,
    );
    if (cachedAck != null) {
      return cachedAck;
    }

    final cartResolution = await _resolveCart(
      guestId: guestId,
      currencyCode: currencyCode,
    );
    final cart = cartResolution.cart;

    if (cart.currencyCode != currencyCode) {
      throw CurrencyMismatchException(
        cartCurrencyCode: cart.currencyCode,
        priceCurrencyCode: currencyCode,
      );
    }

    await _upsertEntry(
      cartId: cart.id,
      product: product,
      price: price,
      quantity: quantity,
    );

    return CartAddAck(
      cartId: cart.id,
      entryProductId: product.id,
      quantityDelta: quantity,
      cartCreated: cartResolution.cartCreated,
    );
  }

  Future<CartAddAck?> _tryAckFromCachedCart({
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
    required String currencyCode,
    String? cachedCartId,
    String? cachedCartCurrencyCode,
  }) async {
    if (cachedCartId == null ||
        cachedCartId.isEmpty ||
        cachedCartCurrencyCode == null ||
        cachedCartCurrencyCode.isEmpty) {
      return null;
    }

    if (cachedCartCurrencyCode != currencyCode) {
      return null;
    }

    try {
      await _upsertEntry(
        cartId: cachedCartId,
        product: product,
        price: price,
        quantity: quantity,
      );
      return CartAddAck(
        cartId: cachedCartId,
        entryProductId: product.id,
        quantityDelta: quantity,
        cartCreated: false,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<_ResolvedCart> _resolveCart({
    required String guestId,
    required String currencyCode,
  }) async {
    final existing = await findActiveCartForGuest(guestId);
    if (existing != null) {
      return _ResolvedCart(cart: existing, cartCreated: false);
    }

    try {
      final created = await createGuestCart(
        guestId: guestId,
        currencyCode: currencyCode,
      );
      return _ResolvedCart(cart: created, cartCreated: true);
    } on CartConflictException catch (error) {
      final concurrent = await findActiveCartForGuest(guestId);
      if (concurrent != null) {
        return _ResolvedCart(cart: concurrent, cartCreated: false);
      }
      _rethrowCause(error);
    }
  }

  Future<void> _upsertEntry({
    required String cartId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
  }) async {
    final existing = await findEntryForProduct(
      cartId: cartId,
      productId: product.id,
    );
    if (existing != null) {
      await updateEntryQuantity(
        entry: existing,
        quantity: existing.quantity + quantity,
        unitPrice: price.price,
      );
      return;
    }

    try {
      await addEntry(
        cartId: cartId,
        product: product,
        price: price,
        quantity: quantity,
      );
    } on CartConflictException catch (error) {
      final concurrent = await findEntryForProduct(
        cartId: cartId,
        productId: product.id,
      );
      if (concurrent != null) {
        await updateEntryQuantity(
          entry: concurrent,
          quantity: concurrent.quantity + quantity,
          unitPrice: price.price,
        );
        return;
      }
      _rethrowCause(error);
    }
  }

  CartAddAck _parseAckJson(Map<String, dynamic> json) {
    final cartId = json['cartId'] as String?;
    final entryProductId = json['entryProductId'] as String?;
    final quantityDelta = switch (json['quantityDelta']) {
      final int value => value,
      final num value => value.toInt(),
      _ => null,
    };
    final cartCreated = json['cartCreated'];

    if (cartId == null ||
        cartId.isEmpty ||
        entryProductId == null ||
        entryProductId.isEmpty ||
        quantityDelta == null ||
        cartCreated is! bool) {
      throw ApiException(
        'Invalid add-to-cart ack response',
        statusCode: 500,
        data: json,
      );
    }

    return CartAddAck(
      cartId: cartId,
      entryProductId: entryProductId,
      quantityDelta: quantityDelta,
      cartCreated: cartCreated,
    );
  }

  Object? _mapEndpointApiException(ApiException error, CatalogPrice price) {
    if (error.statusCode != 409 || error.code != _currencyMismatchCode) {
      return null;
    }

    return CurrencyMismatchException(
      cartCurrencyCode:
          _readErrorString(error, 'cartCurrencyCode') ?? 'unknown',
      priceCurrencyCode:
          _readErrorString(error, 'priceCurrencyCode') ??
          price.currencyCode ??
          'unknown',
    );
  }

  String? _readErrorString(ApiException error, String key) {
    final data = error.data;
    if (data is! Map<Object?, Object?>) {
      return null;
    }

    final direct = data[key];
    if (direct is String && direct.isNotEmpty) {
      return direct;
    }

    final nested = data['data'];
    if (nested is Map<Object?, Object?>) {
      final nestedValue = nested[key];
      if (nestedValue is String && nestedValue.isNotEmpty) {
        return nestedValue;
      }
    }

    return null;
  }

  bool _shouldFallbackToLegacy(ApiException error) {
    final statusCode = error.statusCode;
    if (statusCode == 405 || statusCode == 501) {
      return true;
    }
    if (statusCode != 404) {
      return false;
    }

    final code = error.code;
    return code == null || _routeMissingCodes.contains(code);
  }

  Future<Cart> _getCart(String cartId, {required String guestId}) async {
    final json = await client.getRecord('carts', cartId, cartGuestId: guestId);
    return CartRecord.fromJson(json).toDomain();
  }

  Future<List<CartEntry>> _listAllEntries(
    String cartId, {
    required String guestId,
  }) async {
    final entries = <CartEntry>[];
    var page = 1;
    while (true) {
      final response = await client.listRecords<CartEntryRecord>(
        'cart_entries',
        filter: 'cart="${escapeFilterValue(cartId)}"',
        sort: 'created',
        page: page,
        perPage: entriesPerPage,
        cartGuestId: guestId,
        fromJson: CartEntryRecord.fromJson,
      );

      entries.addAll(response.items.map((entry) => entry.toDomain()));
      if (page >= response.totalPages ||
          response.items.length < entriesPerPage) {
        break;
      }
      page += 1;
    }
    return entries;
  }

  Never _rethrowCause(CartConflictException error) {
    Error.throwWithStackTrace(
      error.cause,
      error.stackTrace ?? StackTrace.current,
    );
  }
}

class _ResolvedCart {
  final Cart cart;
  final bool cartCreated;

  const _ResolvedCart({required this.cart, required this.cartCreated});
}
