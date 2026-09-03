import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/service_cards_section.dart';

void main() {
  ServiceCardItem card(String title) =>
      ServiceCardItem(title: title, href: '/$title');

  Future<void> pumpSection(
    WidgetTester tester, {
    required List<ServiceCardItem> cards,
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceCardsSection(
              config: ServiceCardsConfig(title: 'Services', cards: cards),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('does not use a GridView (no shrinkWrap layout pass)', (
    tester,
  ) async {
    await pumpSection(
      tester,
      cards: [card('a'), card('b'), card('c')],
      size: const Size(1440, 900),
    );
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('desktop: renders 3 cards on a single row', (tester) async {
    await pumpSection(
      tester,
      cards: [card('a'), card('b'), card('c')],
      size: const Size(1440, 900),
    );
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);

    final positions = [
      'a',
      'b',
      'c',
    ].map((label) => tester.getTopLeft(find.text(label)).dy).toList();
    expect(positions.toSet().length, 1, reason: 'All cards on the same row');
  });

  testWidgets('mobile: stacks cards in a single column', (tester) async {
    await pumpSection(
      tester,
      cards: [card('a'), card('b'), card('c')],
      size: const Size(390, 1200),
    );

    final ys = [
      'a',
      'b',
      'c',
    ].map((label) => tester.getTopLeft(find.text(label)).dy).toList();
    expect(ys[0] < ys[1], isTrue);
    expect(ys[1] < ys[2], isTrue);
  });

  testWidgets('handles short last row (2 cards / 3 columns) without crashing', (
    tester,
  ) async {
    await pumpSection(
      tester,
      cards: [card('a'), card('b'), card('c'), card('d'), card('e')],
      size: const Size(1440, 900),
    );
    // 5 items / 3 cols → 2 rows, last row has 2 cards + 1 phantom cell.
    for (final label in ['a', 'b', 'c', 'd', 'e']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
