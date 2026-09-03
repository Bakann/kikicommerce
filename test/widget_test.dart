import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/cart/cart_guest_session_store.dart';
import 'package:kiki_commerce/application/cart/cart_read_models.dart';
import 'package:kiki_commerce/application/cart/cart_repository.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/catalog/product_catalog_repository.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/domain/cart/cart_entities.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/main.dart';
import 'package:kiki_commerce/presentation/providers/content_locale_provider.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_cross_sells.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_route_page.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_page.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_price_block.dart';
import 'package:kiki_commerce/presentation/widgets/image_carousel.dart';
import 'package:kiki_commerce/presentation/widgets/kiki_image.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/top_navigation_bar.dart';
import 'package:kiki_commerce/presentation/widgets/pdp_purchase_bar.dart';
import 'package:kiki_commerce/presentation/widgets/product_hero_tags.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_layout.dart';

import 'support/l10n_harness.dart';
import 'support/storefront_test_overrides.dart';

void main() {
  void setMobileSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
  }

  void resetSurface(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  void setDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1.0;
  }

  void setSplitSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('Admin route renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: KikiCommerceApp(initialRoute: '/admin')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backoffice admin'), findsOneWidget);
    expect(find.text('Import CSV catalogue'), findsOneWidget);
  });

  testWidgets('Slug catalog route renders and drawer lists categories', (
    WidgetTester tester,
  ) async {
    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const deco = CatalogCategory(
      id: 'cat-deco',
      code: 'CAT-DECO',
      name: 'Décoration Château',
      slug: 'decoration-chateau',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires, deco],
              categoryBySlug: accessoires,
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 1,
                totalPages: 1,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [
                  CatalogListingItem(
                    id: 'cp-1',
                    categoryId: 'cat-access',
                    productId: 'prod-1',
                    category: accessoires,
                    product: CatalogProduct(
                      id: 'prod-1',
                      code: 'PROD-1',
                      name: 'Sac Totoro Nuage',
                    ),
                  ),
                ],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(),
          ),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Accessoires Totoro'), findsWidgets);
    expect(find.text('Sac Totoro Nuage'), findsOneWidget);

    await tester.tap(find.byTooltip('Ouvrir le menu').first);
    await tester.pumpAndSettle();

    expect(find.text('Décoration Château'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  });

  testWidgets('Product slug route renders PDP', (WidgetTester tester) async {
    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                ),
                prices: [],
              ),
            ),
          ),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sac Totoro Nuage'), findsOneWidget);
    expect(find.text('Accessoires Totoro'), findsWidgets);
  });

  testWidgets('Hash-style product slug route renders PDP', (
    WidgetTester tester,
  ) async {
    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                ),
                prices: [],
              ),
            ),
          ),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/#/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sac Totoro Nuage'), findsOneWidget);
    expect(find.text('Accessoires Totoro'), findsWidgets);
  });

  testWidgets('PDP category breadcrumb navigates to the category PLP', (
    WidgetTester tester,
  ) async {
    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 1,
                totalPages: 1,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [
                  CatalogListingItem(
                    id: 'cp-1',
                    categoryId: 'cat-access',
                    productId: 'prod-1',
                    category: accessoires,
                    product: CatalogProduct(
                      id: 'prod-1',
                      code: 'PROD-1',
                      name: 'Sac Totoro Nuage',
                    ),
                    productRouteSlug: 'sac-totoro-nuage',
                  ),
                ],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                ),
                prices: [],
              ),
            ),
          ),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Accessoires Totoro').first);
    await tester.pumpAndSettle();

    expect(find.text('Trier & Filtrer'), findsNothing);
    expect(find.byType(TopNavigationBar), findsOneWidget);
  });

  testWidgets('Product slug route redirects to canonical category', (
    WidgetTester tester,
  ) async {
    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
        ]),
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/catalog/decoration-chateau/sac-totoro-nuage',
            overridePlatformDefaultLocation: true,
            routes: [
              GoRoute(
                path: '/catalog/accessoires-totoro/sac-totoro-nuage',
                builder: (context, state) => const Scaffold(
                  body: Center(child: Text('canonical route')),
                ),
              ),
              GoRoute(
                path: '/catalog/:categorySlug/:productSlug',
                builder: (context, state) => ProductDetailRoutePage(
                  categorySlug: state.pathParameters['categorySlug']!,
                  productSlug: state.pathParameters['productSlug']!,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('canonical route'), findsOneWidget);
  });

  testWidgets('PDP edit mode exposes a semantic camera trigger', (
    WidgetTester tester,
  ) async {
    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media = CatalogMedia(
      id: 'media-1',
      url: 'https://example.com/media-1.jpg',
      previewUrl: 'https://example.com/media-1-preview.jpg',
    );

    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                  picture: media,
                ),
                prices: [],
              ),
            ),
          ),
          editModeProvider.overrideWith((ref) => true),
          adminAuthTokenProvider.overrideWith((ref) => 'test-token'),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(kProductImageEditorSemanticsLabel), findsOne);
    semantics.dispose();
  });

  testWidgets('PDP narrative mode syncs chapter copy with the active image', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media1 = CatalogMedia(
      id: 'media-1',
      url: 'https://example.com/media-1.jpg',
      previewUrl: 'https://example.com/media-1-preview.jpg',
    );
    const media2 = CatalogMedia(
      id: 'media-2',
      url: 'https://example.com/media-2.jpg',
      previewUrl: 'https://example.com/media-2-preview.jpg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'robe-kiki-vent',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Robe Kiki du vent',
                  slug: 'robe-kiki-vent',
                  productType: 'Robe',
                  summary: 'Une robe légère pour les jours de grand ciel.',
                  picture: media1,
                  gallery: [media2],
                ),
                prices: [
                  CatalogPrice(
                    id: 'price-1',
                    productId: 'prod-1',
                    price: 129,
                    isDefault: true,
                    currencySymbol: '€',
                    currencyCode: 'EUR',
                  ),
                ],
                chapters: [
                  NarrativeChapter(
                    id: 'chapter-1',
                    mediaId: 'media-1',
                    position: 1,
                    headline: 'Kiki prend son elan',
                    story: 'Le tissu suit le mouvement et ouvre la silhouette.',
                    ctaLabel: 'Zoom sur la robe',
                    ctaAction: NarrativeCtaAction.zoom,
                  ),
                  NarrativeChapter(
                    id: 'chapter-2',
                    mediaId: 'media-2',
                    position: 2,
                    headline: 'La robe accompagne le vol',
                    story: 'On lit mieux le tombé et la ligne du dos.',
                    ctaLabel: 'Details matiere',
                    ctaAction: NarrativeCtaAction.materialDetail,
                  ),
                ],
              ),
            ),
          ),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/robe-kiki-vent',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Kiki prend son elan'), findsOneWidget);
    expect(find.text('COMPLÉTEZ VOTRE LOOK'), findsNothing);
    expect(
      tester.widget<ImageCarousel>(find.byType(ImageCarousel)).imageFit,
      BoxFit.cover,
    );
    expect(
      tester.widget<ImageCarousel>(find.byType(ImageCarousel)).imageAlignment,
      Alignment.topCenter,
    );

    await tester.drag(find.byType(PageView), const Offset(-420, 0));
    await tester.pumpAndSettle();

    expect(find.text('La robe accompagne le vol'), findsOneWidget);
    expect(find.text('Description'), findsNothing);
    expect(
      find.bySemanticsLabel('Une robe légère pour les jours de grand ciel.'),
      findsOneWidget,
    );
    expect(find.text('Information Taille & Coupe'), findsOneWidget);
  });

  testWidgets('Desktop PDP uses stacked images with a sticky summary panel', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media1 = CatalogMedia(
      id: 'media-1',
      url: 'https://example.com/media-1.jpg',
      previewUrl: 'https://example.com/media-1-preview.jpg',
    );
    const media2 = CatalogMedia(
      id: 'media-2',
      url: 'https://example.com/media-2.jpg',
      previewUrl: 'https://example.com/media-2-preview.jpg',
    );
    const media3 = CatalogMedia(
      id: 'media-3',
      url: 'https://example.com/media-3.jpg',
      previewUrl: 'https://example.com/media-3-preview.jpg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                  picture: media1,
                  gallery: [media2, media3],
                ),
                prices: [],
              ),
            ),
          ),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(DesktopImageStack), findsOneWidget);
    expect(find.byType(StorefrontStickySidebar), findsOneWidget);
    expect(find.byType(StorefrontFullBleed), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('Desktop narrative PDP keeps a sticky narrative sidebar', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media1 = CatalogMedia(
      id: 'media-1',
      url: 'https://example.com/media-1.jpg',
      previewUrl: 'https://example.com/media-1-preview.jpg',
    );
    const media2 = CatalogMedia(
      id: 'media-2',
      url: 'https://example.com/media-2.jpg',
      previewUrl: 'https://example.com/media-2-preview.jpg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'robe-kiki-vent',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Robe Kiki du vent',
                  slug: 'robe-kiki-vent',
                  productType: 'Robe',
                  summary: 'Une robe légère pour les jours de grand ciel.',
                  picture: media1,
                  gallery: [media2],
                ),
                prices: [
                  CatalogPrice(
                    id: 'price-1',
                    productId: 'prod-1',
                    price: 129,
                    isDefault: true,
                    currencySymbol: '€',
                    currencyCode: 'EUR',
                  ),
                ],
                chapters: [
                  NarrativeChapter(
                    id: 'chapter-1',
                    mediaId: 'media-1',
                    position: 1,
                    headline: 'Kiki prend son elan',
                    story: 'Le tissu suit le mouvement et ouvre la silhouette.',
                    ctaLabel: 'Zoom sur la robe',
                    ctaAction: NarrativeCtaAction.zoom,
                  ),
                  NarrativeChapter(
                    id: 'chapter-2',
                    mediaId: 'media-2',
                    position: 2,
                    headline: 'La robe accompagne le vol',
                    story: 'On lit mieux le tombé et la ligne du dos.',
                    ctaLabel: 'Details matiere',
                    ctaAction: NarrativeCtaAction.materialDetail,
                  ),
                ],
              ),
            ),
          ),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/robe-kiki-vent',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(StorefrontStickySidebar), findsOneWidget);
    expect(find.byType(DesktopImageStack), findsOneWidget);
    expect(find.byType(StorefrontFullBleed), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets(
    'PDP Hero V1 wraps standard hero bodies and leaves narrative bodies untagged',
    (WidgetTester tester) async {
      setDesktopSurface(tester);
      addTearDown(() => resetSurface(tester));

      const accessoires = CatalogCategory(
        id: 'cat-access',
        code: 'CAT-ACCESS',
        name: 'Accessoires Totoro',
        slug: 'accessoires-totoro',
      );
      const media1 = CatalogMedia(
        id: 'media-1',
        url: 'https://example.com/media-1.jpg',
        previewUrl: 'https://example.com/media-1-preview.jpg',
      );
      const media2 = CatalogMedia(
        id: 'media-2',
        url: 'https://example.com/media-2.jpg',
        previewUrl: 'https://example.com/media-2-preview.jpg',
      );
      final productHero = find.byWidgetPredicate(
        (widget) =>
            widget is Hero && widget.tag == productImageHeroTag('prod-1'),
      );

      Future<void> pumpPdp({required bool narrative}) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: _withDrawerFallback([
              categoryCatalogRepositoryProvider.overrideWithValue(
                _FakeCategoryCatalogRepository(
                  defaultCategory: accessoires,
                  activeCategories: const [accessoires],
                  categoryBySlug: accessoires,
                  resolvedProductRoute: CatalogProductRouteData(
                    category: accessoires,
                    productId: 'prod-1',
                    productSlug: narrative
                        ? 'robe-kiki-vent'
                        : 'sac-totoro-nuage',
                  ),
                  pageData: const CatalogPageData(
                    page: 1,
                    perPage: 20,
                    totalItems: 0,
                    totalPages: 0,
                    categoryId: 'cat-access',
                    categoryName: 'Accessoires Totoro',
                    items: [],
                  ),
                ),
              ),
              productCatalogRepositoryProvider.overrideWithValue(
                _FakeProductCatalogRepository(
                  detail: ProductDetailData(
                    product: CatalogProduct(
                      id: 'prod-1',
                      code: 'PROD-1',
                      name: narrative
                          ? 'Robe Kiki du vent'
                          : 'Sac Totoro Nuage',
                      slug: narrative ? 'robe-kiki-vent' : 'sac-totoro-nuage',
                      productType: narrative ? 'Robe' : 'Accessoire',
                      summary: narrative
                          ? 'Une robe légère pour les jours de grand ciel.'
                          : null,
                      picture: media1,
                      gallery: const [media2],
                    ),
                    prices: const [],
                    // V1 scope: narrative PDPs intentionally do not receive
                    // the PLP->PDP product Hero until scroll-driven image
                    // behavior is designed separately.
                    chapters: narrative
                        ? const [
                            NarrativeChapter(
                              id: 'chapter-1',
                              mediaId: 'media-1',
                              position: 1,
                              headline: 'Kiki prend son elan',
                              story: 'Le tissu suit le mouvement.',
                            ),
                            NarrativeChapter(
                              id: 'chapter-2',
                              mediaId: 'media-2',
                              position: 2,
                              headline: 'La robe accompagne le vol',
                              story: 'On lit mieux le tombé.',
                            ),
                          ]
                        : const [],
                  ),
                ),
              ),
            ]),
            child: KikiCommerceApp(
              initialRoute: narrative
                  ? '/catalog/accessoires-totoro/robe-kiki-vent'
                  : '/catalog/accessoires-totoro/sac-totoro-nuage',
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpPdp(narrative: false);
      expect(find.byType(DesktopImageStack), findsOneWidget);
      expect(productHero, findsOneWidget);
      final productHeroRect = tester.getRect(productHero);
      expect(productHeroRect.height, greaterThan(0));
      expect(productHeroRect.top, lessThan(tester.view.physicalSize.height));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await pumpPdp(narrative: true);
      expect(find.text('Kiki prend son elan'), findsOneWidget);
      expect(find.byType(DesktopImageStack), findsOneWidget);
      expect(productHero, findsNothing);
    },
  );

  testWidgets(
    'Split PDP keeps image and details side by side without sticky desktop stack',
    (WidgetTester tester) async {
      setSplitSurface(tester);
      addTearDown(() => resetSurface(tester));

      const accessoires = CatalogCategory(
        id: 'cat-access',
        code: 'CAT-ACCESS',
        name: 'Accessoires Totoro',
        slug: 'accessoires-totoro',
      );
      const media1 = CatalogMedia(
        id: 'media-1',
        url: 'https://example.com/media-1.jpg',
        previewUrl: 'https://example.com/media-1-preview.jpg',
      );
      const media2 = CatalogMedia(
        id: 'media-2',
        url: 'https://example.com/media-2.jpg',
        previewUrl: 'https://example.com/media-2-preview.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _withDrawerFallback([
            categoryCatalogRepositoryProvider.overrideWithValue(
              _FakeCategoryCatalogRepository(
                defaultCategory: accessoires,
                activeCategories: const [accessoires],
                categoryBySlug: accessoires,
                resolvedProductRoute: const CatalogProductRouteData(
                  category: accessoires,
                  productId: 'prod-1',
                  productSlug: 'robe-kiki-vent',
                ),
                pageData: const CatalogPageData(
                  page: 1,
                  perPage: 20,
                  totalItems: 0,
                  totalPages: 0,
                  categoryId: 'cat-access',
                  categoryName: 'Accessoires Totoro',
                  items: [],
                ),
              ),
            ),
            productCatalogRepositoryProvider.overrideWithValue(
              _FakeProductCatalogRepository(
                detail: const ProductDetailData(
                  product: CatalogProduct(
                    id: 'prod-1',
                    code: 'PROD-1',
                    name: 'Robe Kiki du vent',
                    slug: 'robe-kiki-vent',
                    productType: 'Robe',
                    picture: media1,
                    gallery: [media2],
                  ),
                  prices: [
                    CatalogPrice(
                      id: 'price-1',
                      productId: 'prod-1',
                      price: 129,
                      isDefault: true,
                      currencySymbol: '€',
                      currencyCode: 'EUR',
                    ),
                  ],
                ),
              ),
            ),
          ]),
          child: const KikiCommerceApp(
            initialRoute: '/catalog/accessoires-totoro/robe-kiki-vent',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(StorefrontFullBleed), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(DesktopImageStack), findsNothing);
      expect(find.byType(StorefrontStickySidebar), findsNothing);
      expect(find.text('Ajouter au panier'), findsOneWidget);
    },
  );

  testWidgets('Mobile PDP renders the no-variant purchase section', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media1 = CatalogMedia(
      id: 'media-1',
      url: 'https://example.com/media-1.jpg',
      previewUrl: 'https://example.com/media-1-preview.jpg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                  gallery: [media1],
                ),
                prices: [
                  CatalogPrice(
                    id: 'price-1',
                    productId: 'prod-1',
                    price: 39,
                    isDefault: true,
                    currencySymbol: '€',
                    currencyCode: 'EUR',
                  ),
                ],
              ),
            ),
          ),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PdpPurchaseBar), findsOneWidget);
    expect(find.text('Ajouter au panier'), findsOneWidget);
    expect(find.text('Réserver en boutique'), findsOneWidget);
    expect(find.text('Sélectionnez votre taille'), findsNothing);
    expect(find.text('Guide des tailles'), findsNothing);
    expect(find.text('Description'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Aucune description détaillée n’est renseignée pour le moment.',
      ),
      findsOneWidget,
    );
    expect(find.text('Information Taille & Coupe'), findsOneWidget);
    expect(find.text('Livraison & Retours'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.search), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.person), findsOneWidget);
    expect(find.text('Accessoires Totoro'), findsWidgets);
    expect(
      tester.widget<ImageCarousel>(find.byType(ImageCarousel)).imageFit,
      BoxFit.contain,
    );
    expect(
      tester.widget<ImageCarousel>(find.byType(ImageCarousel)).imageAlignment,
      Alignment.center,
    );
    expect(find.byType(FloatingActionButton), findsNothing);

    final scrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.maxScrollExtent > 0);
    final initialPixels = scrollable.position.pixels;
    await tester.drag(find.byType(PdpPurchaseBar), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(initialPixels));
  });

  testWidgets('Mobile PDP renders related and recently viewed cross-sells', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media2 = CatalogMedia(
      id: 'media-2',
      url: 'https://example.com/media-2.jpg',
      previewUrl: 'https://example.com/media-2-preview.jpg',
    );
    const media3 = CatalogMedia(
      id: 'media-3',
      url: 'https://example.com/media-3.jpg',
      previewUrl: 'https://example.com/media-3-preview.jpg',
    );
    const media4 = CatalogMedia(
      id: 'media-4',
      url: 'https://example.com/media-4.jpg',
      previewUrl: 'https://example.com/media-4-preview.jpg',
    );
    const media5 = CatalogMedia(
      id: 'media-5',
      url: 'https://example.com/media-5.jpg',
      previewUrl: 'https://example.com/media-5-preview.jpg',
    );
    const media6 = CatalogMedia(
      id: 'media-6',
      url: 'https://example.com/media-6.jpg',
      previewUrl: 'https://example.com/media-6-preview.jpg',
    );
    const pageData = CatalogPageData(
      page: 1,
      perPage: 20,
      totalItems: 6,
      totalPages: 1,
      categoryId: 'cat-access',
      categoryName: 'Accessoires Totoro',
      items: [
        CatalogListingItem(
          id: 'cp-current',
          categoryId: 'cat-access',
          productId: 'prod-1',
          category: accessoires,
          product: CatalogProduct(
            id: 'prod-1',
            code: 'PROD-1',
            name: 'Sac Totoro Nuage',
            slug: 'sac-totoro-nuage',
          ),
          productRouteSlug: 'sac-totoro-nuage',
        ),
        CatalogListingItem(
          id: 'cp-2',
          categoryId: 'cat-access',
          productId: 'prod-2',
          category: accessoires,
          product: CatalogProduct(
            id: 'prod-2',
            code: 'PROD-2',
            name: 'Produit recommandé 1',
            slug: 'produit-recommande-1',
            picture: media2,
          ),
          productRouteSlug: 'produit-recommande-1',
        ),
        CatalogListingItem(
          id: 'cp-3',
          categoryId: 'cat-access',
          productId: 'prod-3',
          category: accessoires,
          product: CatalogProduct(
            id: 'prod-3',
            code: 'PROD-3',
            name: 'Produit recommandé 2',
            slug: 'produit-recommande-2',
            picture: media3,
          ),
          productRouteSlug: 'produit-recommande-2',
        ),
        CatalogListingItem(
          id: 'cp-4',
          categoryId: 'cat-access',
          productId: 'prod-4',
          category: accessoires,
          product: CatalogProduct(
            id: 'prod-4',
            code: 'PROD-4',
            name: 'Produit recommandé 3',
            slug: 'produit-recommande-3',
            picture: media4,
          ),
          productRouteSlug: 'produit-recommande-3',
        ),
        CatalogListingItem(
          id: 'cp-5',
          categoryId: 'cat-access',
          productId: 'prod-5',
          category: accessoires,
          product: CatalogProduct(
            id: 'prod-5',
            code: 'PROD-5',
            name: 'Produit recommandé 4',
            slug: 'produit-recommande-4',
            picture: media5,
          ),
          productRouteSlug: 'produit-recommande-4',
        ),
        CatalogListingItem(
          id: 'cp-6',
          categoryId: 'cat-access',
          productId: 'prod-6',
          category: accessoires,
          product: CatalogProduct(
            id: 'prod-6',
            code: 'PROD-6',
            name: 'Produit consulté récemment',
            slug: 'produit-consulte-recemment',
            picture: media6,
          ),
          productRouteSlug: 'produit-consulte-recemment',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: pageData,
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                ),
                prices: [],
              ),
            ),
          ),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mainScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );

    await tester.scrollUntilVisible(
      find.text('Vous aimerez aussi'),
      700,
      scrollable: mainScrollable,
      maxScrolls: 8,
    );
    expect(find.text('Vous aimerez aussi'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Vous aimerez aussi')).style?.fontSize,
      23,
    );
    expect(find.text('Produit recommandé 1'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Consulté récemment'),
      700,
      scrollable: mainScrollable,
      maxScrolls: 8,
    );
    expect(find.text('Consulté récemment'), findsOneWidget);
    expect(find.text('Produit consulté récemment'), findsOneWidget);
    final heroTags = tester
        .widgetList<Hero>(find.byType(Hero))
        .map((hero) => hero.tag)
        .toList(growable: false);
    // Deep-link entry: no source-scoped tag was passed in. The current
    // product has no listing/gallery media in this fixture, so the PDP's main
    // image Hero is suppressed (allMedia is empty) and the cross-sell scope
    // falls back to `pdp-<currentProductId>`. The key guarantee is that
    // prod-2 still does NOT wear the unscoped tag — otherwise it would
    // collide with a PLP card of the same product still in the tree.
    final crossSellScope = productPdpCrossSellHeroScope(
      currentProductId: 'prod-1',
      currentMainImageHeroTag: null,
    );
    expect(
      heroTags,
      contains(productImageHeroTag('prod-2', sourceScope: crossSellScope)),
    );
    expect(heroTags, isNot(contains(productImageHeroTag('prod-2'))));
    expect(heroTags.length, heroTags.toSet().length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDP cross-sell Heroes wait for route transition to settle', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media2 = CatalogMedia(
      id: 'media-2',
      url: 'https://example.com/media-2.jpg',
      previewUrl: 'https://example.com/media-2-preview.jpg',
    );
    const pageData = CatalogPageData(
      page: 1,
      perPage: 20,
      totalItems: 2,
      totalPages: 1,
      categoryId: 'cat-access',
      categoryName: 'Accessoires Totoro',
      items: [
        CatalogListingItem(
          id: 'cp-current',
          categoryId: 'cat-access',
          productId: 'prod-1',
          category: accessoires,
          product: CatalogProduct(
            id: 'prod-1',
            code: 'PROD-1',
            name: 'Sac Totoro Nuage',
            slug: 'sac-totoro-nuage',
          ),
          productRouteSlug: 'sac-totoro-nuage',
        ),
        CatalogListingItem(
          id: 'cp-2',
          categoryId: 'cat-access',
          productId: 'prod-2',
          category: accessoires,
          product: CatalogProduct(
            id: 'prod-2',
            code: 'PROD-2',
            name: 'Produit recommandé 1',
            slug: 'produit-recommande-1',
            picture: media2,
          ),
          productRouteSlug: 'produit-recommande-1',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              pageData: pageData,
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder<void>(
                    transitionDuration: const Duration(seconds: 1),
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const Scaffold(
                          body: ProductDetailCrossSellArea(
                            categoryId: 'cat-access',
                            currentProductId: 'prod-1',
                          ),
                        ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) =>
                            FadeTransition(opacity: animation, child: child),
                  ),
                );
              },
              child: const Text('Open PDP'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open PDP'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Produit recommandé 1'), findsOneWidget);
    expect(find.byType(Hero), findsNothing);

    await tester.pumpAndSettle();

    final heroTags = tester
        .widgetList<Hero>(find.byType(Hero))
        .map((hero) => hero.tag)
        .toList(growable: false);
    // Mounted without a currentMainImageHeroTag, so the scope falls back to
    // the productId-derived placeholder (`pdp-<currentProductId>`).
    final crossSellScope = productPdpCrossSellHeroScope(
      currentProductId: 'prod-1',
      currentMainImageHeroTag: null,
    );
    expect(
      heroTags,
      contains(productImageHeroTag('prod-2', sourceScope: crossSellScope)),
    );
  });

  testWidgets('Mobile PDP shopping bag icon opens checkout', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media1 = CatalogMedia(
      id: 'media-1',
      url: 'https://example.com/media-1.jpg',
      previewUrl: 'https://example.com/media-1-preview.jpg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                  picture: media1,
                ),
                prices: [
                  CatalogPrice(
                    id: 'price-1',
                    productId: 'prod-1',
                    price: 39,
                    isDefault: true,
                    currencySymbol: '€',
                    currencyCode: 'EUR',
                  ),
                ],
              ),
            ),
          ),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Panier'));
    await tester.pumpAndSettle();

    expect(find.text('Votre panier est vide.'), findsOneWidget);
  });

  testWidgets('Mobile PDP add-to-cart persists via cart repository', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media1 = CatalogMedia(
      id: 'media-1',
      url: 'https://example.com/media-1.jpg',
      previewUrl: 'https://example.com/media-1-preview.jpg',
    );
    final cartRepository = _FakeCartRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                  picture: media1,
                ),
                prices: [
                  CatalogPrice(
                    id: 'price-1',
                    productId: 'prod-1',
                    price: 39,
                    isDefault: true,
                    currencySymbol: '€',
                    currencyCode: 'EUR',
                  ),
                ],
              ),
            ),
          ),
        ], cartRepository: cartRepository),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(PdpPurchaseBar));
    await tester.pumpAndSettle();

    expect(cartRepository.addedProductIds, ['prod-1']);
    expect(cartRepository.lastAddedQuantity, 1);
    final cartCountBadge = find.byKey(
      const ValueKey('shared-nav-cart-count-badge'),
    );
    expect(cartCountBadge, findsOneWidget);
    expect(tester.widget<Text>(cartCountBadge).data, '1');
  });

  testWidgets('Mobile PDP prefetches the active cart on first render', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media1 = CatalogMedia(
      id: 'media-1',
      url: 'https://example.com/media-1.jpg',
      previewUrl: 'https://example.com/media-1-preview.jpg',
    );
    final cartRepository = _FakeCartRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                  picture: media1,
                ),
                prices: [
                  CatalogPrice(
                    id: 'price-1',
                    productId: 'prod-1',
                    price: 39,
                    isDefault: true,
                    currencySymbol: '€',
                    currencyCode: 'EUR',
                  ),
                ],
              ),
            ),
          ),
        ], cartRepository: cartRepository),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(cartRepository.findActiveCartCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('Mobile checkout page opens from add-to-cart top sheet', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media1 = CatalogMedia(
      id: 'media-1',
      url: 'https://example.com/media-1.jpg',
      previewUrl: 'https://example.com/media-1-preview.jpg',
    );
    final cartRepository = _FakeCartRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                  gallery: [media1],
                ),
                prices: [
                  CatalogPrice(
                    id: 'price-1',
                    productId: 'prod-1',
                    price: 39,
                    isDefault: true,
                    currencySymbol: '€',
                    currencyCode: 'EUR',
                  ),
                ],
              ),
            ),
          ),
        ], cartRepository: cartRepository),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(PdpPurchaseBar));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Finaliser ma commande'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Récapitulatif de la commande'), findsOneWidget);
    expect(find.text('Emballage et cadeaux'), findsOneWidget);
    expect(find.text('Aide & Services'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is KikiImage && widget.imageUrl == media1.listingUrl,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Mobile checkout keeps line items visible while totals resync in background',
    (WidgetTester tester) async {
      setMobileSurface(tester);
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() => resetSurface(tester));

      const accessoires = CatalogCategory(
        id: 'cat-access',
        code: 'CAT-ACCESS',
        name: 'Accessoires Totoro',
        slug: 'accessoires-totoro',
      );
      const media1 = CatalogMedia(
        id: 'media-1',
        url: 'https://example.com/media-1.jpg',
        previewUrl: 'https://example.com/media-1-preview.jpg',
      );
      final cartRepository = _FakeCartRepository(deferRecompute: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _withDrawerFallback([
            categoryCatalogRepositoryProvider.overrideWithValue(
              _FakeCategoryCatalogRepository(
                defaultCategory: accessoires,
                activeCategories: const [accessoires],
                categoryBySlug: accessoires,
                resolvedProductRoute: const CatalogProductRouteData(
                  category: accessoires,
                  productId: 'prod-1',
                  productSlug: 'sac-totoro-nuage',
                ),
                pageData: const CatalogPageData(
                  page: 1,
                  perPage: 20,
                  totalItems: 0,
                  totalPages: 0,
                  categoryId: 'cat-access',
                  categoryName: 'Accessoires Totoro',
                  items: [],
                ),
              ),
            ),
            productCatalogRepositoryProvider.overrideWithValue(
              _FakeProductCatalogRepository(
                detail: const ProductDetailData(
                  product: CatalogProduct(
                    id: 'prod-1',
                    code: 'PROD-1',
                    name: 'Sac Totoro Nuage',
                    slug: 'sac-totoro-nuage',
                    productType: 'Accessoire',
                    picture: media1,
                  ),
                  prices: [
                    CatalogPrice(
                      id: 'price-1',
                      productId: 'prod-1',
                      price: 39,
                      isDefault: true,
                      currencySymbol: '€',
                      currencyCode: 'EUR',
                    ),
                  ],
                ),
              ),
            ),
          ], cartRepository: cartRepository),
          child: const KikiCommerceApp(
            initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(PdpPurchaseBar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Finaliser ma commande'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Récapitulatif de la commande'), findsOneWidget);
      expect(find.text('Sac Totoro Nuage'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      cartRepository.completeRecompute(0);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Desktop checkout renders Dior-like two-column layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 980);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media1 = CatalogMedia(
      id: 'media-1',
      url: 'https://example.com/media-1.jpg',
      previewUrl: 'https://example.com/media-1-preview.jpg',
    );
    const product = CatalogProduct(
      id: 'prod-1',
      code: 'PROD-1',
      name: 'Sac Totoro Nuage',
      slug: 'sac-totoro-nuage',
      productType: 'Accessoire',
      summary: 'Cuir de veau grainé noir',
      picture: media1,
    );
    const price = CatalogPrice(
      id: 'price-1',
      productId: 'prod-1',
      price: 3500,
      isDefault: true,
      currencySymbol: '€',
      currencyCode: 'EUR',
    );
    final cartRepository = _FakeCartRepository();
    await cartRepository.addToCartAck(
      guestId: 'guest-1',
      product: product,
      price: price,
      quantity: 1,
      idempotencyKey: 'desktop-checkout',
    );
    cartRepository.cart = cartRepository.cart?.copyWith(
      totals: const CartTotals(
        subtotal: 3500,
        taxTotal: 583.33,
        grandTotal: 3500,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              categoryBySlug: accessoires,
              activeCategories: const [accessoires],
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: product,
                prices: [price],
              ),
            ),
          ),
        ], cartRepository: cartRepository),
        child: const KikiCommerceApp(initialRoute: '/cart'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Récapitulatif de la commande'), findsOneWidget);
    expect(find.text('Sac Totoro Nuage'), findsOneWidget);
    expect(find.text('Aide & Services'), findsOneWidget);

    final orderLeft = tester
        .getTopLeft(find.text('Récapitulatif de la commande'))
        .dx;
    final totalLeft = tester.getTopLeft(find.text('Total')).dx;

    expect(orderLeft, lessThan(120));
    expect(totalLeft, greaterThan(900));
  });

  testWidgets(
    'Add-to-cart top sheet opens before background cart resync completes',
    (WidgetTester tester) async {
      setMobileSurface(tester);
      addTearDown(() => resetSurface(tester));

      const accessoires = CatalogCategory(
        id: 'cat-access',
        code: 'CAT-ACCESS',
        name: 'Accessoires Totoro',
        slug: 'accessoires-totoro',
      );
      const media1 = CatalogMedia(
        id: 'media-1',
        url: 'https://example.com/media-1.jpg',
        previewUrl: 'https://example.com/media-1-preview.jpg',
      );
      final cartRepository = _FakeCartRepository(deferRecompute: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _withDrawerFallback([
            categoryCatalogRepositoryProvider.overrideWithValue(
              _FakeCategoryCatalogRepository(
                defaultCategory: accessoires,
                activeCategories: const [accessoires],
                categoryBySlug: accessoires,
                resolvedProductRoute: const CatalogProductRouteData(
                  category: accessoires,
                  productId: 'prod-1',
                  productSlug: 'sac-totoro-nuage',
                ),
                pageData: const CatalogPageData(
                  page: 1,
                  perPage: 20,
                  totalItems: 0,
                  totalPages: 0,
                  categoryId: 'cat-access',
                  categoryName: 'Accessoires Totoro',
                  items: [],
                ),
              ),
            ),
            productCatalogRepositoryProvider.overrideWithValue(
              _FakeProductCatalogRepository(
                detail: const ProductDetailData(
                  product: CatalogProduct(
                    id: 'prod-1',
                    code: 'PROD-1',
                    name: 'Sac Totoro Nuage',
                    slug: 'sac-totoro-nuage',
                    productType: 'Accessoire',
                    picture: media1,
                  ),
                  prices: [
                    CatalogPrice(
                      id: 'price-1',
                      productId: 'prod-1',
                      price: 39,
                      isDefault: true,
                      currencySymbol: '€',
                      currencyCode: 'EUR',
                    ),
                  ],
                ),
              ),
            ),
          ], cartRepository: cartRepository),
          child: const KikiCommerceApp(
            initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(PdpPurchaseBar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));

      expect(find.text('Produit ajouté au panier'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is KikiImage && widget.imageUrl == media1.listingUrl,
        ),
        findsOneWidget,
      );
      expect(cartRepository.recomputeCompleters, hasLength(1));

      cartRepository.completeRecompute(0);
      await tester.pump();
    },
  );

  testWidgets(
    'Late cart resync error closes the top sheet and shows a snackbar',
    (WidgetTester tester) async {
      setMobileSurface(tester);
      addTearDown(() => resetSurface(tester));

      const accessoires = CatalogCategory(
        id: 'cat-access',
        code: 'CAT-ACCESS',
        name: 'Accessoires Totoro',
        slug: 'accessoires-totoro',
      );
      const media1 = CatalogMedia(
        id: 'media-1',
        url: 'https://example.com/media-1.jpg',
        previewUrl: 'https://example.com/media-1-preview.jpg',
      );
      final cartRepository = _FakeCartRepository(deferRecompute: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _withDrawerFallback([
            categoryCatalogRepositoryProvider.overrideWithValue(
              _FakeCategoryCatalogRepository(
                defaultCategory: accessoires,
                activeCategories: const [accessoires],
                categoryBySlug: accessoires,
                resolvedProductRoute: const CatalogProductRouteData(
                  category: accessoires,
                  productId: 'prod-1',
                  productSlug: 'sac-totoro-nuage',
                ),
                pageData: const CatalogPageData(
                  page: 1,
                  perPage: 20,
                  totalItems: 0,
                  totalPages: 0,
                  categoryId: 'cat-access',
                  categoryName: 'Accessoires Totoro',
                  items: [],
                ),
              ),
            ),
            productCatalogRepositoryProvider.overrideWithValue(
              _FakeProductCatalogRepository(
                detail: const ProductDetailData(
                  product: CatalogProduct(
                    id: 'prod-1',
                    code: 'PROD-1',
                    name: 'Sac Totoro Nuage',
                    slug: 'sac-totoro-nuage',
                    productType: 'Accessoire',
                    picture: media1,
                  ),
                  prices: [
                    CatalogPrice(
                      id: 'price-1',
                      productId: 'prod-1',
                      price: 39,
                      isDefault: true,
                      currencySymbol: '€',
                      currencyCode: 'EUR',
                    ),
                  ],
                ),
              ),
            ),
          ], cartRepository: cartRepository),
          child: const KikiCommerceApp(
            initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(PdpPurchaseBar));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      expect(find.text('Produit ajouté au panier'), findsOneWidget);

      cartRepository.completeRecomputeError(0, Exception('boom'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Produit ajouté au panier'), findsNothing);
      expect(
        find.text('Produit ajouté, impossible de synchroniser le panier'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Missing currency shows an in-bar error without opening the top sheet',
    (WidgetTester tester) async {
      setMobileSurface(tester);
      addTearDown(() => resetSurface(tester));

      const accessoires = CatalogCategory(
        id: 'cat-access',
        code: 'CAT-ACCESS',
        name: 'Accessoires Totoro',
        slug: 'accessoires-totoro',
      );
      const media1 = CatalogMedia(
        id: 'media-1',
        url: 'https://example.com/media-1.jpg',
        previewUrl: 'https://example.com/media-1-preview.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: _withDrawerFallback([
            categoryCatalogRepositoryProvider.overrideWithValue(
              _FakeCategoryCatalogRepository(
                defaultCategory: accessoires,
                activeCategories: const [accessoires],
                categoryBySlug: accessoires,
                resolvedProductRoute: const CatalogProductRouteData(
                  category: accessoires,
                  productId: 'prod-1',
                  productSlug: 'sac-totoro-nuage',
                ),
                pageData: const CatalogPageData(
                  page: 1,
                  perPage: 20,
                  totalItems: 0,
                  totalPages: 0,
                  categoryId: 'cat-access',
                  categoryName: 'Accessoires Totoro',
                  items: [],
                ),
              ),
            ),
            productCatalogRepositoryProvider.overrideWithValue(
              _FakeProductCatalogRepository(
                detail: const ProductDetailData(
                  product: CatalogProduct(
                    id: 'prod-1',
                    code: 'PROD-1',
                    name: 'Sac Totoro Nuage',
                    slug: 'sac-totoro-nuage',
                    productType: 'Accessoire',
                    picture: media1,
                  ),
                  prices: [
                    CatalogPrice(
                      id: 'price-1',
                      productId: 'prod-1',
                      price: 39,
                      isDefault: true,
                      currencySymbol: '€',
                    ),
                  ],
                ),
              ),
            ),
          ]),
          child: const KikiCommerceApp(
            initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(PdpPurchaseBar));
      await tester.pumpAndSettle();

      expect(find.text('Produit ajouté au panier'), findsNothing);
      // The error now surfaces inside the purchase bar, not as a SnackBar.
      expect(find.text('Échec, réessayez'), findsOneWidget);
    },
  );

  testWidgets('Desktop PDP add-to-cart persists via cart repository', (
    WidgetTester tester,
  ) async {
    setDesktopSurface(tester);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    const media1 = CatalogMedia(
      id: 'media-1',
      url: 'https://example.com/media-1.jpg',
      previewUrl: 'https://example.com/media-1-preview.jpg',
    );
    final cartRepository = _FakeCartRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                  picture: media1,
                ),
                prices: [
                  CatalogPrice(
                    id: 'price-1',
                    productId: 'prod-1',
                    price: 39,
                    isDefault: true,
                    currencySymbol: '€',
                    currencyCode: 'EUR',
                  ),
                ],
              ),
            ),
          ),
        ], cartRepository: cartRepository),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter au panier'));
    await tester.pumpAndSettle();

    expect(cartRepository.addedProductIds, ['prod-1']);
    expect(cartRepository.lastAddedQuantity, 1);
  });

  testWidgets('PDP edit mode exposes text and price edit triggers', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );

    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                  summary: 'Un sac pour les jours de pluie.',
                ),
                prices: [],
              ),
            ),
          ),
          editModeProvider.overrideWith((ref) => true),
          adminAuthTokenProvider.overrideWith((ref) => 'test-token'),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(kPdpTranslationsEditorSemanticsLabel),
      findsOne,
    );
    expect(find.bySemanticsLabel(kProductPriceEditorSemanticsLabel), findsOne);
    semantics.dispose();
  });

  testWidgets('PDP translations sheet saves a base product update', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    final adminRepository = _RecordingAdminBackofficeRepository();
    adminRepository.recordsByCollection['products'] = [
      {
        'id': 'prod-1',
        'code': 'PROD-1',
        'name': 'Sac Totoro Nuage',
        'slug': 'sac-totoro-nuage',
        'summary': 'Un sac pour les jours de pluie.',
        'description': '',
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                  summary: 'Un sac pour les jours de pluie.',
                ),
                prices: [],
              ),
            ),
          ),
          adminBackofficeRepositoryProvider.overrideWithValue(adminRepository),
          editModeProvider.overrideWith((ref) => true),
          adminAuthTokenProvider.overrideWith((ref) => 'test-token'),
          contentLocaleProvider.overrideWith(
            () => ContentLocaleController(seeded: 'fr'),
          ),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Traductions'));
    await tester.pumpAndSettle();

    expect(find.text('Traductions PDP'), findsOneWidget);
    final nameField = find.widgetWithText(TextField, 'Nom produit *');
    expect(nameField, findsOneWidget);

    await tester.enterText(nameField, 'Sac Totoro Deluxe');
    await tester.pump();
    expect(find.text('Modifié non enregistré'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer').last);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(adminRepository.lastUpdatedCollection, 'products');
    expect(adminRepository.lastUpdatedRecordId, 'prod-1');
    expect(adminRepository.lastUpdatedData?['name'], 'Sac Totoro Deluxe');
    expect(
      adminRepository.lastUpdatedData?['searchIndex'],
      contains('sac totoro deluxe'),
    );
  });

  testWidgets('PDP price edit creates an active price row when missing', (
    WidgetTester tester,
  ) async {
    setMobileSurface(tester);
    addTearDown(() => resetSurface(tester));

    const accessoires = CatalogCategory(
      id: 'cat-access',
      code: 'CAT-ACCESS',
      name: 'Accessoires Totoro',
      slug: 'accessoires-totoro',
    );
    final adminRepository = _RecordingAdminBackofficeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _withDrawerFallback([
          categoryCatalogRepositoryProvider.overrideWithValue(
            _FakeCategoryCatalogRepository(
              defaultCategory: accessoires,
              activeCategories: const [accessoires],
              categoryBySlug: accessoires,
              resolvedProductRoute: const CatalogProductRouteData(
                category: accessoires,
                productId: 'prod-1',
                productSlug: 'sac-totoro-nuage',
              ),
              pageData: const CatalogPageData(
                page: 1,
                perPage: 20,
                totalItems: 0,
                totalPages: 0,
                categoryId: 'cat-access',
                categoryName: 'Accessoires Totoro',
                items: [],
              ),
            ),
          ),
          productCatalogRepositoryProvider.overrideWithValue(
            _FakeProductCatalogRepository(
              detail: const ProductDetailData(
                product: CatalogProduct(
                  id: 'prod-1',
                  code: 'PROD-1',
                  name: 'Sac Totoro Nuage',
                  slug: 'sac-totoro-nuage',
                  productType: 'Accessoire',
                  summary: 'Un sac pour les jours de pluie.',
                ),
                prices: [],
              ),
            ),
          ),
          adminBackofficeRepositoryProvider.overrideWithValue(adminRepository),
          editModeProvider.overrideWith((ref) => true),
          adminAuthTokenProvider.overrideWith((ref) => 'test-token'),
        ]),
        child: const KikiCommerceApp(
          initialRoute: '/catalog/accessoires-totoro/sac-totoro-nuage',
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Ajouter un prix'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter un prix'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey(kProductPriceEditorInputKey)),
      '49,90',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(adminRepository.lastCreatedCollection, 'priceRows');
    expect(adminRepository.lastCreatedData?['product'], 'prod-1');
    expect(adminRepository.lastCreatedData?['currency'], 'currency-eur');
    expect(adminRepository.lastCreatedData?['price'], 49.9);
    expect(adminRepository.lastCreatedData?['isDefault'], isTrue);
    expect(adminRepository.lastCreatedData?['isActive'], isTrue);
  });
}

