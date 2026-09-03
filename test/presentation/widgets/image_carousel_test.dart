import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/navigation/pdp_route_transition.dart';
import 'package:kiki_commerce/presentation/providers/pending_media_provider.dart';
import 'package:kiki_commerce/presentation/widgets/hero_image_back_button.dart';
import 'package:kiki_commerce/presentation/widgets/image_carousel.dart';
import 'package:kiki_commerce/presentation/widgets/kiki_image.dart';
import 'package:kiki_commerce/presentation/widgets/pdp_water_ripple_image.dart';
import 'package:kiki_commerce/presentation/widgets/product_hero_tags.dart';

void main() {
  final transparentImage = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9pX6lzQAAAAASUVORK5CYII=',
    ),
  );

  CatalogMedia media(String id) => CatalogMedia(
    id: id,
    url: 'https://example.com/$id.jpg',
    previewUrl: 'https://example.com/$id-preview.jpg',
  );

  Map<String, PendingMediaEntry> pendingFor(List<CatalogMedia> images) {
    return {
      for (final image in images)
        image.id: PendingMediaEntry(bytes: transparentImage, version: 1),
    };
  }

  Widget buildHarness(ImageCarousel child) {
    return MaterialApp(
      home: Scaffold(body: SizedBox(width: 420, height: 560, child: child)),
    );
  }

  Widget buildRippleHarness({
    required Size mediaSize,
    bool disableAnimations = false,
  }) {
    final images = [media('ripple-1'), media('ripple-2')];
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: mediaSize,
          disableAnimations: disableAnimations,
        ),
        child: Scaffold(
          body: SizedBox(
            width: 420,
            height: 560,
            child: ImageCarousel(
              images: images,
              pendingMedia: pendingFor(images),
              showShoppingOverlays: false,
              mainImageHeroTag: productImageHeroTag('ripple-product'),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPageStorageHarness({
    required PageStorageBucket bucket,
    required Object storageKeyValue,
    required double storedOffset,
    required ImageCarousel child,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 420,
          height: 560,
          child: PageStorage(
            bucket: bucket,
            child: KeyedSubtree(
              key: PageStorageKey<Object>(storageKeyValue),
              child: Builder(
                builder: (context) {
                  PageStorage.maybeOf(
                    context,
                  )?.writeState(context, storedOffset);
                  return child;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('calls onPageChanged when the user swipes', (tester) async {
    final images = [media('m-1'), media('m-2')];
    int? changedIndex;

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          onPageChanged: (index) => changedIndex = index,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-420, 0));
    await tester.pumpAndSettle();

    expect(changedIndex, 1);
  });

  testWidgets('ignores parent PageStorage scroll offsets on first paint', (
    tester,
  ) async {
    final images = [media('m-1'), media('m-2')];

    await tester.pumpWidget(
      buildPageStorageHarness(
        bucket: PageStorageBucket(),
        storageKeyValue: 'pdp-scroll-prod-1',
        storedOffset: 420,
        child: ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          showShoppingOverlays: false,
        ),
      ),
    );
    await tester.pump();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.page, 0);
  });

  testWidgets('can hide the shopping overlays', (tester) async {
    final images = [media('m-1'), media('m-2')];

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          showShoppingOverlays: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COMPLÉTEZ VOTRE LOOK'), findsOneWidget);

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          showShoppingOverlays: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COMPLÉTEZ VOTRE LOOK'), findsNothing);
  });

  testWidgets('wraps only the first carousel image in a Hero', (tester) async {
    final images = [media('m-1'), media('m-2'), media('m-3')];
    final tag = productImageHeroTag('product-1');

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          showShoppingOverlays: false,
          mainImageHeroTag: tag,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heroes = tester.widgetList<Hero>(find.byType(Hero));
    expect(heroes.map((hero) => hero.tag).toList(), [tag]);
  });

  testWidgets('does not add carousel Heroes when no main tag is provided', (
    tester,
  ) async {
    final images = [media('m-1'), media('m-2')];

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          showShoppingOverlays: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('edit mode exposes an add-to-carousel action', (tester) async {
    final images = [media('m-1')];
    var addCalls = 0;

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          isEditMode: true,
          showShoppingOverlays: false,
          onAddMedia: () => addCalls += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ajouter au carousel'), findsOneWidget);

    await tester.tap(find.byTooltip('Ajouter au carousel'));
    await tester.pumpAndSettle();

    expect(addCalls, 1);
  });

  testWidgets('empty edit carousel uses add action when available', (
    tester,
  ) async {
    var addCalls = 0;
    var pickCalls = 0;

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: const [],
          pendingMedia: const {},
          isEditMode: true,
          onAddMedia: () => addCalls += 1,
          onPickMedia: (_) => pickCalls += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ajouter une image'));
    await tester.pumpAndSettle();

    expect(addCalls, 1);
    expect(pickCalls, 0);
  });

  testWidgets('edit replace action is available on gallery pages', (
    tester,
  ) async {
    final images = [media('m-1'), media('m-2')];
    int? replaceIndex;

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          isEditMode: true,
          showShoppingOverlays: false,
          onPickMedia: (index) => replaceIndex = index,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-420, 0));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Choisir une autre image'), findsOneWidget);

    await tester.tap(find.byTooltip('Choisir une autre image'));
    await tester.pumpAndSettle();

    expect(replaceIndex, 1);
  });

  testWidgets('edit mode exposes a remove-from-carousel action', (
    tester,
  ) async {
    final images = [media('m-1'), media('m-2')];
    int? removedIndex;

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          isEditMode: true,
          showShoppingOverlays: false,
          onRemoveMedia: (index) => removedIndex = index,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-420, 0));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Supprimer du carousel'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer du carousel'));
    await tester.pumpAndSettle();

    expect(removedIndex, 1);
  });

  testWidgets('edit mode exposes ordering actions', (tester) async {
    final images = [media('m-1'), media('m-2'), media('m-3')];
    int? firstIndex;
    (int, int)? move;

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          isEditMode: true,
          showShoppingOverlays: false,
          onSetFirstMedia: (index) => firstIndex = index,
          onMoveMedia: (currentIndex, targetIndex) =>
              move = (currentIndex, targetIndex),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-420, 0));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Afficher en premier'), findsOneWidget);
    expect(find.byTooltip('Déplacer avant'), findsOneWidget);
    expect(find.byTooltip('Déplacer après'), findsOneWidget);

    await tester.tap(find.byTooltip('Afficher en premier'));
    await tester.pumpAndSettle();
    expect(firstIndex, 1);

    await tester.tap(find.byTooltip('Déplacer après'));
    await tester.pumpAndSettle();
    expect(move, (1, 2));
  });

  testWidgets('scrolls to a requested media once it appears', (tester) async {
    final first = media('m-1');
    final added = media('m-2');
    String? handledMediaId;
    int? pickedIndex;

    Widget build(List<CatalogMedia> images) {
      return buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          isEditMode: true,
          showShoppingOverlays: false,
          scrollToMediaId: added.id,
          onScrollToMediaHandled: (mediaId) => handledMediaId = mediaId,
          onPickPhoto: (index) => pickedIndex = index,
        ),
      );
    }

    await tester.pumpWidget(build([first]));
    await tester.pumpAndSettle();

    expect(handledMediaId, isNull);

    await tester.pumpWidget(build([first, added]));
    await tester.pumpAndSettle();

    expect(handledMediaId, added.id);

    await tester.tap(find.byTooltip('Recadrer cette image'));
    await tester.pumpAndSettle();

    expect(pickedIndex, 1);
  });

  testWidgets('DesktopImageStack keeps adjacent images flush without gaps', (
    tester,
  ) async {
    final images = [media('m-1'), media('m-2')];
    final keys = [GlobalKey(), GlobalKey()];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: DesktopImageStack(
                images: images,
                pendingMedia: pendingFor(images),
                itemKeys: keys,
                spacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstRect = tester.getRect(find.byKey(keys[0]));
    final secondRect = tester.getRect(find.byKey(keys[1]));

    expect(secondRect.top, closeTo(firstRect.bottom, 1));
  });

  testWidgets('wraps only the first desktop stack image in a Hero', (
    tester,
  ) async {
    final images = [media('m-1'), media('m-2'), media('m-3')];
    final tag = productImageHeroTag('product-1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: DesktopImageStack(
                images: images,
                pendingMedia: pendingFor(images),
                mainImageHeroTag: tag,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heroes = tester.widgetList<Hero>(find.byType(Hero));
    expect(heroes.map((hero) => hero.tag).toList(), [tag]);
  });

  // --- Landing crossfade: destination Hero keeps a listing-URL background
  // behind the PDP image while the larger variant loads/fades in. The Hero
  // shuttle warms NetworkImage(media.listingUrl) in the Skia ImageCache, so
  // this is the SAME provider key and paints synchronously on landing.

  testWidgets('phone Hero uses the shorter lighter water ripple', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildRippleHarness(mediaSize: const Size(360, 800)),
    );

    final ripple = tester.widget<PdpWaterRipple>(find.byType(PdpWaterRipple));
    expect(ripple.enabled, isTrue);
    expect(ripple.duration, const Duration(milliseconds: 650));
    expect(ripple.intensity, 0.60);
    expect(
      ripple.origin.dx,
      closeTo(
        (kHeroImageBackButtonLeftGap + kHeroImageBackButtonSize / 2) / 420,
        0.001,
      ),
    );
    expect(
      ripple.origin.dy,
      closeTo(
        (kHeroImageBackButtonTopGap + kHeroImageBackButtonSize / 2) /
            (420 / 0.85),
        0.001,
      ),
    );
  });

  testWidgets('600px shortest side uses the full water ripple', (tester) async {
    await tester.pumpWidget(
      buildRippleHarness(mediaSize: const Size(600, 900)),
    );

    final ripple = tester.widget<PdpWaterRipple>(find.byType(PdpWaterRipple));
    expect(ripple.enabled, isTrue);
    expect(ripple.duration, const Duration(milliseconds: 1000));
    expect(ripple.intensity, 1.0);
  });

  testWidgets('reduce-motion disables the water ripple on phones', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildRippleHarness(
        mediaSize: const Size(360, 800),
        disableAnimations: true,
      ),
    );

    final rippleFinder = find.byType(PdpWaterRipple);
    final ripple = tester.widget<PdpWaterRipple>(rippleFinder);
    expect(ripple.enabled, isFalse);
    expect(
      find.descendant(of: rippleFinder, matching: find.byType(AnimatedBuilder)),
      findsNothing,
    );
  });

  testWidgets('water ripple drops its sampler after its one-shot pulse', (
    tester,
  ) async {
    await ShaderBuilder.precacheShader(kPdpWaterRippleShaderAsset);
    await tester.pumpWidget(
      const MaterialApp(
        home: PdpWaterRipple(
          duration: Duration(milliseconds: 100),
          child: SizedBox.expand(),
        ),
      ),
    );

    expect(find.byType(AnimatedSampler), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump();

    expect(find.byType(AnimatedSampler), findsNothing);
  });

  test('PDP transition installs the shared water-ripple route scope', () {
    final page = pdpTransitionPage(
      key: const ValueKey('pdp'),
      child: const SizedBox.expand(),
    );

    expect(page.child, isA<PdpWaterRippleRouteScope>());
  });

  testWidgets(
    'route scope starts after landing and continues across image handoff',
    (tester) async {
      await ShaderBuilder.precacheShader(kPdpWaterRippleShaderAsset);
      final navigatorKey = GlobalKey<NavigatorState>();
      late StateSetter replaceHeroImage;
      var showLoadedImage = false;

      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.expand()),
      );

      navigatorKey.currentState!.push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 100),
          pageBuilder: (context, animation, secondaryAnimation) {
            return PdpWaterRippleRouteScope(
              child: StatefulBuilder(
                builder: (context, setState) {
                  replaceHeroImage = setState;
                  return PdpWaterRipple(
                    key: ValueKey(showLoadedImage),
                    duration: const Duration(milliseconds: 100),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            );
          },
        ),
      );
      await tester.pump();

      expect(find.byType(AnimatedSampler), findsNothing);

      await tester.pump(const Duration(milliseconds: 99));
      expect(find.byType(AnimatedSampler), findsNothing);

      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump();
      expect(find.byType(AnimatedSampler), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 40));
      replaceHeroImage(() => showLoadedImage = true);
      await tester.pump();
      expect(find.byType(AnimatedSampler), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 61));
      await tester.pump();
      expect(find.byType(AnimatedSampler), findsNothing);
    },
  );

  testWidgets('mobile Hero keeps listing image behind the loading PDP image', (
    tester,
  ) async {
    final images = [media('m-1'), media('m-2')];
    final tag = productImageHeroTag('product-1');

    // pendingFor short-circuits KikiImage to Image.memory and avoids
    // real NetworkImage loads in the test binding. The KikiImage
    // `placeholder` property — what we're asserting on — is still set
    // by the constructor regardless of which render branch is taken.
    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          showShoppingOverlays: false,
          mainImageHeroTag: tag,
        ),
      ),
    );
    await tester.pump();

    final heroKiki = find.descendant(
      of: find.byType(Hero),
      matching: find.byType(KikiImage),
    );
    expect(heroKiki, findsOneWidget);
    final kiki = tester.widget<KikiImage>(heroKiki);
    expect(kiki.placeholder, isA<SizedBox>());

    final heroImages = tester.widgetList<Image>(
      find.descendant(of: find.byType(Hero), matching: find.byType(Image)),
    );
    expect(
      heroImages
          .where(
            (image) =>
                image.image is NetworkImage &&
                (image.image as NetworkImage).url == images.first.listingUrl,
          )
          .length,
      1,
    );
  });

  testWidgets(
    'mobile carousel KikiImages have no placeholder when Hero is off',
    (tester) async {
      final images = [media('m-1'), media('m-2')];

      await tester.pumpWidget(
        buildHarness(
          ImageCarousel(
            images: images,
            pendingMedia: pendingFor(images),
            showShoppingOverlays: false,
          ),
        ),
      );
      await tester.pump();

      final kikis = tester.widgetList<KikiImage>(find.byType(KikiImage));
      expect(kikis, isNotEmpty);
      for (final kiki in kikis) {
        expect(kiki.placeholder, isNull);
      }
    },
  );

  testWidgets('mobile Hero: only the index-0 KikiImage gets a placeholder', (
    tester,
  ) async {
    final images = [media('m-1'), media('m-2'), media('m-3')];
    final tag = productImageHeroTag('product-1');

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          showShoppingOverlays: false,
          mainImageHeroTag: tag,
        ),
      ),
    );
    await tester.pump();

    final kikiCountWithPlaceholder = tester
        .widgetList<KikiImage>(find.byType(KikiImage))
        .where((k) => k.placeholder != null)
        .length;
    expect(kikiCountWithPlaceholder, 1);
  });

  testWidgets(
    'DesktopImageStack Hero keeps listing image behind the loading PDP image',
    (tester) async {
      final images = [media('m-1'), media('m-2'), media('m-3')];
      final tag = productImageHeroTag('product-1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: DesktopImageStack(
                  images: images,
                  pendingMedia: pendingFor(images),
                  mainImageHeroTag: tag,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final heroKiki = find.descendant(
        of: find.byType(Hero),
        matching: find.byType(KikiImage),
      );
      expect(heroKiki, findsOneWidget);
      final kiki = tester.widget<KikiImage>(heroKiki);
      expect(kiki.placeholder, isA<SizedBox>());

      final heroImages = tester.widgetList<Image>(
        find.descendant(of: find.byType(Hero), matching: find.byType(Image)),
      );
      expect(
        heroImages
            .where(
              (image) =>
                  image.image is NetworkImage &&
                  (image.image as NetworkImage).url == images.first.listingUrl,
            )
            .length,
        1,
      );

      final kikiCountWithPlaceholder = tester
          .widgetList<KikiImage>(find.byType(KikiImage))
          .where((k) => k.placeholder != null)
          .length;
      expect(kikiCountWithPlaceholder, 1);
    },
  );

  testWidgets(
    'DesktopImageStack KikiImages have no placeholder when Hero is off',
    (tester) async {
      final images = [media('m-1'), media('m-2')];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: DesktopImageStack(
                  images: images,
                  pendingMedia: pendingFor(images),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final kikis = tester.widgetList<KikiImage>(find.byType(KikiImage));
      expect(kikis, isNotEmpty);
      for (final kiki in kikis) {
        expect(kiki.placeholder, isNull);
      }
    },
  );

  testWidgets('pending media path does not crash with a Hero-wired carousel', (
    tester,
  ) async {
    // When pendingMedia contains bytes for an id, KikiImage builds an
    // Image.memory and bypasses CachedNetworkImage entirely; the
    // placeholder field is simply unused. This test guards that the
    // construction path stays exception-free with the new wiring.
    final images = [media('m-1'), media('m-2')];
    final tag = productImageHeroTag('product-1');

    await tester.pumpWidget(
      buildHarness(
        ImageCarousel(
          images: images,
          pendingMedia: pendingFor(images),
          showShoppingOverlays: false,
          mainImageHeroTag: tag,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'liquid reveal clips the incoming page mid-swipe but not at rest',
    (tester) async {
      final images = [media('lr-1'), media('lr-2')];

      await tester.pumpWidget(
        buildHarness(
          ImageCarousel(images: images, pendingMedia: pendingFor(images)),
        ),
      );
      await tester.pumpAndSettle();

      // Settled on a page: the carousel paints straight through, no liquid clip.
      expect(find.byType(ClipPath), findsNothing);

      // Hold a drag partway between the two pages so one is mid-transition.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      // Safety net if an expectation throws while the drag is still held; the
      // body releases the gesture on the happy path, so ignore a double-up.
      addTearDown(() async {
        try {
          await gesture.up();
        } catch (_) {}
      });
      await gesture.moveBy(const Offset(-160, 0));
      await tester.pump();

      expect(find.byType(ClipPath), findsWidgets);

      // Release and settle: the clip disappears once a page is settled again.
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(ClipPath), findsNothing);
    },
  );

  testWidgets('reduce motion disables the liquid reveal clip', (tester) async {
    final images = [media('lr-1'), media('lr-2')];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(
              width: 420,
              height: 560,
              child: ImageCarousel(
                images: images,
                pendingMedia: pendingFor(images),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    addTearDown(() async {
      try {
        await gesture.up();
      } catch (_) {}
    });
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();

    // Even mid-swipe, reduced motion paints the page unclipped.
    expect(find.byType(ClipPath), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
