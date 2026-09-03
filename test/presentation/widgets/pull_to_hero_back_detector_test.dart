import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/pull_to_hero_back_detector.dart';

void main() {
  const threshold = 80.0;

  ScrollMetrics metricsAt(double pixels) => FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: 1000,
    pixels: pixels,
    viewportDimension: 800,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 1,
  );

  final drag = DragUpdateDetails(globalPosition: Offset.zero);

  /// Pumps the detector and returns the child [BuildContext] (used both to
  /// dispatch notifications and as their `context` field) plus a getter for
  /// the trigger count.
  Future<({BuildContext ctx, int Function() count})> pumpDetector(
    WidgetTester tester,
  ) async {
    var triggers = 0;
    late BuildContext childContext;

    await tester.pumpWidget(
      MaterialApp(
        home: PullToHeroBackDetector(
          threshold: threshold,
          onTrigger: () => triggers++,
          child: Builder(
            builder: (context) {
              childContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    return (ctx: childContext, count: () => triggers);
  }

  testWidgets('does not pop when overscroll at top is below threshold', (
    tester,
  ) async {
    final h = await pumpDetector(tester);
    ScrollStartNotification(
      metrics: metricsAt(0),
      context: h.ctx,
    ).dispatch(h.ctx);
    OverscrollNotification(
      metrics: metricsAt(0),
      context: h.ctx,
      overscroll: -threshold + 10,
      dragDetails: drag,
    ).dispatch(h.ctx);

    expect(h.count(), 0);
  });

  testWidgets('pops exactly once when overscroll at top exceeds threshold', (
    tester,
  ) async {
    final h = await pumpDetector(tester);
    ScrollStartNotification(
      metrics: metricsAt(0),
      context: h.ctx,
    ).dispatch(h.ctx);
    OverscrollNotification(
      metrics: metricsAt(0),
      context: h.ctx,
      overscroll: -(threshold + 5),
      dragDetails: drag,
    ).dispatch(h.ctx);

    expect(h.count(), 1);
  });

  testWidgets('does not pop when not at the top', (tester) async {
    final h = await pumpDetector(tester);
    ScrollStartNotification(
      metrics: metricsAt(120),
      context: h.ctx,
    ).dispatch(h.ctx);
    OverscrollNotification(
      metrics: metricsAt(120),
      context: h.ctx,
      overscroll: -(threshold + 50),
      dragDetails: drag,
    ).dispatch(h.ctx);

    expect(h.count(), 0);
  });

  testWidgets('ScrollEnd resets accumulation between gestures', (tester) async {
    final h = await pumpDetector(tester);
    // First gesture accumulates just under the threshold.
    OverscrollNotification(
      metrics: metricsAt(0),
      context: h.ctx,
      overscroll: -(threshold - 10),
      dragDetails: drag,
    ).dispatch(h.ctx);
    ScrollEndNotification(
      metrics: metricsAt(0),
      context: h.ctx,
    ).dispatch(h.ctx);

    // Second gesture's small pull must not combine with the first.
    OverscrollNotification(
      metrics: metricsAt(0),
      context: h.ctx,
      overscroll: -20,
      dragDetails: drag,
    ).dispatch(h.ctx);

    expect(h.count(), 0);
  });

  testWidgets('ignores wheel/programmatic overscroll (no dragDetails)', (
    tester,
  ) async {
    final h = await pumpDetector(tester);
    OverscrollNotification(
      metrics: metricsAt(0),
      context: h.ctx,
      overscroll: -(threshold + 100),
    ).dispatch(h.ctx);

    expect(h.count(), 0);
  });

  testWidgets('does not double-pop within the same gesture', (tester) async {
    final h = await pumpDetector(tester);
    ScrollStartNotification(
      metrics: metricsAt(0),
      context: h.ctx,
    ).dispatch(h.ctx);
    for (var i = 0; i < 5; i++) {
      OverscrollNotification(
        metrics: metricsAt(0),
        context: h.ctx,
        overscroll: -(threshold + 30),
        dragDetails: drag,
      ).dispatch(h.ctx);
    }

    expect(h.count(), 1);
  });

  testWidgets('upward overscroll (positive) never pops', (tester) async {
    final h = await pumpDetector(tester);
    OverscrollNotification(
      metrics: metricsAt(0),
      context: h.ctx,
      overscroll: threshold + 100,
      dragDetails: drag,
    ).dispatch(h.ctx);

    expect(h.count(), 0);
  });

  // Real-gesture coverage mirroring the loading branch: a CustomScrollView
  // whose content is shorter than the viewport, made overscrollable via
  // AlwaysScrollableScrollPhysics (the fix that lets the skeleton be pulled).
  Future<int> pumpShortLoadingScrollableAndDrag(
    WidgetTester tester,
    double dragDistance,
  ) async {
    var triggers = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PullToHeroBackDetector(
            threshold: threshold,
            onTrigger: () => triggers++,
            child: const CustomScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              slivers: [SliverToBoxAdapter(child: SizedBox(height: 120))],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(CustomScrollView), Offset(0, dragDistance));
    await tester.pumpAndSettle();
    return triggers;
  }

  testWidgets('real downward drag past threshold on short loading scrollable '
      'pops once', (tester) async {
    final triggers = await pumpShortLoadingScrollableAndDrag(
      tester,
      threshold + 120,
    );
    expect(triggers, 1);
  });

  testWidgets('real downward drag below threshold on short loading scrollable '
      'does not pop', (tester) async {
    final triggers = await pumpShortLoadingScrollableAndDrag(
      tester,
      threshold - 40,
    );
    expect(triggers, 0);
  });
}
