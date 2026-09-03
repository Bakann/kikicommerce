import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/cms/cms_page_editor_repository.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/widgets/cms/cms_edit_overlay.dart';

CmsSectionConfig _section({
  required String id,
  required int position,
  bool isActive = true,
}) {
  return parseCmsSection(
    CmsSectionRecord(
      id: id,
      pageId: 'page1',
      sectionId: id,
      sectionType: CmsSectionType.horizontalTileCarousel,
      rawSectionType: CmsSectionType.horizontalTileCarousel.wireName,
      position: position,
      isActive: isActive,
      config: const {'title': 'Tiles', 'items': []},
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
  testWidgets('CMS edit overlay disables mutating actions while saving', (
    tester,
  ) async {
    final blocker = Completer<void>();
    final repo = _DelayedCmsEditorRepo(updateBlocker: blocker);
    final sections = [
      _section(id: 'top', position: 0),
      _section(id: 'middle', position: 1),
      _section(id: 'bottom', position: 2),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cmsPageEditorRepositoryProvider.overrideWithValue(repo),
          adminAuthTokenProvider.overrideWith((ref) => 'tok-1'),
          editModeProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CmsEditOverlay(
              section: sections[1],
              allSections: sections,
              pageId: 'page1',
              child: const SizedBox(width: 240, height: 120),
            ),
          ),
        ),
      ),
    );

    expect(_buttonsByTooltip(tester, 'Monter').single.onPressed, isNotNull);
    expect(_buttonsByTooltip(tester, 'Descendre').single.onPressed, isNotNull);

    await tester.tap(find.byTooltip('Monter'));
    await tester.pump();

    expect(repo.updateCalls, hasLength(2));
    for (final tooltip in [
      'Monter',
      'Descendre',
      'Masquer',
      'Éditer',
      'Supprimer',
    ]) {
      expect(_buttonsByTooltip(tester, tooltip).single.onPressed, isNull);
    }

    blocker.complete();
    await tester.pump();

    expect(_buttonsByTooltip(tester, 'Monter').single.onPressed, isNotNull);
  });
}
