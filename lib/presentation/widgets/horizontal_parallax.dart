import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Horizontal parallax for a child laid out inside a horizontally-scrolling
/// [Scrollable] (typically a `PageView` of feature cards).
///
/// Adapted from the vertical list parallax used in the PlayStation games demo:
/// instead of panning the background as the item travels *up* a vertical list,
/// this pans it *sideways* as the item travels across the horizontal viewport,
/// so a swipeable card reveals a slightly different crop of its image depending
/// on where it sits between the screen edges.
///
/// The effect is driven entirely at paint time. The render object subscribes to
/// the [Scrollable]'s [ScrollPosition] and calls `markNeedsPaint` on every
/// scroll tick — never `markNeedsLayout` or a rebuild — so the pan stays cheap
/// and the subtree repaints in isolation behind its own [RepaintBoundary].
///
/// The [child] is laid out wider than the box by [overscan] and is expected to
/// fill that oversized rect (e.g. an `Image` with `BoxFit.cover`). That extra
/// width is the slack the image slides within: with no overscan there is
/// nothing to pan. `(overscan - 1)` is the total horizontal travel as a
/// fraction of the box width, split between the two edges.
class HorizontalParallax extends SingleChildRenderObjectWidget {
  HorizontalParallax({
    super.key,
    required this.scrollable,
    required Widget child,
    this.overscan = 1.3,
  }) : assert(overscan >= 1, 'overscan must be >= 1 to leave room to pan'),
       super(child: RepaintBoundary.wrap(child, 0));

  /// The horizontal scrollable whose position drives the pan. Pass
  /// `Scrollable.of(context)` from inside a page/list item.
  final ScrollableState scrollable;

  /// How much wider than the box the child is rendered. `1.3` means the image
  /// is 30% wider than the card, giving 15% of slack on each side.
  final double overscan;

  @override
  RenderHorizontalParallax createRenderObject(BuildContext context) {
    return RenderHorizontalParallax(
      scrollable: scrollable.context,
      listenable: scrollable.position,
      overscan: overscan,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHorizontalParallax renderObject,
  ) {
    renderObject
      ..scrollable = scrollable.context
      ..listenable = scrollable.position
      ..overscan = overscan;
  }
}

class RenderHorizontalParallax extends RenderProxyBox {
  RenderHorizontalParallax({
    required BuildContext scrollable,
    required ScrollPosition listenable,
    required double overscan,
  }) : _scrollable = scrollable,
       _listenable = listenable,
       _overscan = overscan;

  BuildContext get scrollable => _scrollable;
  BuildContext _scrollable;
  set scrollable(BuildContext scrollable) {
    if (_scrollable == scrollable) return;

    _scrollable = scrollable;

    markNeedsPaint();
  }

  ScrollPosition get listenable => _listenable;
  ScrollPosition _listenable;
  set listenable(ScrollPosition listenable) {
    if (_listenable == listenable) return;

    final oldListenable = _listenable;
    _listenable = listenable;

    if (attached) {
      oldListenable.removeListener(markNeedsPaint);
      _listenable.addListener(markNeedsPaint);
    }
  }

  double get overscan => _overscan;
  double _overscan;
  set overscan(double overscan) {
    if (_overscan == overscan) return;

    _overscan = overscan;

    markNeedsLayout();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listenable.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _listenable.removeListener(markNeedsPaint);
    super.detach();
  }

  Size _getSize(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid(), 'Constraints must be valid');
    return constraints.constrain(constraints.biggest);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _getSize(constraints);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = _getSize(constraints);
      return;
    }

    size = _getSize(constraints);

    // Render the child wider than the box (cross-axis kept tight) so there is
    // horizontal slack to pan within. The child is expected to cover this rect.
    final innerConstraints = BoxConstraints.tightFor(
      width: size.width * _overscan,
      height: size.height,
    );

    child.layout(innerConstraints, parentUsesSize: true);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      return;
    }

    final scrollableBox = _scrollable.findRenderObject()! as RenderBox;

    // Horizontal position of this item's centre within the viewport.
    final listItemOffset = localToGlobal(
      size.topCenter(Offset.zero),
      ancestor: scrollableBox,
    );

    // Fraction across the viewport: 0.0 at the left edge, 1.0 at the right.
    final viewportDimension = _listenable.viewportDimension;
    final scrollFraction = (listItemOffset.dx / viewportDimension).clamp(
      0.0,
      1.0,
    );

    // Map the fraction to a horizontal alignment (-1 left .. 1 right) and
    // inscribe the oversized child into the box to get its pixel offset.
    final horizontalAlignment = Alignment(scrollFraction * 2 - 1, 0);
    final childRect = horizontalAlignment.inscribe(
      child.size,
      Offset.zero & size,
    );

    final transform = Transform.translate(
      offset: Offset(childRect.left, 0),
    ).transform;

    // Clip to our own bounds. The oversized child is painted outside the box by
    // the translate, and ancestors that clip only on detected layout overflow
    // (e.g. Stack) won't catch it, so the image would bleed past the card.
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      clipContext,
      clipOffset,
    ) {
      clipContext.pushTransform(
        needsCompositing,
        clipOffset,
        transform,
        super.paint,
      );
    });
  }
}
