import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_providers.dart';
import '../../app/catalog_routes.dart';
import '../../application/catalog/catalog_invalidations.dart';
import '../../application/navigation/drawer_navigation_models.dart';
import '../../core/constants.dart';
import '../../core/utils/slug_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../l10n/l10n_extension.dart';
import '../providers/catalog_invalidator_provider.dart';
import '../providers/category_providers.dart';
import '../providers/content_locale_provider.dart';
import '../providers/edit_mode_provider.dart';
import '../providers/navigation_providers.dart';
import 'cms/cms_admin_auth.dart';
import 'cms/sport_context_cms_href.dart';
import 'storefront_layout.dart';
import 'storefront_managed_navigation_drawer.dart';
import 'drawer/category_drawer_widgets.dart';
import 'drawer/drawer_shared_widgets.dart';

const _kDrawerRuleColor = Color(0xFFE3E0DC);
const _kDrawerOuterMargin = 16.0;
const _kDrawerRadius = 18.0;
const _kDesktopDrawerWidth = 411.594;

bool _hasDefaultManagedVisualPanelForWrapper(
  DrawerNavigationLoadResult? result,
) {
  final roots = result?.normalized?.roots;
  if (roots == null || roots.isEmpty) {
    return false;
  }
  final root = roots.firstWhere(
    (candidate) => candidate.children.isNotEmpty,
    orElse: () => roots.first,
  );
  return _nodeHasVisualPanelForWrapper(root);
}

bool _nodeHasVisualPanelForWrapper(DrawerNavigationNode node) {
  if (node.item.editorialTiles.hasActiveItems) {
    return true;
  }

  final template =
      node.item.desktopDrawerTemplate ??
      DrawerNavigationDesktopTemplate.listOnly;
  if (node.item.promoMedia != null &&
      template != DrawerNavigationDesktopTemplate.listOnly) {
    return true;
  }

  if (template == DrawerNavigationDesktopTemplate.listOnly) {
    return false;
  }

  return node.children.any(
    (child) =>
        child.item.placement == DrawerNavigationPlacement.promo &&
        child.item.promoMedia != null,
  );
}

enum StorefrontNavigationMenuVariant { drawer, fullscreen }

class StorefrontCategoryDrawer extends ConsumerWidget {
  final String? currentCategoryId;

  const StorefrontCategoryDrawer({super.key, this.currentCategoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawerNavigation = ref.watch(mainDrawerNavigationProvider).value;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = StorefrontLayout.isDesktop(width);
    final narrowDrawerWidth = isDesktop
        ? _kDesktopDrawerWidth.clamp(280.0, width).toDouble()
        : (width <= 280 + _kDrawerOuterMargin
              ? width
              : width - _kDrawerOuterMargin);
    final wideCandidateWidth = width <= _kDrawerOuterMargin * 2
        ? width
        : width - (_kDrawerOuterMargin * 2);
    final hasManagedNavigation =
        drawerNavigation?.menu?.liveSource != DrawerLiveSource.categories &&
        (drawerNavigation?.isUsable ?? false);
    final useEditorialManagedDesktopDrawer =
        hasManagedNavigation &&
        isDesktop &&
        wideCandidateWidth >= 900 &&
        _hasDefaultManagedVisualPanelForWrapper(drawerNavigation);
    final drawerWidth = useEditorialManagedDesktopDrawer
        ? wideCandidateWidth
        : narrowDrawerWidth;

    // Closing via the X "drops" the whole panel off-screen instead of the
    // native horizontal slide (see [_DrawerFallExit]); category taps keep the
    // plain `onClose` so navigation never waits behind the fall.
    return _DrawerFallExit(
      onDismissed: () => Navigator.of(context).pop(),
      builder: (context, requestClose) => Drawer(
        width: drawerWidth,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(_kDrawerRadius),
            bottomRight: Radius.circular(_kDrawerRadius),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: StorefrontNavigationMenuContent(
            currentCategoryId: currentCategoryId,
            variant: StorefrontNavigationMenuVariant.drawer,
            showCloseHeader: true,
            showFooter: true,
            onClose: () => Navigator.of(context).pop(),
            onCloseRequested: requestClose,
          ),
        ),
      ),
    );
  }
}

/// Reproduces the GSAP "panels fall away" exit: closing the drawer through its
/// close button drops the entire panel off-screen with a small rotation
/// (`power3.in` ≈ [Curves.easeInCubic]) before performing the real dismissal,
/// rather than the framework's default horizontal slide.
///
/// The fall transform wraps the whole `Drawer` (background + content), so the
/// panel topples as one piece. It is *paint-only* ([Transform]), so layout —
/// and therefore [DrawerController]'s open slide and the scrim — is untouched
/// until the user explicitly closes. Under reduced motion the panel is
/// dismissed immediately with no drop.
class _DrawerFallExit extends StatefulWidget {
  /// The real dismissal (pops the drawer route). Called once the drop finishes.
  final VoidCallback onDismissed;

  /// Builds the panel; `requestClose` triggers the drop-then-dismiss sequence.
  final Widget Function(BuildContext context, VoidCallback requestClose)
  builder;

  const _DrawerFallExit({required this.onDismissed, required this.builder});

  @override
  State<_DrawerFallExit> createState() => _DrawerFallExitState();
}

