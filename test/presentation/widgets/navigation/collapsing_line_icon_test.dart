import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/collapsing_line_icon.dart';

void main() {
  testWidgets('Dior menu-to-close icon starts as two horizontal bars', (
    tester,
  ) async {
    await _pumpIcon(tester, 0);

    expect(
      find.descendant(
        of: find.byType(DiorCollapsingLineIcon),
        matching: find.byType(CustomPaint),
      ),
      paints
        ..line()
        ..line(),
    );
  });

  testWidgets('Dior menu-to-close icon ends as a two-line cross', (
    tester,
  ) async {
    await _pumpIcon(tester, 1);

    expect(
      find.descendant(
        of: find.byType(DiorCollapsingLineIcon),
        matching: find.byType(CustomPaint),
      ),
      paints
        ..line()
        ..line(),
    );
  });
}

Future<void> _pumpIcon(WidgetTester tester, double progress) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: DiorCollapsingLineIcon(
          progress: AlwaysStoppedAnimation<double>(progress),
          shape: DiorCollapsingLineIconShape.menuToClose,
          color: Colors.black,
          size: 40,
          useExpandedMobile: true,
        ),
      ),
    ),
  );
}
