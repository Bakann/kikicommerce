import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/app/cache_providers.dart';
import 'package:kiki_commerce/application/cart/cart_guest_session_store.dart';
import 'package:kiki_commerce/application/cart/cart_read_models.dart';
import 'package:kiki_commerce/application/cart/cart_repository.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/catalog/product_catalog_repository.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/config/pdp_loading_quick_add_flags.dart';
import 'package:kiki_commerce/domain/cart/cart_entities.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/performance/pdp_loading_performance_logger.dart';
import 'package:kiki_commerce/presentation/providers/pdp_loading_commerce_provider.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_loading_skeleton.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_purchase.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_page.dart';
import 'package:kiki_commerce/presentation/widgets/animations/text_reveal/text_reveal.dart';
import 'package:kiki_commerce/presentation/widgets/pdp_purchase_bar.dart';
import 'package:kiki_commerce/presentation/widgets/product_hero_tags.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_layout.dart';

import '../../support/l10n_harness.dart';

void main() {
  const heroProbeMedia = CatalogMedia(
    id: 'media-1',
    url: 'https://example.com/media-1.jpg',
    previewUrl: 'https://example.com/media-1-preview.jpg',
  );
  const unsupportedMedia = CatalogMedia(
    id: 'media-heic',
    url: 'https://example.com/media.heic',
    previewUrl: 'https://example.com/media-preview.heic',
  );
  const product = CatalogProduct(
    id: 'prod-1',
    code: 'CORPS-AND-DENIM',
    name: 'Corps & Denim',
    picture: heroProbeMedia,
  );
  const price = CatalogPrice(
    id: 'price-1',
    productId: 'prod-1',
    price: 133,
    isDefault: true,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
  final baseNow = DateTime(2026, 5, 21, 15);

  void setSurface(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
  }

  void resetSurface(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  Future<ProviderContainer> pumpLoadingPdp(
    WidgetTester tester, {
    required CatalogMedia? listingMediaHint,
    PdpLoadingCommerceSnapshot? commerceSnapshot,
    bool enableQuickAdd = false,
    bool serverValidationEnabled = true,
    DateTime? now,
    _FakeCartRepository? cartRepository,
    ProductCatalogRepository productRepository =
        const _HangingProductCatalogRepository(),
    PdpLoadingTapTrace? tapTrace,
    PdpLoadingPerformanceLogger? performanceLogger,
    Size surfaceSize = const Size(390, 1400),
  }) async {
    setSurface(tester, surfaceSize);
    addTearDown(() => resetSurface(tester));
    final container = ProviderContainer(
      overrides: [
        cacheClockProvider.overrideWith(
          (ref) =>
              () => now ?? baseNow,
        ),
        pdpLoadingQuickAddEnabledProvider.overrideWith((ref) => enableQuickAdd),
        pdpLoadingQuickAddServerValidationProvider.overrideWith(
          (ref) => serverValidationEnabled,
        ),
        if (performanceLogger != null)
          pdpLoadingPerformanceLoggerProvider.overrideWithValue(
            performanceLogger,
          ),
        drawerNavigationRepositoryProvider.overrideWithValue(
          const _FakeDrawerNavigationRepository(),
        ),
        guestSessionStoreProvider.overrideWithValue(
          const _FakeGuestSessionStore(),
        ),
        cartRepositoryProvider.overrideWithValue(
          cartRepository ?? _FakeCartRepository(),
        ),
        categoryCatalogRepositoryProvider.overrideWithValue(
          const _FakeCategoryCatalogRepository(),
        ),
        productCatalogRepositoryProvider.overrideWithValue(productRepository),
      ],
    );
    if (commerceSnapshot != null) {
      container
              .read(pdpLoadingCommerceSnapshotProvider('prod-1').notifier)
              .state =
          commerceSnapshot;
    }
    if (tapTrace != null) {
      container.read(pdpLoadingTapTraceProvider('prod-1').notifier).state =
          tapTrace;
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
          home: ProductDetailPage(
            productId: 'prod-1',
            listingMediaHint: listingMediaHint,
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> disposeHarness(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump();
  }

  testWidgets(
    'loading with listingMediaHint mounts Hero and skeleton with no spinner',
    (tester) async {
      await pumpLoadingPdp(tester, listingMediaHint: heroProbeMedia);

      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == productImageHeroTag('prod-1'),
        ),
        findsOneWidget,
      );
      expect(find.byType(Hero), findsOneWidget);
      expect(find.byType(ProductDetailLoadingSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(TextRevealGroup), findsNothing);
      expect(find.byType(ScrollLineRevealText), findsNothing);
    },
  );

  testWidgets(
    'loading without listingMediaHint falls back to spinner with no skeleton',
    (tester) async {
      await pumpLoadingPdp(tester, listingMediaHint: null);

      expect(find.byType(Hero), findsNothing);
      expect(find.byType(ProductDetailLoadingSkeleton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'loading suppresses Hero and skeleton when animations are disabled',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await pumpLoadingPdp(tester, listingMediaHint: heroProbeMedia);

      expect(find.byType(Hero), findsNothing);
      expect(find.byType(ProductDetailLoadingSkeleton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'loading suppresses Hero and skeleton for unsupported listing media',
    (tester) async {
      await pumpLoadingPdp(tester, listingMediaHint: unsupportedMedia);

      expect(find.byType(Hero), findsNothing);
      expect(find.byType(ProductDetailLoadingSkeleton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'loading quick add renders with a valid PLP snapshot and one Hero',
    (tester) async {
      final container = await pumpLoadingPdp(
        tester,
        listingMediaHint: heroProbeMedia,
        enableQuickAdd: true,
        commerceSnapshot: PdpLoadingCommerceSnapshot(
          product: product,
          prices: const [price],
          capturedAt: baseNow,
        ),
      );

      expect(find.byType(Hero), findsOneWidget);
      expect(find.byType(ProductDetailLoadingSkeleton), findsOneWidget);
      expect(find.byType(PdpLoadingQuickAddSection), findsOneWidget);
      expect(find.byType(PdpPaymentBadges), findsOneWidget);
      expect(find.byType(PdpPurchaseBar), findsOneWidget);
      expect(find.text('Corps & Denim'), findsOneWidget);
      expect(find.text('Référence : CORPS-AND-DENIM'), findsOneWidget);
      expect(find.text('Ajouter au panier'), findsOneWidget);
      expect(find.text('133,00€'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await disposeHarness(tester, container);
    },
  );

  testWidgets('desktop loading quick add mirrors purchase stack spacing', (
    tester,
  ) async {
    final container = await pumpLoadingPdp(
      tester,
      surfaceSize: const Size(1440, 900),
      listingMediaHint: heroProbeMedia,
      enableQuickAdd: true,
      commerceSnapshot: PdpLoadingCommerceSnapshot(
        product: product,
        prices: const [price],
        capturedAt: baseNow,
      ),
    );
    await tester.pump();

    expect(find.byType(StorefrontStickyPanels), findsOneWidget);
    expect(find.byType(PdpLoadingQuickAddSection), findsOneWidget);
    expect(find.byType(PdpPurchaseBar), findsNothing);
    expect(find.text('Corps & Denim'), findsOneWidget);
    expect(find.text('Référence : CORPS-AND-DENIM'), findsOneWidget);
    expect(find.text('Ajouter au panier'), findsOneWidget);
    expect(find.text('133,00€'), findsOneWidget);

    final badges = tester.widget<PdpPaymentBadges>(
      find.byType(PdpPaymentBadges),
    );
    expect(badges.compact, isTrue);

    final referenceBottom = tester
        .getBottomLeft(find.text('Référence : CORPS-AND-DENIM'))
        .dy;
    final referenceRight = tester
        .getTopRight(find.text('Référence : CORPS-AND-DENIM'))
        .dx;
    final paymentTop = tester.getTopLeft(find.byType(PdpPaymentBadges)).dy;
    expect(paymentTop - referenceBottom, closeTo(46, 0.1));
    expect(referenceRight, greaterThan(1300));

    await disposeHarness(tester, container);
  });

  testWidgets('loading quick add prevents double tap after route flight', (
    tester,
  ) async {
    final cartRepository = _FakeCartRepository();
    cartRepository.deferNextAdd();
    final container = await pumpLoadingPdp(
      tester,
      listingMediaHint: heroProbeMedia,
      enableQuickAdd: true,
      cartRepository: cartRepository,
      commerceSnapshot: PdpLoadingCommerceSnapshot(
        product: product,
        prices: const [price],
        capturedAt: baseNow,
      ),
    );
    await tester.pump(const Duration(milliseconds: 560));

    final button = find.byKey(const ValueKey('pdp-loading-quick-add-button'));
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();

    expect(cartRepository.addCalls, 1);

    cartRepository.completeDeferredAdd();
    await tester.pump();
    await disposeHarness(tester, container);
  });

  testWidgets('loading quick add disappears when snapshot ttl expires', (
    tester,
  ) async {
    final container = await pumpLoadingPdp(
      tester,
      listingMediaHint: heroProbeMedia,
      enableQuickAdd: true,
      commerceSnapshot: PdpLoadingCommerceSnapshot(
        product: product,
        prices: const [price],
        capturedAt: baseNow,
      ),
    );

    expect(find.byType(PdpLoadingQuickAddSection), findsOneWidget);
    expect(find.byType(PdpPurchaseBar), findsOneWidget);

    await tester.pump(kPdpLoadingCommerceSnapshotTtl);
    await tester.pump();

    expect(find.byType(PdpLoadingQuickAddSection), findsNothing);
    expect(find.byType(PdpPurchaseBar), findsNothing);
    expect(find.byType(ProductDetailLoadingSkeleton), findsOneWidget);

    await disposeHarness(tester, container);
  });

  testWidgets(
    'loading quick add is gated by endpoint, ttl, currency, and variants',
    (tester) async {
      Future<void> expectNoQuickAdd({
        required PdpLoadingCommerceSnapshot snapshot,
        bool serverValidationEnabled = true,
        DateTime? now,
      }) async {
        final container = await pumpLoadingPdp(
          tester,
          listingMediaHint: heroProbeMedia,
          enableQuickAdd: true,
          serverValidationEnabled: serverValidationEnabled,
          now: now,
          commerceSnapshot: snapshot,
        );
        expect(find.byType(PdpLoadingQuickAddSection), findsNothing);
        expect(find.byType(PdpPurchaseBar), findsNothing);
        await disposeHarness(tester, container);
      }

      await expectNoQuickAdd(
        serverValidationEnabled: false,
        snapshot: PdpLoadingCommerceSnapshot(
          product: product,
          prices: const [price],
          capturedAt: baseNow,
        ),
      );
      await expectNoQuickAdd(
        now: baseNow.add(const Duration(seconds: 61)),
        snapshot: PdpLoadingCommerceSnapshot(
          product: product,
          prices: const [price],
          capturedAt: baseNow,
        ),
      );
      await expectNoQuickAdd(
        snapshot: PdpLoadingCommerceSnapshot(
          product: product,
          prices: const [
            CatalogPrice(
              id: 'price-no-currency',
              productId: 'prod-1',
              price: 133,
              isDefault: true,
              currencySymbol: '€',
              currencyCode: '',
            ),
          ],
          capturedAt: baseNow,
        ),
      );
      await expectNoQuickAdd(
        snapshot: PdpLoadingCommerceSnapshot(
          product: product,
          prices: const [price],
          capturedAt: baseNow,
          hasVariantSelector: true,
        ),
      );
    },
  );

  testWidgets('pdp loading performance logs data ready once', (tester) async {
    final logger = _RecordingPdpLoadingPerformanceLogger();
    final container = await pumpLoadingPdp(
      tester,
      listingMediaHint: heroProbeMedia,
      productRepository: const _ImmediateProductCatalogRepository(
        ProductDetailData(product: product, prices: [price]),
      ),
      tapTrace: PdpLoadingTapTrace(
        productId: 'prod-1',
        tappedAt: baseNow,
        heroEligible: true,
      ),
      performanceLogger: logger,
      now: baseNow.add(const Duration(milliseconds: 240)),
    );

    expect(logger.readyEvents, hasLength(1));
    expect(logger.readyEvents.single.productId, 'prod-1');
    expect(
      logger.readyEvents.single.latency,
      const Duration(milliseconds: 240),
    );
    expect(logger.readyEvents.single.heroEligible, isTrue);

    await tester.pump();

    expect(logger.readyEvents, hasLength(1));
    await disposeHarness(tester, container);
  });

  testWidgets('preserves PDP scroll offset when loading resolves', (
    tester,
  ) async {
    const galleryMedia = CatalogMedia(
      id: 'media-2',
      url: 'https://example.com/media-2.jpg',
      previewUrl: 'https://example.com/media-2-preview.jpg',
    );
    const loadedProduct = CatalogProduct(
      id: 'prod-1',
      code: 'CORPS-AND-DENIM',
      name: 'Corps & Denim',
      picture: heroProbeMedia,
      gallery: [galleryMedia],
    );
    final productRepository = _CompletingProductCatalogRepository();
    final container = await pumpLoadingPdp(
      tester,
      surfaceSize: const Size(390, 760),
      listingMediaHint: heroProbeMedia,
      enableQuickAdd: true,
      commerceSnapshot: PdpLoadingCommerceSnapshot(
        product: product,
        prices: const [price],
        capturedAt: baseNow,
      ),
      productRepository: productRepository,
    );

    final loadingScrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.maxScrollExtent > 0);
    await tester.drag(
      find.byType(ProductDetailLoadingSkeleton),
      const Offset(0, -360),
    );
    await tester.pump();
    final loadingPixels = loadingScrollable.position.pixels;

    expect(loadingPixels, greaterThan(0));

    productRepository.complete(
      const ProductDetailData(product: loadedProduct, prices: [price]),
    );
    await tester.pumpAndSettle();

    final loadedScrollable = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((state) => state.position.maxScrollExtent > 0);

    expect(loadedScrollable.position.pixels, closeTo(loadingPixels, 1));
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.page, 0);
    await disposeHarness(tester, container);
  });

  testWidgets('data branch prefetches the active cart once', (tester) async {
    final cartRepository = _FakeCartRepository();
    final container = await pumpLoadingPdp(
      tester,
      listingMediaHint: heroProbeMedia,
      cartRepository: cartRepository,
      productRepository: const _ImmediateProductCatalogRepository(
        ProductDetailData(product: product, prices: [price]),
      ),
    );

    expect(cartRepository.activeCartLookups, 1);

    await tester.pump();

    expect(cartRepository.activeCartLookups, 1);
    await disposeHarness(tester, container);
  });
}

class _FakeCategoryCatalogRepository implements CategoryCatalogRepository {
  const _FakeCategoryCatalogRepository();

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async =>
      null;

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async => const [];

  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async => null;

  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String locale,
    required String categorySlug,
    required String productSlug,
  }) async => null;

  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async => const CatalogPageData(
    page: 1,
    perPage: 20,
    totalItems: 0,
    totalPages: 0,
    categoryId: '',
    categoryName: '',
    items: [],
  );
}

class _HangingProductCatalogRepository implements ProductCatalogRepository {
  const _HangingProductCatalogRepository();

  @override
  Future<ProductDetailData> getProductDetail(
    String productId, {
    required String locale,
  }) => Completer<ProductDetailData>().future;
}

class _ImmediateProductCatalogRepository implements ProductCatalogRepository {
  final ProductDetailData detail;

  const _ImmediateProductCatalogRepository(this.detail);

  @override
  Future<ProductDetailData> getProductDetail(
    String productId, {
    required String locale,
  }) async => detail;
}

class _CompletingProductCatalogRepository implements ProductCatalogRepository {
  final _completer = Completer<ProductDetailData>();

  @override
  Future<ProductDetailData> getProductDetail(
    String productId, {
    required String locale,
  }) => _completer.future;

  void complete(ProductDetailData detail) {
    _completer.complete(detail);
  }
}

class _RecordingPdpLoadingPerformanceLogger
    implements PdpLoadingPerformanceLogger {
  final readyEvents = <_PdpReadyEvent>[];

  @override
  void tap({required String productId, required bool heroEligible}) {}

  @override
  void dataReady({
    required String productId,
    required Duration latency,
    required bool heroEligible,
  }) {
    readyEvents.add(
      _PdpReadyEvent(
        productId: productId,
        latency: latency,
        heroEligible: heroEligible,
      ),
    );
  }
}

class _PdpReadyEvent {
  final String productId;
  final Duration latency;
  final bool heroEligible;

  const _PdpReadyEvent({
    required this.productId,
    required this.latency,
    required this.heroEligible,
  });
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
  int addCalls = 0;
  int activeCartLookups = 0;
  Completer<CartAddAck>? _deferredAdd;

  void deferNextAdd() {
    _deferredAdd = Completer<CartAddAck>();
  }

  void completeDeferredAdd() {
    _deferredAdd?.complete(_ack);
    _deferredAdd = null;
  }

  static const _ack = CartAddAck(
    cartId: 'cart-1',
    entryProductId: 'prod-1',
    quantityDelta: 1,
    cartCreated: true,
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
  }) {
    addCalls += 1;
    return _deferredAdd?.future ?? Future<CartAddAck>.value(_ack);
  }

  @override
  Future<CartEntry> addEntry({
    required String cartId,
    required CatalogProduct product,
    required CatalogPrice price,
    required int quantity,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Cart> createGuestCart({
    required String guestId,
    required String currencyCode,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CartEntry?> findEntryForProduct({
    required String cartId,
    required String productId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Cart?> findActiveCartForGuest(String guestId) async {
    activeCartLookups += 1;
    return null;
  }

  @override
  Future<CartView> getCartWithEntries(String cartId) async => _emptyCartView;

  @override
  Future<CartView> recomputeAndSaveTotals(String cartId) async =>
      _emptyCartView;

  @override
  Future<void> removeEntry(String entryId) {
    throw UnimplementedError();
  }

  @override
  Future<CartView> clearCart(String cartId) {
    throw UnimplementedError();
  }

  @override
  Future<CartEntry> updateEntryQuantity({
    required CartEntry entry,
    required int quantity,
    double? unitPrice,
  }) {
    throw UnimplementedError();
  }

  static const _emptyCartView = CartView(
    cart: Cart(id: 'cart-1', currencyCode: 'EUR'),
    entries: [],
  );
}
