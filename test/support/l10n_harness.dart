import 'package:flutter/widgets.dart';
// `Override` lives in the `riverpod` core package (a transitive dep brought in
// by flutter_riverpod, which `locale_provider.dart` depends on).
// ignore: depend_on_referenced_packages
import 'package:riverpod/misc.dart' show Override;
import 'package:kiki_commerce/data/local/app_locale_store.dart';
import 'package:kiki_commerce/l10n/app_localizations.dart';
import 'package:kiki_commerce/presentation/providers/locale_provider.dart';

/// Localization delegates to attach to a test's `MaterialApp`/`MaterialApp.router`
/// so widgets calling `context.l10n` resolve. Pair with [testSupportedLocales]
/// and `locale: const Locale('fr')` to keep existing French assertions green.
final List<LocalizationsDelegate<dynamic>> testLocalizationsDelegates =
    AppLocalizations.localizationsDelegates;

final List<Locale> testSupportedLocales = AppLocalizations.supportedLocales;

/// In-memory [AppLocaleStore] so tests never reach `SharedPreferencesAsync`
/// (which throws `MissingPluginException` without a platform binding).
class FakeAppLocaleStore implements AppLocaleStore {
  Locale? _locale;

  FakeAppLocaleStore([this._locale]);

  Locale? get current => _locale;

  @override
  Future<Locale?> read() async => _locale;

  @override
  Future<void> write(Locale locale) async => _locale = locale;

  @override
  Future<void> clear() async => _locale = null;
}

/// ProviderScope overrides that pin the UI language to [locale] (default `fr`)
/// and replace the persistence store with an in-memory fake. Spread into a
/// `ProviderScope(overrides: [...localeOverrides(), ...])` when pumping
/// `KikiCommerceApp` (or any tree that reads `localeProvider`).
List<Override> localeOverrides([Locale locale = const Locale('fr')]) => [
  appLocaleStoreProvider.overrideWithValue(FakeAppLocaleStore(locale)),
  localeProvider.overrideWith(() => LocaleController(seeded: locale)),
];
