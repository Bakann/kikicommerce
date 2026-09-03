import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_providers.dart';
import '../../../application/catalog/catalog_invalidations.dart';
import '../../../core/utils/slug_utils.dart';
import '../../../domain/catalog/catalog_entities.dart';
import '../../providers/catalog_invalidator_provider.dart';
import '../../providers/category_providers.dart';
import '../cms/cms_admin_auth.dart';
import 'category_drawer_widgets.dart';
import 'drawer_shared_widgets.dart';

/// Embeddable editor for the top-level entries of the live drawer when the
/// menu's `displayMode` is `categories`.
///
/// Mirrors the affordances of the live drawer's category column in edit
/// mode (drag-reorder, rename, delete, toggle hidden, add child) without
/// the drill-down behaviour. Used by the `category_banner_strip` section
/// editor so admins can manage the same `categories` records from the
/// section's dialog.
///
/// Mutations go directly to PocketBase via the existing admin providers
/// and invalidate the catalog + drawer caches so the live drawer and any
/// section mirroring it refresh together.
class DrawerCategoryListEditor extends ConsumerWidget {
  const DrawerCategoryListEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(drawerCategoriesProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _CategoryEditorMessage(
        icon: Icons.error_outline,
        text: 'Erreur de chargement des catégories : $error',
      ),
      data: (categories) => _CategoryList(categories: categories),
    );
  }
}

class _CategoryList extends ConsumerStatefulWidget {
  final List<CatalogCategory> categories;

  const _CategoryList({required this.categories});

