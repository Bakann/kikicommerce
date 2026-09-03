import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/category_hero_tags.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/category_tiles_section.dart';

void main() {
  const media = CmsMediaRef(
    recordId: 'rec-1',
    collectionId: 'col-1',
    filename: 'tile.jpg',
  );

  testWidgets('PLP tiles wear a slug Hero tag; non-PLP tiles do not', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryTilesSection(
                config: CategoryTilesConfig(
                  tiles: [
                    CategoryTileItem(
                      label: 'Mercurial',
                      href: '/catalog/mercurial',
                      media: media,
                    ),
                    CategoryTileItem(
                      label: 'Rechercher',
                      href: '/search',
                      media: media,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final heroes = tester.widgetList<Hero>(find.byType(Hero)).toList();
    // Only the PLP-bound tile is heroised.
    expect(heroes, hasLength(1));
    expect(heroes.single.tag, categoryPlpHeroTag('mercurial'));

    // Swallow async image-load errors from the test sandbox.
    tester.takeException();
  });
}