List<T> _withDrawerFallback<T>(
  List<T> overrides, {
  CartRepository? cartRepository,
  CartGuestSessionStore? guestSessionStore,
}) {
  final drawerOverride =
      drawerNavigationRepositoryProvider.overrideWithValue(
            const _FakeDrawerNavigationRepository(),
          )
          as T;
  final guestOverride =
      guestSessionStoreProvider.overrideWithValue(
            guestSessionStore ?? const _FakeGuestSessionStore(),
          )
          as T;
  final cartOverride =
      cartRepositoryProvider.overrideWithValue(
            cartRepository ?? _FakeCartRepository(),
          )
          as T;

  final localeFr = localeOverrides().map((override) => override as T);
  final networkFallbacks = storefrontNetworkTestOverrides().map(
    (override) => override as T,
  );

  return [
    drawerOverride,
    guestOverride,
    cartOverride,
    ...localeFr,
    ...networkFallbacks,
    ...overrides,
  ];
}

class _FakeCategoryCatalogRepository implements CategoryCatalogRepository {
  final CatalogCategory? defaultCategory;
  final CatalogCategory? categoryBySlug;
  final List<CatalogCategory> activeCategories;
  final CatalogProductRouteData? resolvedProductRoute;
  final CatalogPageData pageData;

  _FakeCategoryCatalogRepository({
    required this.defaultCategory,
    required this.categoryBySlug,
    required this.activeCategories,
    this.resolvedProductRoute,
    required this.pageData,
  });

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async =>
      defaultCategory;

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async => activeCategories;

  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async => categoryBySlug;

  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String locale,
    required String categorySlug,
    required String productSlug,
  }) async => resolvedProductRoute;

  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async => pageData;
}

