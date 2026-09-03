import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/cms/cms_models.dart';
import '../../providers/cms_page_editor_controller.dart';
import '../../providers/edit_mode_provider.dart';
import 'cms_admin_auth.dart';
import 'cms_section_editor_dialog.dart';

class CmsEditOverlay extends ConsumerWidget {
  final CmsSectionConfig section;
  final List<CmsSectionConfig> allSections;
  final String pageId;
  final Widget child;

  const CmsEditOverlay({
    super.key,
    required this.section,
    required this.allSections,
    required this.pageId,
    required this.child,
  });

  int get _index =>
      allSections.indexWhere((s) => s.record.id == section.record.id);

  bool get _canMoveUp => _index > 0;
  bool get _canMoveDown => _index >= 0 && _index < allSections.length - 1;

  Future<void> _onEdit(BuildContext context, WidgetRef ref) async {
    final type = section.record.sectionType;
    if (type == null) return;
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;
    await CmsSectionEditorDialog.show(
      context,
      request: CmsSectionEditorRequest.edit(
        type: type,
        pageId: pageId,
        position: section.record.position,
        sectionRecordId: section.record.id,
        existingSectionId: section.record.sectionId,
        initialConfig: section.record.config,
      ),
    );
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette section ?'),
        content: Text(
          'La section "${section.record.sectionId}" sera supprimée du CMS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(cmsPageEditorControllerProvider.notifier)
          .deleteSection(sectionRecordId: section.record.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Section supprimée.')),
      );
    } catch (error) {
      if (error is CmsMutationInProgressException) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Échec de la suppression : $error')),
      );
    }
  }

  Future<void> _swap(
    BuildContext context,
    WidgetRef ref,
    int otherIndex,
  ) async {
    if (otherIndex < 0 || otherIndex >= allSections.length) return;
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;
    final controller = ref.read(cmsPageEditorControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.moveSection(
        sections: allSections,
        sectionRecordId: section.record.id,
        targetIndex: otherIndex,
      );
    } catch (error) {
      if (error is CmsMutationInProgressException) return;
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Échec du déplacement : $error')),
      );
    }
  }

  Future<void> _onToggleActive(BuildContext context, WidgetRef ref) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(cmsPageEditorControllerProvider.notifier)
          .setSectionActive(
            sectionRecordId: section.record.id,
            isActive: !section.record.isActive,
          );
    } catch (error) {
      if (error is CmsMutationInProgressException) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Échec de la bascule : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(editModeProvider);
    final isSaving = ref.watch(cmsPageEditorControllerProvider).isLoading;
    final isUnknown = section is CmsUnknownSection;
    // Keep the widget structure (Stack > Opacity > child) stable across
    // edit-mode toggles so the wrapped section's element tree is preserved
    // (the storefront subtree should not rebuild when the chrome appears /
    // disappears). The toolbar is the only conditional sub-tree.
    return Stack(
      children: [
        Opacity(
          opacity: isEditMode && !section.record.isActive ? 0.45 : 1.0,
          child: child,
        ),
        if (isEditMode)
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToolbarLabel(
                      text:
                          section.record.sectionType?.wireName ??
                          section.record.rawSectionType,
                    ),
                    _ToolbarButton(
                      icon: Icons.arrow_upward,
                      tooltip: 'Monter',
                      onPressed: _canMoveUp && !isSaving
                          ? () => _swap(context, ref, _index - 1)
                          : null,
                    ),
                    _ToolbarButton(
                      icon: Icons.arrow_downward,
                      tooltip: 'Descendre',
                      onPressed: _canMoveDown && !isSaving
                          ? () => _swap(context, ref, _index + 1)
                          : null,
                    ),
                    _ToolbarButton(
                      icon: section.record.isActive
                          ? Icons.visibility
                          : Icons.visibility_off,
                      tooltip: section.record.isActive ? 'Masquer' : 'Activer',
                      onPressed: isSaving
                          ? null
                          : () => _onToggleActive(context, ref),
                    ),
                    _ToolbarButton(
                      icon: Icons.edit,
                      tooltip: 'Éditer',
                      onPressed: isUnknown || isSaving
                          ? null
                          : () => _onEdit(context, ref),
                    ),
                    _ToolbarButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Supprimer',
                      onPressed: isSaving
                          ? null
                          : () => _onDelete(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToolbarLabel extends StatelessWidget {
  final String text;

  const _ToolbarLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return IconButton(
      icon: Icon(
        icon,
        size: 16,
        color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.35),
      ),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    );
  }
}
