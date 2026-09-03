import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_layout.dart';

void main() {
  void setDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
  }

  void resetSurface(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets(
    'StorefrontStickySidebar stays fixed mid-scroll then releases at the end',
    (WidgetTester tester) async {
      setDesktopSurface(tester);
      addTearDown(() => resetSurface(tester));

      const stickyKey = Key('sticky-child');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 2000,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: SizedBox()),
                        SizedBox(width: 32),
                        SizedBox(
                          width: 320,
                          child: StorefrontStickySidebar(
                            topOffset: 24,
                            child: SizedBox(
                              key: stickyKey,
                              height: 1500,
                              child: ColoredBox(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final topBefore = tester.getTopLeft(find.byKey(stickyKey)).dy;
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));

      scrollable.position.jumpTo(300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pumpAndSettle();

      final topMidScroll = tester.getTopLeft(find.byKey(stickyKey)).dy;

      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pumpAndSettle();

      final topNearEnd = tester.getTopLeft(find.byKey(stickyKey)).dy;

      expect(topBefore, lessThanOrEqualTo(24));
      expect(topMidScroll, closeTo(topBefore, 1));
      expect(topNearEnd, lessThan(24));
    },
  );

  testWidgets(
    'StorefrontStickyPanels uses the rendered left column height for the sidebar',
    (WidgetTester tester) async {
      setDesktopSurface(tester);
      addTearDown(() => resetSurface(tester));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StorefrontStickyPanels(
                leftFlex: 1,
                rightFlex: 1,
                fallbackRightHeight: 320,
                leftChild: const SizedBox(
                  height: 960,
                  child: ColoredBox(color: Colors.blue),
                ),
                rightChild: const SizedBox(
                  height: 240,
                  child: ColoredBox(color: Colors.red),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(StorefrontStickySidebar)).height,
        closeTo(960, 1),
      );
    },
  );
}
