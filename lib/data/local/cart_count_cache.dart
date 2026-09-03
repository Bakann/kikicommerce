import 'package:shared_preferences/shared_preferences.dart';

const cartItemCountStorageKey = 'cart_item_count_v1';

class CartCountCache {
  final SharedPreferencesAsync? _override;

  CartCountCache({SharedPreferencesAsync? preferences})
    : _override = preferences;

  SharedPreferencesAsync? _resolve() {
    if (_override != null) return _override;
    try {
      return SharedPreferencesAsync();
    } catch (_) {
      return null;
    }
  }

  Future<int> read() async {
    final prefs = _resolve();
    if (prefs == null) return 0;
    try {
      return (await prefs.getInt(cartItemCountStorageKey)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> write(int value) async {
    final prefs = _resolve();
    if (prefs == null) return;
    try {
      await prefs.setInt(cartItemCountStorageKey, value);
    } catch (_) {
      // best-effort cache; never throw
    }
  }
}
