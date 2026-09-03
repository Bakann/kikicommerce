import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Drives a [SnapDisintegrate] from outside its own subtree.
///
/// The trigger (e.g. a close button) usually lives *inside* the widget being
/// disintegrated, so the effect is started through this controller rather than
/// a `GlobalKey`. Create one in a [State], pass it to [SnapDisintegrate], and
/// call [dismiss] to play the Thanos-style disintegration once. Calls made
/// while it is already running — or before it is attached — are ignored.
class SnapDisintegrateController {
  Future<void> Function()? _onDismiss;

  void _attach(Future<void> Function() onDismiss) => _onDismiss = onDismiss;
  void _detach() => _onDismiss = null;

  /// Plays the disintegration. No-op if unattached or already running.
  void dismiss() => _onDismiss?.call();
}

/// Wraps [child] and, on [SnapDisintegrateController.dismiss], dissolves it into
/// drifting dust before invoking [onDismissed].
///
/// The child is rendered untouched until the effect starts, so it never
/// interferes with entrance animations or layout. When triggered, the child is
/// snapshotted once (`RepaintBoundary.toImage`) and replaced by a same-sized
/// particle field. Each particle is a small tile of the snapshot drawn with
/// `Canvas.drawImageRect` (the most broadly supported draw op — `drawRawAtlas`
/// was avoided because its per-sprite colour variant can stall some mobile GPUs).
class SnapDisintegrate extends StatefulWidget {
  const SnapDisintegrate({
    super.key,
    required this.controller,
    required this.child,
    this.onDismissed,
    this.duration = const Duration(milliseconds: 1100),
    this.cellSize = 12.0,
  });

  final SnapDisintegrateController controller;
  final Widget child;

  /// Called once the dissolve has fully completed (or immediately if reduced
  /// motion is on / the snapshot could not be captured). Typically pops a route.
  final VoidCallback? onDismissed;

  final Duration duration;

  /// Approximate particle size in logical pixels.
  final double cellSize;

  @override
  State<SnapDisintegrate> createState() => _SnapDisintegrateState();
}

class _SnapDisintegrateState extends State<SnapDisintegrate>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _controller;
  _SnapData? _data;
  bool _isDisintegrating = false;
  bool _finished = false;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onStatus);
    widget.controller._attach(_start);
  }

  @override
  void didUpdateWidget(SnapDisintegrate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._detach();
      widget.controller._attach(_start);
    }
    _controller.duration = widget.duration;
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finish();
  }

  /// Calls [SnapDisintegrate.onDismissed] exactly once. Reached from the
  /// animation end, the no-effect fallbacks, or the safety timer — so a tap on
  /// the close button can never leave the route stuck open.
  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDismissed?.call();
  }

  Future<void> _start() async {
    if (_isDisintegrating) return;
    _isDisintegrating = true;

    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null || !mounted) {
      _finish();
      return;
    }

    // Respect reduced motion: skip straight to the real close.
    if (MediaQuery.disableAnimationsOf(context)) {
      _finish();
      return;
    }

    // Cap the capture resolution: keeps the snapshot texture small on
    // high-DPI phones without a visible quality hit for dust.
    final ratio = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);

    // The button tap (ripple / rebuild) can leave the boundary marked
    // needs-paint, which makes RenderRepaintBoundary.toImage assert in debug
    // (and capture a stale frame in release). Wait for a clean painted frame
    // before capturing, retrying a couple of times to be safe.
    ui.Image? image;
    for (var attempt = 0; attempt < 3 && image == null; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      try {
        image = await boundary.toImage(pixelRatio: ratio);
      } catch (_) {
        // Boundary still dirty this frame; the loop waits for the next one.
      }
    }
    if (image == null) {
      _finish();
      return;
    }
    if (!mounted) {
      image.dispose();
      return;
    }

    setState(() => _data = _buildData(image!, ratio));
    // Safety net: if the ticker ever fails to reach `completed`, still close.
    _safetyTimer = Timer(
      widget.duration + const Duration(milliseconds: 600),
      _finish,
    );
    _controller.forward();
  }

  _SnapData _buildData(ui.Image image, double ratio) {
    final rnd = math.Random();
    final imageW = image.width.toDouble();
    final imageH = image.height.toDouble();
    final cellPx = widget.cellSize * ratio;
    final cols = math.max(1, (imageW / cellPx).ceil());
    final rows = math.max(1, (imageH / cellPx).ceil());

    final cells = <_Cell>[];
    // The whole sheet dissolves together (no positional sweep); a small random
    // per-particle stagger only keeps the grain from looking synchronised.
    const maxDelay = 0.18;

    for (var cy = 0; cy < rows; cy++) {
      for (var cx = 0; cx < cols; cx++) {
        final left = cx * cellPx;
        final top = cy * cellPx;
        final w = math.min(cellPx, imageW - left);
        final h = math.min(cellPx, imageH - top);

        cells.add(
          _Cell(
            // Source tile in image pixels; resting centre + size in logical px.
            srcRect: Rect.fromLTWH(left, top, w, h),
            destCenterX: (left + w / 2) / ratio,
            destCenterY: (top + h / 2) / ratio,
            naturalWidth: w / ratio,
            naturalHeight: h / ratio,
            // Gentle upward drift + symmetric sideways wobble — no global wind,
            // so every region crumbles in place like dust rather than being
            // swept off in one direction. Kept small because the sheet hugs the
            // top edge; the shrink + fade do most of the "turn to dust" work.
            rise: 14 + rnd.nextDouble() * 46,
            waveAmplitude: (rnd.nextDouble() * 2 - 1) * 30,
            waveCount: 1 + rnd.nextDouble() * 2,
            fadePower: 1 + rnd.nextDouble() * 3,
            start: rnd.nextDouble() * maxDelay,
          ),
        );
      }
    }

    return _SnapData(
      image: image,
      cells: cells,
      span: 1.0 - maxDelay,
      logicalSize: Size(imageW / ratio, imageH / ratio),
    );
  }

  @override
  void dispose() {
    widget.controller._detach();
    _safetyTimer?.cancel();
    _controller.dispose();
    _data?.image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return RepaintBoundary(key: _boundaryKey, child: widget.child);
    }
    return SizedBox.fromSize(
      size: data.logicalSize,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: data.logicalSize,
            painter: _SnapPainter(data: data, progress: _controller.value),
          ),
        ),
      ),
    );
  }
}

