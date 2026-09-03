import 'dart:math' as math;

import 'package:flutter/material.dart';

const kAnimatedShoppingCartIconKey = ValueKey<String>(
  'animated-shopping-cart-icon',
);

const kSharedNavCartCountBadgeKey = ValueKey<String>(
  'shared-nav-cart-count-badge',
);

enum AnimatedShoppingCartBadgePosition { topRight, bottomRight }

/// CSS-inspired shopping-bag glyph used by the navbar cart target.
///
/// The original interaction opens the bag with CSS transforms and bounces it
/// when the count changes. This Flutter version keeps the same visual beats
/// without the demo +/- controls or counter roll: the flap/front open while a
/// comet flight is incoming, and [bounceProgress] gives the impact squash.
class AnimatedShoppingCartIcon extends StatelessWidget {
  final Color color;
  final double size;
  final int badgeCount;
  final Brightness brightness;
  final Animation<double>? openProgress;
  final Animation<double>? bounceProgress;
  final Animation<double>? badgeScale;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final AnimatedShoppingCartBadgePosition badgePosition;

  const AnimatedShoppingCartIcon({
    super.key,
    required this.color,
    required this.size,
    required this.brightness,
    this.badgeCount = 0,
    this.openProgress,
    this.bounceProgress,
    this.badgeScale,
    this.badgeColor,
    this.badgeTextColor,
    this.badgePosition = AnimatedShoppingCartBadgePosition.topRight,
  });

  @override
  Widget build(BuildContext context) {
    final openProgress =
        this.openProgress ?? const AlwaysStoppedAnimation<double>(0);
    final bounceProgress =
        this.bounceProgress ?? const AlwaysStoppedAnimation<double>(0);
    final label = badgeCount <= 0
        ? null
        : (badgeCount > 99 ? '99+' : '$badgeCount');
    final isDark = brightness == Brightness.dark;
    final effectiveBadgeColor =
        badgeColor ?? (isDark ? Colors.white : const Color(0xFF111111));
    final effectiveBadgeTextColor =
        badgeTextColor ?? (isDark ? const Color(0xFF111111) : Colors.white);
    final iconExtent = math.max(size + 8, 30.0);

    return Stack(
      key: kAnimatedShoppingCartIconKey,
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        SizedBox.square(
          dimension: iconExtent,
          child: AnimatedBuilder(
            animation: Listenable.merge([openProgress, bounceProgress]),
            builder: (context, _) {
              return CustomPaint(
                painter: _ShoppingCartBagPainter(
                  color: color,
                  open: openProgress.value.clamp(0.0, 1.0),
                  bounce: bounceProgress.value.clamp(0.0, 1.0),
                ),
              );
            },
          ),
        ),
        if (label != null)
          _PositionedBadge(
            position: badgePosition,
            child: _ScaledBadge(
              scale: badgeScale,
              child: _CartBadge(
                label: label,
                color: effectiveBadgeColor,
                textColor: effectiveBadgeTextColor,
              ),
            ),
          ),
      ],
    );
  }
}

class _PositionedBadge extends StatelessWidget {
  final AnimatedShoppingCartBadgePosition position;
  final Widget child;

  const _PositionedBadge({required this.position, required this.child});

  @override
  Widget build(BuildContext context) {
    return switch (position) {
      AnimatedShoppingCartBadgePosition.topRight => Positioned(
        top: -6,
        right: -9,
        child: child,
      ),
      AnimatedShoppingCartBadgePosition.bottomRight => Positioned(
        right: -5,
        bottom: -3,
        child: child,
      ),
    };
  }
}

class _ScaledBadge extends StatelessWidget {
  final Animation<double>? scale;
  final Widget child;

