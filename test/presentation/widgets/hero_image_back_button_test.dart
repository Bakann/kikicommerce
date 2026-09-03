import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/hero_image_back_button.dart';

Widget _harness({required bool triggerBubblePop, required VoidCallback onTap}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: HeroImageBackButton(
          onPressed: onTap,
          triggerBubblePop: triggerBubblePop,
        ),
      ),
    ),
  );
}

int _bubblePaintCount(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .where((widget) => widget.painter != null)
      .length;
}

void main() {
  testWidgets('runs bubble pop only on false-to-true trigger', (tester) async {
    var taps = 0;
    void onTap() => taps += 1;

    await tester.pumpWidget(_harness(triggerBubblePop: false, onTap: onTap));
    expect(_bubblePaintCount(tester), 0);

    await tester.pumpWidget(_harness(triggerBubblePop: true, onTap: onTap));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_bubblePaintCount(tester), 1);

    await tester.pump(const Duration(milliseconds: 700));
    expect(_bubblePaintCount(tester), 0);

    await tester.pumpWidget(_harness(triggerBubblePop: true, onTap: onTap));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_bubblePaintCount(tester), 0);

    await tester.tap(find.byKey(kHeroImageBackButtonKey));
    expect(taps, 1);
  });

  testWidgets('runs bubble pop once when mounted with trigger already true', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(triggerBubblePop: true, onTap: () {}));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_bubblePaintCount(tester), 1);

    await tester.pump(const Duration(milliseconds: 700));
    expect(_bubblePaintCount(tester), 0);

    await tester.pumpWidget(_harness(triggerBubblePop: true, onTap: () {}));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_bubblePaintCount(tester), 0);
  });

  testWidgets(
    'does not create animation widgets when animations are disabled',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(_harness(triggerBubblePop: false, onTap: () {}));
      await tester.pumpWidget(_harness(triggerBubblePop: true, onTap: () {}));
      await tester.pump(const Duration(milliseconds: 100));

      expect(_bubblePaintCount(tester), 0);
      expect(find.byKey(kHeroImageBackButtonKey), findsOneWidget);
    },
  );
}
