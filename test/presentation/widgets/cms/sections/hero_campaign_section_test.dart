import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/hero_campaign_section.dart';

void main() {
  Future<void> pumpHero(
    WidgetTester tester,
    HeroCampaignConfig config, {
    String? backgroundFallbackImageUrl,
    bool disableAnimations = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HeroCampaignSection(
              config: config,
              backgroundFallbackImageUrl: backgroundFallbackImageUrl,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('square heightMode renders a full-bleed 1:1 hero', (
    tester,
  ) async {
    await pumpHero(
      tester,
      const HeroCampaignConfig(title: '', heightMode: 'square'),
    );
    await tester.pump();

    final ratios = tester
        .widgetList<AspectRatio>(find.byType(AspectRatio))
        .map((a) => a.aspectRatio);
    expect(ratios, contains(1.0));
  });

  testWidgets('image-only square hero shows no overlay copy', (tester) async {
    await pumpHero(
      tester,
      const HeroCampaignConfig(title: '', heightMode: 'square'),
    );
    await tester.pump();

    // No eyebrow/title/subtitle/body/cta → no text overlay (and no gradient).
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('square hero with a title shows the overlay copy', (
    tester,
  ) async {
    await pumpHero(
      tester,
      const HeroCampaignConfig(title: 'Été', heightMode: 'square'),
    );
    await tester.pump();

    expect(find.text('Été'), findsOneWidget);
  });

  testWidgets('renders all overlay copy when text reveal is disabled', (
    tester,
  ) async {
    await pumpHero(
      tester,
      const HeroCampaignConfig(
        eyebrow: 'Nouveau',
        subtitle: 'Collection été',
        title: 'Été',
        body: 'Une sélection pour la saison.',
        primaryCta: CmsCta(label: 'Découvrir', href: '/catalog'),
      ),
      disableAnimations: true,
    );
    await tester.pump();

    expect(find.text('Nouveau'), findsOneWidget);
    expect(find.text('Collection été'), findsOneWidget);
    expect(find.text('Été'), findsOneWidget);
    expect(find.text('Une sélection pour la saison.'), findsOneWidget);
    expect(find.text('Découvrir'), findsOneWidget);
  });

  testWidgets('keeps the fallback image behind a loading media image', (
    tester,
  ) async {
    const fallbackUrl = 'https://example.test/source-tile.jpg';

    await pumpHero(
      tester,
      const HeroCampaignConfig(
        title: '',
        heightMode: 'square',
        mediaDesktop: CmsMediaRef(
          recordId: 'rec-1',
          collectionId: 'col-1',
          filename: 'plp.jpg',
        ),
      ),
      backgroundFallbackImageUrl: fallbackUrl,
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url == fallbackUrl,
      ),
      findsOneWidget,
    );

    tester.takeException();
  });
}
