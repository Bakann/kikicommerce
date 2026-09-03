import 'package:shared_preferences/shared_preferences.dart';

import '../../application/storefront/storefront_theme.dart';

const visitorStorefrontThemeStorageKey = 'visitor_storefront_theme_v1';

abstract class VisitorStorefrontThemeStore {
  Future<StorefrontTheme?> readOverride();
  Future<void> writeOverride(StorefrontTheme theme);
  Future<void> clearOverride();
}

class SharedPreferencesVisitorStorefrontThemeStore
    implements VisitorStorefrontThemeStore {
  final SharedPreferencesAsync preferences;

  SharedPreferencesVisitorStorefrontThemeStore({
    SharedPreferencesAsync? preferences,
  }) : preferences = preferences ?? SharedPreferencesAsync();

  @override
  Future<StorefrontTheme?> readOverride() async {
    try {
      final value = await preferences.getString(
        visitorStorefrontThemeStorageKey,
      );
      return StorefrontTheme.tryFromWireName(value);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeOverride(StorefrontTheme theme) {
    return preferences.setString(
      visitorStorefrontThemeStorageKey,
      theme.wireName,
    );
  }

  @override
  Future<void> clearOverride() {
    return preferences.remove(visitorStorefrontThemeStorageKey);
  }
}
