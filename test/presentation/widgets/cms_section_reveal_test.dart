import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/screens/storefront_landing_page.dart';
import 'package:kiki_commerce/presentation/widgets/cms/cms_section_reveal.dart';

void main() {
  setUp(resetCmsSectionRevealMemoryForTest);

  group('CmsSectionReveal', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('child is mounted from the start (the reveal wraps it)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const CmsSectionReveal(child: Text('payload'))),
      );
      expect(find.text('payload'), findsOneWidget);
    });

    for (final style in CmsSectionRevealStyle.values) {
      testWidgets('animates to a stable state in style ${style.name}', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            CmsSectionReveal(
              style: style,
              duration: const Duration(milliseconds: 200),
              child: const SizedBox(width: 100, height: 50, child: Text('p')),
            ),
          ),
        );

        // Reveal should be in-progress: pump a frame, controller is running.
        await tester.pump(const Duration(milliseconds: 50));
        // Settle past the full duration; no pending animations afterwards.
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('p'), findsOneWidget);
      });
    }

    testWidgets('non-zero delay keeps the controller idle until it elapses', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          CmsSectionReveal(
            style: CmsSectionRevealStyle.slideUp,
            duration: const Duration(milliseconds: 200),
            delay: const Duration(milliseconds: 300),
            child: const Text('delayed'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Still mounted (it's just the visual that's animating in).
      expect(find.text('delayed'), findsOneWidget);

      // Fast-forward past delay + duration; widget remains stable.
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('delayed'), findsOneWidget);
    });

    testWidgets(
      'premiumFadeUp is layout-neutral: only Opacity, no clip, no Transform '
      'wrapper of its own (safe for full-bleed hero sections, especially '
      'ones hosting an HtmlElementView like the landing video)',
      (tester) async {
        await tester.pumpWidget(
          host(
            const CmsSectionReveal(
              style: CmsSectionRevealStyle.premiumFadeUp,
              duration: Duration(milliseconds: 200),
              child: SizedBox(
                key: ValueKey('hero-payload'),
                width: 100,
                height: 50,
                child: Text('hero'),
              ),
            ),
          ),
        );
        // Mid-animation: opacity wrapping must be present; no clipping, no Transform.
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(ClipRect), findsNothing);
        expect(find.byType(ClipPath), findsNothing);
        // The parent of the payload should not be a Transform if it's layout neutral.
        // It's strictly Opacity -> SizedBox -> Text.
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('hero-payload')),
            matching: find.byType(Transform),
          ),
          findsNothing,
        );
        expect(find.byType(Opacity), findsAtLeastNWidgets(1));

        // After completion: the reveal must short-circuit and put the
        // child back into the tree without ANY of its own wrappers.
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byKey(const ValueKey('hero-payload')), findsOneWidget);
      },
    );

    testWidgets(
      'a unique key per section prevents a previously-played reveal from '
      'replaying on rebuild',
      (tester) async {
        Widget build({required int counter}) => host(
          CmsSectionReveal(
            // Stable key — same reveal across rebuilds.
            key: const ValueKey('cms-reveal-stable'),
            duration: const Duration(milliseconds: 200),
            child: Text('frame $counter'),
          ),
        );

        await tester.pumpWidget(build(counter: 1));
        await tester.pump(const Duration(milliseconds: 250));
        // Trigger a rebuild with a different child but the SAME key — the
        // existing State (and its already-finished controller) is reused.
        await tester.pumpWidget(build(counter: 2));
        await tester.pump();
        expect(find.text('frame 2'), findsOneWidget);
      },
    );
  });

  group('revealStyleFor mapping', () {
    CmsSectionRecord record(String id) => CmsSectionRecord(
      id: id,
      pageId: 'page',
      sectionId: id,
      sectionType: null,
      rawSectionType: id,
      position: 0,
      isActive: true,
      config: const {},
    );

    test('hero sections use premiumFadeUp (not curtain)', () {
      final hero = CmsHeroSection(
        record('hero'),
        const HeroCampaignConfig(title: 'Hero'),
      );
      final collection = CmsCollectionHeroSection(
        record('collection'),
        const CollectionHeroConfig(title: 'Collection'),
      );
      expect(revealStyleFor(hero), CmsSectionRevealStyle.premiumFadeUp);
      expect(revealStyleFor(collection), CmsSectionRevealStyle.premiumFadeUp);

      // Explicit guard: hero must NOT regress to the fragile curtain.
      expect(revealStyleFor(hero), isNot(CmsSectionRevealStyle.curtain));
      expect(revealStyleFor(collection), isNot(CmsSectionRevealStyle.curtain));
    });
  });

  group('shouldRevealSection mapping', () {
    CmsSectionRecord record(String id) => CmsSectionRecord(
      id: id,
      pageId: 'page',
      sectionId: id,
      sectionType: null,
      rawSectionType: id,
      position: 0,
      isActive: true,
      config: const {},
    );

    test('excludes first two sections and all hero variants', () {
      final hero = CmsHeroSection(
        record('hero'),
        const HeroCampaignConfig(title: ''),
      );
      final collectionHero = CmsCollectionHeroSection(
        record('collection'),
        const CollectionHeroConfig(title: ''),
      );
      final tiles = CmsCategoryTilesSection(
        record('tiles'),
        const CategoryTilesConfig(title: ''),
      );

      bool reveal(int index, CmsSectionConfig section) => shouldRevealSection(
        index: index,
        section: section,
        isSegmentedLanding: false,
      );

      expect(reveal(0, hero), isFalse);
      expect(reveal(1, tiles), isFalse);
      expect(reveal(2, tiles), isTrue);
      expect(reveal(3, collectionHero), isFalse);
      expect(reveal(3, tiles), isTrue);
    });

    test('segmented (Sport tab) landing never reveals any section', () {
      final tiles = CmsCategoryTilesSection(
        record('tiles'),
        const CategoryTilesConfig(title: ''),
      );
      // Even a normally-revealing section/index is suppressed on a segmented
      // landing, so switching Homme/Femme/Enfant tabs replays no fade.
      expect(
        shouldRevealSection(index: 2, section: tiles, isSegmentedLanding: true),
        isFalse,
      );
      expect(
        shouldRevealSection(index: 5, section: tiles, isSegmentedLanding: true),
        isFalse,
      );
    });
  });

  group('CmsSectionReveal reveal-once', () {
    Widget reveal(String id) => MaterialApp(
      home: Scaffold(
        body: CmsSectionReveal(
          key: ValueKey(id),
          revealId: id,
          duration: const Duration(milliseconds: 300),
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );

    testWidgets(
      'animates on first mount, then shows resting state on remount with the '
      'same revealId',
      (tester) async {
        await tester.pumpWidget(reveal('section-1'));
        await tester.pump(const Duration(milliseconds: 40));
        expect(find.byType(Opacity), findsWidgets); // animating
        await tester.pumpAndSettle();
        expect(find.byType(Opacity), findsNothing); // settled to resting state

        // Remount the same id (simulating a tab switch): jumps straight to the
        // resting state — no Opacity, i.e. no replayed fade.
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox())),
        );
        await tester.pumpWidget(reveal('section-1'));
        await tester.pump();
        expect(find.byType(Opacity), findsNothing);
      },
    );

    testWidgets('still animates for a different revealId', (tester) async {
      await tester.pumpWidget(reveal('a'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(reveal('b'));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(Opacity), findsWidgets);
      await tester.pumpAndSettle();
    });
  });
}