class _FakeProductCatalogRepository implements ProductCatalogRepository {
  final ProductDetailData detail;

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
  }) async => detail;
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
  Future<void> clearGuestId() async {}

  @override
  Future<String> ensureGuestId() async => 'guest-1';

  @override
  Future<String?> peekGuestId() async => 'guest-1';

  @override
  Future<CachedActiveCart?> peekActiveCart() async => null;

  @override
  Future<void> cacheActiveCart({
    required String cartId,
    required String currencyCode,
  }) async {}

  @override
  Future<void> clearActiveCart() async {}
}

class _FakeCartRepository implements CartRepository {
  Cart? cart;
  CartEntry? entry;
  final addedProductIds = <String>[];
  int? lastAddedQuantity;
  int findActiveCartCalls = 0;
  final bool deferRecompute;
  final List<Completer<CartView>> recomputeCompleters = [];

  _FakeCartRepository({this.deferRecompute = false});

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
    addedProductIds.add(product.id);
    lastAddedQuantity = quantity;
    final resolvedCartId = cart?.id ?? cachedCartId ?? 'cart-1';
    final resolvedGuestId = cart?.guestId ?? guestId;
    final resolvedCurrency =
        cart?.currencyCode ??
        cachedCartCurrencyCode ??
        price.currencyCode ??
        'EUR';
    cart = Cart(
      id: resolvedCartId,
      guestId: resolvedGuestId,
      currencyCode: resolvedCurrency,
    );
    entry = _cartEntry(
      cartId: resolvedCartId,
      productId: product.id,
      name: product.name,
      quantity: quantity,
      unitPrice: price.price,
    );
    return CartAddAck(
      cartId: resolvedCartId,
      entryProductId: product.id,
      quantityDelta: quantity,
      cartCreated: false,
    );
  }

  @override
  Future<CartView> recomputeAndSaveTotals(String cartId) async {
    if (deferRecompute) {
      final completer = Completer<CartView>();
      recomputeCompleters.add(completer);
      return completer.future;
    }
    final currentCart =
        cart ??
        const Cart(id: 'cart-1', guestId: 'guest-1', currencyCode: 'EUR');
    return CartView(cart: currentCart, entries: [?entry]);
  }

  void completeRecompute(int index) {
    final currentCart =
        cart ??
        const Cart(id: 'cart-1', guestId: 'guest-1', currencyCode: 'EUR');
    final completer = recomputeCompleters[index];
    if (!completer.isCompleted) {
      completer.complete(CartView(cart: currentCart, entries: [?entry]));
    }
  }

  void completeRecomputeError(int index, Object error) {
    final completer = recomputeCompleters[index];
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  @override
  Future<CartView> getCartWithEntries(String cartId) async {
    return recomputeAndSaveTotals(cartId);
  }

  @override
  Future<Cart?> findActiveCartForGuest(String guestId) async {
    findActiveCartCalls += 1;
    return cart;
  }

  @override
  Future<Cart> createGuestCart({
    required String guestId,
    required String currencyCode,
  }) async {
    cart = Cart(id: 'cart-1', guestId: guestId, currencyCode: currencyCode);
    return cart!;
  }

  @override
  Future<CartEntry?> findEntryForProduct({
    required String cartId,
    required String productId,
  }) async => entry;

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
  Future<CartEntry> updateEntryQuantity({
    required CartEntry entry,
    required int quantity,
    double? unitPrice,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> removeEntry(String entryId) async {
    entry = null;
  }

  @override
  Future<CartView> clearCart(String cartId) async {
    entry = null;
    return recomputeAndSaveTotals(cartId);
  }

  CartEntry _cartEntry({
    required String cartId,
    required String productId,
    required String name,
    required int quantity,
    required double unitPrice,
  }) {
    return CartEntry(
      id: 'entry-1',
      cartId: cartId,
      productId: productId,
      productNameSnapshot: name,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: unitPrice * quantity,
    );
  }
}

class _RecordingAdminBackofficeRepository implements AdminBackofficeRepository {
  String? lastCreatedCollection;
  String? lastUpdatedCollection;
  String? lastCreatedRecordId;
  String? lastUpdatedRecordId;
  Map<String, dynamic>? lastCreatedData;
  Map<String, dynamic>? lastUpdatedData;
  final recordsByCollection = <String, List<Map<String, dynamic>>>{};
  List<Map<String, dynamic>> currencies = const [
    {'id': 'currency-eur', 'isocode': 'EUR', 'symbol': '€', 'isActive': true},
  ];

  @override
  Future<String> authenticateSuperuser({
    required String baseUrl,
    required String email,
    required String password,
  }) async => 'token';

  @override
  Future<List<Map<String, dynamic>>> listRecords({
    required String baseUrl,
    required String authToken,
    required String collection,
    String sort = '-created',
    int perPage = 500,
    int page = 1,
    String? filter,
  }) async {
    if (collection == 'currencies') {
      return currencies.map(Map<String, dynamic>.from).toList();
    }
    final records = recordsByCollection[collection] ?? const [];
    return records.map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    lastCreatedCollection = collection;
    lastCreatedRecordId = 'created-1';
    lastCreatedData = Map<String, dynamic>.from(data);
    return {'id': lastCreatedRecordId, ...data};
  }

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    lastUpdatedCollection = collection;
    lastUpdatedRecordId = recordId;
    lastUpdatedData = Map<String, dynamic>.from(data);
    return data;
  }

  @override
  Future<Map<String, dynamic>> upsertMediaRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    String? recordId,
    required Map<String, dynamic> data,
    String? mediaSource,
    required String fallbackFilename,
    String? mimeType,
  }) async => data;

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) async => const {};

  @override
  Future<void> deleteRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
  }) async {}

  @override
  Future<CatalogImportReport> importCatalogCsv({
    required String baseUrl,
    required String authToken,
    required String csvContent,
  }) async => CatalogImportReport(totalRows: 0);

  @override
  Future<CatalogExportResult> exportCatalogCsv({
    required String baseUrl,
    required String authToken,
  }) async => CatalogExportResult(csvContent: '', exportedRows: 0);
}
