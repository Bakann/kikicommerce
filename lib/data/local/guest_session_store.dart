import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../application/cart/cart_guest_session_store.dart';

const guestCartIdStorageKey = 'guest_cart_id_v1';
const activeCartIdStorageKey = 'active_cart_id_v1';
const activeCartCurrencyCodeStorageKey = 'active_cart_currency_code_v1';

class GuestSessionStore implements CartGuestSessionStore {
  final SharedPreferencesAsync preferences;
  final Uuid uuid;

  GuestSessionStore({SharedPreferencesAsync? preferences, Uuid? uuid})
    : preferences = preferences ?? SharedPreferencesAsync(),
      uuid = uuid ?? const Uuid();

  @override
  Future<String> ensureGuestId() async {
    final existing = await peekGuestId();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final next = uuid.v4();
    await preferences.setString(guestCartIdStorageKey, next);
    return next;
  }

  @override
  Future<String?> peekGuestId() {
    return preferences.getString(guestCartIdStorageKey);
  }

  @override
  Future<CachedActiveCart?> peekActiveCart() async {
    final cartId = await preferences.getString(activeCartIdStorageKey);
    final currencyCode = await preferences.getString(
      activeCartCurrencyCodeStorageKey,
    );
    if (cartId == null ||
        cartId.isEmpty ||
        currencyCode == null ||
        currencyCode.isEmpty) {
      return null;
    }
    return CachedActiveCart(cartId: cartId, currencyCode: currencyCode);
  }

  @override
  Future<void> cacheActiveCart({
    required String cartId,
    required String currencyCode,
  }) async {
    await preferences.setString(activeCartIdStorageKey, cartId);
    await preferences.setString(activeCartCurrencyCodeStorageKey, currencyCode);
  }

  @override
  Future<void> clearActiveCart() async {
    await preferences.remove(activeCartIdStorageKey);
    await preferences.remove(activeCartCurrencyCodeStorageKey);
  }

  @override
  Future<void> clearGuestId() {
    return Future.wait<void>([
      preferences.remove(guestCartIdStorageKey),
      preferences.remove(activeCartIdStorageKey),
      preferences.remove(activeCartCurrencyCodeStorageKey),
    ]);
  }
}
