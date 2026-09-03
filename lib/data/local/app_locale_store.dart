import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Surfaces best-effort persistence failures in debug/test only; stays silent
/// in release so a flaky pref store never breaks the app.
void _debugReportLocaleStoreFailure(String action, Object error) {
  assert(() {
    debugPrint('AppLocaleStore $action failed: $error');
    return true;
  }());
}

const appLocaleStorageKey = 'app_locale_v1';

/// Persists the visitor's explicit UI language choice (FR/EN).
///
/// `null` means "no explicit choice" — the app then follows the device locale
/// (falling back to French). Mirrors [SharedPreferencesAsync] usage in
/// `last_sport_segment_store.dart`; persistence is best-effort and never throws.
abstract class AppLocaleStore {
  Future<Locale?> read();
  Future<void> write(Locale locale);
  Future<void> clear();
}

class SharedPreferencesAppLocaleStore implements AppLocaleStore {
  final SharedPreferencesAsync? _override;

  SharedPreferencesAppLocaleStore({SharedPreferencesAsync? preferences})
    : _override = preferences;

  SharedPreferencesAsync? _resolve() {
    if (_override != null) return _override;
    try {
      return SharedPreferencesAsync();
    } catch (error) {
      _debugReportLocaleStoreFailure('resolve', error);
      return null;
    }
  }

  @override
  Future<Locale?> read() async {
    final prefs = _resolve();
    if (prefs == null) return null;
    try {
      final value = await prefs.getString(appLocaleStorageKey);
      if (value == null || value.isEmpty) return null;
      return Locale(value);
    } catch (error) {
      _debugReportLocaleStoreFailure('read', error);
      return null;
    }
  }

  @override
  Future<void> write(Locale locale) async {
    final prefs = _resolve();
    if (prefs == null) return;
    try {
      await prefs.setString(appLocaleStorageKey, locale.languageCode);
    } catch (error) {
      // Best-effort persistence; never throw (surfaced in debug only).
      _debugReportLocaleStoreFailure('write', error);
    }
  }

  @override
  Future<void> clear() async {
    final prefs = _resolve();
    if (prefs == null) return;
    try {
      await prefs.remove(appLocaleStorageKey);
    } catch (error) {
      // Best-effort; never throw (surfaced in debug only).
      _debugReportLocaleStoreFailure('clear', error);
    }
  }
}
