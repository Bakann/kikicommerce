import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/catalog_routes.dart';
import '../../application/catalog/catalog_invalidations.dart';
import '../../application/navigation/drawer_editorial_tiles.dart';
import '../../application/navigation/drawer_navigation_models.dart';
import '../../core/constants.dart';
import '../l10n/l10n_extension.dart';
import '../providers/catalog_invalidator_provider.dart';
import '../providers/content_locale_provider.dart';
import '../providers/edit_mode_provider.dart';
import '../providers/navigation_providers.dart';
import 'cms/cms_admin_auth.dart';
import 'cms/sport_context_cms_href.dart';
import 'navigation_item_editor_dialog.dart';
import 'drawer/drawer_shared_widgets.dart';
import 'drawer/managed_drawer_widgets.dart';
import 'storefront_drawer_external_link_stub.dart'
    if (dart.library.html) 'storefront_drawer_external_link_web.dart';
import 'storefront_layout.dart';

const _kDrawerDividerColor = Color(0xFFE8E2DA);

class StorefrontManagedNavigationDrawerAdminState
    extends ConsumerStatefulWidget {
  final DrawerNavigationLoadResult result;

  const StorefrontManagedNavigationDrawerAdminState({
    super.key,
    required this.result,
  });

  @override
  ConsumerState<StorefrontManagedNavigationDrawerAdminState> createState() =>
      _StorefrontManagedNavigationDrawerAdminStateState();
}

