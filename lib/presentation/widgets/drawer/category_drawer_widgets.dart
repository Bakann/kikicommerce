import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/catalog_routes.dart';
import '../../../core/constants.dart';
import '../../../domain/catalog/catalog_entities.dart';
import '../../l10n/l10n_extension.dart';
import '../../providers/content_locale_provider.dart';
import '../../providers/locale_provider.dart';
import '../navigation/collapsing_line_icon.dart';
import '../storefront_layout.dart';
import 'drawer_shared_widgets.dart';

enum DrawerEditScope { navigation, categories }

class DrawerEditScopeSelector extends StatelessWidget {
  final DrawerEditScope selectedScope;
  final bool isSaving;
  final ValueChanged<DrawerEditScope> onChanged;

  const DrawerEditScopeSelector({
    super.key,
    required this.selectedScope,
    required this.isSaving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text(
            'Type du drawer live',
            style: TextStyle(
              color: kNavyBlue,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<DrawerEditScope>(
            segments: const [
              ButtonSegment<DrawerEditScope>(
                value: DrawerEditScope.navigation,
                icon: Icon(Icons.account_tree_outlined),
                label: Text('Navigation'),
              ),
              ButtonSegment<DrawerEditScope>(
                value: DrawerEditScope.categories,
                icon: Icon(Icons.category_outlined),
                label: Text('Catégories'),
              ),
            ],
            selected: {selectedScope},
            onSelectionChanged: isSaving
                ? null
                : (selection) => onChanged(selection.single),
          ),
        ),
        if (isSaving) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
    );
  }
}

class DrawerCloseHeader extends StatefulWidget {
  final VoidCallback onClose;

  const DrawerCloseHeader({super.key, required this.onClose});

