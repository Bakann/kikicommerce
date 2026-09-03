import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/l10n/app_localizations.dart';
import 'package:kiki_commerce/presentation/l10n/l10n_extension.dart';
import 'package:kiki_commerce/presentation/providers/content_locale_provider.dart';
import 'package:kiki_commerce/presentation/providers/locale_provider.dart';
import 'package:kiki_commerce/presentation/widgets/drawer/category_drawer_widgets.dart';

import '../support/l10n_harness.dart';

/// Minimal app whose MaterialApp locale is driven by [localeProvider], used to
/// prove switching the provider re-localizes the tree without a restart.
class _LocaleProbeApp extends ConsumerWidget {
  const _LocaleProbeApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) => Text(context.l10n.navSearchHint)),
    );
  }
}

void main() {
  testWidgets('renders French by default', (tester) async {
    final container = ProviderContainer(overrides: localeOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _LocaleProbeApp(),
      ),
    );

    expect(find.text('Que recherchez-vous ?'), findsOneWidget);
    expect(find.text('What are you looking for?'), findsNothing);
  });

  testWidgets('renders English when the locale is en', (tester) async {
    final container = ProviderContainer(
      overrides: localeOverrides(const Locale('en')),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _LocaleProbeApp(),
      ),
    );

    expect(find.text('What are you looking for?'), findsOneWidget);
    expect(find.text('Que recherchez-vous ?'), findsNothing);
  });

  testWidgets(
    'switching locale via the provider re-localizes without restart',
    (tester) async {
      final container = ProviderContainer(overrides: localeOverrides());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _LocaleProbeApp(),
        ),
      );
      expect(find.text('Que recherchez-vous ?'), findsOneWidget);

      await container
          .read(localeProvider.notifier)
          .setLocale(const Locale('en'));
      await tester.pumpAndSettle();

      expect(find.text('What are you looking for?'), findsOneWidget);
      expect(find.text('Que recherchez-vous ?'), findsNothing);
    },
  );

  test('resolveAppLocale falls back to French for unsupported locales', () {
    expect(
      resolveAppLocale(const Locale('de'), kSupportedLocales),
      kFallbackLocale,
    );
    expect(resolveAppLocale(null, kSupportedLocales), kFallbackLocale);
    expect(
      resolveAppLocale(const Locale('en'), kSupportedLocales),
      const Locale('en'),
    );
    expect(
      resolveAppLocale(const Locale('fr'), kSupportedLocales),
      const Locale('fr'),
    );
  });

  testWidgets('drawer language switcher updates the locale provider', (
    tester,
  ) async {
    // Seed null so we can observe the explicit choice the switcher records.
    final container = ProviderContainer(
      overrides: [
        appLocaleStoreProvider.overrideWithValue(FakeAppLocaleStore()),
        localeProvider.overrideWith(LocaleController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: const Scaffold(body: DrawerLanguageSwitcher()),
        ),
      ),
    );

    expect(container.read(localeProvider), isNull);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(localeProvider), const Locale('en'));
  });

  testWidgets('drawer language switcher rewrites localized public URL', (
    tester,
  ) async {
    final router = _switcherRouter('/fr/catalog/foo');
    addTearDown(router.dispose);
    final container = _switcherContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _LocaleSwitcherRouterApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(localeProvider), const Locale('en'));
    expect(container.read(urlLocaleOverrideProvider), const Locale('en'));
    expect(router.routeInformationProvider.value.uri.path, '/en/catalog/foo');
  });

  testWidgets('drawer language switcher keeps neutral routes unprefixed', (
    tester,
  ) async {
    final router = _switcherRouter(CatalogRoutes.cart);
    addTearDown(router.dispose);
    final container = _switcherContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _LocaleSwitcherRouterApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(localeProvider), const Locale('en'));
    expect(router.routeInformationProvider.value.uri.path, CatalogRoutes.cart);
  });

  test('LocaleController normalizes unsupported locales to French', () async {
    final container = ProviderContainer(
      overrides: [
        appLocaleStoreProvider.overrideWithValue(FakeAppLocaleStore()),
        localeProvider.overrideWith(LocaleController.new),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(localeProvider.notifier);
    await controller.setLocale(const Locale('de'));
    expect(container.read(localeProvider), kFallbackLocale);

    await controller.setLocale(const Locale('en'));
    expect(container.read(localeProvider), const Locale('en'));

    await controller.useDeviceLocale();
    expect(container.read(localeProvider), isNull);
  });
}

ProviderContainer _switcherContainer() {
  return ProviderContainer(
    overrides: [
      appLocaleStoreProvider.overrideWithValue(
        FakeAppLocaleStore(const Locale('fr')),
      ),
      localeProvider.overrideWith(
        () => LocaleController(seeded: const Locale('fr')),
      ),
      contentLocaleProvider.overrideWith(
        () => ContentLocaleController(seeded: 'fr'),
      ),
    ],
  );
}

GoRouter _switcherRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/fr/catalog/:slug',
        builder: (context, state) =>
            const Scaffold(body: DrawerLanguageSwitcher()),
      ),
      GoRoute(
        path: '/en/catalog/:slug',
        builder: (context, state) =>
            const Scaffold(body: DrawerLanguageSwitcher()),
      ),
      GoRoute(
        path: CatalogRoutes.cart,
        builder: (context, state) =>
            const Scaffold(body: DrawerLanguageSwitcher()),
      ),
    ],
  );
}

class _LocaleSwitcherRouterApp extends ConsumerWidget {
  final GoRouter router;

  const _LocaleSwitcherRouterApp({required this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      locale: ref.watch(effectiveLocaleProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
