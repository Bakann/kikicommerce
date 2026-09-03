import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/cms/cms_models.dart';
import 'cms_admin_auth.dart';
import 'cms_section_defaults.dart';
import 'cms_section_editor_dialog.dart';

class CmsAddSectionDialog extends StatelessWidget {
  final String pageId;
  final int nextPosition;

  const CmsAddSectionDialog({
    super.key,
    required this.pageId,
    required this.nextPosition,
  });

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String pageId,
    required int nextPosition,
  }) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;
    final selected = await showDialog<CmsSectionType>(
      context: context,
      builder: (_) =>
          CmsAddSectionDialog(pageId: pageId, nextPosition: nextPosition),
    );
    if (selected == null || !context.mounted) return;
    await CmsSectionEditorDialog.show(
      context,
      request: CmsSectionEditorRequest.create(
        type: selected,
        pageId: pageId,
        position: nextPosition,
        proposedSectionId: _newSectionIdFor(selected),
      ),
    );
  }

  static String _newSectionIdFor(CmsSectionType type) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return '${type.wireName.replaceAll('_', '-')}-$now';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter une section'),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final type in CmsSectionType.values)
              ListTile(
                title: Text(sectionTypeLabel(type)),
                subtitle: Text(
                  type.wireName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6F6F6F),
                  ),
                ),
                onTap: () => Navigator.of(context).pop(type),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
