import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/vertical_parallax.dart';

void main() {
  testWidgets('renders the child taller than the box so it can pan vertically', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              SizedBox(
                height: 200,
                child: Builder(
                  builder: (context) => VerticalParallax(
                    scrollable: Scrollable.of(context),
                    overscan: 1.2,
                    child: const ColoredBox(color: Color(0xFFFF0000)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final parallax = tester.renderObject<RenderVerticalParallax>(
      find.byType(VerticalParallax),
    );

    final child = parallax.child;
    expect(child, isNotNull);
    // overscan (1.2) lays the child out taller than the box: this extra height
    // is the slack the image slides within. Without it there is nothing to pan.
    expect(child!.size.height, greaterThan(parallax.size.height));
    // Cross-axis stays tight so only the vertical crop moves.
    expect(child.size.width, parallax.size.width);
  });
}
