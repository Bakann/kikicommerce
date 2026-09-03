import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../application/catalog/catalog_invalidations.dart';
import '../../../application/navigation/drawer_navigation_models.dart';
import '../../providers/catalog_invalidator_provider.dart';
import '../../providers/navigation_providers.dart';
import '../cms/cms_admin_auth.dart';
import '../navigation_item_editor_dialog.dart';
import 'managed_drawer_widgets.dart';

/// Embeddable editor for the root entries of the live drawer.
///
/// Mirrors the affordances of the live drawer's root column in edit mode
/// (drag-reorder, edit, delete, toggle hidden, add child) without the
/// drill-down behaviour. Used by the `category_banner_strip` section editor
/// so admins can manage the same drawer items from the section's dialog.
///
/// Mutations go directly to PocketBase via the existing admin providers and
/// invalidate [mainDrawerNavigationProvider] so the live drawer and any
/// section mirroring it refresh together. The widget owns no section-local
/// state — closing the dialog without "Enregistrer" still leaves PocketBase
/// in its mutated state.
class DrawerRootListEditor extends ConsumerStatefulWidget {
  final String addEntryLabel;

  const DrawerRootListEditor({
    super.key,
    this.addEntryLabel = 'Nouvelle entrée',
  });

  @override
  ConsumerState<DrawerRootListEditor> createState() =>
      _DrawerRootListEditorState();
}

