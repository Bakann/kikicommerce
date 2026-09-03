import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/app/kiki_commerce_app.dart';
import 'package:kiki_commerce/application/cart/cart_guest_session_store.dart';
import 'package:kiki_commerce/application/cart/cart_read_models.dart';
import 'package:kiki_commerce/application/cart/cart_repository.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/catalog/product_catalog_repository.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/application/storefront/storefront_brand_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_navigation_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/domain/cart/cart_entities.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_page.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_route_page.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/floating_bottom_nav.dart';

import '../support/l10n_harness.dart';
import '../support/storefront_test_overrides.dart';

void main() {
  testWidgets('cart route renders the empty cart page', (tester) async {
    await _pumpApp(tester, CatalogRoutes.cart);
    await tester.pumpAndSettle();

    expect(find.text('Votre panier est vide.'), findsOneWidget);
  });

  testWidgets('cart route renders without transition when disabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pumpApp(tester, CatalogRoutes.cart);
    await tester.pump();

    expect(find.text('Votre panier est vide.'), findsOneWidget);
  });

  testWidgets('checkout route redirects to the access funnel', (tester) async {
    await _pumpApp(
      tester,
      CatalogRoutes.checkout,
      cartRepository: _FakeCartRepository.withCart(),
    );
    await tester.pumpAndSettle();

    // /checkout should NOT re-render the cart; it jumps to the
    // identification step.
    expect(find.text('Votre panier est vide.'), findsNothing);
    expect(
      find.text('Veuillez vous connecter ou continuer en tant qu’invité(e)'),
      findsOneWidget,
    );

    final router = GoRouter.of(
      tester.element(
        find.text('Veuillez vous connecter ou continuer en tant qu’invité(e)'),
      ),
    );
    expect(
      router.routeInformationProvider.value.uri.path,
      CatalogRoutes.checkoutAccess,
    );
  });

  testWidgets('checkout route forwards query params on redirect', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      '${CatalogRoutes.checkout}?email=test%40example.com',
      cartRepository: _FakeCartRepository.withCart(),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(
      tester.element(
        find.text('Veuillez vous connecter ou continuer en tant qu’invité(e)'),
      ),
    );
    final uri = router.routeInformationProvider.value.uri;
    expect(uri.path, CatalogRoutes.checkoutAccess);
    expect(uri.queryParameters['email'], 'test@example.com');
  });

  testWidgets('checkout access subroute renders as a normal route', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      CatalogRoutes.checkoutAccess,
      cartRepository: _FakeCartRepository.withCart(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Se connecter'), findsWidgets);
    expect(
      find.text('Veuillez vous connecter ou continuer en tant qu’invité(e)'),
      findsOneWidget,
    );
  });

  testWidgets('guest address subroute renders as a normal route', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      '${CatalogRoutes.checkoutGuestAddress}?email=test@example.com',
      cartRepository: _FakeCartRepository.withCart(),
    );
    await tester.pumpAndSettle();

    expect(find.text('1. Adresse de livraison'), findsOneWidget);
    expect(
      find.text('Veuillez saisir votre adresse de livraison :'),
      findsOneWidget,
    );
  });

  testWidgets('legacy public route redirects to the French canonical URL', (
    tester,
  ) async {
    await _pumpApp(tester, CatalogRoutes.productById('prod-1'));
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('Produit')));
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/fr/product?productId=prod-1',
    );
  });

  testWidgets('localized public route fetches catalog data in URL locale', (
    tester,
  ) async {
    final requestedLocales = <String>[];
    const category = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Summer',
      slug: 'summer',
    );

    await _pumpApp(
      tester,
      '/en/catalog/summer',
      categoryRepository: _FakeCategoryCatalogRepository(
        categories: const [category],
        requestedLocales: requestedLocales,
      ),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('Summer')));
    expect(
      router.routeInformationProvider.value.uri.path,
      '/en/catalog/summer',
    );
    expect(requestedLocales, contains('en'));
  });

  testWidgets('prefixed neutral cart keeps English session locale', (
    tester,
  ) async {
    await _pumpApp(tester, '/en/cart');
    await tester.pumpAndSettle();

    expect(find.text('Your cart is empty.'), findsOneWidget);
    final router = GoRouter.of(
      tester.element(find.text('Your cart is empty.')),
    );
    expect(router.routeInformationProvider.value.uri.path, CatalogRoutes.cart);

    await tester.tap(find.text('Continue shopping'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/en${CatalogRoutes.catalogBase}',
    );
  });

  testWidgets('navbar cart push opens cart and can return to previous route', (
    tester,
  ) async {
    await _pumpApp(tester, CatalogRoutes.catalogBase);
    await tester.pumpAndSettle();

    expect(find.text('Bientôt disponible'), findsOneWidget);
    // Public empty catalogue: no admin remediation CTA.
    expect(find.text('Ouvrir le backoffice'), findsNothing);
    expect(find.text('Importer des données'), findsNothing);

    await tester.tap(find.byTooltip('Panier'));
    await tester.pumpAndSettle();

    final router = GoRouter.of(
      tester.element(find.text('Votre panier est vide.')),
    );
    expect(router.routeInformationProvider.value.uri.path, CatalogRoutes.cart);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('Bientôt disponible'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr${CatalogRoutes.catalogBase}',
    );
  });

  testWidgets('sport bottom nav omits Acheter destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const catalog = CatalogCategory(
      id: 'catalog',
      code: 'CATALOG',
      name: 'Catalogue',
      slug: 'catalog',
      parentId: 'enfant',
    );
    const enfant = CatalogCategory(
      id: 'enfant',
      code: 'ENFANT',
      name: 'Enfant',
      slug: 'enfant',
    );

    await _pumpApp(
      tester,
      CatalogRoutes.home,
      categoryRepository: const _FakeCategoryCatalogRepository(
        defaultCategory: catalog,
        categories: [catalog, enfant],
      ),
      storefrontTheme: StorefrontTheme.nike,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(FloatingBottomNav.homeTileKey), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byKey(FloatingBottomNav.searchTileKey), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Panier'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Acheter'), findsNothing);
  });

  testWidgets('product slug route preserves ProductDetailRouteHint extra', (
    tester,
  ) async {
    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    final productRepository = _FakeProductCatalogRepository(
      detail: const ProductDetailData(
        product: CatalogProduct(
          id: 'prod-hint',
          code: 'PROD-HINT',
          name: 'Produit depuis hint',
        ),
        prices: [],
      ),
    );

    await _pumpApp(
      tester,
      CatalogRoutes.catalogBase,
      productRepository: productRepository,
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('Bientôt disponible')));
    router.go(
      '/fr/catalog/accessoires-totoro/produit-depuis-hint',
      extra: const ProductDetailRouteHint(
        productId: 'prod-hint',
        category: accessoires,
      ),
    );
    await tester.pumpAndSettle();

    expect(productRepository.requestedProductIds, ['prod-hint']);
    expect(find.text('Produit depuis hint'), findsOneWidget);
    expect(find.text('Accessoires Totoro'), findsWidgets);
  });

  testWidgets('product slug route ignores hint when category slug mismatches', (
    tester,
  ) async {
    const requestedCategory = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const wrongCategory = CatalogCategory(
      id: 'cat-wrong',
      code: 'CAT-WRONG',
      name: 'Mauvaise catégorie',
      slug: 'mauvaise-categorie',
    );
    final productRepository = _FakeProductCatalogRepository(
      detail: const ProductDetailData(
        product: CatalogProduct(
          id: 'resolved-prod',
          code: 'RESOLVED',
          name: 'Produit résolu',
        ),
        prices: [],
      ),
    );

    await _pumpApp(
      tester,
      CatalogRoutes.catalogBase,
      categoryRepository: const _FakeCategoryCatalogRepository(
        resolvedProductRoute: CatalogProductRouteData(
          category: requestedCategory,
          productId: 'resolved-prod',
          productSlug: 'produit-resolu',
        ),
      ),
      productRepository: productRepository,
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('Bientôt disponible')));
    router.go(
      '/fr/catalog/accessoires-totoro/produit-resolu',
      extra: const ProductDetailRouteHint(
        productId: 'hint-prod',
        category: wrongCategory,
      ),
    );
    await tester.pumpAndSettle();

    expect(productRepository.requestedProductIds, ['resolved-prod']);
    expect(find.text('Produit résolu'), findsOneWidget);
    expect(find.text('Mauvaise catégorie'), findsNothing);
  });

  testWidgets('product id route keeps URL productId over mismatched hint', (
    tester,
  ) async {
    final productRepository = _FakeProductCatalogRepository(
      detail: const ProductDetailData(
        product: CatalogProduct(
          id: 'url-prod',
          code: 'URL-PROD',
          name: 'Produit URL',
        ),
        prices: [],
      ),
    );

    await _pumpApp(
      tester,
      CatalogRoutes.catalogBase,
      productRepository: productRepository,
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('Bientôt disponible')));
    router.go(
      CatalogRoutes.localizedLocation(
        CatalogRoutes.productById('url-prod'),
        locale: 'fr',
      ),
      extra: const ProductDetailRouteHint(productId: 'hint-prod'),
    );
    await tester.pumpAndSettle();

    expect(productRepository.requestedProductIds, ['url-prod']);
    expect(find.text('Produit URL'), findsOneWidget);
  });

  testWidgets('PLP product card push opens PDP slug and back returns to PLP', (
    tester,
  ) async {
    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const product = CatalogProduct(
      id: 'prod-sac',
      code: 'PROD-SAC',
      name: 'Sac Totoro Nuage',
      slug: 'sac-totoro-nuage',
    );
    final productRepository = _FakeProductCatalogRepository(
      detail: const ProductDetailData(product: product, prices: []),
    );

    await _pumpApp(
      tester,
      '/catalog/accessoires-totoro',
      categoryRepository: const _FakeCategoryCatalogRepository(
        categories: [accessoires],
        pagesByCategoryId: {
          'cat-access': CatalogPageData(
            page: 1,
            perPage: 20,
            totalItems: 1,
            totalPages: 1,
            categoryId: 'cat-access',
            categoryName: 'Accessoires Totoro',
            category: accessoires,
            items: [
              CatalogListingItem(
                id: 'listing-sac',
                categoryId: 'cat-access',
                productId: 'prod-sac',
                product: product,
                productRouteSlug: 'sac-totoro-nuage',
                category: accessoires,
              ),
            ],
          ),
        },
      ),
      productRepository: productRepository,
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('Sac Totoro Nuage')));
    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/catalog/accessoires-totoro',
    );

    final productCardFinder = find.byKey(
      const ValueKey('product_card_prod-sac'),
    );
    await tester.ensureVisible(productCardFinder);
    await tester.pumpAndSettle();
    await tester.tap(productCardFinder);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/catalog/accessoires-totoro/sac-totoro-nuage',
    );
    expect(productRepository.requestedProductIds, ['prod-sac']);
    expect(find.text('Sac Totoro Nuage'), findsWidgets);

    router.pop();
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/catalog/accessoires-totoro',
    );
    expect(find.byKey(const ValueKey('product_card_prod-sac')), findsOneWidget);
  });

  testWidgets('pushed productId PDP back preserves the sport PLP history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 760));
    tester.view.physicalSize = const Size(430, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const running = CatalogCategory(
      id: 'cat-running',
      code: 'RUNNING',
      name: 'Running',
      slug: 'running',
    );
    const media = CatalogMedia(
      id: 'media-query',
      url: 'https://example.com/media-query.jpg',
      previewUrl: 'https://example.com/media-query-preview.jpg',
    );
    final productRepository = _FakeProductCatalogRepository(
      detail: const ProductDetailData(
        product: CatalogProduct(
          id: 'prod-query',
          code: 'PROD-QUERY',
          name: 'Produit query',
          summary:
              'Un produit technique pense pour les longues sessions. La coupe '
              'reste nette, la matiere garde sa tenue, et les details '
              'accompagnent le mouvement sans surcharge visuelle.',
          picture: media,
        ),
        prices: [
          CatalogPrice(
            id: 'price-query',
            productId: 'prod-query',
            price: 95,
            isDefault: true,
            currencySymbol: '€',
            currencyCode: 'EUR',
          ),
        ],
      ),
    );

    await _pumpApp(
      tester,
      '/sport/homme/running',
      categoryRepository: const _FakeCategoryCatalogRepository(
        categories: [running],
      ),
      productRepository: productRepository,
      storefrontTheme: StorefrontTheme.nike,
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('Running')));
    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/sport/homme/running',
    );

    router.push(
      CatalogRoutes.localizedLocation(
        CatalogRoutes.productById('prod-query'),
        locale: 'fr',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      CatalogRoutes.localizedLocation(
        CatalogRoutes.productById('prod-query'),
        locale: 'fr',
      ),
    );
    expect(productRepository.requestedProductIds, ['prod-query']);
    expect(find.text('Produit query'), findsOneWidget);
    expect(find.byKey(kPdpImageBackButtonKey), findsOneWidget);
    expect(_pdpImageBackButtonOpacity(tester), 1);

    await tester.tap(find.byKey(kPdpImageBackButtonKey));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/sport/homme/running',
    );
    expect(find.text('Running'), findsOneWidget);

    router.push(
      CatalogRoutes.localizedLocation(
        CatalogRoutes.productById('prod-query'),
        locale: 'fr',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(kPdpImageBackButtonKey), findsOneWidget);

    final scrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.maxScrollExtent > 0);
    final initialPixels = scrollable.position.pixels;
    await tester.drag(
      find.text('Ajouter au panier').last,
      const Offset(0, -520),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(scrollable.position.pixels, greaterThan(initialPixels + 390));
    expect(_pdpImageBackButtonOpacity(tester), 0);
  });

  testWidgets('cart and checkout back stack keeps the current sport PLP', (
    tester,
  ) async {
    const running = CatalogCategory(
      id: 'cat-running',
      code: 'RUNNING',
      name: 'Running',
      slug: 'running',
    );

    await _pumpApp(
      tester,
      '/sport/homme/running',
      cartRepository: _FakeCartRepository.withCart(),
      categoryRepository: const _FakeCategoryCatalogRepository(
        categories: [running],
      ),
      storefrontTheme: StorefrontTheme.nike,
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.text('Running')));
    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/sport/homme/running',
    );

    router.push(CatalogRoutes.cart);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, CatalogRoutes.cart);

    router.push(CatalogRoutes.checkout);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      CatalogRoutes.checkoutAccess,
    );

    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, CatalogRoutes.cart);

    router.pop();
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/sport/homme/running',
    );
    expect(find.text('Running'), findsOneWidget);
  });

  testWidgets('product slug route renders when route animations are disabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );

    await _pumpApp(
      tester,
      '/catalog/accessoires-totoro/sac-totoro-nuage',
      categoryRepository: const _FakeCategoryCatalogRepository(
        resolvedProductRoute: CatalogProductRouteData(
          category: accessoires,
          productId: 'prod-1',
          productSlug: 'sac-totoro-nuage',
        ),
      ),
      productRepository: _FakeProductCatalogRepository(
        detail: const ProductDetailData(
          product: CatalogProduct(
            id: 'prod-1',
            code: 'PROD-1',
            name: 'Sac Totoro Nuage',
          ),
          prices: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sac Totoro Nuage'), findsOneWidget);
  });

  testWidgets('sport category route inherits sport shell chrome outside edit', (
    tester,
  ) async {
    await _pumpApp(tester, '/sport/homme/summer-essentials');
    await tester.pumpAndSettle();

    expect(find.text('Page indisponible'), findsOneWidget);
    // Public visitors must never see admin remediation CTAs.
    expect(find.text('Créer la catégorie'), findsNothing);
    expect(find.text('Ouvrir le backoffice'), findsNothing);
    expect(find.text('Importer des données'), findsNothing);
    expect(find.byKey(FloatingBottomNav.homeTileKey), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byKey(FloatingBottomNav.searchTileKey), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Acheter'), findsNothing);
  });

  testWidgets('invalid sport segment redirect preserves the category slug', (
    tester,
  ) async {
    await _pumpApp(tester, '/sport/foo/summer-essentials');
    await tester.pumpAndSettle();

    // Unknown segment "foo" must fall back to "homme" WITHOUT dropping the
    // requested category, so the user still lands on the same PLP.
    final router = GoRouter.of(
      tester.element(find.byKey(FloatingBottomNav.homeTileKey)),
    );
    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/sport/homme/summer-essentials',
    );
  });

  testWidgets('sport category route exposes quick create in edit mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpApp(
      tester,
      '/sport/homme/summer-essentials',
      editMode: true,
      categoryRepository: const _FakeCategoryCatalogRepository(
        categories: [
          CatalogCategory(
            id: 'cat-homme',
            code: 'HOMME',
            name:
                'Homme - collection performance très longue pour tester le champ parent',
            slug: 'homme',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Cette tuile pointe vers une catégorie inexistante'),
      findsOneWidget,
    );
    expect(
      find.text(
        '/fr/sport/homme/summer-essentials ne correspond à aucune catégorie active.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sport'), findsOneWidget);
    expect(find.text('Homme'), findsOneWidget);
    expect(find.text('summer-essentials'), findsOneWidget);
    expect(find.text('Créer la catégorie'), findsOneWidget);
    expect(find.text('Ouvrir le backoffice'), findsOneWidget);

    await tester.tap(find.text('Créer la catégorie'));
    await tester.pumpAndSettle();

    expect(
      find.text('Les champs sont préremplis depuis la tuile cliquée.'),
      findsOneWidget,
    );
    expect(find.text('Summer Essentials'), findsOneWidget);
    expect(find.text('summer-essentials'), findsWidgets);
    expect(find.text('SPORT_HOMME_SUMMER_ESSENTIALS'), findsOneWidget);
    expect(find.text('Créer et ouvrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  String initialRoute, {
  CartRepository? cartRepository,
  CategoryCatalogRepository? categoryRepository,
  ProductCatalogRepository? productRepository,
  bool editMode = false,
  StorefrontTheme? storefrontTheme,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...localeOverrides(),
        if (editMode) editModeProvider.overrideWith((ref) => true),
        if (storefrontTheme != null)
          effectiveStorefrontThemeAsyncProvider.overrideWithValue(
            AsyncValue.data(storefrontTheme),
          ),
        storefrontBrandSettingsProvider.overrideWith(
          (ref) async => const StorefrontBrandSettings(
            id: 'settings-id',
            title: 'Atelier Kiki',
            href: '/',
          ),
        ),
        storefrontNavigationSettingsProvider.overrideWith(
          (ref) async => StorefrontNavigationSettings.fallback,
        ),
        ...storefrontNetworkTestOverrides(),
        drawerNavigationRepositoryProvider.overrideWithValue(
          const _FakeDrawerNavigationRepository(),
        ),
        guestSessionStoreProvider.overrideWithValue(
          const _FakeGuestSessionStore(),
        ),
        cartRepositoryProvider.overrideWithValue(
          cartRepository ?? const _FakeCartRepository.empty(),
        ),
        categoryCatalogRepositoryProvider.overrideWithValue(
          categoryRepository ?? const _FakeCategoryCatalogRepository(),
        ),
        productCatalogRepositoryProvider.overrideWithValue(
          productRepository ?? _FakeProductCatalogRepository(),
        ),
      ],
      child: KikiCommerceApp(initialRoute: initialRoute),
    ),
  );
}

double _pdpImageBackButtonOpacity(WidgetTester tester) {
  final opacityFinder = find.ancestor(
    of: find.byKey(kPdpImageBackButtonKey),
    matching: find.byType(AnimatedOpacity),
  );
  return tester.widget<AnimatedOpacity>(opacityFinder).opacity;
}

class _FakeDrawerNavigationRepository implements DrawerNavigationRepository {
  const _FakeDrawerNavigationRepository();

  @override
  Future<DrawerNavigationLoadResult> fetchMainDrawer({
    required String locale,
    bool includeHidden = false,
  }) async => const DrawerNavigationLoadResult.fallback(
    fallbackReason: DrawerNavigationFallbackReason.menuMissing,
  );
}

class _FakeGuestSessionStore implements CartGuestSessionStore {
  const _FakeGuestSessionStore();

  @override
  Future<void> clearActiveCart() async {}

  @override
  Future<void> clearGuestId() async {}

  @override
  Future<void> cacheActiveCart({
    required String cartId,
    required String currencyCode,
  }) async {}

  @override
  Future<String> ensureGuestId() async => 'guest-1';

  @override
  Future<CachedActiveCart?> peekActiveCart() async => null;

  @override
  Future<String?> peekGuestId() async => 'guest-1';
}

class _FakeCartRepository implements CartRepository {
  final Cart? activeCart;

  const _FakeCartRepository.empty() : activeCart = null;

  const _FakeCartRepository.withCart()
    : activeCart = const Cart(
        id: 'cart-1',
        guestId: 'guest-1',
        currencyCode: 'EUR',
      );

  @override
  Future<CartAddAck> addToCartAck({
    required String guestId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
    required String idempotencyKey,
    String? cachedCartId,
    String? cachedCartCurrencyCode,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CartEntry> addEntry({
    required String cartId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Cart> createGuestCart({
    required String guestId,
    required String currencyCode,
  }) async {
    return Cart(id: 'cart-1', guestId: guestId, currencyCode: currencyCode);
  }

  @override
  Future<Cart?> findActiveCartForGuest(String guestId) async => activeCart;

  @override
  Future<CartEntry?> findEntryForProduct({
    required String cartId,
    required String productId,
  }) async {
    return null;
  }

  @override
  Future<CartView> getCartWithEntries(String cartId) async {
    return CartView(cart: activeCart!, entries: const []);
  }

  @override
  Future<void> removeEntry(String entryId) async {}

  @override
  Future<CartView> clearCart(String cartId) async {
    return getCartWithEntries(cartId);
  }

  @override
  Future<CartView> recomputeAndSaveTotals(String cartId) async {
    return getCartWithEntries(cartId);
  }

  @override
  Future<CartEntry> updateEntryQuantity({
    required CartEntry entry,
    required int quantity,
    double? unitPrice,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeCategoryCatalogRepository implements CategoryCatalogRepository {
  final CatalogProductRouteData? resolvedProductRoute;
  final CatalogCategory? defaultCategory;
  final List<CatalogCategory> categories;
  final Map<String, CatalogPageData> pagesByCategoryId;
  final List<String>? requestedLocales;

  const _FakeCategoryCatalogRepository({
    this.resolvedProductRoute,
    this.defaultCategory,
    this.categories = const [],
    this.pagesByCategoryId = const {},
    this.requestedLocales,
  });

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async {
    requestedLocales?.add(locale);
    return categories;
  }

  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async {
    requestedLocales?.add(locale);
    for (final category in categories) {
      if (category.slug == slug) {
        return category;
      }
    }
    return null;
  }

  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async {
    requestedLocales?.add(locale);
    final injectedPage = pagesByCategoryId[categoryId];
    if (injectedPage != null) {
      return injectedPage;
    }

    CatalogCategory? category;
    for (final candidate in categories) {
      if (candidate.id == categoryId || candidate.slug == categoryId) {
        category = candidate;
        break;
      }
    }
    return CatalogPageData(
      page: 1,
      perPage: 20,
      totalItems: 0,
      totalPages: 0,
      categoryId: category?.id ?? categoryId,
      categoryName: category?.name ?? 'Empty',
      category: category,
      items: [],
    );
  }

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async {
    requestedLocales?.add(locale);
    return defaultCategory;
  }

  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String locale,
    required String categorySlug,
    required String productSlug,
  }) async {
    requestedLocales?.add(locale);
    return resolvedProductRoute;
  }
}

class _FakeProductCatalogRepository implements ProductCatalogRepository {
  final ProductDetailData detail;
  final requestedProductIds = <String>[];

  _FakeProductCatalogRepository({
    this.detail = const ProductDetailData(
      product: CatalogProduct(id: 'prod-1', code: 'PROD-1', name: 'Produit'),
      prices: [],
    ),
  });

  @override
  Future<ProductDetailData> getProductDetail(
    String productId, {
    required String locale,
  }) async {
    requestedProductIds.add(productId);
    return detail;
  }
}
