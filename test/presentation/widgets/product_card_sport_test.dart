import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/cart/cart_guest_session_store.dart';
import 'package:kiki_commerce/application/cart/cart_read_models.dart';
import 'package:kiki_commerce/application/cart/cart_repository.dart';
import 'package:kiki_commerce/application/storefront/storefront_plp_profile.dart';
import 'package:kiki_commerce/domain/cart/cart_entities.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/cart_flight_coordinator_provider.dart';
import 'package:kiki_commerce/presentation/widgets/animations/add_to_cart_comet/add_to_cart_comet.dart';
import 'package:kiki_commerce/presentation/widgets/product_card.dart';

const _listingMedia = CatalogMedia(
  id: 'media-listing',
  url: 'https://example.com/listing.jpg',
  previewUrl: 'https://example.com/listing-preview.jpg',
);

const _productWithSummary = CatalogProduct(
  id: 'product-1',
  code: 'PRODUCT-1',
  name: 'Nike Stride',
  summary: 'Veste de running déperlante avec protection UV pour homme.',
  picture: _listingMedia,
);

const _productNoSummary = CatalogProduct(
  id: 'product-2',
  code: 'PRODUCT-2',
  name: 'Nike Stride Short',
  picture: _listingMedia,
);

const _defaultPrice = CatalogPrice(
  id: 'price-1',
  productId: 'product-1',
  price: 21,
  isDefault: true,
  currencySymbol: '€',
  currencyCode: 'EUR',
);

Widget _harness({
  required CatalogProduct product,
  required ProductCardPresentation presentation,
  List<CatalogPrice> prices = const [],
  Size size = const Size(240, 480),
  double textScaleFactor = 1,
  ProductCardStickyImageActionSpec? stickyImageActionSpec,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: ProductCard(
              product: product,
              prices: prices,
              routeName: '/products/product-1',
              presentation: presentation,
              stickyImageActionSpec: stickyImageActionSpec,
            ),
          ),
        ),
      ),
    ),
  );
}

int _bubblePaintCount(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .where(
        (widget) =>
            widget.painter != null &&
            widget.painter.runtimeType.toString() == '_BubblePopPainter',
      )
      .length;
}

