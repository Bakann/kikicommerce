import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../presentation/providers/content_locale_provider.dart';
import '../presentation/providers/locale_provider.dart';
import 'app_router.dart';
import 'locale_route_resolver.dart';

class CustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class KikiCommerceApp extends ConsumerStatefulWidget {
  final String? initialRoute;
  final AppRouter appRouter;

  const KikiCommerceApp({
    super.key,
    this.initialRoute,
    this.appRouter = const AppRouter(),
  });

  @override
  ConsumerState<KikiCommerceApp> createState() => _KikiCommerceAppState();
}

class _KikiCommerceAppState extends ConsumerState<KikiCommerceApp> {
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = widget.appRouter.createRouter(
      initialLocation: widget.initialRoute,
    );
    _scheduleRouteLocaleSync(
      _initialRouteUri(widget.initialRoute) ?? _currentUri,
    );
    _router.routeInformationProvider.addListener(_handleRouteChanged);
  }

  @override
  void didUpdateWidget(covariant KikiCommerceApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The router is keyed on initialRoute/appRouter only; locale changes flow
    // through MaterialApp and must never recreate the router (it would drop the
    // navigation stack).
    if (oldWidget.initialRoute != widget.initialRoute ||
        oldWidget.appRouter != widget.appRouter) {
      _router.routeInformationProvider.removeListener(_handleRouteChanged);
      _router.dispose();
      _router = widget.appRouter.createRouter(
        initialLocation: widget.initialRoute,
      );
      _scheduleRouteLocaleSync(
        _initialRouteUri(widget.initialRoute) ?? _currentUri,
      );
      _router.routeInformationProvider.addListener(_handleRouteChanged);
    }
  }

  @override
  void dispose() {
    _router.routeInformationProvider.removeListener(_handleRouteChanged);
    _router.dispose();
    super.dispose();
  }

  Uri get _currentUri => _router.routeInformationProvider.value.uri;

  void _handleRouteChanged() {
    _scheduleRouteLocaleSync(_currentUri);
  }

  void _scheduleRouteLocaleSync(Uri uri) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyRouteLocale(uri);
    });
  }

  void _applyRouteLocale(Uri uri) {
    final currentOverride = ref.read(urlLocaleOverrideProvider);
    final persisted = ref.read(localeProvider);
    final resolution = resolveLocaleRoute(
      uri,
      sessionLocale: currentOverride?.languageCode,
      persistedLocale: persisted?.languageCode,
    );
    final nextOverride =
        resolution.urlLocale ??
        (resolution.isPublicLocalizedRoute ? resolution.effectiveLocale : null);
    if (nextOverride == null) return;

    ref.read(urlLocaleOverrideProvider.notifier).setLocale(nextOverride);
    ref.read(contentLocaleProvider.notifier).set(nextOverride.languageCode);
  }

  Locale? _routeLocaleForBuild(Locale? currentOverride, Locale? persisted) {
    final resolution = resolveLocaleRoute(
      _currentUri,
      sessionLocale: currentOverride?.languageCode,
      persistedLocale: persisted?.languageCode,
    );
    return resolution.urlLocale ??
        (resolution.isPublicLocalizedRoute ? resolution.effectiveLocale : null);
  }

  Uri? _initialRouteUri(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) return null;
    final uri = Uri.tryParse(routeName);
    if (uri == null) return null;

    final fragment = uri.fragment.trim();
    if ((uri.path.isEmpty || uri.path == '/') && fragment.isNotEmpty) {
      final normalizedFragment = fragment.startsWith('/')
          ? fragment
          : '/$fragment';
      return Uri.tryParse(normalizedFragment);
    }

    return uri;
  }

  @override
  Widget build(BuildContext context) {
    final currentOverride = ref.watch(urlLocaleOverrideProvider);
    final persisted = ref.watch(localeProvider);
    final locale =
        _routeLocaleForBuild(currentOverride, persisted) ??
        currentOverride ??
        persisted;
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Fall back to French for any unsupported device locale.
      localeResolutionCallback: resolveAppLocale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B3A5C)),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      scrollBehavior: CustomScrollBehavior(),
      // Mirror the locale MaterialApp resolved into contentLocaleProvider so the
      // data layer (catalog/CMS/nav) fetches the matching language. Mounted in
      // builder so `Localizations` is in scope.
      builder: (context, child) => ContentLocaleSync(child: child!),
      routerConfig: _router,
    );
  }
}