  @override
  ConsumerState<_CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends ConsumerState<_CategoryList> {
  String? _activeParentId;

  @override
  Widget build(BuildContext context) {
    final categoriesById = <String, CatalogCategory>{
      for (final category in widget.categories) category.id: category,
    };
    final childrenByParentId = <String, List<CatalogCategory>>{};
    final topLevel = <CatalogCategory>[];

    for (final category in widget.categories) {
      final parentId = _normalizeParentId(category.parentId);
      if (parentId == null || !categoriesById.containsKey(parentId)) {
        topLevel.add(category);
        continue;
      }
      childrenByParentId.putIfAbsent(parentId, () => []).add(category);
    }
    final activeParent = _activeParentId == null
        ? null
        : categoriesById[_activeParentId!];
    final visibleCategories = activeParent == null
        ? topLevel
        : childrenByParentId[activeParent.id] ?? const <CatalogCategory>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeParent != null) ...[
          DrawerBackTile(
            label: activeParent.name,
            onTap: () => _goUpOneLevel(activeParent, categoriesById),
          ),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  _create(parent: activeParent, siblings: visibleCategories),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                activeParent == null
                    ? 'Nouvelle catégorie'
                    : 'Nouvelle sous-catégorie',
              ),
            ),
          ),
        ),
        if (visibleCategories.isEmpty)
          _CategoryEditorMessage(
            icon: Icons.info_outline,
            text: activeParent == null
                ? 'Aucune catégorie. Ajoute une catégorie pour la voir '
                      'apparaître dans le drawer live et dans cette section.'
                : 'Aucune sous-catégorie. Ajoute une sous-catégorie pour '
                      'alimenter ce niveau du drawer live.',
          )
        else
          for (final category in visibleCategories) ...[
            DrawerCategoryTile(
              key: ValueKey(category.id),
              category: category,
              isSelected: false,
              isEditMode: true,
              showDisclosure: true,
              showCreateChildAction: true,
              isHidden: category.isHidden,
              reorderCategory: category,
              reorderGroup: 'section-category-banner-strip:root',
              onTap: () => _rename(category),
              onEdit: () => _rename(category),
              onCreateChild: () => _create(
                parent: category,
                siblings: childrenByParentId[category.id] ?? const [],
              ),
              onToggleHidden: () => _toggleHidden(category),
              onReorderAccepted: (dragged) => _move(
                siblings: visibleCategories,
                dragged: dragged,
                target: category,
              ),
              onOpenChildren: () => _openChildren(category),
              onDelete: () => _confirmDelete(
                category,
                directChildren: childrenByParentId[category.id] ?? const [],
              ),
            ),
            const SizedBox(height: 2),
          ],
      ],
    );
  }

  void _openChildren(CatalogCategory category) {
    setState(() {
      _activeParentId = category.id;
    });
  }

  void _goUpOneLevel(
    CatalogCategory category,
    Map<String, CatalogCategory> categoriesById,
  ) {
    final parentId = _normalizeParentId(category.parentId);
    setState(() {
      _activeParentId = parentId != null && categoriesById.containsKey(parentId)
          ? parentId
          : null;
    });
  }

  Future<void> _create({
    CatalogCategory? parent,
    required List<CatalogCategory> siblings,
  }) async {
    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    final name = await CategoryNameDialog.show(
      context,
      title: parent == null ? 'Nouvelle catégorie' : 'Nouvelle sous-catégorie',
      confirmLabel: 'Créer',
    );
    if (!mounted || name == null || name.isEmpty) return;

    final slug = slugify(name, fallback: 'categorie');
    final code = slug.toUpperCase();
    final position = nextCategoryPosition(siblings);

    final messenger = ScaffoldMessenger.of(context);
    final data = <String, dynamic>{
      'code': code,
      'name': name,
      'slug': slug,
      'isActive': true,
      'isHidden': false,
      'position': position,
      if (parent != null) 'parent': parent.id,
    };

    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'categories',
        data: data,
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création: $error'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    ref
        .read(catalogInvalidatorProvider)
        .applyFromWidget(
          ref,
          invalidationsForAdminSave(collection: 'categories', data: data),
        );
  }

  Future<void> _rename(CatalogCategory category) async {
    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    final nextName = await CategoryNameDialog.show(
      context,
      title: 'Modifier la catégorie',
      confirmLabel: 'Enregistrer',
      initialValue: category.name,
    );
    if (!mounted || nextName == null || nextName.isEmpty) return;
    if (nextName == category.name.trim()) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'categories',
        recordId: category.id,
        data: {'name': nextName},
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $error'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    ref
        .read(catalogInvalidatorProvider)
        .applyFromWidget(
          ref,
          invalidationsForAdminSave(
            collection: 'categories',
            data: {
              'name': nextName,
              if (category.slug?.trim().isNotEmpty == true)
                'slug': category.slug!.trim(),
            },
            recordId: category.id,
          ),
        );
    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nom de catégorie mis à jour.')),
      );
    }
  }

  Future<void> _toggleHidden(CatalogCategory category) async {
    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    final nextHidden = !category.isHidden;
    final messenger = ScaffoldMessenger.of(context);
    final data = <String, dynamic>{
      'isHidden': nextHidden,
      if (category.slug?.trim().isNotEmpty == true)
        'slug': category.slug!.trim(),
    };

    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'categories',
        recordId: category.id,
        data: data,
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erreur lors du masquage: $error'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    ref
        .read(catalogInvalidatorProvider)
        .applyFromWidget(
          ref,
          invalidationsForAdminSave(
            collection: 'categories',
            recordId: category.id,
            data: data,
          ),
        );
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nextHidden ? 'Catégorie masquée.' : 'Catégorie réaffichée.',
          ),
        ),
      );
    }
  }

  Future<void> _move({
    required List<CatalogCategory> siblings,
    required CatalogCategory dragged,
    required CatalogCategory target,
  }) async {
    final reordered = reorderCategories(
      siblings,
      draggedCategoryId: dragged.id,
      targetCategoryId: target.id,
    );
    if (identical(reordered, siblings)) return;

    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Future.wait([
        for (var i = 0; i < reordered.length; i++)
          if (reordered[i].position != categoryPositionForIndex(i))
            ref.read(saveAdminRecordProvider)(
              baseUrl: ref.read(apiBaseUrlProvider),
              authToken: token,
              collection: 'categories',
              recordId: reordered[i].id,
              data: {'position': categoryPositionForIndex(i)},
            ),
      ]);
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erreur lors du changement d’ordre: $error'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    ref.read(catalogInvalidatorProvider).applyFromWidget(ref, const [
      CategoryTreeInvalidation(),
      DrawerNavigationInvalidation(),
    ]);
    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ordre des catégories mis à jour.')),
      );
    }
  }

  Future<void> _confirmDelete(
    CatalogCategory category, {
    required List<CatalogCategory> directChildren,
  }) async {
    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la catégorie'),
        content: Text(
          directChildren.isEmpty
              ? 'Cette action supprimera “${category.name}”.'
              : 'Cette action supprimera “${category.name}” et replacera ses sous-catégories à la racine.',
        ),
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

    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final child in directChildren) {
        await ref.read(saveAdminRecordProvider)(
          baseUrl: ref.read(apiBaseUrlProvider),
          authToken: token,
          collection: 'categories',
          recordId: child.id,
          data: {
            'parent': null,
            if (child.slug?.trim().isNotEmpty == true)
              'slug': child.slug!.trim(),
          },
        );
      }
      await ref.read(deleteAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'categories',
        recordId: category.id,
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $error'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    ref
        .read(catalogInvalidatorProvider)
        .applyFromWidget(
          ref,
          invalidationsForAdminDelete(
            collection: 'categories',
            recordId: category.id,
          ),
        );
    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Catégorie supprimée.')),
      );
    }
  }
}

String? _normalizeParentId(String? parentId) {
  final trimmed = parentId?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

class _CategoryEditorMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CategoryEditorMessage({required this.icon, required this.text});

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