class _DrawerRootListEditorState extends ConsumerState<DrawerRootListEditor> {
  static const _retryRefreshDelay = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mainDrawerNavigationProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _DrawerEditorMessage(
        icon: Icons.error_outline,
        text: 'Erreur de chargement du drawer : $error',
      ),
      data: (result) {
        final menu = result.menu;
        if (menu == null) {
          return _DrawerEditorMessage(
            icon: Icons.info_outline,
            text:
                'Aucun menu `main_drawer` n\'est configuré. Crée le drawer '
                'live depuis l\'éditeur du drawer.',
          );
        }
        final roots =
            result.normalized?.roots ?? const <DrawerNavigationNode>[];
        return _RootList(
          menu: menu,
          roots: roots,
          addEntryLabel: widget.addEntryLabel,
          onAdd: () => _openCreateRootDialog(menu: menu, roots: roots),
          onEdit: (node) => _openEditDialog(menu: menu, node: node),
          onDelete: _confirmDelete,
          onToggleHidden: _toggleHidden,
          onAddChild: (parent) =>
              _openCreateChildDialog(menu: menu, parent: parent),
          onReorder: (siblings, dragged, target) =>
              _move(siblings: siblings, dragged: dragged, target: target),
        );
      },
    );
  }

  Future<void> _openCreateRootDialog({
    required DrawerNavigationMenuData menu,
    required List<DrawerNavigationNode> roots,
  }) async {
    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    final changed = await NavigationItemEditorDialog.show(
      context,
      menuId: menu.id,
      authToken: token,
      depth: 0,
      position: nextPosition(roots.map((r) => r.item)),
      title: 'Nouvelle entrée',
    );
    if (!mounted) return;
    if (changed == true) {
      _refresh();
    }
  }

  Future<void> _openCreateChildDialog({
    required DrawerNavigationMenuData menu,
    required DrawerNavigationItemData parent,
  }) async {
    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    // Find the parent node so we can compute the next child position.
    final result = ref.read(mainDrawerNavigationProvider).value;
    final parentNode = result?.normalized?.roots.firstWhere(
      (r) => r.item.id == parent.id,
      orElse: () => DrawerNavigationNode(item: parent),
    );
    final children = parentNode?.children ?? const <DrawerNavigationNode>[];

    final changed = await NavigationItemEditorDialog.show(
      context,
      menuId: menu.id,
      authToken: token,
      depth: 1,
      parentId: parent.id,
      position: nextPosition(children.map((c) => c.item)),
      title: 'Nouvel item',
    );
    if (!mounted) return;
    if (changed == true) {
      _refresh();
    }
  }

  Future<void> _openEditDialog({
    required DrawerNavigationMenuData menu,
    required DrawerNavigationNode node,
  }) async {
    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    final changed = await NavigationItemEditorDialog.show(
      context,
      menuId: menu.id,
      authToken: token,
      depth: 0,
      position: node.item.position,
      parentId: node.item.parentId,
      title: 'Modifier l’entrée',
      initialItem: node.item,
      hasChildren: node.children.isNotEmpty,
    );
    if (!mounted) return;
    if (changed == true) {
      _refresh();
    }
  }

  Future<void> _confirmDelete(DrawerNavigationItemData item) async {
    final messenger = ScaffoldMessenger.of(context);
    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l’entrée'),
        content: Text('Cette action supprimera “${item.label}”.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(deleteAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'navigation_items',
        recordId: item.id,
      );
      _refresh();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Entrée supprimée.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _toggleHidden(DrawerNavigationItemData item) async {
    final messenger = ScaffoldMessenger.of(context);
    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    final nextHidden = !item.isHidden;
    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'navigation_items',
        recordId: item.id,
        data: {'isHidden': nextHidden},
      );
      _refresh();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              nextHidden ? 'Entrée masquée.' : 'Entrée réaffichée.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du masquage: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _move({
    required List<DrawerNavigationItemData> siblings,
    required DrawerNavigationItemData dragged,
    required DrawerNavigationItemData target,
  }) async {
    final reordered = reorderDrawerItems(
      siblings,
      draggedItemId: dragged.id,
      targetItemId: target.id,
    );
    if (identical(reordered, siblings)) return;

    final messenger = ScaffoldMessenger.of(context);
    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    try {
      await Future.wait([
        for (var i = 0; i < reordered.length; i++)
          if (reordered[i].position != drawerPositionForIndex(i))
            ref.read(saveAdminRecordProvider)(
              baseUrl: ref.read(apiBaseUrlProvider),
              authToken: token,
              collection: 'navigation_items',
              recordId: reordered[i].id,
              data: {'position': drawerPositionForIndex(i)},
            ),
      ]);
      _refresh();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Ordre du drawer mis à jour.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement d’ordre: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _refresh() {
    _invalidate();
    unawaited(
      Future<void>.delayed(_retryRefreshDelay).then((_) {
        if (!mounted) return;
        _invalidate();
      }),
    );
  }

  void _invalidate() {
    ref.read(catalogInvalidatorProvider).applyFromWidget(ref, const [
      DrawerNavigationInvalidation(),
    ]);
  }
}

class _RootList extends StatelessWidget {
  final DrawerNavigationMenuData menu;
  final List<DrawerNavigationNode> roots;
  final String addEntryLabel;
  final VoidCallback onAdd;
  final ValueChanged<DrawerNavigationNode> onEdit;
  final ValueChanged<DrawerNavigationItemData> onDelete;
  final ValueChanged<DrawerNavigationItemData> onToggleHidden;
  final ValueChanged<DrawerNavigationItemData> onAddChild;
  final void Function(
    List<DrawerNavigationItemData> siblings,
    DrawerNavigationItemData dragged,
    DrawerNavigationItemData target,
  )
  onReorder;

  const _RootList({
    required this.menu,
    required this.roots,
    required this.addEntryLabel,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleHidden,
    required this.onAddChild,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final rootItems = roots.map((r) => r.item).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addEntryLabel),
            ),
          ),
        ),
        if (roots.isEmpty)
          _DrawerEditorMessage(
            icon: Icons.info_outline,
            text:
                'Aucune entrée racine. Ajoute une entrée pour la voir '
                'apparaître dans le drawer live et dans cette section.',
          )
        else
          for (final root in roots) ...[
            ManagedDrawerTile(
              key: ValueKey(root.item.id),
              label: root.item.label,
              isSelected: false,
              showDisclosure: root.children.isNotEmpty,
              isEditMode: true,
              isHidden: root.item.isHidden,
              reorderItem: root.item,
              reorderGroup: 'roots',
              onTap: () => onEdit(root),
              onEdit: () => onEdit(root),
              onDelete: root.children.isEmpty
                  ? () => onDelete(root.item)
                  : null,
              onAddChild: () => onAddChild(root.item),
              onToggleHidden: () => onToggleHidden(root.item),
              onReorderAccepted: (dragged) =>
                  onReorder(rootItems, dragged, root.item),
            ),
            const SizedBox(height: 2),
          ],
      ],
    );
  }
}

class _DrawerEditorMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DrawerEditorMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6F2),
        border: Border.all(color: const Color(0xFFDADAD2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6F6F6F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6F6F6F)),
            ),
          ),
        ],
      ),
    );
  }
}