void main() {
  group('ProductCard — sport presentation', () {
    testWidgets('renders the summary line when one is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          product: _productWithSummary,
          presentation: ProductCardPresentation.sportPerformance,
        ),
      );

      expect(find.text('Nike Stride'), findsOneWidget);
      expect(
        find.text('Veste de running déperlante avec protection UV pour homme.'),
        findsOneWidget,
      );
    });

    testWidgets('omits the summary line when product has none', (tester) async {
      await tester.pumpWidget(
        _harness(
          product: _productNoSummary,
          presentation: ProductCardPresentation.sportPerformance,
        ),
      );

      expect(find.text('Nike Stride Short'), findsOneWidget);
      // No summary on this product — the gray subtitle line should not
      // render an empty box.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data ==
                  'Veste de running déperlante avec protection UV pour homme.',
        ),
        findsNothing,
      );
    });

    testWidgets('shows the add-to-cart affordance overlaid on the image', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          product: _productWithSummary,
          presentation: ProductCardPresentation.sportPerformance,
        ),
      );

      expect(find.byIcon(Icons.add_shopping_cart_outlined), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });

    testWidgets('handles long copy with new label and discount', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          size: const Size(180, 360),
          product: CatalogProduct(
            id: 'product-long',
            code: 'PRODUCT-LONG',
            name: 'Nike Mercurial Vapor Elite Terrain Sec Edition Performance',
            summary:
                'Chaussure de foot basse à crampons pour terrain sec avec maintien dynamique et toucher de balle précis.',
            onlineDate: DateTime.now().subtract(const Duration(days: 2)),
            picture: _listingMedia,
          ),
          prices: const [
            CatalogPrice(
              id: 'price-default',
              productId: 'product-long',
              price: 279.99,
              isDefault: true,
            ),
            CatalogPrice(
              id: 'price-original',
              productId: 'product-long',
              price: 329.99,
            ),
          ],
          presentation: ProductCardPresentation.sportPerformance,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Dernières sorties'), findsOneWidget);
      expect(find.text('-15%'), findsOneWidget);
    });

    testWidgets('handles increased text scale on compact cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          size: const Size(180, 390),
          textScaleFactor: 1.3,
          product: CatalogProduct(
            id: 'product-scaled',
            code: 'PRODUCT-SCALED',
            name: 'Nike Phantom Elite Terrain Sec Performance',
            summary:
                'Chaussure de foot basse à crampons pour terrain sec avec maintien dynamique.',
            onlineDate: DateTime.now().subtract(const Duration(days: 2)),
            picture: _listingMedia,
          ),
          prices: const [
            CatalogPrice(
              id: 'price-default',
              productId: 'product-scaled',
              price: 279.99,
              isDefault: true,
            ),
            CatalogPrice(
              id: 'price-original',
              productId: 'product-scaled',
              price: 329.99,
            ),
          ],
          presentation: ProductCardPresentation.sportPerformance,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Dernières sorties'), findsOneWidget);
      expect(find.text('-15%'), findsOneWidget);
    });

    testWidgets(
      'tapping add-to-cart without a price shows a snackbar and does NOT trigger PDP nav',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            product: _productWithSummary,
            presentation: ProductCardPresentation.sportPerformance,
          ),
        );

        // If the gesture bubbled to the outer GestureDetector, openProductDetail
        // would fire and throw (no router/CMS providers wired in the harness).
        // The snackbar appearing and no exception being thrown prove that the
        // add-to-cart button consumed the tap.
        expect(_bubblePaintCount(tester), 0);

        await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(_bubblePaintCount(tester), 1);
        await tester.pump(const Duration(milliseconds: 280));

        expect(tester.takeException(), isNull);
        expect(find.text('Prix indisponible'), findsOneWidget);
      },
    );

    testWidgets('opens the added top sheet after the sticker flight lands', (
      tester,
    ) async {
      final cartRepository = _FakeCardCartRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guestSessionStoreProvider.overrideWithValue(
              const _FakeCardGuestSessionStore(),
            ),
            cartRepositoryProvider.overrideWithValue(cartRepository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 240,
                height: 480,
                child: ProductCard(
                  product: _productWithSummary,
                  prices: const [_defaultPrice],
                  routeName: '/products/product-1',
                  presentation: ProductCardPresentation.sportPerformance,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));

      expect(cartRepository.addedProductIds, const ['product-1']);
      expect(find.text('Produit ajouté au panier'), findsNothing);

      // The gate sits at 1250 ms from the tap: sticker landed (1100 ms) and
      // cart-icon pop under way.
      await tester.pump(const Duration(milliseconds: 929));
      expect(find.text('Produit ajouté au panier'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Produit ajouté au panier'), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'keeps the glass add-to-cart action pinned while the image scrolls',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 240,
                  height: 320,
                  child: ListView(
                    controller: controller,
                    children: [
                      SizedBox(
                        width: 240,
                        height: 480,
                        child: ProductCard(
                          product: _productWithSummary,
                          prices: const [],
                          routeName: '/products/product-1',
                          presentation:
                              ProductCardPresentation.sportPerformance,
                          stickyImageActionSpec:
                              ProductCardStickyImageActionSpec(
                                scrollController: controller,
                                imageScrollOffset: 0,
                                imageExtent: 240,
                                viewportPinTop: 10,
                              ),
                        ),
                      ),
                      const SizedBox(height: 400),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        final icon = find.byIcon(Icons.add_shopping_cart_outlined);
        final initialTop = tester.getTopLeft(icon).dy;

        await tester.drag(find.byType(ListView), const Offset(0, -80));
        await tester.pump();

        expect(tester.getTopLeft(icon).dy, closeTo(initialTop, 0.1));
      },
    );
  });

  group('ProductCard — add-to-cart comet', () {
    final cometPaint = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is CometTrailPainter,
    );

    Future<ProviderContainer> pumpCardWithAnchor(
      WidgetTester tester, {
      required CartRepository cartRepository,
      bool disableAnimations = false,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guestSessionStoreProvider.overrideWithValue(
              const _FakeCardGuestSessionStore(),
            ),
            cartRepositoryProvider.overrideWithValue(cartRepository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(disableAnimations: disableAnimations),
                child: SizedBox(
                  width: 240,
                  height: 480,
                  child: ProductCard(
                    product: _productWithSummary,
                    prices: const [_defaultPrice],
                    routeName: '/products/product-1',
                    presentation: ProductCardPresentation.sportPerformance,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProductCard)),
      );
      // Stand-in for the bottom-nav cart tile (not part of this harness).
      container
          .read(cartFlightCoordinatorProvider.notifier)
          .registerCartAnchor(
            'test-anchor',
            () => const Rect.fromLTWH(300, 560, 24, 24),
          );
      return container;
    }

    testWidgets('tap flies the clone to the anchor and pops at impact', (
      tester,
    ) async {
      final cartRepository = _FakeCardCartRepository();
      final container = await pumpCardWithAnchor(
        tester,
        cartRepository: cartRepository,
      );
      CartFlightBadgeState state() =>
          container.read(cartFlightCoordinatorProvider);

      await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
      await tester.pump(); // sticker overlay entry mounted
      await tester.pump(); // its ticker takes its first tick (t = 0)
      expect(cometPaint, findsOneWidget);

      // Past the 320 ms bubble lead-in: the optimistic add lands and is
      // masked; the comet (t = 400 ms) has not impacted yet.
      await tester.pump(const Duration(milliseconds: 400));
      expect(cartRepository.addedProductIds, const ['product-1']);
      expect(state().pendingBadgeDeferrals, 1);
      expect(state().impactTick, 0);

      // t = 920 ms: past the snap start (raw t = 0.82 → 902 ms of the
      // 1100 ms sticker timeline) — deferral released, one pop.
      await tester.pump(const Duration(milliseconds: 520));
      expect(state().pendingBadgeDeferrals, 0);
      expect(state().impactTick, 1);

      // t = 1120 ms: flight over, overlay removed.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(cometPaint, findsNothing);

      // The cart top sheet opens at its 1250 ms gate, after the landing.
      await tester.pump(const Duration(milliseconds: 129));
      expect(find.text('Produit ajouté au panier'), findsNothing);
      await tester.pump(const Duration(milliseconds: 2));
      expect(find.text('Produit ajouté au panier'), findsOneWidget);

      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });

    testWidgets('failed add: comet cleans up without any celebration', (
      tester,
    ) async {
      final container = await pumpCardWithAnchor(
        tester,
        cartRepository: _ThrowingCartRepository(),
      );

      await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
      await tester.pump();
      await tester.pump();
      expect(cometPaint, findsOneWidget);

      // Through the failed add (~320 ms), the impact instant and the end of
      // the flight: no tick, no deferral, overlay gone, snackbar shown.
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();
      expect(cometPaint, findsNothing);
      final state = container.read(cartFlightCoordinatorProvider);
      expect(state.impactTick, 0);
      expect(state.pendingBadgeDeferrals, 0);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: adds to cart without any comet', (
      tester,
    ) async {
      final cartRepository = _FakeCardCartRepository();
      final container = await pumpCardWithAnchor(
        tester,
        cartRepository: cartRepository,
        disableAnimations: true,
      );

      await tester.tap(find.byIcon(Icons.add_shopping_cart_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(cometPaint, findsNothing);
      expect(cartRepository.addedProductIds, const ['product-1']);
      final state = container.read(cartFlightCoordinatorProvider);
      expect(state.impactTick, 0);
      expect(state.pendingBadgeDeferrals, 0);
      await tester.pumpAndSettle();
    });
  });

  group('ProductCard — editorial presentation', () {
    testWidgets('does not render summary nor favorite affordance', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          product: _productWithSummary,
          presentation: ProductCardPresentation.editorial,
        ),
      );

      expect(
        find.text('Veste de running déperlante avec protection UV pour homme.'),
        findsNothing,
      );
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(find.byIcon(Icons.add_shopping_cart_outlined), findsNothing);
    });
  });
}

