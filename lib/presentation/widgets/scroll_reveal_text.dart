import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Text that progressively turns bold as it scrolls through the viewport.
///
/// Inspired by the Dior Beauty PDP description: the text is split into
/// grapheme clusters and the active prefix becomes bold one character at a
/// time, from left to right, as scroll progress advances from 0 to 1.
///
/// Falls back to a plain [Text] in [baseWeight] when there is no
/// enclosing [Scrollable].
///
/// Implementation note: the text is pre-split by grapheme cluster so accents,
/// emoji and composed characters are not broken. At paint time the active range
/// is contiguous, so the widget renders two text runs instead of rebuilding
/// thousands of per-character spans every scroll frame. We additionally short
/// circuit the rebuild path when the active character count would not change
/// for the new scroll position — most scroll frames carry sub-pixel motion
/// that does not cross a character boundary.
class ScrollRevealText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final FontWeight baseWeight;
  final FontWeight emphasisWeight;

  /// Extra viewport travel added to the reveal distance.
  ///
  /// A value below 1 keeps the effect readable on product descriptions: the
  /// text does not become fully bold as soon as the whole paragraph is visible,
  /// but it still completes before the block has left the viewport.
  final double scrollDistanceViewportFraction;

  const ScrollRevealText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.baseWeight = FontWeight.w400,
    this.emphasisWeight = FontWeight.w700,
    this.scrollDistanceViewportFraction = 0.85,
  });

  @override
  State<ScrollRevealText> createState() => ScrollRevealTextState();
}

class ScrollRevealTextState extends State<ScrollRevealText> {
  ScrollPosition? _position;
  bool _frameScheduled = false;
  List<int> _clusterEndOffsets = const [];
  int _activeCount = 0;

  @visibleForTesting
  int debugBuildCount = 0;

  @override
  void initState() {
    super.initState();
    _splitText();
  }

  @override
  void didUpdateWidget(covariant ScrollRevealText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _splitText();
      _activeCount = _activeCount.clamp(0, _clusterEndOffsets.length);
    }
    // activeCount is cached in state, so any input that can affect either the
    // total character count or the laid-out height of the block has to
    // re-trigger the post-frame recompute. Scroll position is handled by the
    // attached listener; everything else has to be invalidated explicitly.
    // Style/weight/textAlign matter because they change the wrapped height of
    // the paragraph, which feeds back into progress via boundsHeight.
    final shouldRecompute =
        widget.text != oldWidget.text ||
        widget.style != oldWidget.style ||
        widget.textAlign != oldWidget.textAlign ||
        widget.baseWeight != oldWidget.baseWeight ||
        widget.emphasisWeight != oldWidget.emphasisWeight ||
        widget.scrollDistanceViewportFraction !=
            oldWidget.scrollDistanceViewportFraction;
    if (shouldRecompute) {
      _scheduleFrameUpdate();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != _position) {
      _position?.removeListener(_scheduleFrameUpdate);
      _position = next;
      _position?.addListener(_scheduleFrameUpdate);
    }
    // Always recompute on dependency change — viewport size, font scale, or
    // disableAnimations may have flipped without the scroll position moving.
    _scheduleFrameUpdate();
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleFrameUpdate);
    super.dispose();
  }

  void _splitText() {
    var offset = 0;
    _clusterEndOffsets = [
      for (final cluster in widget.text.characters) offset += cluster.length,
    ];
  }

  void _scheduleFrameUpdate() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    // Use a post-frame callback so the active count is computed after the
    // viewport has laid out and painted the new scroll position. Reading
    // localToGlobal during the transient phase (before layout) can return
    // a stale position when the sliver hasn't been re-positioned yet, which
    // would either bail out incorrectly or trigger a useless extra rebuild.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      _maybeUpdateActiveCount();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Recomputes the prefix length from the current scroll position and only
  /// triggers a rebuild when the visible state would actually change.
  ///
  /// Most scroll listener fires move the block by less than a character width,
  /// so calling [setState] on each tick would re-flow [Text.rich] for no
  /// visible difference. Computing the next count here keeps the widget tree
  /// idle for those sub-character ticks.
  void _maybeUpdateActiveCount() {
    if (!mounted) return;
    final next = _computeCurrentActiveCount();
    if (next == _activeCount) return;
    setState(() {
      _activeCount = next;
    });
  }

  int _computeCurrentActiveCount() {
    if (_clusterEndOffsets.isEmpty) {
      return 0;
    }
    if (_position == null) {
      return _clusterEndOffsets.length;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      return _clusterEndOffsets.length;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return _activeCount;
    }
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final globalTop = box.localToGlobal(Offset.zero).dy;
    final boundsHeight = box.size.height;
    final progress = computeScrollReadProgress(
      globalTop: globalTop,
      viewportHeight: viewportHeight,
      boundsHeight: boundsHeight,
      scrollDistanceViewportFraction: widget.scrollDistanceViewportFraction,
    );
    return computeActiveCharacterCount(
      progress: progress,
      totalCharacters: _clusterEndOffsets.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      debugBuildCount++;
      return true;
    }());
    final defaultStyle = DefaultTextStyle.of(context).style;
    final merged = defaultStyle.merge(widget.style);
    final baseStyle = merged.copyWith(fontWeight: widget.baseWeight);
    final emphasisStyle = merged.copyWith(fontWeight: widget.emphasisWeight);

    if (_position == null) {
      return Text(widget.text, style: baseStyle, textAlign: widget.textAlign);
    }

    return Text.rich(
      _buildTextSpan(
        activeCount: _activeCount,
        baseStyle: baseStyle,
        emphasisStyle: emphasisStyle,
      ),
      textAlign: widget.textAlign,
      semanticsLabel: widget.text,
    );
  }

  TextSpan _buildTextSpan({
    required int activeCount,
    required TextStyle baseStyle,
    required TextStyle emphasisStyle,
  }) {
    if (widget.text.isEmpty) {
      return TextSpan(text: widget.text, style: baseStyle);
    }
    final safeActiveCount = activeCount.clamp(0, _clusterEndOffsets.length);
    if (safeActiveCount == 0) {
      return TextSpan(text: widget.text, style: baseStyle);
    }
    if (safeActiveCount == _clusterEndOffsets.length) {
      return TextSpan(text: widget.text, style: emphasisStyle);
    }

    final splitOffset = _clusterEndOffsets[safeActiveCount - 1];
    return TextSpan(
      children: [
        TextSpan(
          text: widget.text.substring(0, splitOffset),
          style: emphasisStyle,
        ),
        TextSpan(text: widget.text.substring(splitOffset), style: baseStyle),
      ],
    );
  }
}

/// Maps the description block into a 0 → 1 reading progress.
///
/// This is the Flutter equivalent of:
/// `(scrollY - elementTop + viewportHeight) / revealDistance`.
double computeScrollReadProgress({
  required double globalTop,
  required double viewportHeight,
  required double boundsHeight,
  double scrollDistanceViewportFraction = 0.85,
}) {
  final height = boundsHeight > 0 ? boundsHeight : 1.0;
  final extraDistance =
      viewportHeight * scrollDistanceViewportFraction.clamp(0.0, 4.0);
  final revealDistance = height + extraDistance;
  return ((viewportHeight - globalTop) / revealDistance).clamp(0.0, 1.0);
}

int computeActiveCharacterCount({
  required double progress,
  required int totalCharacters,
}) {
  if (totalCharacters <= 0) {
    return 0;
  }
  final clampedProgress = progress.clamp(0.0, 1.0);
  return (clampedProgress * totalCharacters).floor().clamp(0, totalCharacters);
}
