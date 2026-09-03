import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Vertical parallax for a child laid out inside a vertically-scrolling
/// [Scrollable] (e.g. the landing feed's `ListView`).
///
/// Ported from the PlayStation games demo list parallax: as the item travels up
/// the viewport the background pans within its window, so a fixed-size banner
/// reveals a slightly different crop of its image depending on where it sits
/// between the top and bottom edges.
///
/// The effect is driven entirely at paint time. The render object subscribes to
/// the [Scrollable]'s [ScrollPosition] and calls `markNeedsPaint` on every
/// scroll tick — never `markNeedsLayout` or a rebuild — so the pan stays cheap
/// and the subtree repaints in isolation behind its own [RepaintBoundary].
///
/// The [child] is laid out taller than the box by [overscan] and is expected to
/// fill that oversized rect (e.g. an image with `BoxFit.cover`). That extra
/// height is the slack the image slides within: with no overscan there is
/// nothing to pan. `(overscan - 1)` is the total vertical travel as a fraction
/// of the box height, split between the two edges. Overflow is clipped by the
/// caller (this widget does not clip).
class VerticalParallax extends SingleChildRenderObjectWidget {
  VerticalParallax({
    super.key,
    required this.scrollable,
    required Widget child,
    this.overscan = 1.2,
  }) : assert(overscan >= 1, 'overscan must be >= 1 to leave room to pan'),
       super(child: RepaintBoundary.wrap(child, 0));

  /// The vertical scrollable whose position drives the pan. Pass
  /// `Scrollable.of(context)` from inside a list item.
  final ScrollableState scrollable;

  /// How much taller than the box the child is rendered. `1.2` means the image
  /// is 20% taller than the banner, giving 10% of slack on each side.
  final double overscan;

  @override
  RenderVerticalParallax createRenderObject(BuildContext context) {
    return RenderVerticalParallax(
      scrollable: scrollable.context,
      listenable: scrollable.position,
      overscan: overscan,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderVerticalParallax renderObject,
  ) {
    renderObject
      ..scrollable = scrollable.context
      ..listenable = scrollable.position
      ..overscan = overscan;
  }
}

class RenderVerticalParallax extends RenderProxyBox {
  RenderVerticalParallax({
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

    // Render the child taller than the box (cross-axis kept tight) so there is
    // vertical slack to pan within. The child is expected to cover this rect.
    final innerConstraints = BoxConstraints.tightFor(
      width: size.width,
      height: size.height * _overscan,
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

    // Vertical position of this item's centre within the viewport.
    final listItemOffset = localToGlobal(
      size.centerLeft(Offset.zero),
      ancestor: scrollableBox,
    );

    // Fraction down the viewport: 0.0 at the top edge, 1.0 at the bottom.
    final viewportDimension = _listenable.viewportDimension;
    final scrollFraction = (listItemOffset.dy / viewportDimension).clamp(
      0.0,
      1.0,
    );

    // Map the fraction to a vertical alignment (-1 top .. 1 bottom) and inscribe
    // the oversized child into the box to get its pixel offset.
    final verticalAlignment = Alignment(0, scrollFraction * 2 - 1);
    final childRect = verticalAlignment.inscribe(
      child.size,
      Offset.zero & size,
    );

    final transform = Transform.translate(
      offset: Offset(0, childRect.top),
    ).transform;

    // Clip to our own bounds. The oversized child is painted outside the box by
    // the translate, and ancestors that clip only on detected layout overflow
    // (e.g. Stack) won't catch it, so the image would bleed past the banner.
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
