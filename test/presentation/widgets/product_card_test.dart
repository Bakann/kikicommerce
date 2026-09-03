import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/app/cache_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/product_catalog_repository.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/performance/pdp_loading_performance_logger.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/providers/pdp_loading_commerce_provider.dart';
import 'package:kiki_commerce/presentation/widgets/kiki_image.dart';
import 'package:kiki_commerce/presentation/widgets/product_card.dart';
import 'package:kiki_commerce/presentation/widgets/product_hero_tags.dart';
import 'package:go_router/go_router.dart';

void main() {
  const listingMedia = CatalogMedia(
    id: 'media-listing',
    url: 'https://example.com/listing.jpg',
    previewUrl: 'https://example.com/listing-preview.jpg',
  );
  const testProduct = CatalogProduct(
    id: 'product-1',
    code: 'PRODUCT-1',
    name: 'Product 1',
    picture: listingMedia,
  );
  const testPrice = CatalogPrice(
    id: 'price-1',
    productId: 'product-1',
    price: 133,
    isDefault: true,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );

  Widget buildHarness({
    CatalogProduct product = testProduct,
    bool enableHeroTransition = false,
    bool editMode = false,
  }) {
    return ProviderScope(
      overrides: [if (editMode) editModeProvider.overrideWith((ref) => true)],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 480,
            child: ProductCard(
              product: product,
              prices: const [],
              routeName: '/products/product-1',
              enableHeroTransition: enableHeroTransition,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'uses first gallery media when picture and thumbnail are absent',
    (tester) async {
      const galleryMedia = CatalogMedia(
        id: 'media-gallery',
        url: 'https://example.com/gallery.jpg',
        previewUrl: 'https://example.com/gallery-preview.jpg',
      );
      const product = CatalogProduct(
        id: 'product-1',
        code: 'PRODUCT-1',
        name: 'Product 1',
        gallery: [galleryMedia],
      );

      await tester.pumpWidget(buildHarness(product: product));

      final image = tester.widget<KikiImage>(find.byType(KikiImage));
      expect(image.imageUrl, galleryMedia.listingUrl);
    },
  );

  testWidgets('wraps the image in a Hero when PLP opt-in is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(buildHarness(enableHeroTransition: true));

    final hero = tester.widget<Hero>(find.byType(Hero));
    // PLP Heroes carry a category-scoped tag so they can't pair with the
    // same product surfaced on an unrelated route (e.g. as a cross-sell on
    // a stacked PDP). The harness omits the category so the scope falls
    // back to the catalog default.
    expect(
      hero.tag,
      productImageHeroTag(
        testProduct.id,
        sourceScope: productListingHeroScope(categoryId: null),
      ),
    );
    expect(hero.tag, isNot(productImageHeroTag(testProduct.id)));
    expect(
      find.descendant(of: find.byType(Hero), matching: find.byType(KikiImage)),
      findsOneWidget,
    );
  });

  testWidgets('does not create a Hero by default', (tester) async {
    await tester.pumpWidget(buildHarness());

    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('does not create a Hero without an image', (tester) async {
    await tester.pumpWidget(
      buildHarness(
        product: const CatalogProduct(
          id: 'product-1',
          code: 'PRODUCT-1',
          name: 'Product 1',
        ),
        enableHeroTransition: true,
      ),
    );

    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('does not create a Hero for unsupported image formats', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        product: const CatalogProduct(
          id: 'product-1',
          code: 'PRODUCT-1',
          name: 'Product 1',
          picture: CatalogMedia(
            id: 'media-svg',
            url: 'https://example.com/listing.svg',
            previewUrl: 'https://example.com/listing.svg',
          ),
        ),
        enableHeroTransition: true,
      ),
    );

    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('does not create a Hero when listing and PDP images differ', (
    tester,
  ) async {
    const thumbnail = CatalogMedia(
      id: 'media-thumbnail',
      url: 'https://example.com/thumb.jpg',
      previewUrl: 'https://example.com/thumb-preview.jpg',
    );
    const gallery = CatalogMedia(
      id: 'media-gallery',
      url: 'https://example.com/gallery.jpg',
      previewUrl: 'https://example.com/gallery-preview.jpg',
    );

    await tester.pumpWidget(
      buildHarness(
        product: const CatalogProduct(
          id: 'product-1',
          code: 'PRODUCT-1',
          name: 'Product 1',
          thumbnail: thumbnail,
          gallery: [gallery],
        ),
        enableHeroTransition: true,
      ),
    );

    expect(find.byType(Hero), findsNothing);
    final image = tester.widget<KikiImage>(find.byType(KikiImage));
    expect(image.imageUrl, thumbnail.listingUrl);
  });

  testWidgets('does not create a Hero when animations are disabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(buildHarness(enableHeroTransition: true));

    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('does not create a Hero in edit mode', (tester) async {
    await tester.pumpWidget(
      buildHarness(enableHeroTransition: true, editMode: true),
    );

    expect(find.byType(Hero), findsNothing);
  });

  testWidgets(
    'tap records timing and commerce snapshot when Hero is eligible',
    (tester) async {
      final now = DateTime(2026, 5, 21, 15);
      final logger = _RecordingPdpLoadingPerformanceLogger();
      final container = ProviderContainer(
        overrides: [
          cacheClockProvider.overrideWith(
            (ref) =>
                () => now,
          ),
          pdpLoadingPerformanceLoggerProvider.overrideWithValue(logger),
          productCatalogRepositoryProvider.overrideWithValue(
            const _HangingProductCatalogRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: SizedBox(
                width: 240,
                height: 480,
                child: ProductCard(
                  product: testProduct,
                  prices: const [testPrice],
                  routeName: '/products/product-1',
                  enableHeroTransition: true,
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/products/product-1',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('product_card_product-1')));
      await tester.pump(const Duration(milliseconds: 801));

      expect(logger.taps, const [_TapEvent('product-1', true)]);
      final trace = container.read(pdpLoadingTapTraceProvider('product-1'));
      expect(trace?.tappedAt, now);
      expect(trace?.heroEligible, isTrue);
      final snapshot = container.read(
        pdpLoadingCommerceSnapshotProvider('product-1'),
      );
      expect(snapshot?.product.id, 'product-1');
      expect(snapshot?.prices.single.id, 'price-1');
      expect(snapshot?.capturedAt, now);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets('tap clears commerce snapshot when Hero is not eligible', (
    tester,
  ) async {
    final now = DateTime(2026, 5, 21, 16);
    final logger = _RecordingPdpLoadingPerformanceLogger();
    final container = ProviderContainer(
      overrides: [
        cacheClockProvider.overrideWith(
          (ref) =>
              () => now,
        ),
        pdpLoadingPerformanceLoggerProvider.overrideWithValue(logger),
        productCatalogRepositoryProvider.overrideWithValue(
          const _HangingProductCatalogRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SizedBox(
              width: 240,
              height: 480,
              child: ProductCard(
                product: testProduct,
                prices: const [testPrice],
                routeName: '/products/product-1',
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/products/product-1',
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('product_card_product-1')));
    await tester.pump();

    expect(logger.taps, const [_TapEvent('product-1', false)]);
    final trace = container.read(pdpLoadingTapTraceProvider('product-1'));
    expect(trace?.tappedAt, now);
    expect(trace?.heroEligible, isFalse);
    expect(
      container.read(pdpLoadingCommerceSnapshotProvider('product-1')),
      isNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  });
}

class _HangingProductCatalogRepository implements ProductCatalogRepository {
  const _HangingProductCatalogRepository();

  @override
  Future<ProductDetailData> getProductDetail(
    String productId, {
    required String locale,
  }) async {
    return Completer<ProductDetailData>().future;
  }
}

class _RecordingPdpLoadingPerformanceLogger
    implements PdpLoadingPerformanceLogger {
  final taps = <_TapEvent>[];

  @override
  void tap({required String productId, required bool heroEligible}) {
    taps.add(_TapEvent(productId, heroEligible));
  }

  @override
  void dataReady({
    required String productId,
    required Duration latency,
    required bool heroEligible,
  }) {}
}

class _TapEvent {
  final String productId;
  final bool heroEligible;

  const _TapEvent(this.productId, this.heroEligible);

  @override
  bool operator ==(Object other) {
    return other is _TapEvent &&
        other.productId == productId &&
        other.heroEligible == heroEligible;
  }

  @override
  int get hashCode => Object.hash(productId, heroEligible);
}
