import 'package:flutter/material.dart';

/// Visual style for the per-section reveal animation. Each section type on
/// the landing page picks one (see `_CmsHomepageBody`) so the page feels
/// composed rather than monotonous.
///
/// All styles complete in roughly the same wall-clock time so a stagger
/// across sections still reads as a coherent cascade.
enum CmsSectionRevealStyle {
  /// Vertical curtain rising — a top-to-bottom `ClipRect` reveals the
  /// content as a "stage curtain" lifting. Kept for completeness, but
  /// AVOID for full-bleed hero sections (background image + overlays +
  /// gradients): the animated `ClipRect` can paint a transient dark
  /// band mid-scroll. Use [premiumFadeUp] for heroes instead.
  curtain,

  /// Two opaque panels split apart vertically (top half slides up,
  /// bottom half slides down) while the content fades in beneath. Reads
  /// as an editorial/cinematic reveal.
  splitOpen,

  /// Soft slide-up + fade. The default polished e-commerce reveal:
  /// translates from +24px to 0 while opacity goes 0 → 1.
  slideUp,

  /// Each visual band drops in from above (-32px → 0) with a fade.
  /// Pairs well with grid sections so the whole grid feels like it
  /// "settles" into place.
  cascadeFromTop,

  /// Premium e-commerce reveal: opacity-only fade.
  /// No clipping, no overlay panels, no Transform.
  /// Designed as the safest fallback style for full-bleed sections,
  /// although heroes are normally excluded by shouldRevealSection.
  premiumFadeUp,
}

/// Wraps a CMS section with a one-shot reveal animation.
///
/// Animation triggers on `initState`. Because the landing page builds
/// sections through `ListView.builder` (lazy), this means a section only
/// reveals when the list actually mounts it — i.e. when it scrolls into
/// the cache window. No `VisibilityDetector` package needed.
///
/// The optional `delay` parameter lets the caller stagger reveals — pass
/// e.g. `Duration(milliseconds: 80 * index)` for the first few items so
/// the initial viewport feels like a cascade rather than a single bang.
/// Section ids that have already played their reveal this app session. A
/// section animates the first time it is mounted, then jumps straight to its
/// resting state on any later remount. This stops the reveal from replaying —
/// and visibly flickering — every time a tabbed landing (e.g. the Sport
/// Homme/Femme/Enfant segments) rebuilds the incoming page subtree on switch.
final Set<String> _revealedSectionIds = <String>{};

/// Clears the "revealed once" memory. Test-only: keeps widget tests hermetic
/// since [_revealedSectionIds] is process-global.
@visibleForTesting
void resetCmsSectionRevealMemoryForTest() => _revealedSectionIds.clear();

class CmsSectionReveal extends StatefulWidget {
  const CmsSectionReveal({
    super.key,
    required this.child,
    this.revealId,
    this.style = CmsSectionRevealStyle.slideUp,
    this.duration = const Duration(milliseconds: 1200),
    this.delay = Duration.zero,
    this.curtainColor = const Color(0xFF000000),
  });

  final Widget child;

  /// Stable identity for "reveal once" deduplication (typically the CMS
  /// section record id). When null, the section animates on every mount.
  final String? revealId;

  final CmsSectionRevealStyle style;
  final Duration duration;
  final Duration delay;

  /// Background color for the [CmsSectionRevealStyle.splitOpen] panels.
  /// Defaults to the page's near-black background so the panels feel like
  /// part of the canvas rather than a coloured overlay.
  final Color curtainColor;

  @override
  State<CmsSectionReveal> createState() => _CmsSectionRevealState();
}

class _CmsSectionRevealState extends State<CmsSectionReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    // A long-tail ease-out so motion settles softly, like a curtain
    // coming to rest after the lift.
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    final id = widget.revealId;
    if (id != null && _revealedSectionIds.contains(id)) {
      // Already revealed once this session: show the resting state directly so
      // a remount (e.g. switching landing tabs) does not replay the fade.
      _controller.value = 1.0;
      return;
    }
    if (id != null) {
      _revealedSectionIds.add(id);
    }

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final t = _progress.value;
        // Optimization: Once animation is complete, return the child directly.
        // This removes all Transform/Opacity/Stack layers from the tree,
        // ensuring neutral layout and preventing compositing glitches on Web.
        if (t >= 1.0) return child!;

        switch (widget.style) {
          case CmsSectionRevealStyle.slideUp:
            return _slideUp(child!, t);
          case CmsSectionRevealStyle.cascadeFromTop:
            return _cascadeFromTop(child!, t);
          case CmsSectionRevealStyle.curtain:
            return _curtain(child!, t);
          case CmsSectionRevealStyle.splitOpen:
            return _splitOpen(child!, t);
          case CmsSectionRevealStyle.premiumFadeUp:
            return _premiumFadeUp(child!, t);
        }
      },
      child: widget.child,
    );
  }

  Widget _slideUp(Widget child, double t) {
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: child),
    );
  }

  Widget _premiumFadeUp(Widget child, double t) {
    // Premium fade up is strictly an opacity fade, avoiding any Transform
    // or clip that might corrupt platform views (like video).
    return Opacity(opacity: t, child: child);
  }

  Widget _cascadeFromTop(Widget child, double t) {
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * -24),
        child: child,
      ),
    );
  }

  Widget _curtain(Widget child, double t) {
    return ClipRect(
      clipper: _BottomGrowingClipper(progress: t),
      child: Opacity(opacity: Curves.easeIn.transform(t), child: child),
    );
  }

  Widget _splitOpen(Widget child, double t) {
    // Safe version of splitOpen: instead of black panels, we use
    // a subtle vertical scale + fade. This gives the "opening"
    // feeling without the risky large black layers.
    return Opacity(
      opacity: t,
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..setEntry(1, 1, 0.95 + (t * 0.05)),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// Reveals the child top-down: rect grows from `(0, 0, w, h * progress)`.
/// Used by the curtain style.
class _BottomGrowingClipper extends CustomClipper<Rect> {
  _BottomGrowingClipper({required this.progress});
  final double progress;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width, size.height * progress);
  }

  @override
  bool shouldReclip(covariant _BottomGrowingClipper oldClipper) =>
      oldClipper.progress != progress;
}
