import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_layout_spec.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_narrative_section.dart';
import 'package:kiki_commerce/presentation/widgets/image_carousel.dart';

import '../../support/l10n_harness.dart';

void main() {
  testWidgets(
    'keeps active narrative image aligned when resizing from desktop to mobile',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _NarrativeHarness(
          layout: ProductDetailLayoutSpec.forWidth(1200),
          images: _media,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -900),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Chapter two'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);

      tester.view.physicalSize = const Size(390, 900);
      await tester.pumpWidget(
        _NarrativeHarness(
          layout: ProductDetailLayoutSpec.forWidth(390),
          images: _media,
        ),
      );
      await tester.pump();
      await tester.pump();

      final carousel = tester.widget<ImageCarousel>(find.byType(ImageCarousel));
      expect(carousel.controller, isNotNull);
      expect(carousel.controller!.page, 1);
      expect(find.text('Chapter two'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
    },
  );

  testWidgets('renders PDP purchase copy in French', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _NarrativeHarness(
        layout: ProductDetailLayoutSpec.forWidth(390),
        images: _media,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sélectionnez votre taille'), findsOneWidget);
    expect(find.text('Select your size'), findsNothing);
  });

  testWidgets('renders PDP purchase copy in English', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _NarrativeHarness(
        layout: ProductDetailLayoutSpec.forWidth(390),
        images: _media,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select your size'), findsOneWidget);
    expect(find.text('Sélectionnez votre taille'), findsNothing);
  });

  // Regression guard: the add-to-cart CTA mixes the (longer) French label with
  // the price in a single Row. 601px is the narrowest `split` layout that still
  // renders the purchase CTA, so it is the tightest real stress for the label.
  // Asserts no RenderFlex overflow — would fail if the Expanded around the
  // label were ever dropped or a non-flexible child added.
  testWidgets('add-to-cart CTA does not overflow in French at narrow split', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(601, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _NarrativeHarness(
        layout: ProductDetailLayoutSpec.forWidth(601),
        images: _media,
        onAddToCart: () async => true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ajouter au panier'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _media = [
  CatalogMedia(
    id: 'media-1',
    url: 'https://example.com/media-1.jpg',
    previewUrl: 'https://example.com/media-1-preview.jpg',
  ),
  CatalogMedia(
    id: 'media-2',
    url: 'https://example.com/media-2.jpg',
    previewUrl: 'https://example.com/media-2-preview.jpg',
  ),
  CatalogMedia(
    id: 'media-3',
    url: 'https://example.com/media-3.jpg',
    previewUrl: 'https://example.com/media-3-preview.jpg',
  ),
];

const _chapters = [
  NarrativeChapter(
    id: 'chapter-1',
    mediaId: 'media-1',
    position: 1,
    headline: 'Chapter one',
  ),
  NarrativeChapter(
    id: 'chapter-2',
    mediaId: 'media-2',
    position: 2,
    headline: 'Chapter two',
  ),
  NarrativeChapter(
    id: 'chapter-3',
    mediaId: 'media-3',
    position: 3,
    headline: 'Chapter three',
  ),
];

class _NarrativeHarness extends StatelessWidget {
  final ProductDetailLayoutSpec layout;
  final List<CatalogMedia> images;
  final Locale locale;
  final Future<bool> Function()? onAddToCart;

  const _NarrativeHarness({
    required this.layout,
    required this.images,
    this.locale = const Locale('fr'),
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final chaptersByMediaId = {
      for (final chapter in _chapters) chapter.mediaId: chapter,
    };
    return MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      locale: locale,
      home: Scaffold(
        body: SingleChildScrollView(
          child: NarrativePdpSection(
            product: const CatalogProduct(
              id: 'prod-1',
              code: 'PROD-1',
              name: 'Narrative product',
              productType: 'Robe',
            ),
            defaultPrice: const CatalogPrice(
              id: 'price-1',
              productId: 'prod-1',
              price: 129,
              currencySymbol: '€',
            ),
            originalPrice: null,
            discount: null,
            symbol: '€',
            images: images,
            layout: layout,
            chaptersByMediaId: chaptersByMediaId,
            pendingMedia: const {},
            isEditMode: false,
            onAddToCart: onAddToCart,
          ),
        ),
      ),
    );
  }
}
