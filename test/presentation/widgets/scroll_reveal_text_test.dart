import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/scroll_reveal_text.dart';

void main() {
  group('computeScrollReadProgress', () {
    test('is zero before the block reaches the viewport', () {
      final progress = computeScrollReadProgress(
        globalTop: 820,
        viewportHeight: 800,
        boundsHeight: 200,
        scrollDistanceViewportFraction: 0.85,
      );

      expect(progress, closeTo(0.0, 0.0001));
    });

    test('slows the reveal by adding viewport distance', () {
      final progress = computeScrollReadProgress(
        globalTop: 600,
        viewportHeight: 800,
        boundsHeight: 400,
        scrollDistanceViewportFraction: 0.85,
      );

      // Visible distance is 200 px, but reveal distance is
      // 400 + (800 * 0.85) = 1080 px.
      expect(progress, closeTo(200 / 1080, 0.0001));
    });

    test('is one after enough of the block has been read', () {
      final progress = computeScrollReadProgress(
        globalTop: -280,
        viewportHeight: 800,
        boundsHeight: 400,
        scrollDistanceViewportFraction: 0.85,
      );

      expect(progress, closeTo(1.0, 0.0001));
    });

    test('zero or negative bounds height does not divide by zero', () {
      final progress = computeScrollReadProgress(
        globalTop: 0,
        viewportHeight: 800,
        boundsHeight: 0,
        scrollDistanceViewportFraction: 0.85,
      );

      expect(progress.isFinite, isTrue);
      expect(progress, inInclusiveRange(0.0, 1.0));
    });

    test('legacy block-height-only mapping is still available', () {
      final progress = computeScrollReadProgress(
        globalTop: 600,
        viewportHeight: 800,
        boundsHeight: 400,
        scrollDistanceViewportFraction: 0,
      );

      expect(progress, closeTo(0.5, 0.0001));
    });
  });

  group('computeActiveCharacterCount', () {
    test('maps progress to a character prefix length', () {
      expect(
        computeActiveCharacterCount(progress: 0.49, totalCharacters: 10),
        4,
      );
      expect(
        computeActiveCharacterCount(progress: 0.5, totalCharacters: 10),
        5,
      );
    });

    test('clamps progress and handles empty text', () {
      expect(computeActiveCharacterCount(progress: -1, totalCharacters: 10), 0);
      expect(computeActiveCharacterCount(progress: 2, totalCharacters: 10), 10);
      expect(computeActiveCharacterCount(progress: 1, totalCharacters: 0), 0);
    });
  });

  group('ScrollRevealText widget', () {
    testWidgets('renders plain text when no Scrollable ancestor exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ScrollRevealText(text: 'Hello world')),
        ),
      );

      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('renders one rich text layer when a Scrollable is present', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: controller,
              children: const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: ScrollRevealText(
                    text: 'Lorem ipsum dolor sit amet',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final richTexts = tester
          .widgetList<RichText>(find.byType(RichText))
          .where(
            (richText) =>
                richText.text.toPlainText() == 'Lorem ipsum dolor sit amet',
          )
          .toList();
      expect(richTexts, hasLength(1));
      expect(
        _textSpanContainsWeight(richTexts.single.text, FontWeight.w700),
        isTrue,
      );
    });

    testWidgets('mounts inside a Scrollable and survives a scroll', (
      tester,
    ) async {
      final longText = 'lorem ipsum ' * 80;
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              controller: controller,
              children: [
                const SizedBox(height: 1200),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ScrollRevealText(text: longText),
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      );

      // ListView is lazy; the description sits below the initial viewport.
      // Scroll until it's in view, then verify it renders without errors.
      controller.jumpTo(1100);
      await tester.pump();
      expect(find.textContaining('lorem ipsum'), findsAtLeastNWidgets(1));

      controller.jumpTo(1500);
      await tester.pump();
      expect(find.textContaining('lorem ipsum'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    // Regression for the freeze caused by the previous _breakLines() loop
    // (see commit 7cd755f). A long, narrow paragraph used to drive
    // TextPainter.getLineBoundary into a non-progressing loop on Flutter
    // Web, eventually throwing JSRangeError "Invalid string length". The
    // current implementation never re-lays the text at build time, so
    // this case must mount, scroll and dispose without throwing.
    testWidgets('long PDP-like description in a narrow column does not throw', (
      tester,
    ) async {
      final pdpDescription =
          ('Une silhouette structurée et fluide à la fois, pensée pour '
              'épouser le mouvement sans contraindre la forme. La matière, '
              'tissée dans un atelier français centenaire, se distingue par '
              'sa main délicate et sa tenue dans le temps. Les finitions ont '
              'été retravaillées à la main pour souligner l\'épure de la '
              'coupe et la justesse des proportions. ') *
          12;

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ScrollRevealText(
                      text: pdpDescription,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // A few scroll positions across the block.
      for (final pixels in const [0.0, 200.0, 800.0, 1600.0, 4000.0]) {
        final targetPixels = pixels
            .clamp(
              controller.position.minScrollExtent,
              controller.position.maxScrollExtent,
            )
            .toDouble();
        controller.jumpTo(targetPixels);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    // Scroll listeners fire many times per gesture. The widget should only
    // rebuild when the bold prefix length actually changes — sub-character
    // scroll deltas should be a no-op.
    testWidgets('skips rebuilds when activeCount is stable across scrolls', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      // SingleChildScrollView so the text isn't unmounted at large scroll
      // offsets — we need a stable State instance across the whole test.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 800),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ScrollRevealText(
                      text: 'lorem ipsum ' * 40,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 800),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      controller.jumpTo(500);
      await tester.pumpAndSettle();

      final state = tester.state<ScrollRevealTextState>(
        find.byType(ScrollRevealText),
      );
      final buildCountBefore = state.debugBuildCount;

      // Move the scroll position by tiny sub-pixel amounts: a total motion
      // of 0.0025 px cannot cross a character boundary in any reasonable
      // layout, so activeCount must stay the same and no rebuild should
      // happen. Pre-optimization, each listener fired a setState and
      // forced a rebuild on every scroll tick (so we would see five extra
      // builds after five pumps).
      for (var i = 1; i <= 5; i++) {
        controller.jumpTo(500 + i * 0.0005);
        await tester.pump();
      }

      expect(state.debugBuildCount, buildCountBefore);

      // A meaningful scroll crosses character boundaries and must rebuild
      // exactly once (one setState per real activeCount change).
      controller.jumpTo(700);
      await tester.pumpAndSettle();
      expect(state.debugBuildCount, buildCountBefore + 1);
    });

    // The cached activeCount must be invalidated when something other than
    // scroll position changes — here, a viewport resize that moves the text
    // up relative to the visible area. Without an explicit recompute on
    // dependency change the widget would keep the previously cached count.
    testWidgets('recomputes when viewport size changes without scrolling', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 200);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 400),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ScrollRevealText(
                      text: 'lorem ipsum ' * 40,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      controller.jumpTo(350);
      await tester.pumpAndSettle();

      final state = tester.state<ScrollRevealTextState>(
        find.byType(ScrollRevealText),
      );
      final buildCountBefore = state.debugBuildCount;

      // Make the viewport taller so the text occupies a different position
      // relative to it, without touching the scroll controller.
      tester.view.physicalSize = const Size(800, 1200);
      await tester.pumpAndSettle();

      expect(state.debugBuildCount, greaterThan(buildCountBefore));
    });
  });
}

bool _textSpanContainsWeight(InlineSpan span, FontWeight weight) {
  if (span is TextSpan) {
    if (span.style?.fontWeight == weight) {
      return true;
    }
    return span.children?.any((child) {
          return _textSpanContainsWeight(child, weight);
        }) ??
        false;
  }
  return false;
}