  const _ScaledBadge({required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    final scale = this.scale;
    if (scale == null) return child;
    return ScaleTransition(scale: scale, child: child);
  }
}

class _CartBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _CartBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        key: kSharedNavCartCountBadgeKey,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Inter',
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _ShoppingCartBagPainter extends CustomPainter {
  static const _sourceSize = Size(198, 186);
  static const _strokeColor = Color(0xFF242836);
  static const _strokeLightColor = Color(0xFF3F4656);
  static const _backgroundColor = Color(0xFFFFFFFF);
  static const _innerColor = Color(0xFFEEF4FF);
  static const _strokeWidth = 8.0;
  static const _insideLineWidth = 5.5;

  final Color color;
  final double open;
  final double bounce;

  _ShoppingCartBagPainter({
    required this.color,
    required this.open,
    required this.bounce,
  });

  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / _sourceSize.width,
      size.height / _sourceSize.height,
    );
    final dx = (size.width - _sourceSize.width * scale) / 2;
    final dy = (size.height - _sourceSize.height * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final t = Curves.easeOutCubic.transform(open);
    final bounceT = Curves.easeOut.transform(bounce);
    final bounceScaleY = 1 - 0.10 * math.sin(math.pi * bounceT);

    canvas.translate(_sourceSize.width / 2, 156);
    canvas.scale(1, bounceScaleY);
    canvas.translate(-_sourceSize.width / 2, -156);

    if (t > 0.01) {
      _paintOpenLid(canvas, t);
    }
    if (t < 0.995) {
      _paintClosedHandle(canvas, t);
    }
    final body = _bodyPath(t);
    _paintBodyFill(canvas, body);
    if (t > 0.01) {
      _paintOpenHandle(canvas, t);
    }
    _paintBodyStroke(canvas, body);
    _paintInsideLine(canvas, t);

    canvas.restore();
  }

  Path _bodyPath(double t) {
    return Path()
      ..moveTo(_lerp(36, 26, t), _lerp(51, 80, t))
      ..lineTo(_lerp(139, 169, t), _lerp(51, 80, t))
      ..lineTo(_lerp(150, 160, t), _lerp(155, 155, t))
      ..lineTo(_lerp(27, 35, t), _lerp(155, 155, t))
      ..close();
  }

  void _paintBodyFill(Canvas canvas, Path path) {
    _fill
      ..color = _backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, _fill);
  }

  void _paintBodyStroke(Canvas canvas, Path path) {
    _stroke
      ..color = _strokeColor
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, _stroke);
  }

  void _paintClosedHandle(Canvas canvas, double t) {
    final fade = 1 - _interval(t, 0.62, 0.92);
    if (fade <= 0) return;
    final lift = 9 * _interval(t, 0.0, 0.6);
    final path = Path()
      ..moveTo(61, 51 + lift)
      ..cubicTo(70, 31 + lift, 83, 31 + lift, 90, 31 + lift)
      ..cubicTo(103, 31 + lift, 112, 40 + lift, 119, 51 + lift);
    _stroke
      ..color = _strokeColor.withValues(alpha: fade)
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, _stroke);
  }

  void _paintOpenHandle(Canvas canvas, double t) {
    final fade = _interval(t, 0.28, 0.85);
    if (fade <= 0) return;
    final path = Path()
      ..moveTo(_lerp(61, 60, t), _lerp(51, 77, t))
      ..cubicTo(
        _lerp(73, 72, t),
        _lerp(37, 97, t),
        _lerp(117, 122, t),
        _lerp(37, 97, t),
        _lerp(130, 135, t),
        _lerp(51, 77, t),
      );
    _stroke
      ..color = _strokeColor.withValues(alpha: fade)
      ..strokeWidth = 4.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, _stroke);
  }

  void _paintOpenLid(Canvas canvas, double t) {
    final fade = _interval(t, 0.1, 0.75);
    if (fade <= 0) return;
    final drop = 8 * (1 - fade);
    final outer = Path()
      ..moveTo(47, 49 + drop)
      ..lineTo(148, 49 + drop)
      ..lineTo(151, 64 + drop)
      ..lineTo(166, 76 + drop)
      ..lineTo(30, 76 + drop)
      ..lineTo(45, 64 + drop)
      ..close();
    _fill
      ..color = _strokeColor.withValues(alpha: fade)
      ..style = PaintingStyle.fill;
    canvas.drawPath(outer, _fill);

    final inner = Path()
      ..moveTo(58, 56 + drop)
      ..lineTo(138, 56 + drop)
      ..lineTo(132, 68 + drop)
      ..lineTo(63, 68 + drop)
      ..close();
    _fill.color = _innerColor.withValues(alpha: fade);
    canvas.drawPath(inner, _fill);
  }

  void _paintInsideLine(Canvas canvas, double t) {
    _stroke
      ..color = _strokeLightColor
      ..strokeWidth = _insideLineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(_lerp(56, 61, t), _lerp(130, 141, t)),
      Offset(_lerp(121, 134, t), _lerp(130, 141, t)),
      _stroke,
    );
  }

  double _lerp(num a, num b, double t) => a + (b - a) * t;

  double _interval(double t, double start, double end) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return (t - start) / (end - start);
  }

  @override
  bool shouldRepaint(covariant _ShoppingCartBagPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.open != open ||
        oldDelegate.bounce != bounce;
  }
}
