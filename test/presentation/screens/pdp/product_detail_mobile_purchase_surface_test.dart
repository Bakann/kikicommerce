import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiki_commerce/presentation/screens/pdp/product_detail_mobile_purchase_surface.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_purchase.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/premium_shell_navbar.dart';
import 'package:kiki_commerce/presentation/widgets/pdp_purchase_bar.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';

void main() {
  Widget buildTestSurface({
    required GlobalKey anchorKey,
    required ScrollController outScrollController,
    required VoidCallback debugOnAnchorMeasured,
    ValueChanged<Rect>? debugOnOverlayRectChanged,
    Size mediaSize = const Size(400, 800),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: mediaSize),
          child: MobilePdpPurchaseSurface(
            anchorKey: anchorKey,
            debugOnAnchorMeasured: debugOnAnchorMeasured,
            debugOnOverlayRectChanged: debugOnOverlayRectChanged,
            defaultPrice: const CatalogPrice(
              id: 'test_price',
              productId: 'test_product',
              price: 100.0,
              currencySymbol: '€',
            ),
            symbol: '€',
            onAddToCart: () async => true,
            scrollBuilder: (controller) {
              return ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) {
                  if (index == 10) {
                    return Container(
                      key: anchorKey,
                      height: 100,
                      color: Colors.red,
                    );
                  }
                  return Container(
                    height: 100,
                    color: index.isEven ? Colors.blue : Colors.green,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets(
    '1. Scroll continu : ne schedule pas de mesure pendant le scroll update, mais estime',
    (tester) async {
      final anchorKey = GlobalKey();
      final dummyController = ScrollController();
      int measureCount = 0;

      await tester.pumpWidget(
        buildTestSurface(
          anchorKey: anchorKey,
          outScrollController: dummyController,
          debugOnAnchorMeasured: () => measureCount++,
        ),
      );

      await tester.pumpAndSettle();

      final initialCount = measureCount;
      expect(initialCount, greaterThanOrEqualTo(1));

      // Scroll continu sans relâcher (drag)
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await gesture.moveBy(const Offset(0, -200));
      // Un pump simple pour simuler la frame pendant le drag
      await tester.pump();

      // Vérifie que debugMeasureCount n'a pas augmenté pendant le mouvement de défilement continu
      expect(measureCount, initialCount);

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '2. ScrollEndNotification : déclenche une recalibration de l\'ancre',
    (tester) async {
      final anchorKey = GlobalKey();
      final dummyController = ScrollController();
      int measureCount = 0;

      await tester.pumpWidget(
        buildTestSurface(
          anchorKey: anchorKey,
          outScrollController: dummyController,
          debugOnAnchorMeasured: () => measureCount++,
        ),
      );

      await tester.pumpAndSettle();

      final initialCount = measureCount;

      // Fling -> génère un drag puis une phase de scroll inertiel, et se termine par un ScrollEndNotification
      await tester.fling(find.byType(ListView), const Offset(0, -500), 1000);
      await tester.pumpAndSettle(); // Attend la fin du fling et des microtasks

      // Le count doit avoir augmenté après le ScrollEndNotification
      expect(measureCount, greaterThan(initialCount));
    },
  );

  testWidgets(
    '3. Drag sur la barre d\'achat : pointeur move scrolle sans mesure, pointeur up mesure',
    (tester) async {
      final anchorKey = GlobalKey();
      final dummyController = ScrollController();
      int measureCount = 0;

      await tester.pumpWidget(
        buildTestSurface(
          anchorKey: anchorKey,
          outScrollController: dummyController,
          debugOnAnchorMeasured: () => measureCount++,
        ),
      );

      await tester.pumpAndSettle();

      final initialCount = measureCount;

      // Récupère le Listener qui écoute les events drag de la barre
      final barFinder = find.byType(PdpPurchaseBar);
      final listenerFinder = find
          .ancestor(of: barFinder, matching: find.byType(Listener))
          .first;

      // Démarre un drag manuellement pour avoir le contrôle fin
      final gesture = await tester.startGesture(
        tester.getCenter(listenerFinder),
      );

      // Déplace le curseur
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();

      // Vérifie qu'il n'y a pas de nouvelle mesure pendant le move
      expect(measureCount, initialCount);

      // Relâche le curseur (déclenche PointerUp)
      await gesture.up();
      await tester.pumpAndSettle();

      // Vérifie que la mesure a été effectuée à la fin du geste
      expect(measureCount, greaterThan(initialCount));
    },
  );

  testWidgets('4. Changement de viewport/padding : schedule une recalibration', (
    tester,
  ) async {
    final anchorKey = GlobalKey();
    final dummyController = ScrollController();
    int measureCount = 0;

    await tester.pumpWidget(
      buildTestSurface(
        anchorKey: anchorKey,
        outScrollController: dummyController,
        debugOnAnchorMeasured: () => measureCount++,
        mediaSize: const Size(400, 800),
      ),
    );

    await tester.pumpAndSettle();

    final initialCount = measureCount;

    // Change la taille de l'écran pour simuler une rotation ou un redimensionnement
    await tester.pumpWidget(
      buildTestSurface(
        anchorKey: anchorKey,
        outScrollController: dummyController,
        debugOnAnchorMeasured: () => measureCount++,
        mediaSize: const Size(400, 600), // Hauteur réduite
      ),
    );
    await tester.pumpAndSettle();

    // La mesure doit être relancée
    expect(measureCount, greaterThan(initialCount));
  });

  testWidgets('5. Position visuelle de la barre mise à jour via offset', (
    tester,
  ) async {
    final anchorKey = GlobalKey();
    int measureCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: MobilePdpPurchaseSurface(
              anchorKey: anchorKey,
              debugOnAnchorMeasured: () => measureCount++,
              defaultPrice: const CatalogPrice(
                id: 'test_price',
                productId: 'test_product',
                price: 100.0,
                currencySymbol: '€',
              ),
              symbol: '€',
              onAddToCart: () async => true,
              scrollBuilder: (controller) {
                return ListView.builder(
                  controller: controller,
                  itemCount: 50,
                  itemBuilder: (context, index) {
                    if (index == 2) {
                      // Changed to 2 so it is initially visible at top=200
                      return Container(
                        key: anchorKey,
                        height: 100,
                        color: Colors.red,
                      );
                    }
                    return Container(
                      height: 100,
                      color: index.isEven ? Colors.blue : Colors.green,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final beforeTopLeft = tester.getTopLeft(find.byType(PdpPurchaseBar));

    // Scroll continu sans relâcher (drag) pour voir que l'offset bouge sans mesure
    final initialCount = measureCount;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump();

    final afterTopLeft = tester.getTopLeft(find.byType(PdpPurchaseBar));

    expect(afterTopLeft.dy, isNot(equals(beforeTopLeft.dy)));
    expect(measureCount, initialCount);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    '6. Mode épinglé : aucune notification de rect pendant le scroll',
    (tester) async {
      // Garantit le dédoublonnage : tant que l\'ancre reste hors viewport
      // (overlay en mode "fixed"), _purchaseRect retourne la même Rect
      // d\'un tick de scroll à l\'autre et le ValueNotifier ne doit pas
      // émettre.
      final anchorKey = GlobalKey();
      final dummyController = ScrollController();
      int measureCount = 0;
      int rectChangeCount = 0;

      await tester.pumpWidget(
        buildTestSurface(
          anchorKey: anchorKey,
          outScrollController: dummyController,
          debugOnAnchorMeasured: () => measureCount++,
          debugOnOverlayRectChanged: (_) => rectChangeCount++,
        ),
      );

      await tester.pumpAndSettle();

      // Le seed initial + un éventuel ajustement post-mesure comptent.
      final initialRectChanges = rectChangeCount;
      expect(initialRectChanges, greaterThanOrEqualTo(1));

      // Scroll continu, petites variations qui maintiennent l\'ancre
      // (index 10, y≈1000) sous le viewport (800px).
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();

      // Aucune nouvelle notification de rect : la dedup a fait son travail.
      expect(rectChangeCount, initialRectChanges);

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('7. Mode épinglé en haut : reste sous la navbar visible', (
    tester,
  ) async {
    final anchorKey = GlobalKey();
    late ScrollController scrollController;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: PremiumShellNavbarMetrics(
              isVisible: true,
              reservedHeight: 74,
              child: MobilePdpPurchaseSurface(
                anchorKey: anchorKey,
                debugOnAnchorMeasured: () {},
                defaultPrice: const CatalogPrice(
                  id: 'test_price',
                  productId: 'test_product',
                  price: 100.0,
                  currencySymbol: '€',
                ),
                symbol: '€',
                onAddToCart: () async => true,
                scrollBuilder: (controller) {
                  scrollController = controller;
                  return ListView.builder(
                    controller: controller,
                    itemCount: 50,
                    itemBuilder: (context, index) {
                      if (index == 2) {
                        return Container(
                          key: anchorKey,
                          height: 100,
                          color: Colors.red,
                        );
                      }
                      return Container(
                        height: 100,
                        color: index.isEven ? Colors.blue : Colors.green,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    scrollController.jumpTo(260);
    await tester.pump();

    expect(tester.getTopLeft(find.byType(PdpPurchaseBar)).dy, 94);
  });

  testWidgets(
    '8. Ancre avec bouton: pas de bouton fallback en double avant mesure',
    (tester) async {
      final anchorKey = GlobalKey();
      const price = CatalogPrice(
        id: 'test_price',
        productId: 'test_product',
        price: 100.0,
        currencySymbol: '€',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(size: Size(400, 800)),
              child: MobilePdpPurchaseSurface(
                anchorKey: anchorKey,
                defaultPrice: price,
                symbol: '€',
                onAddToCart: () async => true,
                scrollBuilder: (controller) {
                  return ListView(
                    controller: controller,
                    children: [
                      Container(height: 200, color: Colors.blue),
                      MobilePurchaseAnchor(
                        key: anchorKey,
                        child: PdpPurchaseBar(
                          defaultPrice: price,
                          symbol: '€',
                          onAddToCart: () async => true,
                          includeSafeArea: false,
                          height: kMobilePurchaseBarHeight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Container(height: 800, color: Colors.green),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PdpPurchaseBar), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(PdpPurchaseBar), findsOneWidget);
    },
  );
}
