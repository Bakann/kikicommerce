import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/animations/text_reveal/text_reveal.dart';

void main() {
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
            ? body
            : SingleChildScrollView(controller: controller, child: body),
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

  TextRevealGroup revealGroup({
    required Key key,
    TextRevealTrigger trigger = TextRevealTrigger.mount,
    List<Widget>? children,
  }) {
    return TextRevealGroup(
      key: key,
      trigger: trigger,
      duration: const Duration(milliseconds: 200),
      stagger: const Duration(milliseconds: 40),
      children:
          children ??
          const [
            TextRevealItem(child: Text('Primary copy')),
            SizedBox(height: 8),
            TextRevealItem(child: Text('Secondary copy')),
          ],
    );
  }

  testWidgets('mounts its content from the first frame', (tester) async {
    const key = ValueKey('mounted');
    await tester.pumpWidget(host(revealGroup(key: key)));

    expect(find.text('Primary copy'), findsOneWidget);
    expect(find.text('Secondary copy'), findsOneWidget);
  });

  testWidgets('disableAnimations shows content directly without a controller', (
    tester,
  ) async {
    const key = ValueKey('disabled');
    await tester.pumpWidget(
      host(revealGroup(key: key), disableAnimations: true),
    );

    final state = tester.state<TextRevealGroupState>(find.byKey(key));
    expect(find.text('Primary copy'), findsOneWidget);
    expect(state.debugHasStarted, isTrue);
    expect(state.debugHasCompleted, isTrue);
    expect(state.debugHasController, isFalse);
  });

  testWidgets('viewport trigger starts post-frame when already visible', (
    tester,
  ) async {
    const key = ValueKey('visible');
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        revealGroup(key: key, trigger: TextRevealTrigger.viewport),
        controller: controller,
      ),
    );
    await tester.pump();

    final state = tester.state<TextRevealGroupState>(find.byKey(key));
    expect(state.debugHasStarted, isTrue);
  });

  testWidgets('viewport trigger starts after scrolling into view', (
    tester,
  ) async {
    setViewSize(tester, const Size(400, 300));
    const key = ValueKey('offscreen');
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        Column(
          children: [
            const SizedBox(height: 900),
            revealGroup(key: key, trigger: TextRevealTrigger.viewport),
            const SizedBox(height: 900),
          ],
        ),
        controller: controller,
      ),
    );
    await tester.pump();

    var state = tester.state<TextRevealGroupState>(find.byKey(key));
    expect(state.debugHasStarted, isFalse);
    expect(state.debugHasScrollListener, isTrue);

    controller.jumpTo(820);
    await tester.pump();
    await tester.pump();

    state = tester.state<TextRevealGroupState>(find.byKey(key));
    expect(state.debugHasStarted, isTrue);
    expect(state.debugHasScrollListener, isFalse);
  });

  testWidgets('viewport trigger falls back to mount without a Scrollable', (
    tester,
  ) async {
    const key = ValueKey('no-scrollable');
    await tester.pumpWidget(
      host(revealGroup(key: key, trigger: TextRevealTrigger.viewport)),
    );
    await tester.pump();

    final state = tester.state<TextRevealGroupState>(find.byKey(key));
    expect(find.text('Primary copy'), findsOneWidget);
    expect(state.debugHasStarted, isTrue);
  });

  testWidgets('dispose cleans listeners without post-dispose exceptions', (
    tester,
  ) async {
    setViewSize(tester, const Size(400, 300));
    const key = ValueKey('dispose');
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      host(
        Column(
          children: [
            const SizedBox(height: 900),
            revealGroup(key: key, trigger: TextRevealTrigger.viewport),
            const SizedBox(height: 900),
          ],
        ),
        controller: controller,
      ),
    );
    await tester.pump();
    final state = tester.state<TextRevealGroupState>(find.byKey(key));
    expect(state.debugHasScrollListener, isTrue);

    await tester.pumpWidget(
      host(const SizedBox(height: 1200), controller: controller),
    );
    controller.jumpTo(200);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
