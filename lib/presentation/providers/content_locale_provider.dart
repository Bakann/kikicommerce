import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_provider.dart';

/// The resolved UI language code (`'fr'` / `'en'`) exposed to the data layer.
///
/// Data-layer providers (catalog, CMS, navigation) have no [BuildContext], so
/// they cannot call `Localizations.localeOf` themselves — and watching
/// [localeProvider] directly yields `null` whenever the visitor follows the
/// device locale. This holds the *resolved* code instead, kept current by
/// [ContentLocaleSync] and seeded in `main.dart` from the persisted/device
/// locale so the very first catalog/CMS fetch already uses the right language.
///
/// Reads here flow into both the `KikiCacheKeys.*(locale: ...)` axis and the
/// remote loader, so switching language re-keys every locale-aware read.
class ContentLocaleController extends Notifier<String> {
  ContentLocaleController({String? seeded}) : _seeded = seeded;

  final String? _seeded;

  @override
  String build() => _seeded ?? kFallbackLocale.languageCode;

  /// Mirrors the locale `MaterialApp` resolved. No-op when unchanged so a
  /// rebuild storm never fires on identical post-frame syncs.
  void set(String code) {
    if (state != code) state = code;
  }
}

final contentLocaleProvider = NotifierProvider<ContentLocaleController, String>(
  ContentLocaleController.new,
);

/// Mirrors the locale `MaterialApp` actually resolved into
/// [contentLocaleProvider].
///
/// Must be mounted inside `MaterialApp`'s `builder:` so the surrounding
/// `Localizations` widget is in scope. Reading `Localizations.localeOf(context)`
/// registers a dependency, so this rebuilds whenever the resolved locale
/// changes (explicit switch or device-locale change); the resolved code is
/// never `null` because `localeResolutionCallback` (`resolveAppLocale`) has
/// already run. The provider is written after the frame to avoid mutating it
/// during build.
class ContentLocaleSync extends ConsumerWidget {
  final Widget child;

  const ContentLocaleSync({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = Localizations.localeOf(context).languageCode;
    if (ref.read(contentLocaleProvider) != code) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(contentLocaleProvider.notifier).set(code);
        }
      });
    }
    return child;
  }
}
