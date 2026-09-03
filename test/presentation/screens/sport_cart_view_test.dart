import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kiki_commerce/application/cart/cart_read_models.dart';
import 'package:kiki_commerce/domain/cart/cart_entities.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/product_providers.dart';
import 'package:kiki_commerce/presentation/screens/checkout/cart_theme_tokens.dart';
import 'package:kiki_commerce/presentation/screens/checkout/sport_cart_checkout_bar.dart';
import 'package:kiki_commerce/presentation/screens/checkout/sport_cart_delivery_section.dart';
import 'package:kiki_commerce/presentation/screens/checkout/sport_cart_view.dart';

import '../../support/l10n_harness.dart';

void main() {
  testWidgets('burning cart fragment shader compiles and instantiates', (
    tester,
  ) async {
    ui.FragmentProgram? program;
    await tester.runAsync(() async {
      program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/cart_burning_texture_fade.frag',
      );
    });
    expect(program, isNotNull);
    expect(program!.fragmentShader(), isNotNull);
  });

  CartEntry entry({
    String id = 'e1',
    String productId = 'p1',
    String name = 'Nike Stride',
    int qty = 1,
    double lineTotal = 129.99,
  }) => CartEntry(
    id: id,
    cartId: 'c1',
    productId: productId,
    productNameSnapshot: name,
    quantity: qty,
    unitPrice: lineTotal,
    lineTotal: lineTotal,
  );

  CartView buildCart(
    List<CartEntry> entries, {
    CartTotals totals = const CartTotals(subtotal: 129.99, grandTotal: 129.99),
  }) => CartView(
    cart: Cart(id: 'c1', currencyCode: 'EUR', userId: 'u1', totals: totals),
    entries: entries,
  );

  Future<void> pumpView(
    WidgetTester tester, {
    required AsyncValue<CartView?> state,
    bool isCartSyncing = false,
    VoidCallback? onShop,
    ValueChanged<CartEntry>? onQuantityEdit,
    Future<bool> Function()? onClearCart,
    VoidCallback? onCheckout,
  }) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CatalogProduct product(String id, String name) =>
        CatalogProduct(id: id, code: id, name: name, summary: 'Desc $name');

    final router = GoRouter(
      initialLocation: '/cart',
      routes: [
        GoRoute(
          path: '/cart',
          builder: (context, _) => SportCartView(
            cartState: state,
            isCartSyncing: isCartSyncing,
            tokens: CartThemeTokens.nike,
            onShop: onShop ?? () {},
            onQuantityEdit: onQuantityEdit ?? (_) {},
            onClearCart: onClearCart ?? () async => true,
            onCheckout: onCheckout ?? () {},
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pdpProvider('p1').overrideWith(
            (ref) async => ProductDetailData(
              product: product('p1', 'Nike Stride'),
              prices: const [],
            ),
          ),
          pdpProvider('p2').overrideWith(
            (ref) async => ProductDetailData(
              product: product('p2', 'Nike Mercurial'),
              prices: const [],
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('multi-product cart renders one pickup block per item', (
    tester,
  ) async {
    await pumpView(
      tester,
      state: AsyncValue.data(
        buildCart([
          entry(id: 'e1', productId: 'p1', name: 'Nike Stride'),
          entry(
            id: 'e2',
            productId: 'p2',
            name: 'Nike Mercurial',
            lineTotal: 279.99,
          ),
        ], totals: const CartTotals(subtotal: 409.98, grandTotal: 409.98)),
      ),
    );

    expect(find.text('Nike Stride'), findsWidgets);
    expect(find.text('Nike Mercurial'), findsWidgets);
    expect(find.text('Retrait le jour même'), findsNWidgets(2));
    expect(find.text('Total estimé'), findsOneWidget);
    expect(find.text('Paiement'), findsOneWidget);
    expect(find.byTooltip('Vider le panier'), findsOneWidget);
    expect(find.byType(SportCartSummary), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SportCartSummary),
        matching: find.text('Total estimé'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SportCartCheckoutBar),
        matching: find.text('Paiement'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SportCartCheckoutBar),
        matching: find.text('Total estimé'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(SportCartCheckoutBar),
        matching: find.byTooltip('Vider le panier'),
      ),
      findsNothing,
    );
    final lastDeliveryBottom = tester
        .getBottomLeft(find.byType(SportCartDeliverySection).last)
        .dy;
    final summaryTop = tester.getTopLeft(find.byType(SportCartSummary)).dy;
    expect(summaryTop, greaterThan(lastDeliveryBottom));
    // Promo section was removed (no fake interaction).
    expect(find.text('As-tu un code promo ?'), findsNothing);
  });

  testWidgets('summary shows shipping/tax/discount lines only when non-zero', (
    tester,
  ) async {
    await pumpView(
      tester,
      state: AsyncValue.data(
        buildCart(
          [entry()],
          totals: const CartTotals(
            subtotal: 100,
            discountTotal: 10,
            shippingTotal: 5,
            taxTotal: 2,
            grandTotal: 97,
          ),
        ),
      ),
    );

    expect(find.text('Sous-total'), findsOneWidget);
    expect(find.text('Remise'), findsOneWidget);
    expect(find.text('Livraison'), findsOneWidget);
    expect(find.text('Taxes incluses'), findsOneWidget);
    // Free-shipping copy must NOT appear when shipping is charged.
    expect(find.text('Standard - Gratuit'), findsNothing);
  });

  testWidgets('tapping the quantity selector invokes onQuantityEdit', (
    tester,
  ) async {
    CartEntry? edited;
    await pumpView(
      tester,
      state: AsyncValue.data(buildCart([entry()])),
      onQuantityEdit: (e) => edited = e,
    );

    await tester.tap(find.text('Qté 1'));
    await tester.pump();
    expect(edited, isNotNull);
    expect(edited!.id, 'e1');
  });

  testWidgets('tapping Paiement invokes onCheckout when not syncing', (
    tester,
  ) async {
    var checkout = 0;
    await pumpView(
      tester,
      state: AsyncValue.data(buildCart([entry()])),
      onCheckout: () => checkout++,
    );

    await tester.tap(find.text('Paiement'));
    await tester.pump();
    expect(checkout, 1);
  });

  testWidgets('tapping the sticky delete-all action reveals the empty cart', (
    tester,
  ) async {
    var cleared = 0;
    await pumpView(
      tester,
      state: AsyncValue.data(buildCart([entry()])),
      onClearCart: () async {
        cleared++;
        return true;
      },
    );

    await tester.tap(find.byTooltip('Vider le panier'));
    expect(cleared, 0);

    await tester.pump();
    await tester.pump();

    expect(cleared, 1);
    expect(find.text('Ton panier est vide.'), findsWidgets);
    expect(find.text('Nike Stride'), findsWidgets);
  });

  testWidgets('delete-all waits for the clear response before burning away', (
    tester,
  ) async {
    final clearCompleter = Completer<bool>();
    var cleared = 0;
    await pumpView(
      tester,
      state: AsyncValue.data(buildCart([entry()])),
      onClearCart: () {
        cleared++;
        return clearCompleter.future;
      },
    );

    await tester.tap(find.byTooltip('Vider le panier'));
    expect(cleared, 0);

    await tester.pump();

    expect(cleared, 1);
    expect(find.text('Ton panier est vide.'), findsNothing);
    expect(find.text('Nike Stride'), findsWidgets);

    clearCompleter.complete(true);
    await tester.pump();

    expect(find.text('Ton panier est vide.'), findsWidgets);
    expect(find.text('Nike Stride'), findsWidgets);
    expect(find.widgetWithText(SportPrimaryButton, 'Acheter'), findsNothing);
  });

  testWidgets('Paiement is disabled and totals show "—" while syncing', (
    tester,
  ) async {
    var checkout = 0;
    await pumpView(
      tester,
      state: AsyncValue.data(buildCart([entry()])),
      isCartSyncing: true,
      onCheckout: () => checkout++,
    );

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Paiement'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull); // disabled
    final clearButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Vider le panier'),
        matching: find.byType(IconButton),
      ),
    );
    expect(clearButton.onPressed, isNull);
    expect(
      find.descendant(
        of: find.byType(SportCartSummary),
        matching: find.text('—'),
      ),
      findsWidgets,
    );

    await tester.tap(find.text('Paiement'), warnIfMissed: false);
    await tester.pump();
    expect(checkout, 0);
  });

  testWidgets('empty cart shows the empty state and Acheter invokes onShop', (
    tester,
  ) async {
    var shopped = 0;
    await pumpView(
      tester,
      state: AsyncValue.data(buildCart([])),
      onShop: () => shopped++,
    );

    expect(find.text('Ton panier est vide.'), findsOneWidget);
    expect(find.text('Paiement'), findsNothing);

    await tester.tap(find.widgetWithText(SportPrimaryButton, 'Acheter'));
    await tester.pump();
    expect(shopped, 1);
  });

  testWidgets('null cart shows the empty state', (tester) async {
    await pumpView(tester, state: const AsyncValue.data(null));
    expect(find.text('Ton panier est vide.'), findsOneWidget);
  });

  testWidgets('receipt action is absent when the cart is empty', (
    tester,
  ) async {
    await pumpView(tester, state: AsyncValue.data(buildCart([])));
    expect(find.byTooltip('Voir la facture'), findsNothing);
  });

  testWidgets('tapping the receipt action prints the itemised receipt', (
    tester,
  ) async {
    await pumpView(
      tester,
      state: AsyncValue.data(
        buildCart([
          entry(name: 'Nike Stride', qty: 2, lineTotal: 259.98),
        ], totals: const CartTotals(subtotal: 259.98, grandTotal: 259.98)),
      ),
    );

    expect(find.byTooltip('Voir la facture'), findsOneWidget);

    await tester.tap(find.byTooltip('Voir la facture'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Receipt content is built (behind the unroll clip) as soon as it prints.
    expect(find.text('TICKET DE CAISSE'), findsOneWidget);
    expect(find.text('NIKE STRIDE'), findsWidgets);
    expect(find.text('TOTAL'), findsOneWidget);
  });
}
