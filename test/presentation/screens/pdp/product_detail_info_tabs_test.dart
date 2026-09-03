import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_info_tabs.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_layout_spec.dart';
import 'package:kiki_commerce/presentation/widgets/animations/text_reveal/text_reveal.dart';
import 'package:kiki_commerce/presentation/widgets/scroll_reveal_text.dart';

import '../../../support/l10n_harness.dart';

void main() {
  const product = CatalogProduct(
    id: 'prod-1',
    code: 'TENSION-SILENCIEUSE',
    name: 'Tension Silencieuse',
    productType: 'Denim',
    brand: 'Kiki',
  );

  Future<void> pumpTabs(
    WidgetTester tester, {
    ProductDetailLayoutSpec layout = const ProductDetailLayoutSpec(
      mode: ProductDetailLayoutMode.mobile,
      maxWidth: 720,
      horizontalPadding: 0,
      heroTopPadding: 0,
      heroGap: 0,
      heroAspectRatio: productDetailMobileHeroAspectRatio,
      heroImageFlex: 0,
      heroTextFlex: 0,
      imagePanelPadding: EdgeInsets.zero,
      detailsPanelPadding: EdgeInsets.fromLTRB(22, 38, 22, 0),
      titleFontSize: 24,
      subtitleFontSize: 14,
      referenceFontSize: 12,
      priceFontSize: 18,
    ),
    String summary =
        'Une allure brute, presque instinctive. Le denim s’impose ici comme '
        'une seconde peau, sculptant la silhouette avec une précision '
        'sensuelle.',
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        locale: const Locale('fr'),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          );
        },
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductDetailInfoTabs(
              product: product,
              layout: layout,
              visibleSummary: summary,
              isEditMode: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('mobile description is a standalone Dior-style block', (
    tester,
  ) async {
    await pumpTabs(tester);

    expect(find.text('Description'), findsNothing);
    expect(find.text('Information Taille & Coupe'), findsOneWidget);
    expect(find.text('Livraison & Retours'), findsOneWidget);
    expect(find.byType(ScrollRevealText), findsNothing);
    expect(find.byType(ScrollLineRevealText), findsOneWidget);
    final revealState = tester.state<ScrollLineRevealTextState>(
      find.byType(ScrollLineRevealText),
    );
    expect(
      revealState.debugVisualLineSegments.expand((line) => line),
      contains('Une'),
    );
  });

  testWidgets('disableAnimations shows the description immediately', (
    tester,
  ) async {
    await pumpTabs(tester, disableAnimations: true);

    final revealState = tester.state<ScrollLineRevealTextState>(
      find.byType(ScrollLineRevealText),
    );
    expect(
      revealState.debugVisualLineSegments.expand((line) => line),
      contains('Une'),
    );
    expect(revealState.debugHasCompleted, isTrue);
    expect(revealState.debugHasController, isFalse);
  });

  testWidgets('same product rebuild does not reset the description reveal', (
    tester,
  ) async {
    await pumpTabs(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    final revealedState = tester.state<ScrollLineRevealTextState>(
      find.byType(ScrollLineRevealText),
    );
    final revealedTarget = revealedState.debugTargetLineCount;
    expect(revealedTarget, greaterThan(0));

    await pumpTabs(tester);

    final rebuiltState = tester.state<ScrollLineRevealTextState>(
      find.byType(ScrollLineRevealText),
    );
    expect(identical(rebuiltState, revealedState), isTrue);
    expect(
      rebuiltState.debugTargetLineCount,
      greaterThanOrEqualTo(revealedTarget),
    );
  });

  testWidgets('show more and show less keep the description expandable', (
    tester,
  ) async {
    const tailMarker = 'signature-fin-description';
    final longSummary =
        '${List.filled(120, 'matière sculptée').join(' ')} $tailMarker';
    await pumpTabs(tester, summary: longSummary, disableAnimations: true);

    expect(find.text('Voir plus'), findsOneWidget);
    expect(find.textContaining(tailMarker), findsNothing);

    await tester.tap(find.text('Voir plus'));
    await tester.pumpAndSettle();

    expect(find.text('Voir moins'), findsOneWidget);
    expect(find.textContaining(tailMarker), findsOneWidget);

    await tester.ensureVisible(find.text('Voir moins'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir moins'));
    await tester.pumpAndSettle();

    expect(find.text('Voir plus'), findsOneWidget);
    expect(find.textContaining(tailMarker), findsNothing);
  });

  testWidgets('show more adds lines without hiding revealed description', (
    tester,
  ) async {
    final longSummary =
        '${List.filled(120, 'matière sculptée').join(' ')} fin revealed';
    await pumpTabs(tester, summary: longSummary);
    await tester.pump(const Duration(milliseconds: 900));

    final initialState = tester.state<ScrollLineRevealTextState>(
      find.byType(ScrollLineRevealText),
    );
    final initialTarget = initialState.debugTargetLineCount;
    final initialLineCount = initialState.debugLineCount;
    expect(initialTarget, greaterThan(0));

    await tester.tap(find.text('Voir plus'));
    await tester.pump();

    final expandedState = tester.state<ScrollLineRevealTextState>(
      find.byType(ScrollLineRevealText),
    );
    expect(identical(expandedState, initialState), isTrue);
    expect(expandedState.debugLineCount, greaterThan(initialLineCount));
    expect(
      expandedState.debugTargetLineCount,
      greaterThanOrEqualTo(initialTarget),
    );
  });
}