class _DrawerFallExitState extends State<_DrawerFallExit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fall = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 540),
  );

  // A fixed tilt resolved once per open, so the drop reads as a playful topple
  // without a per-frame random (GSAP uses `rotation: random(-15, 15)`).
  late final double _tiltRadians =
      ((math.Random().nextDouble() * 2) - 1) * (10 * math.pi / 180); // ±10°

  bool _falling = false;

  @override
  void dispose() {
    _fall.dispose();
    super.dispose();
  }

  void _requestClose() {
    if (_falling) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onDismissed();
      return;
    }
    _falling = true;
    _fall.forward(from: 0).whenComplete(() {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final panel = widget.builder(context, _requestClose);
    return AnimatedBuilder(
      animation: _fall,
      builder: (context, child) {
        final t = Curves.easeInCubic.transform(_fall.value);
        if (t == 0) return child!;
        // Travel ~1.3× the screen height so the full-height panel clears the
        // viewport, tumbling around its centre as it goes.
        final dy = t * MediaQuery.sizeOf(context).height * 1.3;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(angle: t * _tiltRadians, child: child),
        );
      },
      child: panel,
    );
  }
}

class StorefrontNavigationMenuContent extends ConsumerStatefulWidget {
  final String? currentCategoryId;
  final StorefrontNavigationMenuVariant variant;
  final bool showCloseHeader;
  final bool showFooter;
  final bool isOpen;
  final VoidCallback onClose;

  /// Optional close action for the X button only. When set, the close header
  /// calls this instead of [onClose] so the drawer variant can play its
  /// drop-away exit; category taps still use [onClose] directly.
  final VoidCallback? onCloseRequested;

  const StorefrontNavigationMenuContent({
    super.key,
    this.currentCategoryId,
    required this.variant,
    required this.showCloseHeader,
    required this.showFooter,
    this.isOpen = false,
    required this.onClose,
    this.onCloseRequested,
  });

  @override
  ConsumerState<StorefrontNavigationMenuContent> createState() =>
      _StorefrontNavigationMenuContentState();
}

