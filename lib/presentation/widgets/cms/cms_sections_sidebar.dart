import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/cms/cms_models.dart';
import '../../providers/cms_page_editor_controller.dart';
import 'cms_add_section_dialog.dart';
import 'cms_admin_auth.dart';
import 'cms_appearance_block.dart';
import 'cms_section_defaults.dart';
import 'cms_section_editor_dialog.dart';

class CmsSectionsSidebar extends ConsumerWidget {
  final String pageId;
  final List<CmsSectionConfig> sections;
  final int nextPosition;
  final bool isExpanded;
  final ValueChanged<bool> onExpandedChanged;

  const CmsSectionsSidebar({
    super.key,
    required this.pageId,
    required this.sections,
    required this.nextPosition,
    this.isExpanded = true,
    required this.onExpandedChanged,
  });

  Future<void> _onEdit(
    BuildContext context,
    WidgetRef ref,
    CmsSectionConfig section,
  ) async {
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

  Future<void> _onRename(
    BuildContext context,
    WidgetRef ref,
    CmsSectionConfig section,
  ) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;

    final nextId = await _showRenameDialog(context, section.record.sectionId);
    if (nextId == null || nextId == section.record.sectionId) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(cmsPageEditorControllerProvider.notifier)
          .renameSection(sectionRecordId: section.record.id, sectionId: nextId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Section renommée.')),
      );
    } catch (error) {
      if (error is CmsMutationInProgressException) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Échec du renommage : $error')),
      );
    }
  }

  Future<String?> _showRenameDialog(BuildContext context, String initialId) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _RenameSectionDialog(initialId: initialId),
    );
  }

  Future<void> _onDuplicate(
    BuildContext context,
    WidgetRef ref,
    CmsSectionConfig section,
  ) async {
    if (section.record.sectionType == null) return;
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(cmsPageEditorControllerProvider.notifier)
          .duplicateSection(
            section: section.record,
            sectionId: _duplicateSectionId(section.record.sectionId),
            position: nextPosition,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Section dupliquée.')),
      );
    } catch (error) {
      if (error is CmsMutationInProgressException) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Échec de la duplication : $error')),
      );
    }
  }

  String _duplicateSectionId(String sourceId) {
    final sanitized = sourceId
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final base = sanitized.isEmpty ? 'section' : sanitized;
    final suffix = DateTime.now().millisecondsSinceEpoch;
    final candidate = '$base-copy-$suffix';
    return candidate.length <= 64
        ? candidate
        : candidate.substring(candidate.length - 64);
  }

  Future<void> _swap(
    BuildContext context,
    WidgetRef ref,
    CmsSectionConfig section,
    int otherIndex,
  ) async {
    if (otherIndex < 0 || otherIndex >= sections.length) return;
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;

    final controller = ref.read(cmsPageEditorControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.moveSection(
        sections: sections,
        sectionRecordId: section.record.id,
        targetIndex: otherIndex,
      );
    } catch (error) {
      if (error is CmsMutationInProgressException) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Échec du déplacement : $error')),
      );
    }
  }

  Future<void> _onToggleActive(
    BuildContext context,
    WidgetRef ref,
    CmsSectionConfig section,
  ) async {
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

  Future<void> _onDelete(
    BuildContext context,
    WidgetRef ref,
    CmsSectionConfig section,
  ) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isExpanded) {
      return const SizedBox.shrink();
    }

    final isSaving = ref.watch(cmsPageEditorControllerProvider).isLoading;
    final topPadding = MediaQuery.paddingOf(context).top + 72;
    return Material(
      color: const Color(0xFFF7F6F2),
      elevation: 6,
      child: SizedBox(
        width: 336,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Homepage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CmsSidebarToggleButton(
                    isExpanded: true,
                    onPressed: () => onExpandedChanged(false),
                  ),
                  IconButton(
                    tooltip: 'Ajouter une section',
                    onPressed: isSaving
                        ? null
                        : () => CmsAddSectionDialog.show(
                            context,
                            ref,
                            pageId: pageId,
                            nextPosition: nextPosition,
                          ),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              SizedBox(
                height: 3,
                child: isSaving
                    ? const LinearProgressIndicator(minHeight: 3)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              CmsAppearanceBlock(isDisabled: isSaving),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: sections.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return _CmsSidebarSectionTile(
                      section: section,
                      index: index,
                      canMoveUp: index > 0,
                      canMoveDown: index < sections.length - 1,
                      onEdit: isSaving
                          ? null
                          : () => _onEdit(context, ref, section),
                      onRename: isSaving
                          ? null
                          : () => _onRename(context, ref, section),
                      onDuplicate:
                          isSaving || section.record.sectionType == null
                          ? null
                          : () => _onDuplicate(context, ref, section),
                      onMoveUp: isSaving
                          ? null
                          : () => _swap(context, ref, section, index - 1),
                      onMoveDown: isSaving
                          ? null
                          : () => _swap(context, ref, section, index + 1),
                      onToggleActive: isSaving
                          ? null
                          : () => _onToggleActive(context, ref, section),
                      onDelete: isSaving
                          ? null
                          : () => _onDelete(context, ref, section),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CmsSidebarToggleButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onPressed;

  const CmsSidebarToggleButton({
    super.key,
    required this.isExpanded,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        tooltip: isExpanded ? 'Replier le CMS' : 'Ouvrir le CMS',
        onPressed: onPressed,
        icon: Icon(
          isExpanded ? Icons.chevron_left : Icons.account_tree_outlined,
          color: Colors.white,
          size: 18,
        ),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
      ),
    );
  }
}

class _CmsSidebarSectionTile extends StatelessWidget {
  final CmsSectionConfig section;
  final int index;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onEdit;
  final VoidCallback? onRename;
  final VoidCallback? onDuplicate;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onToggleActive;
  final VoidCallback? onDelete;

  const _CmsSidebarSectionTile({
    required this.section,
    required this.index,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEdit,
    required this.onRename,
    required this.onDuplicate,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = _typeLabel(section.record);
    final isUnknown = section is CmsUnknownSection;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: section.record.isActive
              ? const Color(0xFFE2E0D8)
              : const Color(0xFFD0CCC0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        section.record.sectionId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6F6F6F),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                if (!section.record.isActive)
                  const _SidebarStatusPill(label: 'Masquée'),
                if (isUnknown) const _SidebarStatusPill(label: 'Inconnue'),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                _SidebarIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Éditer',
                  onPressed: isUnknown ? null : onEdit,
                ),
                _SidebarIconButton(
                  icon: Icons.drive_file_rename_outline,
                  tooltip: 'Renommer',
                  onPressed: onRename,
                ),
                _SidebarIconButton(
                  icon: Icons.content_copy_outlined,
                  tooltip: 'Dupliquer',
                  onPressed: onDuplicate,
                ),
                _SidebarIconButton(
                  icon: Icons.arrow_upward,
                  tooltip: 'Monter',
                  onPressed: canMoveUp ? onMoveUp : null,
                ),
                _SidebarIconButton(
                  icon: Icons.arrow_downward,
                  tooltip: 'Descendre',
                  onPressed: canMoveDown ? onMoveDown : null,
                ),
                _SidebarIconButton(
                  icon: section.record.isActive
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  tooltip: section.record.isActive ? 'Masquer' : 'Activer',
                  onPressed: onToggleActive,
                ),
                _SidebarIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Supprimer',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(CmsSectionRecord record) {
    final type = record.sectionType;
    if (type == null) return record.rawSectionType;
    return sectionTypeLabel(type);
  }
}

/// Rename-section dialog with its own [TextEditingController] lifecycle.
///
/// Owning the controller in a [StatefulWidget] (vs creating it inside
/// `_showRenameDialog` and disposing via `Future.whenComplete`) avoids the
/// "TextEditingController was used after being disposed" crash: the dialog's
/// exit animation can rebuild the [TextFormField] AFTER the future
/// completes, so disposing in `whenComplete` is too early. Disposing in
/// [State.dispose] ties the controller lifetime to the actual widget tree
/// instead.
class _RenameSectionDialog extends StatefulWidget {
  final String initialId;

  const _RenameSectionDialog({required this.initialId});

  @override
  State<_RenameSectionDialog> createState() => _RenameSectionDialogState();
}

class _RenameSectionDialogState extends State<_RenameSectionDialog> {
  late final TextEditingController _controller;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renommer la section'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'sectionId',
            helperText: 'a-z, 0-9, _ et - uniquement',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) return 'Champ requis';
            if (trimmed.length > 64) return '64 caractères maximum';
            if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(trimmed)) {
              return 'Format invalide';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('Renommer'),
        ),
      ],
    );
  }
}

class _SidebarStatusPill extends StatelessWidget {
  final String label;

  const _SidebarStatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EEE7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF5A5549)),
      ),
    );
  }
}

class _SidebarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _SidebarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    );
  }
}
