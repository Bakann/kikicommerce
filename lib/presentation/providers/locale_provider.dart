import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/app_locale_store.dart';

/// Locales the storefront UI ships translations for. Single source of truth for
/// both `MaterialApp.supportedLocales` and locale normalization below.
const List<Locale> kSupportedLocales = [Locale('fr'), Locale('en')];

/// Language used when the device locale is not one we support.
const Locale kFallbackLocale = Locale('fr');

/// Resolves the locale `MaterialApp` should use for a given [deviceLocale],
/// falling back to French for anything outside [supportedLocales]. Used as the
/// app's `localeResolutionCallback` (the framework default would otherwise pick
/// the first supported locale, which is not necessarily French).
Locale resolveAppLocale(
  Locale? deviceLocale,
  Iterable<Locale> supportedLocales,
) {
  if (deviceLocale != null) {
    for (final supported in supportedLocales) {
      if (supported.languageCode == deviceLocale.languageCode) {
        return supported;
      }
    }
  }
  return kFallbackLocale;
}

Locale? supportedLocaleFromCode(String? code) {
  final normalized = code?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  final languageCode = normalized.split('-').first;
  for (final supported in kSupportedLocales) {
    if (supported.languageCode == languageCode) return supported;
  }
  return null;
}

/// Store for the persisted UI language choice. Overridable in tests.
final appLocaleStoreProvider = Provider<AppLocaleStore>(
  (ref) => SharedPreferencesAppLocaleStore(),
);

/// Holds the visitor's explicit UI language, or `null` to follow the device
/// locale (resolved by `MaterialApp` with a French fallback).
///
/// Seeded synchronously from the persisted value read before `runApp` (see
/// `main.dart`) so the first frame never flashes the wrong language.
class LocaleController extends Notifier<Locale?> {
  LocaleController({Locale? seeded}) : _seeded = seeded;

  final Locale? _seeded;

  @override
  Locale? build() => _seeded;

  /// Selects [locale], normalizing to a supported language, and persists it.
  Future<void> setLocale(Locale locale) async {
    final normalized = _normalize(locale);
    state = normalized;
    await ref.read(appLocaleStoreProvider).write(normalized);
  }

  /// Clears the explicit choice so the app follows the device locale again.
  Future<void> useDeviceLocale() async {
    state = null;
    await ref.read(appLocaleStoreProvider).clear();
  }

  Locale _normalize(Locale locale) =>
      supportedLocaleFromCode(locale.languageCode) ?? kFallbackLocale;
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

class UrlLocaleOverrideController extends Notifier<Locale?> {
  UrlLocaleOverrideController({Locale? seeded}) : _seeded = seeded;

  final Locale? _seeded;

  @override
  Locale? build() => _seeded;

  void setLocale(Locale? locale) {
    final normalized = locale == null
        ? null
        : supportedLocaleFromCode(locale.languageCode) ?? kFallbackLocale;
    if (state != normalized) state = normalized;
  }
}

final urlLocaleOverrideProvider =
    NotifierProvider<UrlLocaleOverrideController, Locale?>(
      UrlLocaleOverrideController.new,
    );

final effectiveLocaleProvider = Provider<Locale?>((ref) {
  return ref.watch(urlLocaleOverrideProvider) ?? ref.watch(localeProvider);
});
