import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/horizontal_tile_carousel_section.dart';
import 'package:kiki_commerce/presentation/widgets/horizontal_parallax.dart';

import '../../../../support/l10n_harness.dart';

void main() {
  Widget buildFeatureCarousel() {
    return MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: HorizontalTileCarouselSection(
            config: HorizontalTileCarouselConfig(
              title: 'En ce moment',
              layout: 'feature',
              items: const [
                HorizontalTileItem(label: "Articles d'été", href: '/catalog'),
                HorizontalTileItem(label: "Pack Ballon d'Or", href: '/catalog'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('feature cards wrap their image in a HorizontalParallax', (
    tester,
  ) async {
    await tester.pumpWidget(buildFeatureCarousel());
    await tester.pump();

    // One parallax per built feature card.
    expect(find.byType(HorizontalParallax), findsWidgets);
  });

  testWidgets('parallax renders the image wider than the card so it can pan', (
    tester,
  ) async {
    await tester.pumpWidget(buildFeatureCarousel());
    await tester.pump();

    final parallax = tester
        .renderObjectList<RenderHorizontalParallax>(
          find.byType(HorizontalParallax),
        )
        .first;

    final child = parallax.child;
    expect(child, isNotNull);
    // Default overscan (1.3) lays the child out wider than the box: this extra
    // width is the slack the image slides within. Without it there is nothing
    // to pan and the effect is invisible.
    expect(child!.size.width, greaterThan(parallax.size.width));
    // Cross-axis stays tight so only the horizontal crop moves.
    expect(child.size.height, parallax.size.height);
  });
}
