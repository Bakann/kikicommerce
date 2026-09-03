import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/screens/pdp/pdp_animated_heart_button.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_hero.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_layout_spec.dart';
import 'package:kiki_commerce/presentation/widgets/animations/text_reveal/text_reveal.dart';

void main() {
  const product = CatalogProduct(
    id: 'prod-1',
    code: 'CORPS-AND-DENIM',
    name: 'Corps & Denim',
    slug: 'corps-denim',
    productType: 'Denim',
    brand: 'Kiki',
  );
  const price = CatalogPrice(
    id: 'price-1',
    productId: 'prod-1',
    price: 133,
    isDefault: true,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );
  const summaryRevealKey = ValueKey('pdp-summary-text-prod-1-corps-denim');
  const mobileLayout = ProductDetailLayoutSpec(
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
  );

  void setSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  PdpHeroContext heroContext({required Widget detailTabs}) {
    return PdpHeroContext(
      product: product,
      layout: mobileLayout,
      pendingMedia: const {},
      isEditMode: false,
      allMedia: const [],
      defaultPrice: price,
      originalPrice: null,
      discount: null,
      symbol: '€',
      isNew: false,
      hasVariantSelector: false,
      heroBreadcrumbOverlay: const SizedBox.shrink(),
      detailTabs: detailTabs,
      mobilePurchaseAnchorKey: null,
      onPickPhoto: (_, _) {},
      onPickMedia: (_, _) {},
      onRemoveMedia: (_, _) {},
      onMoveMedia: (_, _, _) {},
      onSetFirstMedia: (_, _) {},
      onAddMedia: () {},
      carouselScrollTargetMediaId: null,
      onCarouselScrollTargetHandled: (_) {},
      onEditTranslations: () {},
      onSavePrice: (_) async => true,
      onAddToCart: () async => true,
      onOpenVisionModal: null,
      mainImageHeroTag: null,
    );
  }

  Future<void> pumpHero(WidgetTester tester, {required Widget detailTabs}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MobileHeroBody(
              heroContext: heroContext(detailTabs: detailTabs),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('same-product rebuild does not reset revealed summary text', (
    tester,
  ) async {
    setSurface(tester);

    await pumpHero(tester, detailTabs: const Text('initial detail tabs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final revealedState = tester.state<TextRevealGroupState>(
      find.byKey(summaryRevealKey),
    );
    expect(find.text('Corps & Denim'), findsOneWidget);
    expect(find.text('Denim • Kiki'), findsOneWidget);
    expect(find.text('Référence : CORPS-AND-DENIM'), findsOneWidget);
    expect(revealedState.debugHasStarted, isTrue);
    expect(revealedState.debugHasCompleted, isTrue);

    await pumpHero(tester, detailTabs: const Text('rebuilt detail tabs'));

    final rebuiltState = tester.state<TextRevealGroupState>(
      find.byKey(summaryRevealKey),
    );
    expect(identical(rebuiltState, revealedState), isTrue);
    expect(rebuiltState.debugHasStarted, isTrue);
    expect(rebuiltState.debugHasCompleted, isTrue);
  });

  testWidgets('favorite heart plays like and unlike reactions', (tester) async {
    setSurface(tester);

    await pumpHero(tester, detailTabs: const Text('detail tabs'));
    await tester.pump();

    final heart = find.byKey(kPdpFavoriteHeartButtonKey);
    expect(heart, findsOneWidget);

    await tester.tap(heart);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);

    await tester.tap(heart);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
  });
}
