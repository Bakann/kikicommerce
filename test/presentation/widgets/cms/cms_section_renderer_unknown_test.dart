import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/cms/cms_section_renderer.dart';

CmsUnknownSection _unknown({
  String rawType = 'not_a_real_type',
  Object? parseError,
}) {
  return CmsUnknownSection(
    CmsSectionRecord(
      id: 's1',
      pageId: 'p1',
      sectionId: 's1',
      sectionType: CmsSectionType.fromWireName(rawType),
      rawSectionType: rawType,
      position: 0,
      isActive: true,
      config: const {},
    ),
    parseError: parseError,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required CmsUnknownSection section,
  required bool isEditMode,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) =>
                renderCmsSection(context, section, isEditMode: isEditMode),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('renderCmsSection unknown section', () {
    testWidgets('renders SizedBox.shrink in storefront mode', (tester) async {
      await _pump(tester, section: _unknown(), isEditMode: false);

      expect(find.text('Type de section inconnu'), findsNothing);
      expect(find.text('Section CMS en erreur'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('renders the diagnostic in edit mode', (tester) async {
      await _pump(
        tester,
        section: _unknown(rawType: 'not_a_real_type'),
        isEditMode: true,
      );

      expect(find.text('Type de section inconnu'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('not_a_real_type'), findsOneWidget);
    });

    testWidgets('exposes the parse error message in edit mode', (tester) async {
      await _pump(
        tester,
        section: _unknown(
          rawType: 'hero_campaign',
          parseError: const FormatException('bad config field'),
        ),
        isEditMode: true,
      );

      expect(find.text('Section CMS en erreur'), findsOneWidget);
      expect(find.textContaining('bad config field'), findsOneWidget);
    });
  });
}
