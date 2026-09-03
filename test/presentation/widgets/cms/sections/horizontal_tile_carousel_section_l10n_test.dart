import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/horizontal_tile_carousel_section.dart';

import '../../../../support/l10n_harness.dart';

void main() {
  testWidgets('localizes legacy French Nike carousel copy in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(
          body: HorizontalTileCarouselSection(
            config: HorizontalTileCarouselConfig(
              title: 'En ce moment',
              items: [
                HorizontalTileItem(label: "Articles d'été", href: '/catalog'),
                HorizontalTileItem(label: "Pack Ballon d'Or", href: '/catalog'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Trending now'), findsOneWidget);
    expect(find.text('Summer essentials'), findsOneWidget);
    expect(find.text("Ballon d'Or pack"), findsOneWidget);
    expect(find.text('En ce moment'), findsNothing);
    expect(find.text("Articles d'été"), findsNothing);
    expect(find.text("Pack Ballon d'Or"), findsNothing);
  });

  testWidgets('feature layout renders a paged carousel with overlaid labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HorizontalTileCarouselSection(
              config: HorizontalTileCarouselConfig(
                title: 'En ce moment',
                layout: 'feature',
                items: [
                  HorizontalTileItem(label: "Articles d'été", href: '/catalog'),
                  HorizontalTileItem(
                    label: "Pack Ballon d'Or",
                    href: '/catalog',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Feature mode swaps the tile ListView for a swipeable PageView.
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    // Labels are localized and overlaid on the card.
    expect(find.text('Summer essentials'), findsOneWidget);
    expect(find.text('Trending now'), findsOneWidget);
  });
}
