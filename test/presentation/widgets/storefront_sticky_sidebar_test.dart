import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiki_commerce/presentation/widgets/storefront_layout.dart';

void main() {
  Widget buildSidebarTest({
    required Widget child,
    required ScrollController outScrollController,
    double topOffset = 24.0,
    double containerHeight = 1000.0,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: outScrollController,
          children: [
            Container(height: 200, color: Colors.blue), // Espace au-dessus
            SizedBox(
              height: containerHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.red,
                    ), // Contenu principal pour forcer la hauteur
                  ),
                  SizedBox(
                    width: 300,
                    child: StorefrontStickySidebar(
                      topOffset: topOffset,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 800,
              color: Colors.green,
            ), // Espace en-dessous pour scroller loin
          ],
        ),
      ),
    );
  }

  double getTranslateY(WidgetTester tester) {
    final transformFinder = find.byKey(const Key('sidebar_transform'));
    final transform = tester.widget<Transform>(transformFinder.first);
    return transform.transform.getTranslation().y;
  }

  testWidgets(
    '1. Le scroll met à jour _translateY sans rebuild complet du widget parent',
    (tester) async {
      final scrollController = ScrollController();
      int buildCount = 0;

      await tester.pumpWidget(
        buildSidebarTest(
          outScrollController: scrollController,
          child: Builder(
            builder: (context) {
              buildCount++;
              return Container(height: 300, color: Colors.orange);
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final initialBuildCount = buildCount;
      expect(getTranslateY(tester), 0.0);

      // Scroll de 300 pixels vers le bas (container start=200, topOffset=24 -> it sticks at 176)
      scrollController.jumpTo(300);
      await tester.pump(); // On simule la frame

      // La translation doit avoir bougé pour compenser le scroll
      expect(getTranslateY(tester), greaterThan(0.0));

      // Le buildCount du child ne doit pas avoir augmenté (ValueListenableBuilder prévient le rebuild)
      expect(buildCount, initialBuildCount);
    },
  );

  testWidgets('2. La translation reste bornée entre 0 et maxOffset', (
    tester,
  ) async {
    final scrollController = ScrollController();

    await tester.pumpWidget(
      buildSidebarTest(
        outScrollController: scrollController,
        containerHeight: 1000,
        topOffset: 0,
        child: Container(
          height: 300,
          color: Colors.orange,
        ), // maxOffset = 1000 - 300 = 700
      ),
    );

    await tester.pumpAndSettle();

    // Le haut de la row est à y=200 au départ.
    expect(getTranslateY(tester), 0.0);

    // Scroll tout en bas du conteneur (dépassant maxOffset)
    // 200 (espace haut) + 1000 (conteneur) = 1200
    scrollController.jumpTo(900);
    await tester.pump();

    // La translation ne doit pas dépasser maxOffset (700)
    expect(getTranslateY(tester), 700.0);
  });

  testWidgets('3. Le changement de taille du panel recalcule maxOffset', (
    tester,
  ) async {
    final scrollController = ScrollController();

    // On doit reconstruire StorefrontStickySidebar pour qu'il recalcule maxOffset
    await tester.pumpWidget(
      buildSidebarTest(
        outScrollController: scrollController,
        containerHeight: 1000,
        topOffset: 0,
        child: Container(height: 300, color: Colors.orange),
      ),
    );

    await tester.pumpAndSettle();

    scrollController.jumpTo(900);
    await tester.pumpAndSettle();

    // Max offset est 1000 - 300 = 700
    expect(getTranslateY(tester), 700.0);

    // Change la taille de l'enfant en pumpant un nouveau widget
    await tester.pumpWidget(
      buildSidebarTest(
        outScrollController: scrollController,
        containerHeight: 1000,
        topOffset: 0,
        child: Container(height: 500, color: Colors.orange),
      ),
    );
    await tester.pumpAndSettle(); // pumpAndSettle attend les scheduleMeasure

    // L'enfant fait 500, donc maxOffset devient 1000 - 500 = 500.
    // Comme le scroll est à 900, offset cible est 700 mais clampé à 500.
    expect(getTranslateY(tester), 500.0);
  });

  testWidgets(
    '4. Le child reste hittable/clickable après Transform.translate',
    (tester) async {
      final scrollController = ScrollController();
      bool clicked = false;

      await tester.pumpWidget(
        buildSidebarTest(
          outScrollController: scrollController,
          topOffset: 0,
          child: GestureDetector(
            onTap: () {
              clicked = true;
            },
            child: Container(height: 300, color: Colors.orange),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll pour déplacer la sidebar
      scrollController.jumpTo(300);
      await tester.pump();

      // On clique sur le conteneur déplacé
      await tester.tap(find.byType(GestureDetector));
      expect(clicked, isTrue);
    },
  );
}