class _FakeCardGuestSessionStore implements CartGuestSessionStore {
  const _FakeCardGuestSessionStore();

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

class _ThrowingCartRepository extends _FakeCardCartRepository {
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
    throw StateError('add rejected');
  }
}

class _FakeCardCartRepository implements CartRepository {
  final addedProductIds = <String>[];
  Cart? cart;
  CartEntry? entry;

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
    cart = Cart(
      id: cachedCartId ?? 'cart-1',
      guestId: guestId,
      currencyCode: price.currencyCode ?? 'EUR',
    );
    entry = CartEntry(
      id: 'entry-1',
      cartId: cart!.id,
      productId: product.id,
      productNameSnapshot: product.name,
      quantity: quantity,
      unitPrice: price.price,
      lineTotal: price.price * quantity,
    );
    return CartAddAck(
      cartId: cart!.id,
      entryProductId: product.id,
      quantityDelta: quantity,
      cartCreated: false,
    );
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
  Future<Cart?> findActiveCartForGuest(String guestId) async => cart;

  @override
  Future<CartEntry?> findEntryForProduct({
    required String cartId,
    required String productId,
  }) async => entry;

  @override
  Future<CartView> getCartWithEntries(String cartId) async =>
      recomputeAndSaveTotals(cartId);

  @override
  Future<void> removeEntry(String entryId) async {
    entry = null;
  }

  @override
  Future<CartView> clearCart(String cartId) async {
    entry = null;
    return recomputeAndSaveTotals(cartId);
  }

  @override
  Future<CartView> recomputeAndSaveTotals(String cartId) async {
    final currentCart =
        cart ??
        const Cart(id: 'cart-1', guestId: 'guest-1', currencyCode: 'EUR');
    return CartView(cart: currentCart, entries: [?entry]);
  }

  @override
  Future<CartEntry> updateEntryQuantity({
    required CartEntry entry,
    required int quantity,
    double? unitPrice,
  }) {
    throw UnimplementedError();
  }
}