class _StorefrontManagedNavigationDrawerAdminStateState
    extends ConsumerState<StorefrontManagedNavigationDrawerAdminState> {
  static const _defaultRootPosition = 10;
  static const _retryRefreshDelay = Duration(milliseconds: 700);

  bool _isSubmitting = false;

  DrawerNavigationFallbackReason? get _reason => widget.result.fallbackReason;
  DrawerNavigationMenuData? get _menu => widget.result.menu;

  @override
  Widget build(BuildContext context) {
    final message = switch (_reason) {
      DrawerNavigationFallbackReason.menuMissing =>
        'Le menu "main_drawer" n’existe pas encore. '
            'Crée-le ici pour administrer le drawer sans seed PocketBase.',
      DrawerNavigationFallbackReason.menuInactive =>
        'Le menu "main_drawer" existe mais il est inactif. '
            'Réactive-le pour reprendre la navigation gérée.',
      DrawerNavigationFallbackReason.noValidRoots =>
        'Le menu existe mais aucune entrée racine visible n’est exploitable. '
            'Ajoute une première entrée pour remplacer le fallback catégories.',
      DrawerNavigationFallbackReason.treeInvalid =>
        'Le menu existe mais sa structure actuelle ne permet pas de rendre '
            'le drawer. Ajoute une entrée valide ici puis corrige les items '
            'invalides dans le backoffice.',
      DrawerNavigationFallbackReason.fetchError =>
        'Le drawer géré ne peut pas être chargé pour le moment.',
      null => 'Le drawer géré n’est pas encore prêt.',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        Text(
          'Drawer géré',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: kNavyBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          style: const TextStyle(color: kNavyBlue, fontSize: 16, height: 1.45),
        ),
        if (_menu != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF5F7FA),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(label: 'Nom', value: _menu!.name),
                const SizedBox(height: 8),
                _InfoLine(label: 'Code', value: _menu!.code),
                const SizedBox(height: 8),
                _InfoLine(
                  label: 'Actif',
                  value: _menu!.isActive ? 'Oui' : 'Non',
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (_reason == DrawerNavigationFallbackReason.menuMissing)
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _createMenuAndOpenFirstItem,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_motion_outlined),
            label: Text(_isSubmitting ? 'Création…' : 'Créer le drawer géré'),
          ),
        if (_reason == DrawerNavigationFallbackReason.menuInactive) ...[
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _activateMenu,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_circle_outline),
            label: Text(
              _isSubmitting ? 'Activation…' : 'Activer le drawer géré',
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_menu != null &&
            _reason != DrawerNavigationFallbackReason.menuInactive &&
            _reason != DrawerNavigationFallbackReason.fetchError)
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _openFirstItemDialog,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une entrée racine'),
          ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _isSubmitting ? null : _refreshManagedDrawerNavigation,
          icon: const Icon(Icons.refresh),
          label: const Text('Recharger le drawer géré'),
        ),
      ],
    );
  }

  Future<void> _createMenuAndOpenFirstItem() async {
    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final record = await ref
          .read(adminBackofficeRepositoryProvider)
          .createRecord(
            baseUrl: ref.read(apiBaseUrlProvider),
            authToken: token,
            collection: 'navigation_menus',
            data: {
              'name': 'Main drawer',
              'code': 'main_drawer',
              'displayMode': 'drawer',
              'isActive': true,
            },
          );

      if (!mounted) {
        return;
      }

      final menu = DrawerNavigationMenuData.fromJson(record);
      await _showRootItemDialog(token: token, menu: menu);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _activateMenu() async {
    final menu = _menu;
    if (menu == null) {
      return;
    }

    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'navigation_menus',
        recordId: menu.id,
        data: {
          'name': menu.name.isEmpty ? 'Main drawer' : menu.name,
          'code': menu.code.isEmpty ? 'main_drawer' : menu.code,
          'displayMode': menu.displayMode.isEmpty ? 'drawer' : menu.displayMode,
          'isActive': true,
        },
      );

      _refreshManagedDrawerNavigation();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _openFirstItemDialog() async {
    final menu = _menu;
    if (menu == null) {
      return;
    }

    final token = await ensureAdminToken(context, ref, enableEditMode: true);
    if (token == null || !mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _showRootItemDialog(token: token, menu: menu);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showRootItemDialog({
    required String token,
    required DrawerNavigationMenuData menu,
  }) async {
    final changed = await NavigationItemEditorDialog.show(
      context,
      menuId: menu.id,
      authToken: token,
      depth: 0,
      position: _defaultRootPosition,
      title: 'Nouvelle entrée',
    );

    if (!mounted) {
      return;
    }

    _refreshManagedDrawerNavigation();
    if (changed == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Drawer géré mis à jour.')));
    }
  }

  void _refreshManagedDrawerNavigation() {
    _invalidateManagedDrawerNavigation();
    unawaited(
      Future<void>.delayed(_retryRefreshDelay).then((_) {
        if (!mounted) {
          return;
        }
        _invalidateManagedDrawerNavigation();
      }),
    );
  }

  void _invalidateManagedDrawerNavigation() {
    ref.read(catalogInvalidatorProvider).applyFromWidget(ref, const [
      DrawerNavigationInvalidation(),
    ]);
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur lors de la configuration du drawer: $error'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF697586),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              color: kNavyBlue,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class StorefrontManagedNavigationDrawerContent extends ConsumerStatefulWidget {
  final DrawerNavigationMenuData menu;
  final DrawerNavigationNormalizedResult normalized;
  final String? currentCategoryId;
  final bool forceSingleColumn;
  final ValueChanged<bool>? onVisualPanelChanged;

  @visibleForTesting
  final VoidCallback? debugOnActiveRootChanged;

  const StorefrontManagedNavigationDrawerContent({
    super.key,
    required this.menu,
    required this.normalized,
    this.currentCategoryId,
    this.forceSingleColumn = false,
    this.onVisualPanelChanged,
    this.debugOnActiveRootChanged,
  });

  @override
  ConsumerState<StorefrontManagedNavigationDrawerContent> createState() =>
      _StorefrontManagedNavigationDrawerContentState();
}

class _StorefrontManagedNavigationDrawerContentState
    extends ConsumerState<StorefrontManagedNavigationDrawerContent> {
  static const _retryRefreshDelay = Duration(milliseconds: 700);
  String? _activeRootId;
  String? _mobileParentId;
  bool? _lastReportedHasVisualPanel;
  bool _didResolveInitialDesktopRoot = false;
  bool _didResolveInitialMobileParent = false;
  DrawerLevelTransitionDirection _mobileLevelTransitionDirection =
      DrawerLevelTransitionDirection.forward;
  // Banner-strip drill support: consume a pending drill target once per open,
  // and reset the drill level on a fresh manual open so a previous banner
  // drill does not resurface. See [pendingDrawerDrillTargetProvider].
  bool _didConsumePendingDrillTarget = false;
  bool _wasDrawerOpen = false;

  @override
  void didUpdateWidget(
    covariant StorefrontManagedNavigationDrawerContent oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCategoryId != widget.currentCategoryId ||
        oldWidget.menu.id != widget.menu.id) {
      _activeRootId = null;
      _mobileParentId = null;
      _didResolveInitialDesktopRoot = false;
      _didResolveInitialMobileParent = false;
      _mobileLevelTransitionDirection = DrawerLevelTransitionDirection.forward;
      _didConsumePendingDrillTarget = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop =
        !widget.forceSingleColumn && StorefrontLayout.isDesktop(screenWidth);

    if (widget.normalized.roots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.navNoActiveNavigation,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    _handleDrawerOpenStateChange(context);
    _maybeConsumePendingDrillTarget(widget.normalized.roots);

    return isDesktop
        ? _buildDesktopLayout(context)
        : _buildMobileLayout(context);
  }

  /// See [_StorefrontNavigationMenuContentState] for the rationale: keep the
  /// banner-driven drill predictable across drawer opens/closes. Fields are
  /// mutated directly (not via setState) because this runs inside build.
  void _handleDrawerOpenStateChange(BuildContext context) {
    final isDrawerOpen = Scaffold.maybeOf(context)?.isDrawerOpen ?? false;
    if (isDrawerOpen == _wasDrawerOpen) return;
    _wasDrawerOpen = isDrawerOpen;
    if (!isDrawerOpen) {
      _didConsumePendingDrillTarget = false;
      if (ref.read(pendingDrawerDrillTargetProvider) != null) {
        _clearPendingDrillTargetAfterFrame();
      }
      return;
    }
    if (ref.read(pendingDrawerDrillTargetProvider) == null) {
      _activeRootId = null;
      _mobileParentId = null;
      _didResolveInitialDesktopRoot = false;
      _didResolveInitialMobileParent = false;
      _mobileLevelTransitionDirection = DrawerLevelTransitionDirection.back;
    }
  }

  /// Consumes a pending banner drill target for the managed-navigation drawer.
  /// Resolves the target root node (by node id, then by category id) and drills
  /// into it on both desktop and mobile layouts when it has children. Runs once
  /// per open and clears the target either way.
  void _maybeConsumePendingDrillTarget(List<DrawerNavigationNode> roots) {
    if (_didConsumePendingDrillTarget) return;
    final target = ref.read(pendingDrawerDrillTargetProvider);
    if (target == null) return;
    _didConsumePendingDrillTarget = true;

    final rootId = _resolveDrillRootId(roots, target);
    if (rootId != null) {
      final matching = roots.where((root) => root.item.id == rootId);
      if (matching.isNotEmpty && matching.first.children.isNotEmpty) {
        _activeRootId = rootId;
        _didResolveInitialDesktopRoot = true;
        _mobileParentId = rootId;
        _didResolveInitialMobileParent = true;
        _mobileLevelTransitionDirection =
            DrawerLevelTransitionDirection.forward;
      }
    }
    _clearPendingDrillTargetAfterFrame();
  }

  String? _resolveDrillRootId(
    List<DrawerNavigationNode> roots,
    DrawerDrillTarget target,
  ) {
    final nodeId = target.nodeId;
    if (nodeId != null && roots.any((root) => root.item.id == nodeId)) {
      return nodeId;
    }
    return findRootIdForCategory(roots, target.categoryId);
  }

  void _clearPendingDrillTargetAfterFrame() {
    // A provider cannot be modified during build; defer to after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(pendingDrawerDrillTargetProvider) != null) {
        ref.read(pendingDrawerDrillTargetProvider.notifier).state = null;
      }
    });
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final roots = widget.normalized.roots;
    final rootItems = roots.map((root) => root.item).toList(growable: false);
    final activeRootId = _didResolveInitialDesktopRoot
        ? _activeRootId
        : (findRootIdForCategory(roots, widget.currentCategoryId) ??
              roots
                  .firstWhere(
                    (root) => root.children.isNotEmpty,
                    orElse: () => roots.first,
                  )
                  .item
                  .id);
    final activeRoot = roots.firstWhere(
      (root) => root.item.id == activeRootId,
      orElse: () => roots.first,
    );
    final levelVm = buildLevelVm(
      activeRoot,
      currentCategoryId: widget.currentCategoryId,
      isDesktop: true,
    );
    final showSecondaryColumn = levelVm.hasSecondaryNavigationContent;
    final showVisualPanel = levelVm.hasVisualPanel;
    final isEditMode = ref.watch(editModeProvider);
    _reportVisualPanel(showVisualPanel);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 300,
          child: Column(
            children: [
              if (isEditMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  child: ActionTile(
                    icon: Icons.add,
                    label: 'Nouvelle entrée',
                    onTap: () => _openCreateItemDialog(
                      context,
                      depth: 0,
                      nextPosition: nextPosition(
                        roots.map((root) => root.item),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  children: [
                    for (var index = 0; index < roots.length; index++) ...[
                      Builder(
                        builder: (_) {
                          final root = roots[index];
                          return ManagedDrawerTile(
                            label: root.item.label,
                            isSelected: root.item.id == activeRoot.item.id,
                            showDisclosure: root.children.isNotEmpty,
                            isEditMode: isEditMode,
                            isHidden: root.item.isHidden,
                            reorderItem: isEditMode ? root.item : null,
                            reorderGroup: 'roots',
                            onTap: () => _handleDesktopRootTap(context, root),
                            onHoverActivate: () => _setActiveRoot(root.item.id),
                            onEdit: isEditMode
                                ? () => _openEditItemDialog(
                                    context,
                                    node: root,
                                    depth: 0,
                                    hasChildren: root.children.isNotEmpty,
                                  )
                                : null,
                            onDelete: isEditMode && root.children.isEmpty
                                ? () => _confirmDeleteItem(context, root.item)
                                : null,
                            onAddChild: isEditMode
                                ? () => _openCreateItemDialog(
                                    context,
                                    depth: 1,
                                    parent: root.item,
                                    nextPosition: nextPosition(
                                      root.children.map((child) => child.item),
                                    ),
                                  )
                                : null,
                            onToggleHidden: isEditMode
                                ? () => _toggleNavigationItemHidden(
                                    context,
                                    root.item,
                                  )
                                : null,
                            onReorderAccepted: isEditMode
                                ? (draggedItem) => _moveNavigationItem(
                                    context,
                                    siblings: rootItems,
                                    draggedItem: draggedItem,
                                    targetItem: root.item,
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showSecondaryColumn)
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: _kDrawerDividerColor,
          ),
        if (showSecondaryColumn)
          SizedBox(
            width: 292,
            child: DesktopLevelColumn(
              levelVm: levelVm,
              isEditMode: isEditMode,
              onItemTap: (item) => _performAction(context, item.action),
              onEditItem: (item) => _openEditItemDialog(
                context,
                node: item.node,
                depth: 1,
                hasChildren: false,
              ),
              onDeleteItem: (item) =>
                  _confirmDeleteItem(context, item.node.item),
              onToggleHiddenItem: (item) =>
                  _toggleNavigationItemHidden(context, item.node.item),
              onReorderItem: (items, draggedItem, targetItem) =>
                  _moveNavigationItem(
                    context,
                    siblings: items
                        .map((item) => item.node.item)
                        .toList(growable: false),
                    draggedItem: draggedItem.node.item,
                    targetItem: targetItem.node.item,
                  ),
              onAddChild: isEditMode
                  ? () => _openCreateItemDialog(
                      context,
                      depth: 1,
                      parent: activeRoot.item,
                      nextPosition: nextPosition(
                        activeRoot.children.map((child) => child.item),
                      ),
                    )
                  : null,
            ),
          ),
        if (!showSecondaryColumn && showVisualPanel)
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: _kDrawerDividerColor,
          ),
        if (showVisualPanel) SizedBox(width: showSecondaryColumn ? 24 : 20),
        if (showVisualPanel)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 18, 0),
              child: DrawerVisualPanel(
                levelVm: levelVm,
                isDesktop: true,
                onLegacyCardTap: (card) => _performAction(context, card.action),
                onEditorialTileTap: (tile) =>
                    _performEditorialTileAction(context, tile),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final roots = widget.normalized.roots;
    final rootItems = roots.map((root) => root.item).toList(growable: false);
    final initialParentId = _didResolveInitialMobileParent
        ? _mobileParentId
        : findParentIdForChildCategory(roots, widget.currentCategoryId);
    final activeParent = initialParentId == null
        ? null
        : roots.firstWhere(
            (root) => root.item.id == initialParentId,
            orElse: () => roots.first,
          );
    final isShowingSecondLevel = activeParent != null;
    final isEditMode = ref.watch(editModeProvider);
    if (activeParent != null) {
      final levelVm = buildLevelVm(
        activeParent,
        currentCategoryId: widget.currentCategoryId,
        isDesktop: false,
      );
      _reportVisualPanel(levelVm.hasVisualPanel);
    } else {
      _reportVisualPanel(false);
    }

    final levelKey = isShowingSecondLevel
        ? 'managed:${activeParent.item.id}'
        : 'managed:root';

    return DrawerLevelTransitionSwitcher(
      levelKey: levelKey,
      direction: _mobileLevelTransitionDirection,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(40, 22, 40, 24),
        children: [
          if (!isShowingSecondLevel && isEditMode) ...[
            ActionTile(
              icon: Icons.add,
              label: 'Nouvelle entrée',
              onTap: () => _openCreateItemDialog(
                context,
                depth: 0,
                nextPosition: nextPosition(roots.map((root) => root.item)),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (isShowingSecondLevel) ...[
            DrawerBackTile(
              label: activeParent.item.label,
              onTap: () {
                setState(() {
                  _didResolveInitialMobileParent = true;
                  _mobileLevelTransitionDirection =
                      DrawerLevelTransitionDirection.back;
                  _mobileParentId = null;
                });
              },
            ),
            const Divider(height: 34, color: _kDrawerDividerColor),
            if (isEditMode) ...[
              ActionTile(
                icon: Icons.add,
                label: 'Nouvel item',
                onTap: () => _openCreateItemDialog(
                  context,
                  depth: 1,
                  parent: activeParent.item,
                  nextPosition: nextPosition(
                    activeParent.children.map((child) => child.item),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            ..._buildMobileSecondLevel(context, activeParent),
          ] else ...[
            for (var index = 0; index < roots.length; index++) ...[
              Builder(
                builder: (_) {
                  final root = roots[index];
                  return ManagedDrawerTile(
                    label: root.item.label,
                    isSelected: containsCategoryId(
                      root,
                      widget.currentCategoryId,
                    ),
                    showDisclosure: root.children.isNotEmpty,
                    isEditMode: isEditMode,
                    isHidden: root.item.isHidden,
                    reorderItem: isEditMode ? root.item : null,
                    reorderGroup: 'roots',
                    onTap: () => _handleMobileRootTap(context, root),
                    onEdit: isEditMode
                        ? () => _openEditItemDialog(
                            context,
                            node: root,
                            depth: 0,
                            hasChildren: root.children.isNotEmpty,
                          )
                        : null,
                    onDelete: isEditMode && root.children.isEmpty
                        ? () => _confirmDeleteItem(context, root.item)
                        : null,
                    onAddChild: isEditMode
                        ? () => _openCreateItemDialog(
                            context,
                            depth: 1,
                            parent: root.item,
                            nextPosition: nextPosition(
                              root.children.map((child) => child.item),
                            ),
                          )
                        : null,
                    onToggleHidden: isEditMode
                        ? () => _toggleNavigationItemHidden(context, root.item)
                        : null,
                    onReorderAccepted: isEditMode
                        ? (draggedItem) => _moveNavigationItem(
                            context,
                            siblings: rootItems,
                            draggedItem: draggedItem,
                            targetItem: root.item,
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(height: 2),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildMobileSecondLevel(
    BuildContext context,
    DrawerNavigationNode root,
  ) {
    final levelVm = buildLevelVm(
      root,
      currentCategoryId: widget.currentCategoryId,
      isDesktop: false,
    );
    final isEditMode = ref.read(editModeProvider);
    final widgets = <Widget>[];

    if (levelVm.viewAllItem != null) {
      widgets.add(
        ManagedDrawerTile(
          label: levelVm.viewAllItem!.label,
          isSelected: false,
          showDisclosure: false,
          isEditMode: false,
          onTap: () => _performAction(context, levelVm.viewAllItem!.action),
        ),
      );
      widgets.add(const SizedBox(height: 2));
    }

    for (var index = 0; index < levelVm.navItems.length; index++) {
      final item = levelVm.navItems[index];
      widgets.add(
        ManagedDrawerTile(
          label: item.label,
          isSelected: item.isCurrentCategory,
          showDisclosure: false,
          isEditMode: isEditMode,
          isHidden: item.node.item.isHidden,
          reorderItem: isEditMode ? item.node.item : null,
          reorderGroup: '${levelVm.rootId}:nav',
          onTap: () => _performAction(context, item.action),
          onEdit: isEditMode
              ? () => _openEditItemDialog(
                  context,
                  node: item.node,
                  depth: 1,
                  hasChildren: false,
                )
              : null,
          onDelete: isEditMode
              ? () => _confirmDeleteItem(context, item.node.item)
              : null,
          onToggleHidden: isEditMode
              ? () => _toggleNavigationItemHidden(context, item.node.item)
              : null,
          onReorderAccepted: isEditMode
              ? (draggedItem) => _moveNavigationItem(
                  context,
                  siblings: levelVm.navItems
                      .map((item) => item.node.item)
                      .toList(growable: false),
                  draggedItem: draggedItem,
                  targetItem: item.node.item,
                )
              : null,
        ),
      );
      widgets.add(const SizedBox(height: 2));
    }

    if (levelVm.promoTextItems.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
          child: Text(
            context.l10n.navHighlights,
            style: const TextStyle(
              fontFamily: kDrawerFontFamily,
              color: kDrawerMutedColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
      for (var index = 0; index < levelVm.promoTextItems.length; index++) {
        final item = levelVm.promoTextItems[index];
        widgets.add(
          ManagedDrawerTile(
            label: item.label,
            isSelected: false,
            showDisclosure: false,
            isEditMode: isEditMode,
            isHidden: item.node.item.isHidden,
            reorderItem: isEditMode ? item.node.item : null,
            reorderGroup: '${levelVm.rootId}:promo',
            onTap: () => _performAction(context, item.action),
            onEdit: isEditMode
                ? () => _openEditItemDialog(
                    context,
                    node: item.node,
                    depth: 1,
                    hasChildren: false,
                  )
                : null,
            onDelete: isEditMode
                ? () => _confirmDeleteItem(context, item.node.item)
                : null,
            onToggleHidden: isEditMode
                ? () => _toggleNavigationItemHidden(context, item.node.item)
                : null,
            onReorderAccepted: isEditMode
                ? (draggedItem) => _moveNavigationItem(
                    context,
                    siblings: levelVm.promoTextItems
                        .map((item) => item.node.item)
                        .toList(growable: false),
                    draggedItem: draggedItem,
                    targetItem: item.node.item,
                  )
                : null,
          ),
        );
        widgets.add(const SizedBox(height: 2));
      }
    }

    if (levelVm.hasVisualPanel) {
      widgets.add(const SizedBox(height: 22));
      widgets.add(
        DrawerVisualPanel(
          levelVm: levelVm,
          isDesktop: false,
          onLegacyCardTap: (card) => _performAction(context, card.action),
          onEditorialTileTap: (tile) =>
              _performEditorialTileAction(context, tile),
        ),
      );
    }

    return widgets;
  }

  void _reportVisualPanel(bool hasVisualPanel) {
    if (_lastReportedHasVisualPanel == hasVisualPanel) {
      return;
    }
    _lastReportedHasVisualPanel = hasVisualPanel;
    final callback = widget.onVisualPanelChanged;
    if (callback == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      callback(hasVisualPanel);
    });
  }

  void _handleDesktopRootTap(BuildContext context, DrawerNavigationNode root) {
    final action = resolveAction(root.item);
    if (root.children.isNotEmpty && _activeRootId != root.item.id) {
      _setActiveRoot(root.item.id);
      return;
    }

    if (root.children.isNotEmpty && !action.isNavigable) {
      _setActiveRoot(root.item.id);
      return;
    }

    _performAction(context, action);
  }

  void _handleMobileRootTap(BuildContext context, DrawerNavigationNode root) {
    if (root.children.isNotEmpty) {
      setState(() {
        _didResolveInitialMobileParent = true;
        _mobileLevelTransitionDirection =
            DrawerLevelTransitionDirection.forward;
        _mobileParentId = root.item.id;
      });
      return;
    }

    _performAction(context, resolveAction(root.item));
  }

  void _setActiveRoot(String rootId) {
    // Hover-driven entry point: avoid redundant setState when the active root
    // has not changed (a mouse moving over an already-active tile would
    // otherwise rebuild the whole drawer tree).
    if (_didResolveInitialDesktopRoot && _activeRootId == rootId) {
      return;
    }
    setState(() {
      _didResolveInitialDesktopRoot = true;
      _activeRootId = rootId;
    });
    assert(() {
      widget.debugOnActiveRootChanged?.call();
      return true;
    }());
  }

  Future<String?> _ensureAdminToken(BuildContext context) async {
    return ensureAdminToken(context, ref, enableEditMode: true);
  }

  Future<void> _openCreateItemDialog(
    BuildContext context, {
    required int depth,
    DrawerNavigationItemData? parent,
    required int nextPosition,
  }) async {
    final token = await _ensureAdminToken(context);
    if (token == null || !context.mounted) {
      return;
    }

    final changed = await NavigationItemEditorDialog.show(
      context,
      menuId: widget.menu.id,
      authToken: token,
      depth: depth,
      position: nextPosition,
      parentId: parent?.id,
      title: depth == 0 ? 'Nouvelle entrée' : 'Nouvel item',
    );

    if (changed != true || !mounted) {
      return;
    }

    _refreshManagedDrawerNavigation();
    if (parent != null) {
      setState(() {
        _didResolveInitialDesktopRoot = true;
        _activeRootId = parent.id;
        _didResolveInitialMobileParent = true;
        _mobileParentId = parent.id;
      });
    }
  }

  Future<void> _openEditItemDialog(
    BuildContext context, {
    required DrawerNavigationNode node,
    required int depth,
    required bool hasChildren,
  }) async {
    final token = await _ensureAdminToken(context);
    if (token == null || !context.mounted) {
      return;
    }

    final changed = await NavigationItemEditorDialog.show(
      context,
      menuId: widget.menu.id,
      authToken: token,
      depth: depth,
      position: node.item.position,
      parentId: node.item.parentId,
      title: 'Modifier l’entrée',
      initialItem: node.item,
      hasChildren: hasChildren,
    );

    if (changed != true || !mounted) {
      return;
    }

    _refreshManagedDrawerNavigation();
  }

  Future<void> _confirmDeleteItem(
    BuildContext context,
    DrawerNavigationItemData item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final token = await _ensureAdminToken(context);
    if (token == null || !context.mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l’entrée'),
        content: Text('Cette action supprimera “${item.label}”.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref.read(deleteAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'navigation_items',
        recordId: item.id,
      );
      _refreshManagedDrawerNavigation();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Entrée supprimée.')),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _toggleNavigationItemHidden(
    BuildContext context,
    DrawerNavigationItemData item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final token = await _ensureAdminToken(context);
    if (token == null || !context.mounted) {
      return;
    }

    final nextHidden = !item.isHidden;
    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'navigation_items',
        recordId: item.id,
        data: {'isHidden': nextHidden},
      );
      _refreshManagedDrawerNavigation();
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
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du masquage: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _moveNavigationItem(
    BuildContext context, {
    required List<DrawerNavigationItemData> siblings,
    required DrawerNavigationItemData draggedItem,
    required DrawerNavigationItemData targetItem,
  }) async {
    final reorderedItems = reorderDrawerItems(
      siblings,
      draggedItemId: draggedItem.id,
      targetItemId: targetItem.id,
    );
    if (identical(reorderedItems, siblings)) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final token = await _ensureAdminToken(context);
    if (token == null || !context.mounted) {
      return;
    }

    try {
      await _saveNavigationItemPositions(
        authToken: token,
        items: reorderedItems,
      );
      _refreshManagedDrawerNavigation();
      messenger.showSnackBar(
        const SnackBar(content: Text('Ordre du drawer mis à jour.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement d’ordre: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _saveNavigationItemPositions({
    required String authToken,
    required List<DrawerNavigationItemData> items,
  }) async {
    await Future.wait([
      for (var index = 0; index < items.length; index++)
        if (items[index].position != drawerPositionForIndex(index))
          ref.read(saveAdminRecordProvider)(
            baseUrl: ref.read(apiBaseUrlProvider),
            authToken: authToken,
            collection: 'navigation_items',
            recordId: items[index].id,
            data: {'position': drawerPositionForIndex(index)},
          ),
    ]);
  }

  void _refreshManagedDrawerNavigation() {
    _invalidateManagedDrawerNavigation();
    unawaited(
      Future<void>.delayed(_retryRefreshDelay).then((_) {
        if (!mounted) {
          return;
        }
        _invalidateManagedDrawerNavigation();
      }),
    );
  }

  void _invalidateManagedDrawerNavigation() {
    ref.read(catalogInvalidatorProvider).applyFromWidget(ref, const [
      DrawerNavigationInvalidation(),
    ]);
  }

  void _performAction(BuildContext context, ResolvedDrawerAction action) {
    if (action.externalUrl != null) {
      _closeHostingDrawer(context);
      openStorefrontDrawerExternalLink(action.externalUrl!);
      return;
    }

    if (action.routeName == null) {
      return;
    }

    final router = GoRouter.of(context);
    // Keep category links inside the active sport flow (rewrite /catalog/<slug>
    // -> /sport/<segment>/<slug> when opened from /sport/...), like landing
    // tiles do — a no-op for non-category links. Resolve before closing, while
    // the route context is still stable.
    final routeName = CatalogRoutes.localizedLocation(
      sportContextualCmsHref(context, action.routeName!),
      locale: ref.read(contentLocaleProvider),
    );
    _closeHostingDrawer(context);
    // Close the drawer first, then navigate on the next microtask so the
    // overlay is gone before the route changes. Category links push (so the
    // PLP back arrow returns here); everything else replaces with `go`.
    Future<void>.microtask(() {
      if (action.preserveHistory) {
        router.push(routeName);
      } else {
        router.go(routeName);
      }
    });
  }

  void _performEditorialTileAction(
    BuildContext context,
    DrawerEditorialTile tile,
  ) {
    if (tile.isExternalLink) {
      _closeHostingDrawer(context);
      openStorefrontDrawerExternalLink(tile.link);
      return;
    }

    final router = GoRouter.of(context);
    final link = CatalogRoutes.localizedLocation(
      sportContextualCmsHref(context, tile.link),
      locale: ref.read(contentLocaleProvider),
    );
    _closeHostingDrawer(context);
    Future<void>.microtask(() {
      router.go(link);
    });
  }

  /// Close the Scaffold drawer that hosts this widget, if any. Using
  /// `Navigator.pop` here would pop the underlying GoRouter page instead
  /// of the drawer overlay (Flutter's Scaffold drawer is not a real route
  /// on every host), which empties the route stack and crashes go_router
  /// with `currentConfiguration.isNotEmpty`. `closeDrawer` is the correct
  /// API: it is a no-op when the widget is rendered inline (desktop) and
  /// closes the overlay when it is hosted in a Scaffold drawer (mobile).
  void _closeHostingDrawer(BuildContext context) {
    Scaffold.maybeOf(context)?.closeDrawer();
  }
}
