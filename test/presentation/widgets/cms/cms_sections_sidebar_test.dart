import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/cms/cms_page_editor_repository.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/widgets/cms/cms_sections_sidebar.dart';

CmsSectionConfig _section({
  required String id,
  required CmsSectionType type,
  required int position,
  bool isActive = true,
  Map<String, dynamic> config = const {},
}) {
  return parseCmsSection(
    CmsSectionRecord(
      id: id,
      pageId: 'page1',
      sectionId: id,
      sectionType: type,
      rawSectionType: type.wireName,
      position: position,
      isActive: isActive,
      config: config,
    ),
  );
}

List<IconButton> _buttonsByTooltip(WidgetTester tester, String tooltip) {
  return tester
      .widgetList<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      )
      .toList();
}

class _DelayedCmsEditorRepo implements CmsPageEditorRepository {
  final Completer<void> updateBlocker;
  final List<Map<String, dynamic>> updateCalls = [];

  _DelayedCmsEditorRepo({required this.updateBlocker});

  @override
  Future<String> createPlpPage({
    required String authToken,
    required String code,
    required String locale,
    required String title,
    required String sourceCategoryId,
    String? seoTitle,
    String? seoDescription,
  }) async {
    return 'page-plp-1';
  }

  @override
  Future<void> createSection({
    required String authToken,
    required String pageId,
    required String sectionId,
    required String sectionType,
    required int position,
    required bool isActive,
    required Map<String, dynamic> config,
  }) async {}

  @override
  Future<void> updateSection({
    required String authToken,
    required String sectionRecordId,
    required Map<String, dynamic> patch,
  }) async {
    updateCalls.add({
      'authToken': authToken,
      'sectionRecordId': sectionRecordId,
      'patch': patch,
    });
    await updateBlocker.future;
  }

  @override
  Future<void> deleteSection({
    required String authToken,
    required String sectionRecordId,
  }) async {}
}

void main() {
  testWidgets('CMS sidebar renders section tree and action availability', (
    tester,
  ) async {
    final sections = [
      _section(
        id: 'homepage-hero',
        type: CmsSectionType.heroCampaign,
        position: 0,
        config: {'title': 'Hero'},
      ),
      _section(
        id: 'homepage-services',
        type: CmsSectionType.serviceCards,
        position: 1,
        isActive: false,
        config: {
          'cards': [
            {'title': 'Livraison', 'href': '/shipping'},
          ],
        },
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CmsSectionsSidebar(
              pageId: 'page1',
              sections: sections,
              nextPosition: 2,
              onExpandedChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Homepage'), findsOneWidget);
    expect(find.text('Hero campagne'), findsOneWidget);
    expect(find.text('Cartes services'), findsOneWidget);
    expect(find.text('homepage-hero'), findsOneWidget);
    expect(find.text('homepage-services'), findsOneWidget);
    expect(find.text('Masquée'), findsOneWidget);

    expect(find.byTooltip('Éditer'), findsNWidgets(2));
    expect(find.byTooltip('Renommer'), findsNWidgets(2));
    expect(find.byTooltip('Dupliquer'), findsNWidgets(2));
    expect(find.byTooltip('Masquer'), findsOneWidget);
    expect(find.byTooltip('Activer'), findsOneWidget);

    final moveUpButtons = tester
        .widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.arrow_upward),
        )
        .toList();
    final moveDownButtons = tester
        .widgetList<IconButton>(
          find.widgetWithIcon(IconButton, Icons.arrow_downward),
        )
        .toList();
    expect(moveUpButtons, hasLength(2));
    expect(moveDownButtons, hasLength(2));
    expect(moveUpButtons.first.onPressed, isNull);
    expect(moveUpButtons.last.onPressed, isNotNull);
    expect(moveDownButtons.first.onPressed, isNotNull);
    expect(moveDownButtons.last.onPressed, isNull);
  });

  testWidgets('CMS sidebar can render collapsed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CmsSectionsSidebar(
              pageId: 'page1',
              sections: const [],
              nextPosition: 0,
              isExpanded: false,
              onExpandedChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Homepage'), findsNothing);
  });

  testWidgets('CMS sidebar disables mutating actions while saving', (
    tester,
  ) async {
    final blocker = Completer<void>();
    final repo = _DelayedCmsEditorRepo(updateBlocker: blocker);
    final sections = [
      _section(
        id: 'homepage-hero',
        type: CmsSectionType.heroCampaign,
        position: 0,
      ),
      _section(
        id: 'homepage-services',
        type: CmsSectionType.serviceCards,
        position: 1,
        isActive: false,
        config: {
          'cards': [
            {'title': 'Livraison', 'href': '/shipping'},
          ],
        },
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cmsPageEditorRepositoryProvider.overrideWithValue(repo),
          adminAuthTokenProvider.overrideWith((ref) => 'tok-1'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CmsSectionsSidebar(
              pageId: 'page1',
              sections: sections,
              nextPosition: 2,
              onExpandedChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_upward).last);
    await tester.pump();

    expect(repo.updateCalls, hasLength(2));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      _buttonsByTooltip(tester, 'Ajouter une section').single.onPressed,
      isNull,
    );
    for (final tooltip in [
      'Éditer',
      'Renommer',
      'Dupliquer',
      'Monter',
      'Descendre',
      'Masquer',
      'Activer',
      'Supprimer',
    ]) {
      for (final button in _buttonsByTooltip(tester, tooltip)) {
        expect(button.onPressed, isNull, reason: tooltip);
      }
    }
    expect(
      _buttonsByTooltip(tester, 'Replier le CMS').single.onPressed,
      isNotNull,
    );

    blocker.complete();
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
