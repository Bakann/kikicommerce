import 'package:flutter/material.dart';

import '../../../core/constants.dart';

enum DrawerLevelTransitionDirection { forward, back }

/// Uses the same horizontal relationship as a PageView between drawer levels.
class DrawerLevelTransitionSwitcher extends StatelessWidget {
  final Object levelKey;
  final DrawerLevelTransitionDirection direction;
  final Widget child;

  const DrawerLevelTransitionSwitcher({
    super.key,
    required this.levelKey,
    required this.direction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final keyedChild = KeyedSubtree(key: ValueKey(levelKey), child: child);
    if (MediaQuery.disableAnimationsOf(context)) {
      return keyedChild;
    }

    final currentKey = keyedChild.key;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (currentChild, previousChildren) {
          final children = <Widget>[...previousChildren];
          if (currentChild != null) {
            children.add(currentChild);
          }
          return Stack(alignment: Alignment.topLeft, children: children);
        },
        transitionBuilder: (switcherChild, animation) {
          final isIncoming = switcherChild.key == currentKey;
          final directionSign =
              direction == DrawerLevelTransitionDirection.forward ? 1.0 : -1.0;
          final offsetSign = isIncoming ? directionSign : -directionSign;
          final slideAnimation = Tween<Offset>(
            begin: Offset(offsetSign, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeInOutCubic)).animate(animation);

          return SlideTransition(
            position: slideAnimation,
            child: switcherChild,
          );
        },
        child: keyedChild,
      ),
    );
  }
}

/// Pill badge marking a hidden navigation entry. Shared by the category and
/// managed drawers, which previously each kept an identical private copy.
class DrawerHiddenBadge extends StatelessWidget {
  const DrawerHiddenBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          'Masqué',
          style: TextStyle(
            fontFamily: kDrawerFontFamily,
            color: kDrawerMutedColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Back navigation row ("‹ label") used at the top of a nested drawer level.
/// Shared by the category and managed drawers.
class DrawerBackTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const DrawerBackTile({required this.label, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    // Transparent Material: the Drawer's white backgroundColor introduces a
    // ColoredBox ancestor that would hide ListTile ink splashes; a transparent
    // Material restores them.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding: EdgeInsets.zero,
        dense: true,
        visualDensity: kDrawerTileDensity,
        leading: const Icon(Icons.chevron_left, color: kDrawerChrome, size: 23),
        title: Text(
          label,
          style: const TextStyle(
            fontFamily: kDrawerFontFamily,
            color: kDrawerChrome,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Drawer entry title row: the label, dimmed and badged when hidden. Shared by
/// the category and managed drawers.
class DrawerTileTitle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isHidden;

  const DrawerTileTitle({
    required this.label,
    required this.isSelected,
    required this.isHidden,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kDrawerFontFamily,
              color: isHidden ? kDrawerMutedColor : kDrawerChrome,
              fontSize: 15.5,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              height: 1.3,
            ),
          ),
        ),
        if (isHidden) ...[
          const SizedBox(width: 4),
          const Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: DrawerHiddenBadge(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Floating drag feedback chip shown while reordering a drawer entry. Shared by
/// the category and managed drawers.
class DrawerDragFeedback extends StatelessWidget {
  final String label;

  const DrawerDragFeedback({required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_indicator, color: kNavyBlue, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kDrawerFontFamily,
                  color: kDrawerChrome,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
