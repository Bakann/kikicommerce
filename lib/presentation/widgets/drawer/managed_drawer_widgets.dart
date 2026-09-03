import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/catalog_routes.dart';
import '../../../application/navigation/drawer_editorial_tiles.dart';
import '../../../application/navigation/drawer_navigation_models.dart';
import '../../../core/constants.dart';
import '../kiki_image.dart';
import '../storefront_layout.dart';
import 'drawer_shared_widgets.dart';

class DesktopLevelColumn extends StatelessWidget {
  final DrawerLevelVm levelVm;
  final bool isEditMode;
  final VoidCallback? onAddChild;
  final ValueChanged<DrawerItemVm> onItemTap;
  final ValueChanged<DrawerItemVm> onEditItem;
  final ValueChanged<DrawerItemVm> onDeleteItem;
  final ValueChanged<DrawerItemVm> onToggleHiddenItem;
  final void Function(
    List<DrawerItemVm> siblings,
    DrawerItemVm draggedItem,
    DrawerItemVm targetItem,
  )
  onReorderItem;

  const DesktopLevelColumn({
    super.key,
    required this.levelVm,
    required this.isEditMode,
    required this.onItemTap,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onToggleHiddenItem,
    required this.onReorderItem,
    this.onAddChild,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
          child: Text(
            levelVm.title,
            style: const TextStyle(
              fontFamily: kDrawerFontFamily,
              color: kDrawerChrome,
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
        if (isEditMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ActionTile(
              icon: Icons.add,
              label: 'Nouvel item',
              onTap: onAddChild,
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            children: [
              for (var index = 0; index < levelVm.navItems.length; index++) ...[
                Builder(
                  builder: (_) {
                    final item = levelVm.navItems[index];
                    return ManagedDrawerTile(
                      label: item.label,
                      isSelected: item.isCurrentCategory,
                      showDisclosure: false,
                      isEditMode: isEditMode,
                      isHidden: item.node.item.isHidden,
                      reorderItem: isEditMode ? item.node.item : null,
                      reorderGroup: '${levelVm.rootId}:nav',
                      onTap: () => onItemTap(item),
                      onEdit: isEditMode ? () => onEditItem(item) : null,
                      onDelete: isEditMode ? () => onDeleteItem(item) : null,
                      onToggleHidden: isEditMode
                          ? () => onToggleHiddenItem(item)
                          : null,
                      onReorderAccepted: isEditMode
                          ? (draggedItem) {
                              final draggedVm = levelVm.navItems.firstWhere(
                                (candidate) =>
                                    candidate.node.item.id == draggedItem.id,
                              );
                              onReorderItem(levelVm.navItems, draggedVm, item);
                            }
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 2),
              ],
              if (levelVm.promoTextItems.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
                  child: Text(
                    'Highlights',
                    style: const TextStyle(
                      fontFamily: kDrawerFontFamily,
                      color: kDrawerMutedColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                for (
                  var index = 0;
                  index < levelVm.promoTextItems.length;
                  index++
                ) ...[
                  Builder(
                    builder: (_) {
                      final item = levelVm.promoTextItems[index];
                      return ManagedDrawerTile(
                        label: item.label,
                        isSelected: false,
                        showDisclosure: false,
                        isEditMode: isEditMode,
                        isHidden: item.node.item.isHidden,
                        reorderItem: isEditMode ? item.node.item : null,
                        reorderGroup: '${levelVm.rootId}:promo',
                        onTap: () => onItemTap(item),
                        onEdit: isEditMode ? () => onEditItem(item) : null,
                        onDelete: isEditMode ? () => onDeleteItem(item) : null,
                        onToggleHidden: isEditMode
                            ? () => onToggleHiddenItem(item)
                            : null,
                        onReorderAccepted: isEditMode
                            ? (draggedItem) {
                                final draggedVm = levelVm.promoTextItems
                                    .firstWhere(
                                      (candidate) =>
                                          candidate.node.item.id ==
                                          draggedItem.id,
                                    );
                                onReorderItem(
                                  levelVm.promoTextItems,
                                  draggedVm,
                                  item,
                                );
                              }
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class DesktopPromoPanel extends StatelessWidget {
  final List<DrawerPromoVm> cards;
  final ValueChanged<DrawerPromoVm> onTap;

  const DesktopPromoPanel({
    super.key,
    required this.cards,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.length == 1) {
      return _DrawerPromoCard(
        card: cards.first,
        onTap: () => onTap(cards.first),
      );
    }

    return GridView.builder(
      itemCount: cards.length,
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cards.length > 2 ? 2 : 1,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: cards.length > 2 ? 0.78 : 0.88,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        return _DrawerPromoCard(card: card, onTap: () => onTap(card));
      },
    );
  }
}

class DrawerVisualPanel extends StatelessWidget {
  final DrawerLevelVm levelVm;
  final bool isDesktop;
  final ValueChanged<DrawerPromoVm> onLegacyCardTap;
  final ValueChanged<DrawerEditorialTile> onEditorialTileTap;

  const DrawerVisualPanel({
    super.key,
    required this.levelVm,
    required this.isDesktop,
    required this.onLegacyCardTap,
    required this.onEditorialTileTap,
  });

  @override
  Widget build(BuildContext context) {
    final editorialTiles = levelVm.editorialTiles;
    if (editorialTiles != null && editorialTiles.hasActiveItems) {
      return DrawerEditorialTilesPreview(
        config: editorialTiles,
        isDesktop: isDesktop,
        onTap: onEditorialTileTap,
      );
    }

    return LegacyPromoPanel(
      cards: levelVm.promoCards,
      isDesktop: isDesktop,
      onTap: onLegacyCardTap,
    );
  }
}

class LegacyPromoPanel extends StatelessWidget {
  final List<DrawerPromoVm> cards;
  final bool isDesktop;
  final ValueChanged<DrawerPromoVm> onTap;

  const LegacyPromoPanel({
    super.key,
    required this.cards,
    required this.isDesktop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return DesktopPromoPanel(cards: cards, onTap: onTap);
    }

    return Column(
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          AspectRatio(
            aspectRatio: cards.length == 1 ? 0.78 : 1.18,
            child: _DrawerPromoCard(
              card: cards[index],
              onTap: () => onTap(cards[index]),
            ),
          ),
          if (index < cards.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class DrawerEditorialTilesPreview extends StatelessWidget {
  final DrawerEditorialTilesConfig config;
  final bool isDesktop;
  final ValueChanged<DrawerEditorialTile> onTap;

  const DrawerEditorialTilesPreview({
    super.key,
    required this.config,
    required this.isDesktop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final layout = config.resolvedLayout;
    final tiles = _tilesForLayout(config.activeTiles, layout);
    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    if (layout == DrawerEditorialTilesResolvedLayout.single ||
        tiles.length == 1) {
      return _DrawerEditorialTileCard(
        tile: tiles.first,
        onTap: () => onTap(tiles.first),
        aspectRatio: isDesktop ? null : 0.78,
      );
    }

    if (isDesktop && layout == DrawerEditorialTilesResolvedLayout.stacked) {
      return Column(
        children: [
          for (var index = 0; index < tiles.length; index++) ...[
            Expanded(
              child: _DrawerEditorialTileCard(
                tile: tiles[index],
                onTap: () => onTap(tiles[index]),
              ),
            ),
            if (index < tiles.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }

    final crossAxisCount = isDesktop ? 2 : 1;
    final childAspectRatio = isDesktop ? 0.78 : 1.18;
    return GridView.builder(
      itemCount: tiles.length,
      shrinkWrap: !isDesktop,
      physics: isDesktop
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final tile = tiles[index];
        return _DrawerEditorialTileCard(tile: tile, onTap: () => onTap(tile));
      },
    );
  }

  List<DrawerEditorialTile> _tilesForLayout(
    List<DrawerEditorialTile> tiles,
    DrawerEditorialTilesResolvedLayout layout,
  ) {
    return switch (layout) {
      DrawerEditorialTilesResolvedLayout.single => tiles.take(1).toList(),
      DrawerEditorialTilesResolvedLayout.stacked => tiles.take(2).toList(),
      DrawerEditorialTilesResolvedLayout.grid2x2 => tiles.take(4).toList(),
      DrawerEditorialTilesResolvedLayout.adaptive => tiles,
    };
  }
}

class _DrawerEditorialTileCard extends StatelessWidget {
  final DrawerEditorialTile tile;
  final VoidCallback onTap;
  final double? aspectRatio;

  const _DrawerEditorialTileCard({
    required this.tile,
    required this.onTap,
    this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final card = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            KikiImage(
              imageUrl: tile.media.thumbUrl(size: '900x1200f'),
              fit: BoxFit.cover,
              errorWidget: const ColoredBox(
                color: Color(0xFFF3F0EB),
                child: Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Color(0xFF7A7A7A),
                  ),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.55, 1],
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tile.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 74,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (aspectRatio == null) {
      return card;
    }

    return AspectRatio(aspectRatio: aspectRatio!, child: card);
  }
}

class _DrawerPromoCard extends StatelessWidget {
  final DrawerPromoVm card;
  final VoidCallback onTap;

  const _DrawerPromoCard({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: card.action.isNavigable ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            KikiImage(
              imageUrl: card.imageUrl,
              fit: BoxFit.cover,
              errorWidget: const ColoredBox(
                color: Color(0xFFF3F0EB),
                child: Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Color(0xFF7A7A7A),
                  ),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.55, 1],
                  colors: [Colors.transparent, Color(0xCC000000)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      card.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 74,
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DrawerTileAction { toggleHidden }

class _DrawerReorderPayload {
  final DrawerNavigationItemData item;
  final String group;

  const _DrawerReorderPayload({required this.item, required this.group});
}

class ManagedDrawerTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool showDisclosure;
  final bool isEditMode;
  final bool isHidden;
  final DrawerNavigationItemData? reorderItem;
  final String? reorderGroup;
  final VoidCallback onTap;
  final VoidCallback? onHoverActivate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddChild;
  final VoidCallback? onToggleHidden;
  final ValueChanged<DrawerNavigationItemData>? onReorderAccepted;

  const ManagedDrawerTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.showDisclosure,
    required this.isEditMode,
    required this.onTap,
    this.isHidden = false,
    this.reorderItem,
    this.reorderGroup,
    this.onHoverActivate,
    this.onEdit,
    this.onDelete,
    this.onAddChild,
    this.onToggleHidden,
    this.onReorderAccepted,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus && onHoverActivate != null) {
          onHoverActivate!();
        }
      },
      child: MouseRegion(
        onEnter: (_) => onHoverActivate?.call(),
        // Transparent Material so ListTile ink splashes paint on top of the
        // Drawer's white ColoredBox ancestor (Flutter 3.44 assertion).
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            selected: isSelected,
            selectedTileColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: kDrawerTileDensity,
            leading: _buildDragHandle(context),
            title: Opacity(
              opacity: isHidden ? 0.58 : 1,
              child: DrawerTileTitle(
                label: label,
                isSelected: isSelected,
                isHidden: isHidden,
              ),
            ),
            trailing: _buildTrailing(),
            onTap: onTap,
          ),
        ),
      ),
    );

    final reorderItem = this.reorderItem;
    final reorderGroup = this.reorderGroup;
    final onReorderAccepted = this.onReorderAccepted;
    if (reorderItem == null ||
        reorderGroup == null ||
        onReorderAccepted == null) {
      return tile;
    }

    return DragTarget<_DrawerReorderPayload>(
      onWillAcceptWithDetails: (details) {
        return details.data.group == reorderGroup &&
            details.data.item.id != reorderItem.id;
      },
      onAcceptWithDetails: (details) => onReorderAccepted(details.data.item),
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
    final reorderItem = this.reorderItem;
    final reorderGroup = this.reorderGroup;
    if (!isEditMode || reorderItem == null || reorderGroup == null) {
      return null;
    }

    final payload = _DrawerReorderPayload(
      item: reorderItem,
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
    final feedback = DrawerDragFeedback(label: label);
    final isDesktop = StorefrontLayout.isDesktop(
      MediaQuery.sizeOf(context).width,
    );

    if (kIsWeb || isDesktop) {
      return Draggable<_DrawerReorderPayload>(
        data: payload,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.35, child: handle),
        child: handle,
      );
    }

    return LongPressDraggable<_DrawerReorderPayload>(
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

    final actions = <Widget>[];
    if (showDisclosure) {
      actions.add(
        const Icon(Icons.chevron_right, color: kDrawerChrome, size: 24),
      );
    }

    if (isEditMode) {
      actions.add(
        IconButton(
          tooltip: 'Modifier',
          visualDensity: VisualDensity.compact,
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, color: kNavyBlue),
        ),
      );
      if (onAddChild != null) {
        actions.add(
          IconButton(
            tooltip: 'Ajouter un enfant',
            visualDensity: VisualDensity.compact,
            onPressed: onAddChild,
            icon: const Icon(Icons.add, color: kNavyBlue),
          ),
        );
      }
      if (onDelete != null) {
        actions.add(
          IconButton(
            tooltip: 'Supprimer',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: kNavyBlue),
          ),
        );
      }
      if (onToggleHidden != null) {
        actions.add(
          PopupMenuButton<_DrawerTileAction>(
            tooltip: 'Actions navigation',
            icon: const Icon(Icons.more_vert, color: kNavyBlue),
            onSelected: (action) {
              switch (action) {
                case _DrawerTileAction.toggleHidden:
                  onToggleHidden?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_DrawerTileAction>(
                value: _DrawerTileAction.toggleHidden,
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
            ],
          ),
        );
      }
    }

    if (actions.isEmpty) {
      return null;
    }

    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Transparent Material: see DrawerCategoryTile for rationale.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: kDrawerTileDensity,
        leading: Icon(icon, color: kDrawerChrome),
        title: Text(
          label,
          style: const TextStyle(
            fontFamily: kDrawerFontFamily,
            color: kDrawerChrome,
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class DrawerLevelVm {
  final String rootId;
  final String title;
  final List<DrawerItemVm> navItems;
  final List<DrawerItemVm> promoTextItems;
  final List<DrawerPromoVm> promoCards;
  final DrawerEditorialTilesConfig? editorialTiles;
  final DrawerItemVm? viewAllItem;

  const DrawerLevelVm({
    required this.rootId,
    required this.title,
    required this.navItems,
    required this.promoTextItems,
    required this.promoCards,
    this.editorialTiles,
    this.viewAllItem,
  });

  bool get hasSecondaryNavigationContent =>
      navItems.isNotEmpty || promoTextItems.isNotEmpty;

  bool get hasVisualPanel =>
      (editorialTiles?.hasActiveItems ?? false) || promoCards.isNotEmpty;
}

class DrawerItemVm {
  final DrawerNavigationNode node;
  final String label;
  final ResolvedDrawerAction action;
  final bool isCurrentCategory;

  const DrawerItemVm({
    required this.node,
    required this.label,
    required this.action,
    required this.isCurrentCategory,
  });
}

class DrawerPromoVm {
  final String id;
  final String label;
  final String imageUrl;
  final ResolvedDrawerAction action;

  const DrawerPromoVm({
    required this.id,
    required this.label,
    required this.imageUrl,
    required this.action,
  });
}

class ResolvedDrawerAction {
  final String? routeName;
  final String? externalUrl;

  /// Whether navigating to [routeName] should push onto the history stack
  /// (instead of replacing it). Category PLP links set this so the PLP back
  /// arrow returns to the page the drawer was opened from, rather than walking
  /// up the catalog hierarchy. Tabs/pages/technical routes keep `go` semantics.
  final bool preserveHistory;

  const ResolvedDrawerAction({
    this.routeName,
    this.externalUrl,
    this.preserveHistory = false,
  });

  bool get isNavigable => routeName != null || externalUrl != null;
}

DrawerLevelVm buildLevelVm(
  DrawerNavigationNode root, {
  required String? currentCategoryId,
  required bool isDesktop,
}) {
  final navItems = <DrawerItemVm>[];
  final promoTextItems = <DrawerItemVm>[];
  final promoCards = <DrawerPromoVm>[];
  final rootAction = resolveAction(root.item);

  for (final child in root.children) {
    final itemVm = DrawerItemVm(
      node: child,
      label: child.item.label,
      action: resolveAction(child.item),
      isCurrentCategory: child.item.categoryId == currentCategoryId,
    );

    if (child.item.placement == DrawerNavigationPlacement.nav) {
      navItems.add(itemVm);
      continue;
    }

    promoTextItems.add(itemVm);
    final media = child.item.promoMedia;
    if (media != null) {
      promoCards.add(
        DrawerPromoVm(
          id: child.item.id,
          label: child.item.label,
          imageUrl: media.listingUrl,
          action: itemVm.action,
        ),
      );
    }
  }

  final template =
      root.item.desktopDrawerTemplate ??
      DrawerNavigationDesktopTemplate.listOnly;
  final editorialTiles = root.item.editorialTiles.hasActiveItems
      ? root.item.editorialTiles
      : null;
  final rootPromoMedia = root.item.promoMedia;
  if (editorialTiles == null &&
      promoCards.isEmpty &&
      rootPromoMedia != null &&
      template != DrawerNavigationDesktopTemplate.listOnly) {
    promoCards.add(
      DrawerPromoVm(
        id: root.item.id,
        label: root.item.label,
        imageUrl: rootPromoMedia.listingUrl,
        action: rootAction,
      ),
    );
  }

  final clippedPromoCards = editorialTiles != null
      ? const <DrawerPromoVm>[]
      : switch (template) {
          DrawerNavigationDesktopTemplate.listOnly => const <DrawerPromoVm>[],
          DrawerNavigationDesktopTemplate.heroSingle =>
            promoCards.take(1).toList(),
          DrawerNavigationDesktopTemplate.promoGrid2x2 =>
            promoCards.take(4).toList(),
          DrawerNavigationDesktopTemplate.promoStack2 =>
            promoCards.take(2).toList(),
        };

  return DrawerLevelVm(
    rootId: root.item.id,
    title: root.item.label,
    navItems: navItems,
    promoTextItems: promoTextItems,
    promoCards: clippedPromoCards,
    editorialTiles: editorialTiles,
    viewAllItem: !isDesktop && rootAction.isNavigable
        ? DrawerItemVm(
            node: root,
            label: 'Voir tout',
            action: rootAction,
            isCurrentCategory: false,
          )
        : null,
  );
}

ResolvedDrawerAction resolveAction(DrawerNavigationItemData item) {
  return switch (item.itemType) {
    DrawerNavigationItemType.category => _catalogAwareAction(
      item.category != null
          ? CatalogRoutes.categoryLocation(item.category!)
          : (item.categoryId == null
                ? null
                : CatalogRoutes.categoryById(item.categoryId!)),
    ),
    DrawerNavigationItemType.product => ResolvedDrawerAction(
      routeName: item.product != null
          ? CatalogRoutes.productById(item.product!.id)
          : (item.productId == null
                ? null
                : CatalogRoutes.productById(item.productId!)),
    ),
    // Page items may resolve to a category PLP (e.g. a "Toutes les chaussures"
    // entry whose pageKey maps to a `/catalog/<slug>` page) or to a technical
    // destination (home/search/admin). Push only for the former.
    DrawerNavigationItemType.page => _catalogAwareAction(
      item.pageKey == null || item.pageKey!.trim().isEmpty
          ? null
          : CatalogRoutes.pageKeyLocation(item.pageKey!),
    ),
    DrawerNavigationItemType.external => ResolvedDrawerAction(
      externalUrl: item.url?.trim().isEmpty == true ? null : item.url,
    ),
    DrawerNavigationItemType.unknown => const ResolvedDrawerAction(),
  };
}

/// Builds a navigable action that preserves history when [routeName] points at
/// a catalog category PLP, so the PLP back arrow returns to the page the drawer
/// was opened from instead of walking up the catalog hierarchy.
ResolvedDrawerAction _catalogAwareAction(String? routeName) {
  return ResolvedDrawerAction(
    routeName: routeName,
    preserveHistory:
        routeName != null && CatalogRoutes.isCategoryPlpLocation(routeName),
  );
}

bool containsCategoryId(DrawerNavigationNode node, String? categoryId) {
  if (categoryId == null || categoryId.isEmpty) {
    return false;
  }

  if (node.item.itemType == DrawerNavigationItemType.category &&
      node.item.categoryId == categoryId) {
    return true;
  }

  for (final child in node.children) {
    if (containsCategoryId(child, categoryId)) {
      return true;
    }
  }

  return false;
}

String? findRootIdForCategory(
  List<DrawerNavigationNode> roots,
  String? categoryId,
) {
  for (final root in roots) {
    if (containsCategoryId(root, categoryId)) {
      return root.item.id;
    }
  }
  return null;
}

String? findParentIdForChildCategory(
  List<DrawerNavigationNode> roots,
  String? categoryId,
) {
  if (categoryId == null || categoryId.isEmpty) {
    return null;
  }

  for (final root in roots) {
    for (final child in root.children) {
      if (containsCategoryId(child, categoryId)) {
        return root.item.id;
      }
    }
  }

  return null;
}

int nextPosition(Iterable<DrawerNavigationItemData> items) {
  var maxPosition = 0;
  for (final item in items) {
    if (item.position > maxPosition) {
      maxPosition = item.position;
    }
  }
  return maxPosition + 10;
}

List<DrawerNavigationItemData> reorderDrawerItems(
  List<DrawerNavigationItemData> items, {
  required String draggedItemId,
  required String targetItemId,
}) {
  final oldIndex = items.indexWhere((item) => item.id == draggedItemId);
  final targetIndex = items.indexWhere((item) => item.id == targetItemId);
  if (oldIndex < 0 || targetIndex < 0 || oldIndex == targetIndex) {
    return items;
  }

  final reordered = [...items];
  final moved = reordered.removeAt(oldIndex);
  reordered.insert(targetIndex, moved);
  return reordered;
}

int drawerPositionForIndex(int index) => (index + 1) * 10;
