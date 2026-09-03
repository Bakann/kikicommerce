import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/cms/cms_page_repository.dart';
import 'package:kiki_commerce/presentation/providers/category_plp_hero_provider.dart';
import 'package:kiki_commerce/presentation/providers/cms_page_provider.dart';
import 'package:kiki_commerce/presentation/widgets/category_hero_tags.dart';
import 'package:kiki_commerce/presentation/widgets/category_plp_hero.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/hero_campaign_section.dart';

void main() {
  const slugKey = 'mercurial';
  const categoryId = 'cat-1';

  // Keep the configured-image read offline: the destination CMS PLP resolves to
  // no hero section, so only the carried tile image (or nothing) is rendered.
  final noConfiguredHero = cmsPlpProvider(
    const CmsPlpRequest(categoryId: categoryId, locale: defaultCmsLocale),
  ).overrideWith((ref) async => null);

  testWidgets('mounts a 1:1 Hero with the slug tag when a tile hint exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noConfiguredHero,
          categoryPlpHeroShuttleProvider(slugKey).overrideWith(
            (ref) => const CategoryPlpHeroShuttle(
              imageUrl: 'https://example.test/tile.jpg',
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CategoryPlpHero(slugKey: slugKey, categoryId: categoryId),
          ),
        ),
      ),
    );
    // Single frame only: do not settle so the NetworkImage load never resolves
    // (the Hero exists in the tree regardless of image loading).
    await tester.pump();

    final heroFinder = find.byType(Hero);
    expect(heroFinder, findsOneWidget);
    expect(tester.widget<Hero>(heroFinder).tag, categoryPlpHeroTag(slugKey));
    expect(find.byType(AspectRatio), findsOneWidget);

    // The base NetworkImage cannot load in the test sandbox; swallow that
    // async image error so it does not fail the test (the Hero structure,
    // which is what we assert, is independent of the image load).
    tester.takeException();
  });

  testWidgets(
    'renders nothing when there is neither a hint nor configured image',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [noConfiguredHero],
          child: const MaterialApp(
            home: Scaffold(
              body: CategoryPlpHero(slugKey: slugKey, categoryId: categoryId),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Hero), findsNothing);
    },
  );

  testWidgets(
    'with a null categoryId (loading placeholder) still mounts the tagged Hero '
    'from the hint',
    (tester) async {
      // Regression: on a cold visit the destination category is still resolving
      // (categoryId unknown), but the hero must already exist so the inbound
      // flight pairs. A pending hint alone must be enough.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoryPlpHeroShuttleProvider(slugKey).overrideWith(
              (ref) => const CategoryPlpHeroShuttle(
                imageUrl: 'https://example.test/tile.jpg',
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CategoryPlpHero(slugKey: slugKey, categoryId: null),
            ),
          ),
        ),
      );
      await tester.pump();

      final heroFinder = find.byType(Hero);
      expect(heroFinder, findsOneWidget);
      expect(tester.widget<Hero>(heroFinder).tag, categoryPlpHeroTag(slugKey));

      tester.takeException();
    },
  );

  testWidgets(
    'renders the configured hero_campaign section (WYSIWYG with edit mode)',
    (tester) async {
      final bundle = CmsPageBundle(
        page: const CmsPageRecord(
          id: 'page-1',
          code: 'plp_x',
          locale: 'fr',
          title: 'X',
          isActive: true,
        ),
        sections: [
          CmsHeroSection(
            const CmsSectionRecord(
              id: 'sec-hero',
              pageId: 'page-1',
              sectionId: 'hero',
              sectionType: CmsSectionType.heroCampaign,
              rawSectionType: 'hero_campaign',
              position: 0,
              isActive: true,
              config: {},
            ),
            const HeroCampaignConfig(
              title: '',
              heightMode: 'square',
              mediaDesktop: CmsMediaRef(
                recordId: 'rec-1',
                collectionId: 'col-1',
                filename: 'plp.jpg',
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoryPlpHeroShuttleProvider(slugKey).overrideWith(
              (ref) => const CategoryPlpHeroShuttle(
                imageUrl: 'https://example.test/tile.jpg',
              ),
            ),
            cmsPlpProvider(
              const CmsPlpRequest(
                categoryId: categoryId,
                locale: defaultCmsLocale,
              ),
            ).overrideWith((ref) async => bundle),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CategoryPlpHero(
                  slugKey: slugKey,
                  categoryId: categoryId,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(); // resolve the cmsPlp future
      await tester.pump(); // rebuild with data

      // The storefront hero is the very same HeroCampaignSection the admin
      // edits, so it cannot drift from what they see in edit mode.
      final heroCampaign = tester.widget<HeroCampaignSection>(
        find.byType(HeroCampaignSection),
      );
      expect(
        heroCampaign.backgroundFallbackImageUrl,
        'https://example.test/tile.jpg',
      );

      tester.takeException();
    },
  );
}