class _StorefrontNavigationMenuContentState
    extends ConsumerState<StorefrontNavigationMenuContent> {
  String? _activeParentId;
  DrawerEditScope _editScope = DrawerEditScope.navigation;
  DrawerLiveSource? _selectedDrawerLiveSource;
  bool _didSelectEditScope = false;
  bool _isUpdatingDrawerLiveSource = false;
  bool _didResolveInitialLevel = false;
  DrawerLevelTransitionDirection _drawerLevelTransitionDirection =
      DrawerLevelTransitionDirection.forward;
  bool _didAutoRefreshManagedNavigationForCurrentOpen = false;
  bool _managedNavigationRefreshScheduled = false;
  bool? _managedVisualPanelOverride;
  Timer? _visualPanelDebounce;
  // Banner-strip drill support: consume a pending drill target once per open,
  // and reset the drill level on a fresh manual open so a previous banner
  // drill does not resurface. See [pendingDrawerDrillTargetProvider].
  bool _didConsumePendingDrillTarget = false;
  bool _wasDrawerOpen = false;

  @override
  void dispose() {
    _visualPanelDebounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StorefrontNavigationMenuContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCategoryId != widget.currentCategoryId) {
      _activeParentId = null;
      _didResolveInitialLevel = false;
      _drawerLevelTransitionDirection = DrawerLevelTransitionDirection.forward;
      _didConsumePendingDrillTarget = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = ref.watch(editModeProvider);
    final areEditControlsVisible = ref.watch(editControlsVisibleProvider);
    final drawerNavigationAsync = ref.watch(mainDrawerNavigationProvider);
    final drawerNavigation = drawerNavigationAsync.value;
    final drawerLiveSource =
        _selectedDrawerLiveSource ??
        drawerNavigation?.menu?.liveSource ??
        DrawerLiveSource.navigation;
    final effectiveEditScope = _effectiveEditScope(drawerLiveSource);
    final isCategoryEditScope =
        isEditMode && effectiveEditScope == DrawerEditScope.categories;
    final isCategoryLiveSource =
        !isEditMode && drawerLiveSource == DrawerLiveSource.categories;
    final isDrawerOpen =
        widget.isOpen || (Scaffold.maybeOf(context)?.isDrawerOpen ?? false);
    _handleDrawerOpenStateChange(isDrawerOpen);
    _maybeRefreshManagedNavigationOnDrawerOpen(
      isEditMode: isEditMode,
      isDrawerOpen: isDrawerOpen,
      isNavigationScope: !isCategoryEditScope,
    );
    final isRefreshingManagedNavigation =
        drawerNavigationAsync.isLoading && drawerNavigation != null;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = StorefrontLayout.isDesktop(width);
    final hasManagedNavigation =
        !isCategoryLiveSource && (drawerNavigation?.isUsable ?? false);
    final hasManagedNavigationAdminState =
        isEditMode && _supportsManagedNavigationBootstrap(drawerNavigation);
    final wideCandidateWidth = width <= _kDrawerOuterMargin * 2
        ? width
        : width - (_kDrawerOuterMargin * 2);
    final hasInitialVisualPanel = _hasDefaultManagedVisualPanel(
      drawerNavigation,
    );
    final hasVisualPanel = _managedVisualPanelOverride ?? hasInitialVisualPanel;
    final useEditorialManagedDesktopDrawer =
        hasManagedNavigation &&
        isDesktop &&
        wideCandidateWidth >= 900 &&
        hasVisualPanel;
    final drawerBody = isCategoryLiveSource || isCategoryEditScope
        ? _buildCategoryEditPanel()
        : _buildNavigationPanel(
            drawerNavigationAsync,
            drawerNavigation,
            hasManagedNavigationAdminState: hasManagedNavigationAdminState,
            forceSingleColumn: !useEditorialManagedDesktopDrawer,
          );
    final drawerContent =
        !isCategoryEditScope &&
            !isCategoryLiveSource &&
            isRefreshingManagedNavigation
        ? Column(
            children: [
              const LinearProgressIndicator(minHeight: 2),
              Expanded(child: drawerBody),
            ],
          )
        : drawerBody;

    return useEditorialManagedDesktopDrawer
        ? _buildEditorialManagedDesktopShell(
            context,
            drawerContent,
            isEditMode,
            areEditControlsVisible: areEditControlsVisible,
            selectedScope: effectiveEditScope,
            drawerNavigation: drawerNavigation,
          )
        : _buildDefaultDrawerShell(
            context,
            drawerContent,
            isEditMode,
            areEditControlsVisible: areEditControlsVisible,
            selectedScope: effectiveEditScope,
            drawerNavigation: drawerNavigation,
          );
  }

  DrawerEditScope _effectiveEditScope(DrawerLiveSource liveSource) {
    if (_didSelectEditScope) {
      return _editScope;
    }

    return _editScopeForDrawerLiveSource(liveSource);
  }

  DrawerEditScope _editScopeForDrawerLiveSource(DrawerLiveSource liveSource) {
    return switch (liveSource) {
      DrawerLiveSource.navigation => DrawerEditScope.navigation,
      DrawerLiveSource.categories => DrawerEditScope.categories,
    };
  }

  DrawerLiveSource _drawerLiveSourceForEditScope(DrawerEditScope scope) {
    return switch (scope) {
      DrawerEditScope.navigation => DrawerLiveSource.navigation,
      DrawerEditScope.categories => DrawerLiveSource.categories,
    };
  }

  Widget _buildNavigationPanel(
    AsyncValue<DrawerNavigationLoadResult> drawerNavigationAsync,
    DrawerNavigationLoadResult? drawerNavigation, {
    required bool hasManagedNavigationAdminState,
    required bool forceSingleColumn,
  }) {
    if (drawerNavigation != null) {
      return _buildManagedOrFallbackDrawerContent(
        drawerNavigation,
        hasManagedNavigationAdminState: hasManagedNavigationAdminState,
        forceSingleColumn: forceSingleColumn,
      );
    }

    if (drawerNavigationAsync.hasError) {
      return _buildCategoryFallback();
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildCategoryEditPanel() {
    return _buildCategoryFallback();
  }

  Widget _buildManagedOrFallbackDrawerContent(
    DrawerNavigationLoadResult result, {
    required bool hasManagedNavigationAdminState,
    required bool forceSingleColumn,
  }) {
    if (result.isUsable && result.menu != null && result.normalized != null) {
      return StorefrontManagedNavigationDrawerContent(
        menu: result.menu!,
        normalized: result.normalized!,
        currentCategoryId: widget.currentCategoryId,
        forceSingleColumn: forceSingleColumn,
        onVisualPanelChanged: _handleManagedVisualPanelChanged,
      );
    }

    if (hasManagedNavigationAdminState) {
      return StorefrontManagedNavigationDrawerAdminState(result: result);
    }

    return _buildCategoryFallback();
  }

  Widget _buildEditorialManagedDesktopShell(
    BuildContext context,
    Widget drawerContent,
    bool isEditMode, {
    required bool areEditControlsVisible,
    required DrawerEditScope selectedScope,
    required DrawerNavigationLoadResult? drawerNavigation,
  }) {
    return Column(
      children: [
        if (widget.showCloseHeader) ...[
          DrawerCloseHeader(onClose: widget.onCloseRequested ?? widget.onClose),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Divider(height: 1, color: _kDrawerRuleColor),
          ),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 26, 0, 0),
            child: _buildScopedDrawerContent(
              context,
              drawerContent,
              isEditMode,
              selectedScope: selectedScope,
              drawerNavigation: drawerNavigation,
            ),
          ),
        ),
        if (widget.showFooter)
          DrawerFooter(
            isEditMode: isEditMode,
            showEditModeAction: areEditControlsVisible,
            onToggleEditMode: () => _toggleEditMode(context),
          ),
      ],
    );
  }

  Widget _buildDefaultDrawerShell(
    BuildContext context,
    Widget drawerContent,
    bool isEditMode, {
    required bool areEditControlsVisible,
    required DrawerEditScope selectedScope,
    required DrawerNavigationLoadResult? drawerNavigation,
  }) {
    return Column(
      children: [
        if (widget.showCloseHeader) ...[
          DrawerCloseHeader(onClose: widget.onCloseRequested ?? widget.onClose),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Divider(height: 1, color: _kDrawerRuleColor),
          ),
        ],
        Expanded(
          child: _buildScopedDrawerContent(
            context,
            drawerContent,
            isEditMode,
            selectedScope: selectedScope,
            drawerNavigation: drawerNavigation,
          ),
        ),
        if (widget.showFooter)
          DrawerFooter(
            isEditMode: isEditMode,
            showEditModeAction: areEditControlsVisible,
            onToggleEditMode: () => _toggleEditMode(context),
          ),
      ],
    );
  }

  Widget _buildScopedDrawerContent(
    BuildContext context,
    Widget drawerContent,
    bool isEditMode, {
    required DrawerEditScope selectedScope,
    required DrawerNavigationLoadResult? drawerNavigation,
  }) {
    if (!isEditMode) {
      return drawerContent;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 16, 34, 12),
          child: DrawerEditScopeSelector(
            selectedScope: selectedScope,
            isSaving: _isUpdatingDrawerLiveSource,
            onChanged: (scope) => _handleDrawerLiveSourceChanged(
              context,
              scope,
              drawerNavigation,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Divider(height: 1, color: _kDrawerRuleColor),
        ),
        Expanded(child: drawerContent),
      ],
    );
  }

  Future<void> _handleDrawerLiveSourceChanged(
    BuildContext context,
    DrawerEditScope nextScope,
    DrawerNavigationLoadResult? drawerNavigation,
  ) async {
    final previousScope = _effectiveEditScope(
      drawerNavigation?.menu?.liveSource ?? DrawerLiveSource.navigation,
    );
    final previousLiveSource =
        _selectedDrawerLiveSource ??
        drawerNavigation?.menu?.liveSource ??
        DrawerLiveSource.navigation;
    final nextLiveSource = _drawerLiveSourceForEditScope(nextScope);
    final menu = drawerNavigation?.menu;

    setState(() {
      _editScope = nextScope;
      _didSelectEditScope = true;
    });

    final currentLiveSource =
        _selectedDrawerLiveSource ??
        menu?.liveSource ??
        DrawerLiveSource.navigation;
    if (currentLiveSource == nextLiveSource &&
        (menu?.isActive ?? nextLiveSource == DrawerLiveSource.navigation)) {
      _selectedDrawerLiveSource = nextLiveSource;
      return;
    }

    if (drawerNavigation?.fallbackReason ==
        DrawerNavigationFallbackReason.fetchError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible de modifier le type du drawer: configuration inaccessible.',
          ),
        ),
      );
      setState(() {
        _editScope = previousScope;
        _selectedDrawerLiveSource = previousLiveSource;
        _didSelectEditScope = true;
      });
      return;
    }

    final token = await ensureAdminToken(context, ref);
    if (token == null) {
      if (mounted) {
        setState(() {
          _editScope = previousScope;
          _selectedDrawerLiveSource = previousLiveSource;
          _didSelectEditScope = true;
        });
      }
      return;
    }

    if (!context.mounted) return;

    setState(() {
      _isUpdatingDrawerLiveSource = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final displayMode = displayModeForDrawerLiveSource(nextLiveSource);

    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'navigation_menus',
        recordId: menu?.id,
        data: {
          'name': menu?.name.isNotEmpty == true ? menu!.name : 'Main drawer',
          'code': menu?.code.isNotEmpty == true ? menu!.code : 'main_drawer',
          'displayMode': displayMode,
          'isActive': true,
        },
      );

      ref.read(catalogInvalidatorProvider).applyFromWidget(ref, [
        ...invalidationsForAdminSave(
          collection: 'navigation_menus',
          recordId: menu?.id,
          data: {'displayMode': displayMode, 'isActive': true},
        ),
      ]);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nextLiveSource == DrawerLiveSource.categories
                ? 'Le drawer live utilisera les catégories.'
                : 'Le drawer live utilisera la navigation.',
          ),
        ),
      );
      _selectedDrawerLiveSource = nextLiveSource;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _editScope = previousScope;
        _selectedDrawerLiveSource = previousLiveSource;
        _didSelectEditScope = true;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement de type: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingDrawerLiveSource = false;
        });
      }
    }
  }

  void _maybeRefreshManagedNavigationOnDrawerOpen({
    required bool isEditMode,
    required bool isDrawerOpen,
    required bool isNavigationScope,
  }) {
    if (!isEditMode || !isDrawerOpen || !isNavigationScope) {
      _didAutoRefreshManagedNavigationForCurrentOpen = false;
      _managedNavigationRefreshScheduled = false;
      if (!isDrawerOpen) {
        _managedVisualPanelOverride = null;
        _visualPanelDebounce?.cancel();
      }
      return;
    }

    if (_didAutoRefreshManagedNavigationForCurrentOpen ||
        _managedNavigationRefreshScheduled) {
      return;
    }

    _managedNavigationRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ref.read(catalogInvalidatorProvider).applyFromWidget(ref, const [
        DrawerNavigationInvalidation(),
      ]);
      _managedNavigationRefreshScheduled = false;
      _didAutoRefreshManagedNavigationForCurrentOpen = true;
    });
  }

  void _handleManagedVisualPanelChanged(bool hasVisualPanel) {
    _visualPanelDebounce?.cancel();
    _visualPanelDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || _managedVisualPanelOverride == hasVisualPanel) {
        return;
      }
      setState(() {
        _managedVisualPanelOverride = hasVisualPanel;
      });
    });
  }

  bool _hasDefaultManagedVisualPanel(DrawerNavigationLoadResult? result) {
    final roots = result?.normalized?.roots;
    if (roots == null || roots.isEmpty) {
      return false;
    }
    final root = _defaultManagedRootForVisualPanel(roots);
    if (root == null) {
      return false;
    }
    return _nodeHasVisualPanel(root);
  }

  DrawerNavigationNode? _defaultManagedRootForVisualPanel(
    List<DrawerNavigationNode> roots,
  ) {
    final currentCategoryId = widget.currentCategoryId;
    if (currentCategoryId != null && currentCategoryId.isNotEmpty) {
      for (final root in roots) {
        if (_managedNodeContainsCategoryId(root, currentCategoryId)) {
          return root;
        }
      }
    }
    for (final root in roots) {
      if (root.children.isNotEmpty) {
        return root;
      }
    }
    return roots.first;
  }

  bool _nodeHasVisualPanel(DrawerNavigationNode node) {
    if (node.item.editorialTiles.hasActiveItems) {
      return true;
    }

    final template =
        node.item.desktopDrawerTemplate ??
        DrawerNavigationDesktopTemplate.listOnly;
    if (node.item.promoMedia != null &&
        template != DrawerNavigationDesktopTemplate.listOnly) {
      return true;
    }

    if (template == DrawerNavigationDesktopTemplate.listOnly) {
      return false;
    }

    return node.children.any(
      (child) =>
          child.item.placement == DrawerNavigationPlacement.promo &&
          child.item.promoMedia != null,
    );
  }

  bool _managedNodeContainsCategoryId(
    DrawerNavigationNode node,
    String categoryId,
  ) {
    if (node.item.itemType == DrawerNavigationItemType.category &&
        node.item.categoryId == categoryId) {
      return true;
    }
    for (final child in node.children) {
      if (_managedNodeContainsCategoryId(child, categoryId)) {
        return true;
      }
    }
    return false;
  }

  bool _supportsManagedNavigationBootstrap(DrawerNavigationLoadResult? result) {
    final reason = result?.fallbackReason;
    return switch (reason) {
      DrawerNavigationFallbackReason.menuMissing ||
      DrawerNavigationFallbackReason.menuInactive ||
      DrawerNavigationFallbackReason.noValidRoots ||
      DrawerNavigationFallbackReason.treeInvalid => true,
      DrawerNavigationFallbackReason.fetchError || null => false,
    };
  }

  Widget _buildCategoryFallback() {
    final categoriesAsync = ref.watch(drawerCategoriesProvider);
    final isEditMode = ref.watch(editModeProvider);

    return categoriesAsync.when(
      data: (categories) =>
          _buildCategoryContent(context, categories, isEditMode),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.navCategoriesLoadError(error.toString()),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryContent(
    BuildContext context,
    List<CatalogCategory> categories,
    bool isEditMode,
  ) {
    final categoriesById = <String, CatalogCategory>{
      for (final category in categories) category.id: category,
    };
    final childrenByParentId = <String, List<CatalogCategory>>{};
    final topLevelCategories = <CatalogCategory>[];

    for (final category in categories) {
      final parentId = _normalizeParentId(category.parentId);
      if (parentId == null || !categoriesById.containsKey(parentId)) {
        topLevelCategories.add(category);
        continue;
      }
      childrenByParentId.putIfAbsent(parentId, () => []).add(category);
    }

    _maybeConsumePendingDrillTarget(categoriesById, childrenByParentId);

    final inferredParentId = _didResolveInitialLevel
        ? _activeParentId
        : _inferInitialParentId(categoriesById);
    final activeParent = inferredParentId == null
        ? null
        : categoriesById[inferredParentId];
    final secondLevelCategories = activeParent == null
        ? const <CatalogCategory>[]
        : (childrenByParentId[activeParent.id] ?? const <CatalogCategory>[]);
    final isShowingSecondLevel = activeParent != null;
    final visibleCategories = isShowingSecondLevel
        ? secondLevelCategories
        : topLevelCategories;
    final reorderGroup = isShowingSecondLevel
        ? 'category:${activeParent.id}'
        : 'category:root';

    if (visibleCategories.isEmpty && !isEditMode) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.navNoActiveCategories,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final levelKey = isShowingSecondLevel
        ? 'category:${activeParent.id}'
        : 'category:root';

    return DrawerLevelTransitionSwitcher(
      levelKey: levelKey,
      direction: _drawerLevelTransitionDirection,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(40, 22, 40, 24),
        children: [
          if (isShowingSecondLevel) ...[
            DrawerBackTile(
              label: activeParent.name,
              onTap: () => _goUpOneLevel(activeParent),
            ),
            const Divider(height: 34, color: _kDrawerRuleColor),
          ],
          if (isEditMode && isShowingSecondLevel) ...[
            // Transparent Material: the Drawer's white backgroundColor puts a
            // ColoredBox between Material and ListTile (Flutter 3.44 asserts).
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: kDrawerTileDensity,
                leading: const Icon(Icons.add, color: kDrawerChrome),
                title: Text(
                  'Nouvelle sous-catégorie',
                  style: const TextStyle(
                    fontFamily: kDrawerFontFamily,
                    color: kDrawerChrome,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _handleCreateCategory(
                  context,
                  parentCategory: activeParent,
                  siblingCategories: secondLevelCategories,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (isEditMode && !isShowingSecondLevel) ...[
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: kDrawerTileDensity,
                leading: const Icon(Icons.add, color: kDrawerChrome),
                title: Text(
                  'Nouvelle catégorie',
                  style: const TextStyle(
                    fontFamily: kDrawerFontFamily,
                    color: kDrawerChrome,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _handleCreateCategory(
                  context,
                  siblingCategories: topLevelCategories,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          for (var index = 0; index < visibleCategories.length; index++) ...[
            _buildCategoryTile(
              context,
              visibleCategories[index],
              siblingCategories: visibleCategories,
              reorderGroup: reorderGroup,
              allCategories: categories,
              childrenByParentId: childrenByParentId,
              isEditMode: isEditMode,
              isShowingSecondLevel: isShowingSecondLevel,
            ),
            const SizedBox(height: 2),
          ],
          // Portfolio demo link, last at the top level only. This renders in the
          // category drawer (the live source); the managed drawer has its own
          // items, so there is no duplication path here.
          if (!isEditMode && !isShowingSecondLevel) ...[
            const Divider(height: 34, color: _kDrawerRuleColor),
            _buildCommercetoolsLabTile(context),
          ],
        ],
      ),
    );
  }

  Widget _buildCommercetoolsLabTile(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: kDrawerTileDensity,
        leading: const Icon(Icons.science_outlined, color: kDrawerChrome),
        title: Text(
          context.l10n.navCommercetoolsDemo,
          style: const TextStyle(
            fontFamily: kDrawerFontFamily,
            color: kDrawerChrome,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
        onTap: () => _navigateToCommercetoolsLab(context),
      ),
    );
  }

  void _navigateToCommercetoolsLab(BuildContext context) {
    final router = GoRouter.of(context);
    widget.onClose();
    Future<void>.microtask(() {
      router.go(CatalogRoutes.labCommercetoolsProducts);
    });
  }

  Widget _buildCategoryTile(
    BuildContext context,
    CatalogCategory category, {
    required List<CatalogCategory> siblingCategories,
    required String reorderGroup,
    required List<CatalogCategory> allCategories,
    required Map<String, List<CatalogCategory>> childrenByParentId,
    required bool isEditMode,
    required bool isShowingSecondLevel,
  }) {
    final isTopLevel = !isShowingSecondLevel;
    final directChildren =
        childrenByParentId[category.id] ?? const <CatalogCategory>[];
    final hasChildren = directChildren.isNotEmpty;

    return DrawerCategoryTile(
      category: category,
      isSelected: category.id == widget.currentCategoryId,
      isEditMode: isEditMode,
      // A '>' disclosure on any category that has children, at any depth — not
      // just the top level — so intermediate categories (e.g. Homme >
      // Chaussures/Vêtements/Sport) signal they drill further.
      showDisclosure: hasChildren,
      showCreateChildAction: isTopLevel,
      isHidden: category.isHidden,
      reorderCategory: isEditMode ? category : null,
      reorderGroup: reorderGroup,
      onTap: () =>
          _handleCategoryTap(context, category, hasChildren: hasChildren),
      onEdit: isEditMode
          ? () => _handleRenameCategory(context, category)
          : null,
      onCreateChild: isEditMode && isTopLevel
          ? () => _handleCreateCategory(
              context,
              parentCategory: category,
              siblingCategories: directChildren,
            )
          : null,
      onToggleHidden: isEditMode
          ? () => _handleToggleCategoryHidden(context, category)
          : null,
      onReorderAccepted: isEditMode
          ? (draggedCategory) => _handleMoveCategory(
              context,
              siblings: siblingCategories,
              draggedCategory: draggedCategory,
              targetCategory: category,
            )
          : null,
      onReparent: isEditMode
          ? () => _handleReparentCategory(
              context,
              category,
              allCategories: allCategories,
              directChildren: directChildren,
            )
          : null,
      onDelete: isEditMode
          ? () => _confirmDeleteCategory(
              context,
              category,
              directChildren: directChildren,
            )
          : null,
      onOpenChildren: hasChildren ? () => _openSecondLevel(category) : null,
    );
  }

  String? _inferInitialParentId(Map<String, CatalogCategory> categoriesById) {
    final currentCategoryId = widget.currentCategoryId;
    if (currentCategoryId == null || currentCategoryId.isEmpty) {
      return null;
    }

    final currentCategory = categoriesById[currentCategoryId];
    if (currentCategory == null) {
      return null;
    }

    final parentId = _normalizeParentId(currentCategory.parentId);
    if (parentId == null || !categoriesById.containsKey(parentId)) {
      return null;
    }

    return parentId;
  }

  String? _normalizeParentId(String? parentId) {
    final trimmed = parentId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  void _handleCategoryTap(
    BuildContext context,
    CatalogCategory category, {
    required bool hasChildren,
  }) {
    final isEditMode = ref.read(editModeProvider);
    if (!isEditMode && hasChildren) {
      _openSecondLevel(category);
      return;
    }

    _navigateToCategory(
      context,
      category,
      isSelected: category.id == widget.currentCategoryId,
    );
  }

  void _openSecondLevel(CatalogCategory category) {
    setState(() {
      _didResolveInitialLevel = true;
      _drawerLevelTransitionDirection = DrawerLevelTransitionDirection.forward;
      _activeParentId = category.id;
    });
  }

  void _goUpOneLevel(CatalogCategory category) {
    // Navigate up exactly one level: show the children of the current
    // category's parent, or the top level when the parent is a root. Fixes the
    // back tile for trees deeper than two levels (e.g. Homme > Chaussures > … →
    // back goes to Homme's children, not all the way to the top).
    setState(() {
      _didResolveInitialLevel = true;
      _drawerLevelTransitionDirection = DrawerLevelTransitionDirection.back;
      _activeParentId = _normalizeParentId(category.parentId);
    });
  }

  /// Reacts to the Scaffold drawer opening/closing so banner-driven drills
  /// behave predictably:
  /// - On a fresh open with no pending target, reset to the top level so a
  ///   previous banner drill does not resurface on a manual open.
  /// - On close, allow the next open to consume a new target and clear any
  ///   target that was never consumed (backstop against stale state).
  ///
  /// Fields are mutated directly (not via setState): this runs inside build,
  /// which reads them immediately afterwards.
  void _handleDrawerOpenStateChange(bool isDrawerOpen) {
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
      _activeParentId = null;
      _didResolveInitialLevel = false;
      _drawerLevelTransitionDirection = DrawerLevelTransitionDirection.back;
    }
  }

  /// Consumes a pending banner drill target for the category-fallback drawer.
  /// Drills into the target category's children when it exists and has any,
  /// otherwise leaves the drawer at the top level. Runs once per open and
  /// clears the target either way (this drawer instance is fixed in category
  /// mode, so an unconsumed target here would never be consumed).
  void _maybeConsumePendingDrillTarget(
    Map<String, CatalogCategory> categoriesById,
    Map<String, List<CatalogCategory>> childrenByParentId,
  ) {
    if (_didConsumePendingDrillTarget) return;
    final target = ref.read(pendingDrawerDrillTargetProvider);
    if (target == null) return;
    _didConsumePendingDrillTarget = true;

    final categoryId = target.categoryId;
    final hasChildren =
        categoryId != null &&
        (childrenByParentId[categoryId]?.isNotEmpty ?? false);
    if (categoryId != null &&
        categoriesById.containsKey(categoryId) &&
        hasChildren) {
      _activeParentId = categoryId;
      _didResolveInitialLevel = true;
      _drawerLevelTransitionDirection = DrawerLevelTransitionDirection.forward;
    }
    _clearPendingDrillTargetAfterFrame();
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

  void _navigateToCategory(
    BuildContext context,
    CatalogCategory category, {
    required bool isSelected,
  }) {
    final router = GoRouter.of(context);

    if (isSelected) {
      widget.onClose();
      return;
    }

    // Keep category browsing inside the active sport flow: rewrite
    // /catalog/<slug> -> /sport/<segment>/<slug> when the drawer is opened from
    // /sport/..., so the PLP opens under the same SportFlowShell (same bottom
    // nav) — matching how a landing tile navigates (sportContextualCmsHref).
    // A no-op outside the sport flow. Resolved before onClose, while the route
    // context is still stable.
    final routeName = CatalogRoutes.localizedLocation(
      sportContextualCmsHref(context, CatalogRoutes.categoryLocation(category)),
      locale: ref.read(contentLocaleProvider),
    );
    widget.onClose();
    // Push (not go): browsing a category from the drawer must be reversible so
    // the PLP back arrow returns to the page the drawer was opened from.
    Future<void>.microtask(() {
      router.push(routeName);
    });
  }

  Future<void> _toggleEditMode(BuildContext context) async {
    final isEditMode = ref.read(editModeProvider);
    if (isEditMode) {
      setState(() {
        _didSelectEditScope = false;
        _selectedDrawerLiveSource = null;
      });
      ref.read(editModeProvider.notifier).state = false;
      return;
    }

    final token = await ensureAdminToken(context, ref);
    if (token == null) return;
    ref.read(editModeProvider.notifier).state = true;
  }

  Future<void> _handleCreateCategory(
    BuildContext context, {
    CatalogCategory? parentCategory,
    List<CatalogCategory> siblingCategories = const [],
  }) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null) return;

    if (!context.mounted) return;

    final name = await CategoryNameDialog.show(
      context,
      title: parentCategory == null
          ? 'Nouvelle catégorie'
          : 'Nouvelle sous-catégorie',
      confirmLabel: 'Créer',
    );
    if (!context.mounted || name == null || name.isEmpty) {
      return;
    }

    final slug = slugify(name, fallback: 'categorie');
    final code = slug.toUpperCase();
    final position = nextCategoryPosition(siblingCategories);

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'categories',
        data: {
          'code': code,
          'name': name,
          'slug': slug,
          'isActive': true,
          'isHidden': false,
          'position': position,
          if (parentCategory != null) 'parent': parentCategory.id,
        },
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    ref
        .read(catalogInvalidatorProvider)
        .applyFromWidget(
          ref,
          invalidationsForAdminSave(
            collection: 'categories',
            data: {
              'code': code,
              'name': name,
              'slug': slug,
              'isActive': true,
              'isHidden': false,
              'position': position,
              if (parentCategory != null) 'parent': parentCategory.id,
            },
          ),
        );

    if (parentCategory != null && mounted) {
      setState(() {
        _didResolveInitialLevel = true;
        _activeParentId = parentCategory.id;
      });
    }

    widget.onClose();

    final routeName = CatalogRoutes.localizedLocation(
      CatalogRoutes.categoryBySlug(slug),
      locale: ref.read(contentLocaleProvider),
    );
    Future<void>.microtask(() {
      router.go(routeName);
    });
  }

  Future<void> _handleRenameCategory(
    BuildContext context,
    CatalogCategory category,
  ) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null) return;

    if (!context.mounted) return;

    final nextName = await CategoryNameDialog.show(
      context,
      title: 'Modifier la catégorie',
      confirmLabel: 'Enregistrer',
      initialValue: category.name,
    );
    if (!context.mounted || nextName == null || nextName.isEmpty) {
      return;
    }
    if (nextName == category.name.trim()) {
      return;
    }

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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
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

    messenger.showSnackBar(
      const SnackBar(content: Text('Nom de catégorie mis à jour.')),
    );
  }

  Future<void> _handleReparentCategory(
    BuildContext context,
    CatalogCategory category, {
    required List<CatalogCategory> allCategories,
    required List<CatalogCategory> directChildren,
  }) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null) return;

    if (!context.mounted) return;

    final parentCandidates = allCategories
        .where(
          (candidate) =>
              candidate.id != category.id &&
              _normalizeParentId(candidate.parentId) == null,
        )
        .toList(growable: false);
    final selectedParentId = await CategoryParentDialog.show(
      context,
      category: category,
      parentCandidates: parentCandidates,
      initialParentId: _normalizeParentId(category.parentId) ?? '',
    );
    if (!context.mounted || selectedParentId == null) {
      return;
    }

    final nextParentId = selectedParentId.isEmpty ? null : selectedParentId;
    final currentParentId = _normalizeParentId(category.parentId);
    if (nextParentId == currentParentId) {
      return;
    }

    if (directChildren.isNotEmpty && nextParentId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Rattachez d’abord ses sous-catégories avant de déplacer cette catégorie.',
          ),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'categories',
        recordId: category.id,
        data: {
          'parent': nextParentId,
          if (category.slug?.trim().isNotEmpty == true)
            'slug': category.slug!.trim(),
        },
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du rattachement: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    ref
        .read(catalogInvalidatorProvider)
        .applyFromWidget(
          ref,
          invalidationsForAdminSave(
            collection: 'categories',
            recordId: category.id,
            data: {
              'parent': nextParentId,
              if (category.slug?.trim().isNotEmpty == true)
                'slug': category.slug!.trim(),
            },
          ),
        );

    if (mounted) {
      setState(() {
        _didResolveInitialLevel = true;
        _activeParentId = nextParentId;
      });
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Catégorie rattachée.')),
    );
  }

  Future<void> _handleToggleCategoryHidden(
    BuildContext context,
    CatalogCategory category,
  ) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null) return;

    if (!context.mounted) return;

    final nextHidden = !category.isHidden;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(saveAdminRecordProvider)(
        baseUrl: ref.read(apiBaseUrlProvider),
        authToken: token,
        collection: 'categories',
        recordId: category.id,
        data: {
          'isHidden': nextHidden,
          if (category.slug?.trim().isNotEmpty == true)
            'slug': category.slug!.trim(),
        },
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du masquage: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    ref
        .read(catalogInvalidatorProvider)
        .applyFromWidget(
          ref,
          invalidationsForAdminSave(
            collection: 'categories',
            recordId: category.id,
            data: {
              'isHidden': nextHidden,
              if (category.slug?.trim().isNotEmpty == true)
                'slug': category.slug!.trim(),
            },
          ),
        );

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          nextHidden ? 'Catégorie masquée.' : 'Catégorie réaffichée.',
        ),
      ),
    );
  }

  Future<void> _handleMoveCategory(
    BuildContext context, {
    required List<CatalogCategory> siblings,
    required CatalogCategory draggedCategory,
    required CatalogCategory targetCategory,
  }) async {
    final reordered = reorderCategories(
      siblings,
      draggedCategoryId: draggedCategory.id,
      targetCategoryId: targetCategory.id,
    );
    if (identical(reordered, siblings)) {
      return;
    }

    final token = await ensureAdminToken(context, ref);
    if (token == null) return;

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await Future.wait([
        for (var index = 0; index < reordered.length; index++)
          if (reordered[index].position != categoryPositionForIndex(index))
            ref.read(saveAdminRecordProvider)(
              baseUrl: ref.read(apiBaseUrlProvider),
              authToken: token,
              collection: 'categories',
              recordId: reordered[index].id,
              data: {'position': categoryPositionForIndex(index)},
            ),
      ]);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors du changement d’ordre: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    ref.read(catalogInvalidatorProvider).applyFromWidget(ref, const [
      CategoryTreeInvalidation(),
      DrawerNavigationInvalidation(),
    ]);

    messenger.showSnackBar(
      const SnackBar(content: Text('Ordre des catégories mis à jour.')),
    );
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    CatalogCategory category, {
    required List<CatalogCategory> directChildren,
  }) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null) return;

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la catégorie'),
        content: Text(
          directChildren.isEmpty
              ? 'Cette action supprimera “${category.name}”.'
              : 'Cette action supprimera “${category.name}” et replacera ses sous-catégories à la racine.',
        ),
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
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
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
      setState(() {
        if (_activeParentId == category.id) {
          _activeParentId = null;
        }
        _didResolveInitialLevel = true;
      });
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Catégorie supprimée.')),
    );
  }
}