/// Immutable per-particle parameters (computed once when the effect starts).
class _Cell {
  const _Cell({
    required this.srcRect,
    required this.destCenterX,
    required this.destCenterY,
    required this.naturalWidth,
    required this.naturalHeight,
    required this.rise,
    required this.waveAmplitude,
    required this.waveCount,
    required this.fadePower,
    required this.start,
  });

  /// Source tile inside the snapshot, in image pixels.
  final Rect srcRect;

  /// Resting centre in logical pixels (where the particle sits at progress 0).
  final double destCenterX;
  final double destCenterY;

  /// Tile size in logical pixels at rest (before shrinking).
  final double naturalWidth;
  final double naturalHeight;

  /// How far the particle rises (logical px) over its dissolve.
  final double rise;

  /// Amplitude and frequency of the symmetric sideways wobble.
  final double waveAmplitude;
  final double waveCount;

  /// Ease power for the opacity fade (higher = lingers longer, then drops).
  final double fadePower;

  /// Timeline fraction [0, maxDelay) at which this particle starts dissolving.
  final double start;
}

/// Everything the painter needs, allocated once per effect run.
class _SnapData {
  _SnapData({
    required this.image,
    required this.cells,
    required this.span,
    required this.logicalSize,
  });

  final ui.Image image;
  final List<_Cell> cells;

  /// Length of each particle's dissolve, as a timeline fraction.
  final double span;
  final Size logicalSize;
}

/// Symmetric ease-in-out with a tunable [power] (mirrors the reference JS
/// `EaseInOut`): the opacity stays high, then drops off near the end.
double _easeInOutPow(double t, double power) {
  if (t < 0.5) return math.pow(t * 2, power).toDouble() / 2;
  return 1 - math.pow((1 - t) * 2, power).toDouble() / 2;
}

class _SnapPainter extends CustomPainter {
  _SnapPainter({required this.data, required this.progress});

  final _SnapData data;
  final double progress;

  final Paint _paint = Paint()
    ..filterQuality = FilterQuality.low
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final cells = data.cells;
    final span = data.span;
    final image = data.image;

    for (var i = 0; i < cells.length; i++) {
      final c = cells[i];
      final local = ((progress - c.start) / span).clamp(0.0, 1.0);

      final shrink = 1.0 - local;
      final opacity = 1.0 - _easeInOutPow(local, c.fadePower);
      if (shrink <= 0.0 || opacity <= 0.004) continue; // fully gone — skip.

      // Rise in place, wobble symmetrically side to side, shrink to nothing,
      // and fade — every particle on the same timeline (no directional sweep).
      final cx =
          c.destCenterX +
          c.waveAmplitude * math.sin(c.waveCount * math.pi * local);
      final cy = c.destCenterY - c.rise * local;
      final halfW = c.naturalWidth * shrink / 2;
      final halfH = c.naturalHeight * shrink / 2;

      _paint.color = Color.fromRGBO(255, 255, 255, opacity);
      canvas.drawImageRect(
        image,
        c.srcRect,
        Rect.fromLTRB(cx - halfW, cy - halfH, cx + halfW, cy + halfH),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SnapPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.data != data;
}