  @override
  State<DrawerCloseHeader> createState() => _DrawerCloseHeaderState();
}

class _DrawerCloseHeaderState extends State<DrawerCloseHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: kDiorIconCollapseDuration,
      reverseDuration: const Duration(milliseconds: 170),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _closeAfterIconCollapse() async {
    if (_isClosing) {
      return;
    }

    setState(() {
      _isClosing = true;
    });

    await _controller.forward(from: 0);
    if (!mounted) {
      return;
    }

    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 28, 40, 22),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: _closeAfterIconCollapse,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DiorCollapsingLineIcon(
                  progress: _controller,
                  shape: DiorCollapsingLineIconShape.close,
                  color: kDrawerChrome,
                  size: 22,
                ),
                const SizedBox(width: 18),
                Text(
                  context.l10n.commonClose,
                  style: const TextStyle(
                    fontFamily: kDrawerFontFamily,
                    color: kDrawerChrome,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DrawerFooter extends StatelessWidget {
  final bool isEditMode;
  final bool showEditModeAction;
  final VoidCallback onToggleEditMode;

  const DrawerFooter({
    super.key,
    required this.isEditMode,
    required this.showEditModeAction,
    required this.onToggleEditMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 12, 40, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showEditModeAction) ...[
            InkWell(
              onTap: onToggleEditMode,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      isEditMode
                          ? Icons.edit_off_outlined
                          : Icons.edit_outlined,
                      color: kDrawerChrome,
                      size: 21,
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Text(
                        isEditMode
                            ? 'Quitter le mode édition'
                            : 'Activer le mode édition',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: kDrawerFontFamily,
                          color: kDrawerChrome,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            context.l10n.commonContact,
            style: const TextStyle(
              fontFamily: kDrawerFontFamily,
              color: kDrawerChrome,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 20),
          const DrawerLanguageSwitcher(),
        ],
      ),
    );
  }
}

/// FR/EN language switcher shown in the drawer footer. Selecting a language
/// updates [localeProvider] (persisted) so the whole app re-localizes
/// immediately without a restart.
class DrawerLanguageSwitcher extends ConsumerWidget {
  const DrawerLanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Highlight the locale Flutter actually resolved (covers the device-locale
    // case where localeProvider is still null).
    final activeCode = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.languageLabel,
          style: const TextStyle(
            fontFamily: kDrawerFontFamily,
            color: kDrawerMutedColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _LanguageOption(
              label: context.l10n.languageFrench,
              isSelected: activeCode == 'fr',
              onTap: () =>
                  unawaited(_selectLocale(context, ref, const Locale('fr'))),
            ),
            const SizedBox(width: 18),
            _LanguageOption(
              label: context.l10n.languageEnglish,
              isSelected: activeCode == 'en',
              onTap: () =>
                  unawaited(_selectLocale(context, ref, const Locale('en'))),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _selectLocale(
    BuildContext context,
    WidgetRef ref,
    Locale locale,
  ) async {
    final router = _maybeRouter(context);
    final currentUri = router?.routeInformationProvider.value.uri;
    await ref.read(localeProvider.notifier).setLocale(locale);
    ref.read(urlLocaleOverrideProvider.notifier).setLocale(locale);
    ref.read(contentLocaleProvider.notifier).set(locale.languageCode);

    if (router == null || currentUri == null) return;
    final target = CatalogRoutes.localizedLocation(
      currentUri.toString(),
      locale: locale.languageCode,
    );
    if (target != currentUri.toString()) {
      router.go(target);
    }
  }

  GoRouter? _maybeRouter(BuildContext context) {
    try {
      return GoRouter.of(context);
    } catch (_) {
      return null;
    }
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: kDrawerFontFamily,
            color: kDrawerChrome,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            decoration: isSelected ? TextDecoration.underline : null,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

enum _CategoryTileAction { toggleHidden, reparent, delete }

class _CategoryReorderPayload {
  final CatalogCategory category;
  final String group;

  const _CategoryReorderPayload({required this.category, required this.group});
}

class DrawerCategoryTile extends StatelessWidget {
  final CatalogCategory category;
  final bool isSelected;
  final bool isEditMode;
  final bool showDisclosure;
  final bool showCreateChildAction;
  final bool isHidden;
  final CatalogCategory? reorderCategory;
  final String? reorderGroup;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCreateChild;
  final VoidCallback? onToggleHidden;
  final ValueChanged<CatalogCategory>? onReorderAccepted;
  final VoidCallback? onReparent;
  final VoidCallback? onDelete;
  final VoidCallback? onOpenChildren;

  const DrawerCategoryTile({
    super.key,
    required this.category,
    required this.isSelected,
    required this.isEditMode,
    required this.showDisclosure,
    required this.showCreateChildAction,
    required this.onTap,
    this.isHidden = false,
    this.reorderCategory,
    this.reorderGroup,
    this.onEdit,
    this.onCreateChild,
    this.onToggleHidden,
    this.onReorderAccepted,
    this.onReparent,
    this.onDelete,
    this.onOpenChildren,
  });

  @override
  Widget build(BuildContext context) {
    // The Drawer ancestor (storefront_category_drawer.dart) supplies its
    // background via `backgroundColor: Colors.white`, which in Flutter 3.44+
    // is realised as a ColoredBox between the Drawer's Material and our
    // child. Without a Material immediately around the ListTile, the
    // framework asserts that the ColoredBox would hide ListTile ink splashes
    // and selected-tile background (both painted on the nearest Material).
    // MaterialType.transparency adds no pixels but gives the ListTile its
    // own Material to paint into, over the ColoredBox.
    final tile = Material(
      type: MaterialType.transparency,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        selected: isSelected,
        selectedTileColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: kDrawerTileDensity,
        leading: _buildDragHandle(context),
        title: Opacity(
          opacity: isHidden ? 0.58 : 1,
          child: DrawerTileTitle(
            label: category.name,
            isSelected: isSelected,
            isHidden: isHidden,
          ),
        ),
        trailing: _buildTrailing(),
        onTap: onTap,
      ),
    );

    final reorderCategory = this.reorderCategory;
    final reorderGroup = this.reorderGroup;
    final onReorderAccepted = this.onReorderAccepted;
    if (reorderCategory == null ||
        reorderGroup == null ||
        onReorderAccepted == null) {
      return tile;
    }

    return DragTarget<_CategoryReorderPayload>(
      onWillAcceptWithDetails: (details) {
        return details.data.group == reorderGroup &&
            details.data.category.id != reorderCategory.id;
      },
      onAcceptWithDetails: (details) =>
          onReorderAccepted(details.data.category),
      builder: (context, candidates, _) {
        if (candidates.isEmpty) {
          return tile;
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: kNavyBlue, width: 1.4),
            borderRadius: BorderRadius.circular(6),
          ),
          child: tile,
        );
      },
    );
  }

  Widget? _buildDragHandle(BuildContext context) {
    final reorderCategory = this.reorderCategory;
    final reorderGroup = this.reorderGroup;
    if (!isEditMode || reorderCategory == null || reorderGroup == null) {
      return null;
    }

    final payload = _CategoryReorderPayload(
      category: reorderCategory,
      group: reorderGroup,
    );
    final handle = const MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Tooltip(
          message: 'Glisser pour réordonner',
          child: Icon(Icons.drag_indicator, color: kNavyBlue, size: 20),
        ),
      ),
    );
    final feedback = DrawerDragFeedback(label: category.name);
    final isDesktop = StorefrontLayout.isDesktop(
      MediaQuery.sizeOf(context).width,
    );

    if (kIsWeb || isDesktop) {
      return Draggable<_CategoryReorderPayload>(
        data: payload,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.35, child: handle),
        child: handle,
      );
    }

    return LongPressDraggable<_CategoryReorderPayload>(
      data: payload,
      feedback: feedback,
      childWhenDragging: Opacity(opacity: 0.35, child: handle),
      child: handle,
    );
  }

  Widget? _buildTrailing() {
    if (!isEditMode && !showDisclosure) {
      return null;
    }

    if (!isEditMode) {
      return const Icon(Icons.chevron_right, color: kDrawerChrome);
    }

    final actions = <Widget>[
      IconButton(
        tooltip: 'Modifier le nom',
        visualDensity: VisualDensity.compact,
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined, color: kNavyBlue),
      ),
    ];

    if (showCreateChildAction) {
      actions.add(
        IconButton(
          tooltip: 'Ajouter une sous-catégorie',
          visualDensity: VisualDensity.compact,
          onPressed: onCreateChild,
          icon: const Icon(Icons.add, color: kNavyBlue),
        ),
      );
    }

    if (showDisclosure) {
      actions.add(
        IconButton(
          tooltip: 'Voir les sous-catégories',
          visualDensity: VisualDensity.compact,
          onPressed: onOpenChildren,
          icon: const Icon(Icons.chevron_right, color: kNavyBlue),
        ),
      );
    }

    if (onToggleHidden != null || onReparent != null || onDelete != null) {
      actions.add(
        PopupMenuButton<_CategoryTileAction>(
          tooltip: 'Actions catégorie',
          icon: const Icon(Icons.more_vert, color: kNavyBlue),
          onSelected: (action) {
            switch (action) {
              case _CategoryTileAction.toggleHidden:
                onToggleHidden?.call();
                break;
              case _CategoryTileAction.reparent:
                onReparent?.call();
                break;
              case _CategoryTileAction.delete:
                onDelete?.call();
                break;
            }
          },
          itemBuilder: (context) => [
            if (onToggleHidden != null)
              PopupMenuItem<_CategoryTileAction>(
                value: _CategoryTileAction.toggleHidden,
                child: Row(
                  children: [
                    Icon(
                      isHidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(isHidden ? 'Réafficher' : 'Masquer'),
                  ],
                ),
              ),
            if (onReparent != null)
              const PopupMenuItem<_CategoryTileAction>(
                value: _CategoryTileAction.reparent,
                child: Row(
                  children: [
                    Icon(Icons.drive_file_move_outline, size: 20),
                    SizedBox(width: 10),
                    Text('Rattacher'),
                  ],
                ),
              ),
            if (onDelete != null)
              const PopupMenuItem<_CategoryTileAction>(
                value: _CategoryTileAction.delete,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 10),
                    Text('Supprimer'),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }
}

class CategoryParentDialog extends StatefulWidget {
  final CatalogCategory category;
  final List<CatalogCategory> parentCandidates;
  final String initialParentId;

  const CategoryParentDialog({
    super.key,
    required this.category,
    required this.parentCandidates,
    required this.initialParentId,
  });

  static Future<String?> show(
    BuildContext context, {
    required CatalogCategory category,
    required List<CatalogCategory> parentCandidates,
    required String initialParentId,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => CategoryParentDialog(
        category: category,
        parentCandidates: parentCandidates,
        initialParentId: initialParentId,
      ),
    );
  }

  @override
  State<CategoryParentDialog> createState() => _CategoryParentDialogState();
}

class _CategoryParentDialogState extends State<CategoryParentDialog> {
  late String _selectedParentId;

  @override
  void initState() {
    super.initState();
    final availableIds = widget.parentCandidates
        .map((category) => category.id)
        .toSet();
    _selectedParentId = availableIds.contains(widget.initialParentId)
        ? widget.initialParentId
        : '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rattacher la catégorie'),
      content: DropdownButtonFormField<String>(
        initialValue: _selectedParentId,
        decoration: const InputDecoration(labelText: 'Parent'),
        items: [
          const DropdownMenuItem<String>(
            value: '',
            child: Text('Aucune catégorie parente'),
          ),
          for (final category in widget.parentCandidates)
            DropdownMenuItem<String>(
              value: category.id,
              child: Text(category.name),
            ),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _selectedParentId = value;
          });
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedParentId),
          style: ElevatedButton.styleFrom(backgroundColor: kNavyBlue),
          child: const Text(
            'Enregistrer',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class CategoryNameDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String initialValue;

  const CategoryNameDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialValue = '',
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String initialValue = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => CategoryNameDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialValue: initialValue,
      ),
    );
  }

  @override
  State<CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<CategoryNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nom de la catégorie'),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: kNavyBlue),
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

int nextCategoryPosition(Iterable<CatalogCategory> categories) {
  var maxPosition = 0;
  for (final category in categories) {
    if (category.position > maxPosition) {
      maxPosition = category.position;
    }
  }
  return maxPosition + 10;
}

List<CatalogCategory> reorderCategories(
  List<CatalogCategory> categories, {
  required String draggedCategoryId,
  required String targetCategoryId,
}) {
  final oldIndex = categories.indexWhere(
    (category) => category.id == draggedCategoryId,
  );
  final targetIndex = categories.indexWhere(
    (category) => category.id == targetCategoryId,
  );
  if (oldIndex < 0 || targetIndex < 0 || oldIndex == targetIndex) {
    return categories;
  }

  final reordered = [...categories];
  final moved = reordered.removeAt(oldIndex);
  reordered.insert(targetIndex, moved);
  return reordered;
}

int categoryPositionForIndex(int index) => (index + 1) * 10;
