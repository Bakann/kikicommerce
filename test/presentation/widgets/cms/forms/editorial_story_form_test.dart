import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/cms/forms/editorial_story_form.dart';

Future<Map<String, dynamic>> _pumpAndCapture(
  WidgetTester tester, {
  required Map<String, dynamic> initial,
  required Future<void> Function() interact,
}) async {
  Map<String, dynamic> latest = Map<String, dynamic>.from(initial);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1024,
            child: EditorialStoryForm(
              initialConfig: initial,
              onChanged: (next) => latest = next,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await interact();
  await tester.pumpAndSettle();
  return latest;
}

void main() {
  group('EditorialStoryForm', () {
    testWidgets('renders the initial config fields', (tester) async {
      await _pumpAndCapture(
        tester,
        initial: {
          'eyebrow': 'DIOR WORLD',
          'title': 'Le sac Cigale',
          'body': 'Réinterprétant les lignes architecturales',
          'primaryCta': {'label': 'Découvrir', 'href': '/stories/cigale'},
          'mediaDesktop': null,
          'mediaMobile': null,
          'mediaType': 'image',
          'layoutVariant': 'mediaLeft',
          'backgroundTone': 'sand',
        },
        interact: () async {},
      );

      expect(find.text('DIOR WORLD'), findsOneWidget);
      expect(find.text('Le sac Cigale'), findsOneWidget);
      expect(find.textContaining('Réinterprétant'), findsOneWidget);
      expect(find.text('Découvrir'), findsOneWidget);
      expect(find.text('/stories/cigale'), findsOneWidget);
    });

    testWidgets('emits the new title on text change', (tester) async {
      final emitted = await _pumpAndCapture(
        tester,
        initial: {'title': 'Old', 'mediaType': 'image'},
        interact: () async {
          final titleField = find.widgetWithText(TextField, 'Old');
          await tester.enterText(titleField, 'New title');
        },
      );
      expect(emitted['title'], 'New title');
    });

    testWidgets('clears optional text fields back to null in the map', (
      tester,
    ) async {
      final emitted = await _pumpAndCapture(
        tester,
        initial: {
          'eyebrow': 'INTRO',
          'title': 'Required',
          'body': null,
          'mediaType': 'image',
        },
        interact: () async {
          final eyebrowField = find.widgetWithText(TextField, 'INTRO');
          await tester.enterText(eyebrowField, '   ');
        },
      );
      expect(emitted.containsKey('eyebrow'), isTrue);
      expect(emitted['eyebrow'], isNull);
    });

    testWidgets('emits a parseable EditorialStoryConfig after edits', (
      tester,
    ) async {
      final emitted = await _pumpAndCapture(
        tester,
        initial: {
          'title': 'Initial',
          'mediaType': 'image',
          'layoutVariant': 'mediaTop',
          'backgroundTone': 'light',
        },
        interact: () async {
          final titleField = find.widgetWithText(TextField, 'Initial');
          await tester.enterText(titleField, 'Edited');
        },
      );

      final parsed = EditorialStoryConfig.fromJson(emitted);
      expect(parsed.title, 'Edited');
      expect(parsed.layoutVariant, 'mediaTop');
      expect(parsed.backgroundTone, 'light');
    });

    testWidgets('hydrates without crashing when text fields are mistyped', (
      tester,
    ) async {
      // The storefront read path tolerates wrong-typed config (numbers, bools,
      // arrays) and degrades gracefully; the editor form must not crash when an
      // author opens such a section. Previously these values hit `as String`
      // casts in _hydrate and threw a TypeError.
      // Reaching pumpAndSettle without throwing already proves _hydrate no
      // longer crashes on these values (it previously threw a TypeError on the
      // `as String` casts). Editing the title forces an emit so we can also
      // assert the mistyped fields were coerced to safe defaults.
      final emitted = await _pumpAndCapture(
        tester,
        initial: {
          'eyebrow': 123,
          'title': true,
          'body': ['a', 'b'],
          'primaryCta': {'label': 42, 'href': false},
          'mediaType': 7,
          'layoutVariant': {'bad': 'shape'},
          'backgroundTone': ['dark'],
        },
        // Index 1 is the title field (0=eyebrow, 1=title, 2=body, ...).
        interact: () async {
          await tester.enterText(find.byType(TextField).at(1), 'Recovered');
        },
      );

      expect(emitted['title'], 'Recovered');
      expect(emitted['eyebrow'], isNull);
      expect(emitted['mediaType'], 'image');
      expect(emitted['layoutVariant'], 'mediaTop');
      expect(emitted['backgroundTone'], 'light');
    });

    testWidgets('drops the cta object when both label and href are blank', (
      tester,
    ) async {
      final emitted = await _pumpAndCapture(
        tester,
        initial: {
          'title': 'X',
          'primaryCta': {'label': 'a', 'href': '/b'},
          'mediaType': 'image',
        },
        interact: () async {
          await tester.enterText(find.widgetWithText(TextField, 'a'), '');
          await tester.enterText(find.widgetWithText(TextField, '/b'), '');
        },
      );
      expect(emitted['primaryCta'], isNull);
    });
  });
}
