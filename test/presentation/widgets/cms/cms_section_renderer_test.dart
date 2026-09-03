import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/cms/cms_section_defaults.dart';
import 'package:kiki_commerce/presentation/widgets/cms/cms_section_renderer.dart';

void main() {
  CmsSectionRecord makeRecord(
    String type, {
    Map<String, dynamic> config = const {},
  }) {
    return CmsSectionRecord(
      id: 's',
      pageId: 'p',
      sectionId: 's',
      sectionType: CmsSectionType.fromWireName(type),
      rawSectionType: type,
      position: 0,
      isActive: true,
      config: config,
    );
  }

  testWidgets('renderer dispatches every known section type to a widget', (
    tester,
  ) async {
    final configs = <CmsSectionConfig>[
      for (final type in CmsSectionType.values)
        parseCmsSection(
          makeRecord(type.wireName, config: defaultConfigFor(type)),
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ListView(
                children: [
                  for (final c in configs) renderCmsSection(context, c),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // No exception during build means the registry covers all types.
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown section type renders SizedBox.shrink', (tester) async {
    final record = makeRecord('not_a_real_type');
    final config = parseCmsSection(record);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => renderCmsSection(context, config),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SizedBox), findsWidgets);
  });
}
