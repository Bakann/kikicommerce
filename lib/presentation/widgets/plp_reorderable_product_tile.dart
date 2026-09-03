import 'package:flutter/material.dart';

import '../../domain/catalog/catalog_entities.dart';

class PlpReorderableProductTile extends StatelessWidget {
  final CatalogListingItem item;
  final Widget child;
  final ValueChanged<CatalogListingItem> onAccept;

  const PlpReorderableProductTile({
    super.key,
    required this.item,
    required this.child,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<CatalogListingItem>(
      onWillAcceptWithDetails: (details) => details.data.id != item.id,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateItems, _) {
        final isTargeted = candidateItems.isNotEmpty;

        return _ReorderableProductChrome(
          isTargeted: isTargeted,
          dragHandle: Draggable<CatalogListingItem>(
            data: item,
            feedback: _ProductDragFeedback(label: item.product.name),
            childWhenDragging: const Opacity(
              opacity: 0.35,
              child: _DragHandle(),
            ),
            child: const _DragHandle(),
          ),
          child: child,
        );
      },
    );
  }
}

class _ReorderableProductChrome extends StatelessWidget {
  final bool isTargeted;
  final Widget child;
  final Widget dragHandle;

  const _ReorderableProductChrome({
    required this.isTargeted,
    required this.child,
    required this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (isTargeted)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF1F3D5A), width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
            ),
          ),
        Positioned(top: 8, left: 8, child: dragHandle),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Glisser pour réordonner',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(Icons.drag_indicator, color: Color(0xFF2F2F2C), size: 20),
        ),
      ),
    );
  }
}

class _ProductDragFeedback extends StatelessWidget {
  final String label;

  const _ProductDragFeedback({required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_indicator, color: Color(0xFF2F2F2C)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF2F2F2C),
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
