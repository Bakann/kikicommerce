import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_loading_skeleton.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_purchase.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_layout_spec.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_page.dart';
import 'package:kiki_commerce/presentation/widgets/pdp_water_ripple_image.dart';
import 'package:kiki_commerce/presentation/widgets/pdp_purchase_bar.dart';
import 'package:kiki_commerce/presentation/widgets/product_hero_tags.dart';

void main() {
  const productId = 'p1';
  const listingMedia = CatalogMedia(
    id: 'media-1',
    url: 'https://example.com/p1.jpg',
    previewUrl: 'https://example.com/p1-preview.jpg',
  );
  const price = CatalogPrice(
    id: 'price-1',
    productId: productId,
    price: 133,
    isDefault: true,
    currencySymbol: '€',
    currencyCode: 'EUR',
  );

  Widget pumpPlaceholder(ProductDetailLayoutSpec layout, {Widget? quickAdd}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PdpHeroPlaceholder(
            productId: productId,
            listingMedia: listingMedia,
            layout: layout,
            loadingQuickAdd: quickAdd,
          ),
        ),
      ),
    );
  }

  Widget quickAddFor(ProductDetailLayoutSpec layout) {
    return PdpLoadingQuickAddSection(
      layout: layout,
      defaultPrice: price,
      symbol: '€',
      onAddToCart: () async => true,
    );
  }

  ProductDetailLayoutSpec layoutFor(double width) =>
      ProductDetailLayoutSpec.forWidth(width);

  testWidgets('mobile placeholder mounts a Hero with the matching tag', (
    tester,
  ) async {
    await tester.pumpWidget(pumpPlaceholder(layoutFor(360)));
    await tester.pump();

    final heroFinder = find.byWidgetPredicate(
      (w) => w is Hero && w.tag == productImageHeroTag(productId),
    );
    expect(heroFinder, findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);
  });

  testWidgets('split layout mounts a Hero with the matching tag', (
    tester,
  ) async {
    await tester.pumpWidget(pumpPlaceholder(layoutFor(900)));
    await tester.pump();

    final heroFinder = find.byWidgetPredicate(
      (w) => w is Hero && w.tag == productImageHeroTag(productId),
    );
    expect(heroFinder, findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);
  });

  testWidgets('desktop layout mounts a Hero with the matching tag', (
    tester,
  ) async {
    await tester.pumpWidget(pumpPlaceholder(layoutFor(1280)));
    await tester.pump();

    final heroFinder = find.byWidgetPredicate(
      (w) => w is Hero && w.tag == productImageHeroTag(productId),
    );
    expect(heroFinder, findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);
  });

  testWidgets('mobile placeholder renders details skeleton below the image', (
    tester,
  ) async {
    await tester.pumpWidget(pumpPlaceholder(layoutFor(360)));
    await tester.pump();

    expect(find.byType(ProductDetailLoadingSkeleton), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pdp-loading-details-skeleton')),
      findsOneWidget,
    );
    expect(find.byType(Hero), findsOneWidget);
  });

  testWidgets('split layout renders details skeleton in the right column', (
    tester,
  ) async {
    await tester.pumpWidget(pumpPlaceholder(layoutFor(900)));
    await tester.pump();

    expect(find.byType(ProductDetailLoadingSkeleton), findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);
  });

  testWidgets('desktop layout renders details skeleton in the right column', (
    tester,
  ) async {
    await tester.pumpWidget(pumpPlaceholder(layoutFor(1280)));
    await tester.pump();

    expect(find.byType(ProductDetailLoadingSkeleton), findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);
  });

  testWidgets(
    'Hero child paints a NetworkImage of the listing URL (no CachedNetworkImage)',
    (tester) async {
      await tester.pumpWidget(pumpPlaceholder(layoutFor(360)));
      await tester.pump();

      final imageFinder = find.descendant(
        of: find.byType(Hero),
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(image.image, isA<NetworkImage>());
      expect((image.image as NetworkImage).url, listingMedia.listingUrl);
      // Regression guard: must not use CachedNetworkImage providers.
      // CachedNetworkImageProvider routes through flutter_cache_manager
      // (empty on web) and would not hit the Skia ImageCache key the
      // shuttle warmed at tap time.
      expect(image.image, isNot(isA<CachedNetworkImageProvider>()));
      expect(
        find.descendant(
          of: find.byType(Hero),
          matching: find.byType(PdpWaterRipple),
        ),
        findsOneWidget,
      );
      // Hero uses the productImageHeroFlightShuttleBuilder so the flight
      // pixels match the source side; verify the shuttle builder is wired.
      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.flightShuttleBuilder, isNotNull);
    },
  );

  testWidgets(
    'split layout splits the screen into image and details flex columns',
    (tester) async {
      await tester.pumpWidget(pumpPlaceholder(layoutFor(900)));
      await tester.pump();

      // The non-mobile placeholder lives in a Row with two Expanded
      // children sized via the layout flex. Mobile uses StorefrontFullBleed
      // wrap instead.
      final rowFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Row &&
            widget.children.length == 2 &&
            widget.children.every((child) => child is Expanded),
      );
      expect(rowFinder, findsOneWidget);
      final row = tester.widget<Row>(rowFinder);
      expect(row.children.length, 2);
    },
  );

  testWidgets('mobile quick add uses the mobile purchase bar with price', (
    tester,
  ) async {
    final layout = layoutFor(360);
    await tester.pumpWidget(
      pumpPlaceholder(layout, quickAdd: quickAddFor(layout)),
    );
    await tester.pump();

    expect(find.byType(Hero), findsOneWidget);
    expect(find.byType(PdpPurchaseBar), findsOneWidget);
    expect(find.byType(HeroPurchaseButton), findsNothing);
    expect(find.text('Ajouter au panier'), findsOneWidget);
    expect(find.text('133,00€'), findsOneWidget);
  });

  testWidgets('desktop quick add uses the hero purchase button with price', (
    tester,
  ) async {
    final layout = layoutFor(1280);
    await tester.pumpWidget(
      pumpPlaceholder(layout, quickAdd: quickAddFor(layout)),
    );
    await tester.pump();

    expect(find.byType(Hero), findsOneWidget);
    expect(find.byType(HeroPurchaseButton), findsOneWidget);
    expect(find.byType(PdpPurchaseBar), findsNothing);
    expect(find.text('Ajouter au panier'), findsOneWidget);
    expect(find.text('133,00€'), findsOneWidget);
  });

  testWidgets('quick add fallback ignores taps before route flight fallback', (
    tester,
  ) async {
    var addCalls = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 1200)),
          child: Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 390,
                child: PdpLoadingQuickAddSection(
                  layout: layoutFor(360),
                  defaultPrice: price,
                  symbol: '€',
                  onAddToCart: () async {
                    addCalls += 1;
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final button = find.byKey(const ValueKey('pdp-loading-quick-add-button'));
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();

    expect(addCalls, 0);

    await tester.pump(const Duration(milliseconds: 560));
    await tester.tap(button);
    await tester.pump();

    expect(addCalls, 1);
  });
}
