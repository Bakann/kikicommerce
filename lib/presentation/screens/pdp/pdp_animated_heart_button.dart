import 'dart:math' as math;

import 'package:flutter/material.dart';

const kPdpFavoriteHeartButtonKey = ValueKey<String>(
  'pdp-favorite-heart-button',
);

enum _HeartReaction { like, unlike }

class PdpAnimatedHeartButton extends StatefulWidget {
  static const double minTapSize = 44;

  final double size;
  final double tapSize;

  const PdpAnimatedHeartButton({
    super.key,
    required this.size,
    this.tapSize = minTapSize,
  });

  @override
  State<PdpAnimatedHeartButton> createState() => _PdpAnimatedHeartButtonState();
}

class _PdpAnimatedHeartButtonState extends State<PdpAnimatedHeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 840),
  );

  bool _liked = false;
  _HeartReaction _reaction = _HeartReaction.like;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _reaction = _liked ? _HeartReaction.unlike : _HeartReaction.like;
      _liked = !_liked;
    });
    if (reduceMotion) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final label = _liked ? 'Retirer des favoris' : 'Ajouter aux favoris';
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: _liked,
        label: label,
        child: GestureDetector(
          key: kPdpFavoriteHeartButtonKey,
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: SizedBox.square(
            dimension: widget.tapSize,
            child: OverflowBox(
              maxWidth: math.max(widget.size * 7, widget.tapSize + 96),
              maxHeight: math.max(widget.size * 7, widget.tapSize + 96),
              child: SizedBox.square(
                dimension: math.max(widget.size * 7, widget.tapSize + 96),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _PdpAnimatedHeartPainter(
                      progress: _controller,
                      liked: _liked,
                      reaction: _reaction,
                      visualSize: widget.size,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PdpAnimatedHeartPainter extends CustomPainter {
  _PdpAnimatedHeartPainter({
    required this.progress,
    required this.liked,
    required this.reaction,
    required this.visualSize,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final bool liked;
  final _HeartReaction reaction;
  final double visualSize;

  static final Path _heart = _buildHeartPath();
  static final Path _paper = _centerPath(_buildPaperPath());
  static final Path _star = _centerPath(_buildStarSvgPath());
  static final Path _diamond = _centerPath(_buildDiamondPath());
  static final Path _breakLine = _buildBreakLinePath();
  static final Rect _heartBounds = Rect.fromLTRB(259.5, 259.5, 340.5, 340.5);
  static const Offset _sourceCenter = Offset(300, 300.5);
  static const Offset _heartLineOrigin = Offset(230, 230);
  static const Offset _heartLineLocalCenter = Offset(71, 71);
  static const List<Offset> _heartLineLocalEnds = <Offset>[
    Offset(71, 0),
    Offset(121.205, 20.795),
    Offset(142, 71),
    Offset(121.205, 121.205),
    Offset(71, 142),
    Offset(20.795, 121.205),
    Offset(0, 71),
    Offset(20.795, 20.795),
  ];
  static const List<Offset> _heartLineCloneOrigins = <Offset>[
    Offset(216, 128),
    Offset(252, 148),
    Offset(194, 172),
    Offset(278, 112),
    Offset(232, 188),
  ];
  static const Color _grey = Color(0xFFAAB8C2);
  static const Color _pink = Color(0xFFE2264D);
  static const List<Color> _burstLineColors = <Color>[
    Color(0xFF98D4F8),
    Color(0xFFCA90F2),
    Color(0xFF94EFC6),
    Color(0xFFF9DB96),
    Color(0xFF98D4F8),
    Color(0xFFCA90F2),
    Color(0xFF94EFC6),
    Color(0xFFF9DB96),
  ];
  static const List<Color> _particleColors = <Color>[
    Color(0xFF34A3F2),
    Color(0xFFB400AC),
    Color(0xFF88E259),
    Color(0xFFF75E19),
    Color(0xFF39C5C0),
    Color(0xFFE3004D),
  ];
  static final List<_HeartParticle> _particles = _buildParticles();

  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    _withSourceSpace(canvas, size, () {
      final t = progress.value.clamp(0.0, 1.0);
      if (reaction == _HeartReaction.unlike) {
        _paintUnlike(canvas, t);
      } else {
        _paintLike(canvas, t);
      }
    });
  }

  void _paintLike(Canvas canvas, double t) {
    if (!liked && t == 0) {
      _drawHeart(canvas, _grey);
      return;
    }
    if (t >= 0.94) {
      _drawHeart(canvas, _pink);
      return;
    }

    _paintJumpBurstLines(canvas, t);
    _paintJumpParticles(canvas, t);

    final jumpY = _heartJumpY(t);
    final settleScale =
        1 +
        0.06 *
            math.sin(math.pi * _interval(t, 0.42, 0.78, Curves.easeOutCubic));
    canvas.save();
    canvas.translate(0, jumpY);
    _drawScaledHeart(
      canvas,
      Color.lerp(_grey, _pink, _interval(t, 0.0, 0.18, Curves.easeInCubic))!,
      scale: settleScale,
      origin: _sourceCenter,
    );
    canvas.restore();
  }

  void _paintUnlike(Canvas canvas, double t) {
    if (liked && t == 0) {
      _drawHeart(canvas, _pink);
      return;
    }

    final greyIn = _interval(t, 0.42, 0.86, Curves.easeOutCubic);
    if (greyIn > 0) {
      _drawScaledHeart(
        canvas,
        _grey.withValues(alpha: greyIn),
        scale: 0.82 + 0.18 * greyIn,
        origin: _sourceCenter,
      );
    }

    final breakT = _interval(t, 0.0, 0.82, Curves.easeInCubic);
    final fade = 1 - _interval(t, 0.56, 0.92, Curves.easeOutCubic);
    if (fade <= 0) {
      if (!liked) _drawHeart(canvas, _grey);
      return;
    }

    final angle = 0.92 * breakT;
    final dx = 18 * breakT;
    final dy = 30 * breakT * breakT;
    _paintBrokenHalf(
      canvas,
      clip: const Rect.fromLTRB(240, 238, 300.5, 360),
      pivot: const Offset(302, 334),
      translate: Offset(-dx, dy),
      rotation: -angle,
      opacity: fade,
    );
    _paintBrokenHalf(
      canvas,
      clip: const Rect.fromLTRB(299.5, 238, 362, 360),
      pivot: const Offset(298, 334),
      translate: Offset(dx, dy),
      rotation: angle,
      opacity: fade,
    );
  }

  double _heartJumpY(double t) {
    final up = _interval(t, 0.0, 0.26, Curves.easeOutCubic);
    if (t <= 0.26) return -100 * up;
    final down = _interval(t, 0.26, 0.74, Curves.easeOutBack);
    return -100 * (1 - down);
  }

  void _paintJumpBurstLines(Canvas canvas, double t) {
    _stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Original `.heartLines`: drawSVG starts at `0% 35%` and is tweened to
    // `100% 100%`, making a colored segment travel outwards from the heart.
    final baseT = _interval(t, 0.0, 0.72, Curves.linear);
    if (baseT > 0 && baseT < 1) {
      _paintHeartLineGroup(
        canvas,
        origin: _heartLineOrigin,
        scale: 1,
        startPercent: baseT,
        endPercent: 0.35 + 0.65 * baseT,
        opacity: math.sin(math.pi * baseT).clamp(0.0, 1.0),
      );
    }

    // Cloned `.heartLines` pool: five small copies above the heart, staggered
    // after the jump starts. Timings are compressed into the like controller so
    // the final frame never keeps a half-drawn clone on screen.
    for (var i = 0; i < _heartLineCloneOrigins.length; i++) {
      final start = 0.30 + i * 0.052;
      final growT = _interval(t, start, start + 0.11, Curves.linear);
      final moveT = _interval(t, start + 0.11, start + 0.38, Curves.linear);
      if (growT <= 0 && moveT <= 0) continue;
      final startPercent = moveT > 0 ? 0.10 + 0.90 * moveT : 0.10 * growT;
      final endPercent = moveT > 0 ? 0.30 + 0.70 * moveT : 0.30 * growT;
      _paintHeartLineGroup(
        canvas,
        origin: _heartLineCloneOrigins[i],
        scale: 0.5,
        startPercent: startPercent,
        endPercent: endPercent,
        opacity: (1 - moveT * 0.35).clamp(0.0, 1.0),
      );
    }
  }

  void _paintHeartLineGroup(
    Canvas canvas, {
    required Offset origin,
    required double scale,
    required double startPercent,
    required double endPercent,
    required double opacity,
  }) {
    if (endPercent <= startPercent || opacity <= 0) return;
    final localCenter = _heartLineLocalCenter * scale + origin;
    for (var i = 0; i < _heartLineLocalEnds.length; i++) {
      final localEnd = _heartLineLocalEnds[i] * scale + origin;
      final vector = localEnd - localCenter;
      _stroke.color = _burstLineColors[i].withValues(alpha: opacity);
      canvas.drawLine(
        localCenter + vector * startPercent,
        localCenter + vector * endPercent,
        _stroke,
      );
    }
  }

  void _paintJumpParticles(Canvas canvas, double t) {
    final particleT = _interval(t, 0.20, 1.0, Curves.easeOutCubic);
    if (particleT <= 0 || particleT >= 1) return;
    for (final particle in _particles) {
      final gravity = Offset(0, 72 * particle.weight * particleT * particleT);
      final center =
          const Offset(310, 220) + particle.velocity * particleT + gravity;
      final opacity = (1 - _interval(particleT, 0.58, 1.0, Curves.easeOutCubic))
          .clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(particle.rotation * particleT);
      canvas.scale(particle.scale * (1 - 0.18 * particleT));
      _fill.color = particle.color.withValues(alpha: opacity);
      _drawParticle(canvas, particle.kind);
      canvas.restore();
    }
  }

  void _drawParticle(Canvas canvas, _HeartParticleKind kind) {
    switch (kind) {
      case _HeartParticleKind.paper:
        canvas.drawPath(_paper, _fill);
        return;
      case _HeartParticleKind.ring:
        _stroke
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..color = _fill.color;
        canvas.drawCircle(Offset.zero, 9.344, _stroke);
        return;
      case _HeartParticleKind.star:
        canvas.drawPath(_star, _fill);
        return;
      case _HeartParticleKind.diamond:
        canvas.drawPath(_diamond, _fill);
        return;
    }
  }

  void _paintBrokenHalf(
    Canvas canvas, {
    required Rect clip,
    required Offset pivot,
    required Offset translate,
    required double rotation,
    required double opacity,
  }) {
    canvas.save();
    canvas.translate(pivot.dx + translate.dx, pivot.dy + translate.dy);
    canvas.rotate(rotation);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.clipRect(clip);
    _drawHeart(canvas, _pink.withValues(alpha: opacity));
    _stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.78 * opacity);
    canvas.drawPath(_breakLine, _stroke);
    canvas.restore();
  }

  void _drawHeart(Canvas canvas, Color color) {
    _fill.color = color;
    canvas.drawPath(_heart, _fill);
  }

  void _drawScaledHeart(
    Canvas canvas,
    Color color, {
    required double scale,
    required Offset origin,
  }) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    canvas.translate(-origin.dx, -origin.dy);
    _drawHeart(canvas, color);
    canvas.restore();
  }

  void _withSourceSpace(Canvas canvas, Size size, VoidCallback paint) {
    final scale = visualSize / _heartBounds.width;
    final center = size.center(Offset.zero);
    canvas.save();
    canvas.translate(
      center.dx - _heartBounds.center.dx * scale,
      center.dy - _heartBounds.center.dy * scale,
    );
    canvas.scale(scale);
    paint();
    canvas.restore();
  }

  static double _interval(double t, double begin, double end, Curve curve) {
    if (t <= begin) return 0;
    if (t >= end) return 1;
    return curve.transform((t - begin) / (end - begin));
  }

  @override
  bool shouldRepaint(covariant _PdpAnimatedHeartPainter oldDelegate) {
    return oldDelegate.liked != liked ||
        oldDelegate.reaction != reaction ||
        oldDelegate.visualSize != visualSize;
  }
}

Path _buildHeartPath() {
  return Path()
    ..moveTo(318.2, 259.5)
    ..relativeCubicTo(-7.5, 0, -14.2, 3.7, -18.2, 9.5)
    ..relativeCubicTo(-4, -5.7, -10.7, -9.5, -18.2, -9.5)
    ..relativeCubicTo(-12.3, 0, -22.3, 10, -22.3, 22.3)
    ..relativeCubicTo(0, 30.4, 31.6, 58.7, 40.5, 58.7)
    ..cubicTo(308.9, 340.5, 340.5, 312.1, 340.5, 281.8)
    ..cubicTo(340.5, 269.5, 330.5, 259.5, 318.2, 259.5)
    ..close();
}

Path _buildBreakLinePath() {
  return Path()
    ..moveTo(300, 340.5)
    ..lineTo(299, 331.5)
    ..lineTo(303, 324.8)
    ..lineTo(295.7, 315.8)
    ..lineTo(303.5, 303)
    ..lineTo(292.2, 291.7)
    ..lineTo(304, 276.2)
    ..lineTo(300, 268.9);
}

Path _buildPaperPath() {
  return Path()
    ..moveTo(8.871, 18.001)
    ..cubicTo(8.714, 18.001, 8.555, 17.986, 8.394, 17.955)
    ..cubicTo(6.330, 17.557, 4.508, 16.637, 3.126, 15.294)
    ..cubicTo(-0.197, 12.067, -0.940, 6.663, 1.231, 1.527)
    ..cubicTo(1.769, 0.256, 3.235, -0.339, 4.507, 0.198)
    ..cubicTo(5.780, 0.736, 6.374, 2.203, 5.837, 3.474)
    ..cubicTo(4.495, 6.647, 4.806, 9.955, 6.609, 11.707)
    ..cubicTo(7.301, 12.379, 8.220, 12.830, 9.341, 13.046)
    ..cubicTo(10.696, 13.307, 11.584, 14.618, 11.322, 15.974)
    ..cubicTo(11.092, 17.170, 10.044, 18.001, 8.871, 18.001)
    ..close();
}

Path _buildStarSvgPath() {
  return Path()
    ..moveTo(17.365, 18.587)
    ..lineTo(10.846, 15.880)
    ..lineTo(4.920, 19.716)
    ..lineTo(5.480, 12.679)
    ..lineTo(0, 8.229)
    ..lineTo(6.865, 6.587)
    ..lineTo(9.405, 0)
    ..lineTo(13.088, 6.022)
    ..lineTo(20.137, 6.401)
    ..lineTo(15.548, 11.765)
    ..close();
}

Path _buildDiamondPath() {
  return Path()
    ..moveTo(6.444, 17.442)
    ..lineTo(0, 8.721)
    ..lineTo(6.444, 0)
    ..lineTo(12.888, 8.721)
    ..close();
}

Path _centerPath(Path path) {
  final bounds = path.getBounds();
  return path.shift(-bounds.center);
}

enum _HeartParticleKind { paper, ring, star, diamond }

class _HeartParticle {
  const _HeartParticle({
    required this.kind,
    required this.color,
    required this.velocity,
    required this.weight,
    required this.rotation,
    required this.scale,
  });

  final _HeartParticleKind kind;
  final Color color;
  final Offset velocity;
  final double weight;
  final double rotation;
  final double scale;
}

List<_HeartParticle> _buildParticles() {
  const kinds = _HeartParticleKind.values;
  const weights = <double>[1.8, 2.1, 1.7, 2.3];
  return List<_HeartParticle>.generate(20, (i) {
    final kindIndex = (i * 7 + 3) % kinds.length;
    final colorIndex =
        (i * 5 + 2) % _PdpAnimatedHeartPainter._particleColors.length;
    final angle = (-110 + (i * 17 % 31)) * math.pi / 180;
    final speed = 115 + (i * 31 % 116);
    return _HeartParticle(
      kind: kinds[kindIndex],
      color: _PdpAnimatedHeartPainter._particleColors[colorIndex],
      velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
      weight: weights[kindIndex],
      rotation: (220 + (i * 61 % 520)) * math.pi / 180,
      scale: 0.62 + (i * 13 % 34) / 100,
    );
  });
}
