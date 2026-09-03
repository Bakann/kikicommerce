import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/kiki_commerce_app.dart';
import 'app/locale_route_resolver.dart';
import 'config/api_config.dart';
import 'data/local/app_locale_store.dart';
import 'presentation/providers/content_locale_provider.dart';
import 'presentation/providers/locale_provider.dart';

export 'app/kiki_commerce_app.dart' show KikiCommerceApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.assertMediaConfigured();
  usePathUrlStrategy();
  // Fonts are bundled under assets/google_fonts/; never fetch over the
  // network at runtime (the HTTP fetch causes a text reflow on web).
  GoogleFonts.config.allowRuntimeFetching = false;
  final criticalFonts = _warmCriticalFonts();
  // Read the persisted UI language before the first frame so the app never
  // flashes the wrong language on launch (notably on web).
  final storedLocale = await SharedPreferencesAppLocaleStore().read();
  final launchResolution = resolveLocaleRoute(
    Uri.base,
    persistedLocale: storedLocale?.languageCode,
  );
  final launchUrlOverride =
      launchResolution.urlLocale ??
      (launchResolution.isPublicLocalizedRoute
          ? launchResolution.effectiveLocale
          : null);
  final resolvedLaunchLocale = launchUrlOverride == null
      ? resolveAppLocale(
          storedLocale ?? WidgetsBinding.instance.platformDispatcher.locale,
          kSupportedLocales,
        )
      : launchResolution.effectiveLocale;
  // Resolve the launch locale and seed contentLocaleProvider so the first
  // catalog/CMS fetch already uses the right language instead of fetching FR
  // then re-fetching after sync.
  await _bestEffortFontWarmup(criticalFonts);
  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith(
          () => LocaleController(seeded: storedLocale),
        ),
        contentLocaleProvider.overrideWith(
          () => ContentLocaleController(
            seeded: resolvedLaunchLocale.languageCode,
          ),
        ),
        urlLocaleOverrideProvider.overrideWith(
          () => UrlLocaleOverrideController(seeded: launchUrlOverride),
        ),
      ],
      child: const KikiCommerceApp(),
    ),
  );
}

Future<void> _bestEffortFontWarmup(Future<void> warmup) async {
  try {
    await warmup.timeout(const Duration(milliseconds: 900));
  } catch (_) {
    // Font warm-up must never prevent the Flutter tree from mounting.
  }
}

Future<void> _warmCriticalFonts() async {
  final loader = FontLoader('CormorantGaramond')
    ..addFont(
      rootBundle.load('assets/google_fonts/CormorantGaramond-Regular.ttf'),
    )
    ..addFont(
      rootBundle.load('assets/google_fonts/CormorantGaramond-Medium.ttf'),
    );
  await loader.load();
}
