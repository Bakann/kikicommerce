import 'dart:math' as math;

import 'package:flutter/material.dart';

const kDiorIconCollapseDuration = Duration(milliseconds: 420);
const kDiorIconResetDelay = Duration(milliseconds: 420);

enum DiorCollapsingLineIconShape { menu, close, menuToClose }

class DiorCollapsingLineIcon extends StatelessWidget {
  final Animation<double> progress;
  final DiorCollapsingLineIconShape shape;
  final Color color;
  final double size;
  final bool useExpandedMobile;

  const DiorCollapsingLineIcon({
    super.key,
    required this.progress,
    required this.shape,
    required this.color,
    required this.size,
    this.useExpandedMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _DiorCollapsingLineIconPainter(
        progress: progress,
        shape: shape,
        color: color,
        useExpandedMobile: useExpandedMobile,
      ),
    );
  }
}

class _DiorCollapsingLineIconPainter extends CustomPainter {
  final Animation<double> progress;
  final DiorCollapsingLineIconShape shape;
  final Color color;
  final bool useExpandedMobile;

  _DiorCollapsingLineIconPainter({
    required this.progress,
    required this.shape,
    required this.color,
    required this.useExpandedMobile,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rawProgress = progress.value.clamp(0.0, 1.0);
    final t = Curves.easeInOutCubic.transform(rawProgress);
    switch (shape) {
      case DiorCollapsingLineIconShape.menu:
        _paintMenu(canvas, size, t);
      case DiorCollapsingLineIconShape.close:
        _paintClose(canvas, size, t);
      case DiorCollapsingLineIconShape.menuToClose:
        _paintMenuToClose(canvas, size, rawProgress);
    }
  }

  void _paintMenu(Canvas canvas, Size size, double t) {
    final center = Offset(size.width / 2, size.height / 2);
    final lineWidth = useExpandedMobile ? 21.0 : 19.5;
    final gap = useExpandedMobile ? 4.8 : 4.4;
    final strokeWidth = useExpandedMobile ? 1.65 : 1.6;

    void drawLine(double y) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(center.dx - lineWidth / 2, y),
        Offset(center.dx + lineWidth / 2, y),
        paint,
      );
    }

    final collapsedGap = gap * (1 - t);
    drawLine(center.dy - collapsedGap);
    drawLine(center.dy + collapsedGap);
  }

  void _paintMenuToClose(Canvas canvas, Size size, double rawProgress) {
    final center = Offset(size.width / 2, size.height / 2);
    final lineWidth = useExpandedMobile ? 21.0 : 19.5;
    final gap = useExpandedMobile ? 4.8 : 4.4;
    final strokeWidth = useExpandedMobile ? 1.65 : 1.6;
    final p = rawProgress.clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    void drawHorizontalLine(double y) {
      canvas.drawLine(
        Offset(center.dx - lineWidth / 2, y),
        Offset(center.dx + lineWidth / 2, y),
        paint,
      );
    }

    void drawRotatedLine(double angle) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(angle)
        ..drawLine(Offset(-lineWidth / 2, 0), Offset(lineWidth / 2, 0), paint)
        ..restore();
    }

    if (p <= 0.5) {
      final mergeT = Curves.easeInOutCubic.transform(p / 0.5);
      final currentGap = _lerpDouble(gap, 0, mergeT);
      drawHorizontalLine(center.dy - currentGap);
      drawHorizontalLine(center.dy + currentGap);
      return;
    }

    final rotateT = Curves.easeInOutCubic.transform((p - 0.5) / 0.5);
    drawRotatedLine(_lerpDouble(0, -math.pi / 4, rotateT));
    drawRotatedLine(_lerpDouble(0, math.pi / 4, rotateT));
  }

  void _paintClose(Canvas canvas, Size size, double t) {
    final center = Offset(size.width / 2, size.height / 2);
    final lineWidth = useExpandedMobile ? 20.0 : 19.0;
    final strokeWidth = useExpandedMobile ? 1.45 : 1.55;
    final primaryAngle = _lerpDouble(-math.pi / 4, 0, t);
    final secondaryAngle = _lerpDouble(math.pi / 4, 0, t);
    final secondaryOpacity = 1 - t;

    void drawRotatedLine(double angle, double opacity) {
      if (opacity <= 0) {
        return;
      }

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(angle)
        ..drawLine(Offset(-lineWidth / 2, 0), Offset(lineWidth / 2, 0), paint)
        ..restore();
    }

    drawRotatedLine(primaryAngle, 1);
    drawRotatedLine(secondaryAngle, secondaryOpacity);
  }

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _DiorCollapsingLineIconPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shape != shape ||
        oldDelegate.color != color ||
        oldDelegate.useExpandedMobile != useExpandedMobile;
  }
}
