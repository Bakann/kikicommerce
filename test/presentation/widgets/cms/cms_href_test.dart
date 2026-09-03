import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/presentation/providers/product_providers.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/screens/product_list_page.dart';
import 'package:kiki_commerce/presentation/widgets/cms/cms_href.dart';

import '../../../support/l10n_harness.dart';

GoRouter _router(String href) {
  return GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Landing Page'),
                TextButton(
                  onPressed: () => launchCmsHref(context, href),
                  child: const Text('Open CMS tile'),
                ),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: CatalogRoutes.search,
        builder: (context, state) => const Scaffold(body: Text('Search Page')),
      ),
      GoRoute(
        path: '/fr${CatalogRoutes.search}',
        builder: (context, state) => const Scaffold(body: Text('Search Page')),
      ),
      // The PLP lives inside a ShellRoute while /start does not, mirroring the
      // real app (MainShell wraps /catalog/...).
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: CatalogRoutes.catalogBase,
            builder: (context, state) =>
                const Scaffold(body: Text('Catalog Root')),
          ),
          GoRoute(
            path: '/fr${CatalogRoutes.catalogBase}',
            builder: (context, state) =>
                const Scaffold(body: Text('Catalog Root')),
          ),
          GoRoute(
            path: '${CatalogRoutes.catalogBase}/:slug',
            builder: (context, state) => Scaffold(
              body: ProductListPage(categoryId: state.pathParameters['slug']!),
            ),
          ),
          GoRoute(
            path: '/fr${CatalogRoutes.catalogBase}/:slug',
            builder: (context, state) => Scaffold(
              body: ProductListPage(categoryId: state.pathParameters['slug']!),
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _harness(GoRouter router) {
  return ProviderScope(
    overrides: [
      effectiveStorefrontThemeAsyncProvider.overrideWithValue(
        const AsyncValue.data(StorefrontTheme.nike),
      ),
      plpProvider('shirts').overrideWith(
        (ref) async => const CatalogPageData(
          page: 1,
          perPage: 20,
          totalItems: 0,
          totalPages: 1,
          categoryId: 'shirts',
          categoryName: 'Shirts',
          items: [],
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      locale: const Locale('fr'),
    ),
  );
}

void main() {
  testWidgets('landing CMS tile pushes PLP so back returns to landing', (
    tester,
  ) async {
    final router = _router('/catalog/shirts');
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open CMS tile'));
    await tester.pumpAndSettle();

    // Pushed PLP is on top, and there is history to pop.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(router.canPop(), isTrue);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Back returns to the origin page, not /catalog (the witness "Catalog Root")
    // nor a parent category.
    expect(find.text('Landing Page'), findsOneWidget);
    expect(find.text('Catalog Root'), findsNothing);
  });

  testWidgets('non-catalog CMS links replace (no history to pop)', (
    tester,
  ) async {
    final router = _router(CatalogRoutes.search);
    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open CMS tile'));
    await tester.pumpAndSettle();

    expect(find.text('Search Page'), findsOneWidget);
    // `go` replaced the stack: there is nothing to pop back to.
    expect(router.canPop(), isFalse);
  });
}
