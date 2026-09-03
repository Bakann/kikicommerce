import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/animations/text_reveal/text_reveal.dart';

void main() {
  const text =
      'Alpha  beta gamma delta epsilon zeta eta theta iota kappa lambda.';
  const frenchDescription =
      'Simple, solaire et naturellement cool, ce t-shirt olive incarne '
      'l’esprit des fins d’après-midi légèrement décontractée.';

  Widget host(
    Widget body, {
    bool disableAnimations = false,
    ScrollController? controller,
  }) {
    return MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        );
      },
      home: Scaffold(
        body: controller == null
            ? Center(child: body)
            : SingleChildScrollView(controller: controller, child: body),
      ),
    );
  }

  Widget reveal({
    required Key key,
    String copy = text,
    double width = 140,
    bool enabled = true,
    bool disableRotation = false,
    TextAlign textAlign = TextAlign.center,
    double viewportRevealFraction = 0.85,
    TextStyle style = const TextStyle(fontSize: 18, height: 1.2),
  }) {
    return SizedBox(
      width: width,
      child: ScrollLineRevealText(
        key: key,
        text: copy,
        style: style,
        textAlign: textAlign,
        enabled: enabled,
        maxWordRotationDegrees: disableRotation ? 0 : 7,
        viewportRevealFraction: viewportRevealFraction,
      ),
    );
  }

  void setViewSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  bool hasLetterOrDigitAt(String copy, int index) {
    if (index < 0 || index >= copy.length) return false;
    return RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(copy[index]);
  }

  bool isWordLikeAt(String copy, int index) {
    if (index < 0 || index >= copy.length) return false;
    final character = copy[index];
    if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(character)) {
      return true;
    }
    if (character != "'" && character != '’' && character != '-') {
      return false;
    }
    return hasLetterOrDigitAt(copy, index - 1) &&
        hasLetterOrDigitAt(copy, index + 1);
  }

  bool breaksInsideWord(String copy, int boundary) {
    if (boundary <= 0 || boundary >= copy.length) return false;
    return isWordLikeAt(copy, boundary - 1) && isWordLikeAt(copy, boundary);
  }

  List<int> unsafeVisualLineBoundaries(String copy, List<String> lines) {
    final boundaries = <int>[];
    var searchStart = 0;
    for (final line in lines) {
      if (line.isEmpty) continue;
      final start = copy.indexOf(line, searchStart);
      expect(start, isNot(-1), reason: 'Line "$line" must exist in source');
      final end = start + line.length;
      if (breaksInsideWord(copy, start)) {
        boundaries.add(start);
      }
      if (breaksInsideWord(copy, end)) {
        boundaries.add(end);
      }
      searchStart = end;
    }
    return boundaries;
  }

  testWidgets('disableAnimations renders immediately without a controller', (
    tester,
  ) async {
    const key = ValueKey('disabled-lines');
    await tester.pumpWidget(host(reveal(key: key), disableAnimations: true));

    final state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(find.text(text), findsOneWidget);
    expect(state.debugLayoutMode, ScrollLineRevealTextLayoutMode.nativeText);
    expect(state.debugLineCount, 1);
    expect(state.debugTargetLineCount, state.debugLineCount);
    expect(state.debugHasCompleted, isTrue);
    expect(state.debugHasController, isFalse);
  });

  testWidgets('enabled false renders native text without a controller', (
    tester,
  ) async {
    const key = ValueKey('enabled-false-native');
    await tester.pumpWidget(host(reveal(key: key, enabled: false)));

    final state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(find.text(text), findsOneWidget);
    expect(state.debugLayoutMode, ScrollLineRevealTextLayoutMode.nativeText);
    expect(state.debugHasController, isFalse);
  });

  testWidgets('exposes the complete text as a single semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const key = ValueKey('semantics-label');

    try {
      await tester.pumpWidget(host(reveal(key: key), disableAnimations: true));

      expect(find.bySemanticsLabel(text), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('excludes visual words and lines from semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    const key = ValueKey('visual-words-excluded');

    try {
      await tester.pumpWidget(host(reveal(key: key)));

      final state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
      final firstLine = state.debugVisualLines.first.trim();
      expect(firstLine, isNot(text));
      expect(find.bySemanticsLabel(firstLine), findsNothing);
      expect(find.bySemanticsLabel('Alpha'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('splits visual lines into word and exact whitespace segments', (
    tester,
  ) async {
    const key = ValueKey('segments');
    await tester.pumpWidget(host(reveal(key: key, width: 520)));

    final state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugLayoutMode, ScrollLineRevealTextLayoutMode.wordFirst);
    final segments = state.debugVisualLineSegments.expand((line) => line);
    final segmentTypes = state.debugVisualLineSegmentIsWord.expand(
      (line) => line,
    );
    expect(segments, contains('Alpha'));
    expect(segments, contains('  '));
    expect(segmentTypes, containsAll([true, false]));
  });

  testWidgets('spaces are not animated words', (tester) async {
    const key = ValueKey('space-segments');
    await tester.pumpWidget(host(reveal(key: key, width: 520)));

    final state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    final segments = state.debugVisualLineSegments.expand((line) => line);
    final wordFlags = state.debugVisualLineSegmentIsWord.expand((line) => line);
    final wordIndexes = state.debugVisualLineWordIndexes.expand((line) => line);
    final zipped = Iterable.generate(segments.length, (index) {
      return (
        text: segments.elementAt(index),
        isWord: wordFlags.elementAt(index),
        wordIndex: wordIndexes.elementAt(index),
      );
    });

    final spaceSegment = zipped.firstWhere((segment) => segment.text == '  ');
    expect(spaceSegment.isWord, isFalse);
    expect(spaceSegment.wordIndex, -1);
    expect(
      state.debugWordRotationsRadians.expand((line) => line).length,
      wordFlags.where((isWord) => isWord).length,
    );
  });

  testWidgets('word rotation is deterministic across same-key rebuilds', (
    tester,
  ) async {
    const key = ValueKey('rotation-stable');
    await tester.pumpWidget(host(reveal(key: key)));

    final firstState = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    final firstRotations = firstState.debugWordRotationsRadians;

    await tester.pumpWidget(host(reveal(key: key)));

    final secondState = tester.state<ScrollLineRevealTextState>(
      find.byKey(key),
    );
    expect(secondState.debugWordRotationsRadians, firstRotations);
  });

  testWidgets('reuses cached layout across identical rebuilds', (tester) async {
    const key = ValueKey('layout-cache');
    await tester.pumpWidget(host(reveal(key: key, width: 520)));

    var state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugLayoutMode, ScrollLineRevealTextLayoutMode.wordFirst);
    final initialLayoutCount = state.debugLayoutComputeCount;
    final initialMeasureCount = state.debugTokenMeasureCount;
    expect(initialLayoutCount, greaterThan(0));
    expect(initialMeasureCount, greaterThan(0));

    for (var index = 0; index < 3; index += 1) {
      await tester.pumpWidget(host(reveal(key: key, width: 520)));
    }

    state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugLayoutComputeCount, initialLayoutCount);
    expect(state.debugTokenMeasureCount, initialMeasureCount);

    await tester.pumpWidget(host(reveal(key: key, width: 560)));

    state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugLayoutComputeCount, initialLayoutCount + 1);
    expect(state.debugTokenMeasureCount, greaterThan(initialMeasureCount));
  });

  testWidgets('rotation degree changes do not recompute word layout', (
    tester,
  ) async {
    const key = ValueKey('rotation-no-layout');
    await tester.pumpWidget(host(reveal(key: key, width: 520)));

    var state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    final initialLayoutCount = state.debugLayoutComputeCount;
    final initialMeasureCount = state.debugTokenMeasureCount;
    expect(
      state.debugWordRotationsRadians
          .expand((line) => line)
          .any((rotation) => rotation != 0),
      isTrue,
    );

    await tester.pumpWidget(
      host(reveal(key: key, width: 520, disableRotation: true)),
    );

    state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugLayoutComputeCount, initialLayoutCount);
    expect(state.debugTokenMeasureCount, initialMeasureCount);
    expect(
      state.debugWordRotationsRadians.expand((line) => line),
      everyElement(0),
    );
  });

  testWidgets('maxWordRotationDegrees zero disables rotation only', (
    tester,
  ) async {
    const key = ValueKey('rotation-disabled');
    await tester.pumpWidget(host(reveal(key: key, disableRotation: true)));

    final state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(
      state.debugWordRotationsRadians.expand((line) => line),
      everyElement(0),
    );
    expect(
      state.debugVisualLineSegments.expand((line) => line),
      contains('Alpha'),
    );
  });

  testWidgets('center textAlign resolves to centered visual lines', (
    tester,
  ) async {
    const key = ValueKey('center-alignment');
    await tester.pumpWidget(
      host(
        reveal(key: key, textAlign: TextAlign.center),
        disableAnimations: true,
      ),
    );

    final state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugResolvedAlignment, Alignment.center);
  });

  testWidgets('justify textAlign resolves like start', (tester) async {
    const key = ValueKey('justify-alignment');
    await tester.pumpWidget(
      host(
        reveal(key: key, textAlign: TextAlign.justify),
        disableAnimations: true,
      ),
    );

    final state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugResolvedAlignment, Alignment.centerLeft);
  });

  testWidgets('oversized words use native fallback mode', (tester) async {
    const key = ValueKey('oversized-word');
    await tester.pumpWidget(
      host(reveal(key: key, copy: 'Supercalifragilistic', width: 4)),
    );

    final state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(
      state.debugLayoutMode,
      ScrollLineRevealTextLayoutMode.oversizedWordFallback,
    );
    expect(state.debugHasController, isFalse);
    expect(find.text('Supercalifragilistic'), findsOneWidget);
  });

  testWidgets('French mobile copy never exposes isolated letter lines', (
    tester,
  ) async {
    const key = ValueKey('french-mobile-copy');
    await tester.pumpWidget(
      host(
        reveal(
          key: key,
          copy: frenchDescription,
          width: 346,
          style: const TextStyle(fontSize: 28, height: 1.14),
        ),
      ),
    );

    final state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugLayoutMode, ScrollLineRevealTextLayoutMode.wordFirst);
    final isolatedLetterLines = state.debugVisualLines
        .map((line) => line.trim())
        .where((line) => RegExp(r'^\p{L}$', unicode: true).hasMatch(line));
    expect(isolatedLetterLines, isEmpty);
    expect(
      unsafeVisualLineBoundaries(frenchDescription, state.debugVisualLines),
      isEmpty,
    );
  });

  testWidgets('oversized fallback keeps semantics and native text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const key = ValueKey('oversized-semantics');

    try {
      await tester.pumpWidget(
        host(
          reveal(
            key: key,
            copy: 'Anticonstitutionnellement',
            width: 4,
            style: const TextStyle(fontSize: 28, height: 1.14),
          ),
        ),
      );

      final state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
      expect(
        state.debugLayoutMode,
        ScrollLineRevealTextLayoutMode.oversizedWordFallback,
      );
      expect(state.debugHasController, isFalse);
      expect(find.text('Anticonstitutionnellement'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Anticonstitutionnellement'),
        findsOneWidget,
      );
      expect(state.debugVisualLines, ['Anticonstitutionnellement']);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('viewportRevealFraction gates reveal near the viewport bottom', (
    tester,
  ) async {
    setViewSize(tester, const Size(400, 300));
    const key = ValueKey('viewport-fraction');
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        Column(
          children: [
            const SizedBox(height: 260),
            reveal(key: key, viewportRevealFraction: 0.85),
            const SizedBox(height: 900),
          ],
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    var state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugTargetLineCount, 0);

    controller.jumpTo(12);
    await tester.pump();
    await tester.pump();

    state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugTargetLineCount, greaterThan(0));
  });

  testWidgets('newly visible lines get a fresh word-drop timeline on scroll', (
    tester,
  ) async {
    setViewSize(tester, const Size(400, 240));
    const key = ValueKey('fresh-line-timeline');
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        Column(
          children: [
            const SizedBox(height: 200),
            reveal(
              key: key,
              copy: 'Alpha beta gamma delta epsilon zeta eta theta iota',
              width: 70,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 900),
          ],
        ),
        controller: controller,
      ),
    );
    await tester.pump();
    await tester.pump();

    var state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugLineCount, greaterThan(2));
    expect(state.debugTargetLineCount, 1);
    expect(state.debugLineRevealStartMs[0], 0);

    await tester.pump(const Duration(seconds: 2));

    controller.jumpTo(24);
    await tester.pump();
    await tester.pump();

    state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugTargetLineCount, 2);
    expect(state.debugLineRevealStartMs[1], greaterThanOrEqualTo(600));
  });

  testWidgets('scrolling up does not hide already revealed lines', (
    tester,
  ) async {
    setViewSize(tester, const Size(400, 300));
    const key = ValueKey('scroll-up-keeps-lines');
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        Column(
          children: [
            const SizedBox(height: 900),
            reveal(key: key),
            const SizedBox(height: 900),
          ],
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    controller.jumpTo(760);
    await tester.pump();
    await tester.pump();

    var state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    final revealedCount = state.debugTargetLineCount;
    expect(revealedCount, greaterThan(0));

    controller.jumpTo(100);
    await tester.pump();
    await tester.pump();

    state = tester.state<ScrollLineRevealTextState>(find.byKey(key));
    expect(state.debugTargetLineCount, revealedCount);
  });
}
