import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/collection_hero_section.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/editorial_intro_section.dart';

void main() {
  Future<void> pumpSection(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  testWidgets('editorial intro copy renders when text reveal is disabled', (
    tester,
  ) async {
    await pumpSection(
      tester,
      const EditorialIntroSection(
        config: EditorialIntroConfig(
          eyebrow: 'Maison',
          title: 'Une ligne éditoriale',
          body: 'Un texte court pour introduire la sélection.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MAISON'), findsOneWidget);
    expect(find.text('Une ligne éditoriale'), findsOneWidget);
    expect(
      find.text('Un texte court pour introduire la sélection.'),
      findsOneWidget,
    );
  });

  testWidgets('collection hero copy renders when text reveal is disabled', (
    tester,
  ) async {
    await pumpSection(
      tester,
      const CollectionHeroSection(
        config: CollectionHeroConfig(
          title: 'Collection capsule',
          intro: 'Une introduction claire pour la collection.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Collection capsule'), findsOneWidget);
    expect(
      find.text('Une introduction claire pour la collection.'),
      findsOneWidget,
    );
  });
}
