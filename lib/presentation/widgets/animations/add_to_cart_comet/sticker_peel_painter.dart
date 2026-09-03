import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'add_to_cart_comet_render_profile.dart';
import 'comet_flight_geometry.dart';
import 'sticker_peel_geometry.dart';

/// Peel.js-style sticker flyer, fully canvas-drawn.
///
/// One painter renders all three phases from the raw controller time:
/// the corner peel on the card (stuck layer clipped to the un-peeled
/// half-plane, back face mirrored across the fold line, cast shadow, glue
/// web), the flight along the coaster path (tangent tilt + squash/stretch,
/// residual curl relaxing), and the snap into the cart (fast scale-down,
/// micro rebound, absorption).
///
// TODO(comet): swap the diagonal iridescent sweep for a small fragment
// shader (cf. assets/shaders/) once the effect is validated visually.
class StickerPeelPainter extends CustomPainter {
  StickerPeelPainter({
    required this.progress,
    required this.particles,
    required this.stickerRect,
    required this.targetSize,
    required this.crestFraction,
    required this.corner,
    required this.intensity,
    required this.image,
    this.renderProfile = AddToCartCometRenderProfile.rich,
  }) : super(repaint: Listenable.merge([progress, image]));

  /// Raw controller time in [0, 1] (phases derived internally).
  final Animation<double> progress;
  final List<SampledCometParticle> particles;

  /// Where the sticker sits on the card, in overlay coordinates.
  final Rect stickerRect;
  final Size targetSize;
  final double crestFraction;
  final StickerPeelCorner corner;
  final double intensity;

  /// Product texture for the sticker face; a premium flat gradient is used
  /// until it resolves (or forever, if it never does).
  final ValueListenable<ui.Image?> image;
  final AddToCartCometRenderProfile renderProfile;

  static const _cornerRadius = Radius.circular(10);

  final Paint _fillPaint = Paint();
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _opacityLayerPaint = Paint();
  late final _StickerPeelShaders _shaders = _StickerPeelShaders(stickerRect);
  late final RRect _stickerRRect = RRect.fromRectAndRadius(
    stickerRect,
    _cornerRadius,
  );
  late final RRect _innerStrokeRRect = RRect.fromRectAndRadius(
    stickerRect.deflate(0.5),
    _cornerRadius,
  );
  late final Path _stickerRRectPath = Path()..addRRect(_stickerRRect);

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.length < 2) return;
    final t = progress.value.clamp(0.0, 1.0);
    final fold = buildStickerFold(
      stickerRect,
      corner,
      stickerFoldDistanceAt(t, stickerRect, corner, intensity: intensity),
      intensity: intensity,
    );

    if (t <= kStickerPeelEnd) {
      _paintPeelPhase(canvas, t, fold);
    } else if (t <= kStickerFlightEnd) {
      _paintFlightPhase(canvas, t, fold);
    } else {
      _paintSnapPhase(canvas, t);
    }
  }

  void _paintPeelPhase(Canvas canvas, double t, StickerFoldFrame fold) {
    final peel = stickerPeelProgress(t);
    _drawSticker(
      canvas,
      fold,
      opacity: 1.0,
      shineT: _usesFirstTapCheapProfile ? null : peel * 0.35,
      glueOpacity: stickerGlueOpacity(peel),
    );
  }

  void _paintFlightPhase(Canvas canvas, double t, StickerFoldFrame fold) {
    final flightLocal = stickerFlightLocal(t);
    final pathProgress = stickerPathProgress(t, crestFraction);
    final head = cometHeadPosition(particles, pathProgress);
    final tilt = cometHeadAngle(
      particles,
      pathProgress,
    ).clamp(-kStickerMaxTilt, kStickerMaxTilt);
    final targetScale = stickerTargetScale(stickerRect.size, targetSize);
    final scale = stickerFlightScale(flightLocal, targetScale: targetScale);
    final squash = stickerFlightSquash(flightLocal, intensity);
    final center = stickerRect.center;

    canvas.save();
    canvas.translate(head.dx - center.dx, head.dy - center.dy);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    // Squash along the tangent, stretch across it: volume-ish preservation.
    canvas.scale(scale * (1 + squash), scale * (1 - squash));
    canvas.translate(-center.dx, -center.dy);
    _drawSticker(
      canvas,
      fold,
      opacity: 1.0,
      shineT: _usesFirstTapCheapProfile ? null : 0.35 + flightLocal * 0.65,
      glueOpacity: 0.0,
      flying: true,
    );
    canvas.restore();
  }

  void _paintSnapPhase(Canvas canvas, double t) {
    final snap = stickerSnapProgress(t);
    final opacity = stickerSnapOpacity(snap);
    if (opacity <= 0.004) return;
    final head = particles.last.position;
    final targetScale = stickerTargetScale(stickerRect.size, targetSize);
    final scale =
        stickerFlightScale(1.0, targetScale: targetScale) *
        stickerSnapScale(snap);
    if (scale <= 0.004) return;
    final center = stickerRect.center;
    final flatFold = buildStickerFold(stickerRect, corner, 0);

    canvas.save();
    canvas.translate(head.dx - center.dx, head.dy - center.dy);
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    _drawSticker(
      canvas,
      flatFold,
      opacity: opacity,
      shineT: _usesFirstTapCheapProfile ? null : 1.0,
      glueOpacity: 0.0,
      flying: true,
    );
    canvas.restore();
  }

  /// Draws the sticker with its current fold, Peel.js layer order: stuck
  /// face → cast shadow → glue → mirrored back face → fold highlight.
  void _drawSticker(
    Canvas canvas,
    StickerFoldFrame fold, {
    required double opacity,
    required double? shineT,
    required double glueOpacity,
    bool flying = false,
  }) {
    final rect = stickerRect;
    final geometry = _StickerFoldPaintGeometry(
      rect: rect,
      rrect: _stickerRRect,
      rrectPath: _stickerRRectPath,
      fold: fold,
    );
    final foldRatio = fold.maxFoldDistance > 0
        ? fold.foldDistance / fold.maxFoldDistance
        : 0.0;

    // Soft drop shadow under the whole sticker while it flies.
    if (flying) {
      _drawFlyingShadow(canvas, geometry.rrect, opacity: opacity);
    }

    // 1. Stuck face: the sticker clipped to the not-yet-peeled half-plane.
    canvas.save();
    canvas.clipRRect(geometry.rrect);
    final stuckHalfPlane = geometry.stuckHalfPlane;
    if (stuckHalfPlane != null) {
      canvas.clipPath(stuckHalfPlane);
    }
    _drawFace(canvas, rect, opacity: opacity, shineT: shineT);
    canvas.restore();

    if (fold.isFolded) {
      // 2. Cast shadow of the lifted flap onto the card / stuck face.
      final flapOnCard = geometry.flapOnCard!;
      _drawFlapShadow(
        canvas,
        flapOnCard,
        fold,
        opacity: opacity,
        foldRatio: foldRatio,
      );

      // 3. Glue web between the card and the lifting flap.
      if (glueOpacity > 0.004) {
        _fillPaint
          ..shader = null
          ..color = const Color(
            0xFFEFEDE8,
          ).withValues(alpha: glueOpacity * opacity);
        canvas.drawPath(stickerGluePath(fold), _fillPaint);
      }

      // 4. Back face: mirror the canvas across the fold line, then paint the
      // sticker clipped to the peeled half-plane — the drawing lands exactly
      // on the visible flap. Matte finish: ghosted texture under a warm
      // white veil, plus an inner shadow darkening toward the fold.
      canvas.save();
      canvas.transform(geometry.reflection!.storage);
      canvas.clipRRect(geometry.rrect);
      canvas.clipPath(geometry.peeledHalfPlane!);
      _drawFace(canvas, rect, opacity: opacity * 0.35, shineT: null);
      _fillPaint
        ..shader = null
        ..color = const Color(0xFFF3F1EC).withValues(alpha: 0.78 * opacity);
      canvas.drawRect(rect, _fillPaint);
      _drawFoldInnerShadow(canvas, rect, fold, opacity: opacity);
      canvas.restore();

      // 5. Fold-line highlight: the bright cylinder edge of the curl, plus a
      // faint refractive-looking secondary line just behind it.
      canvas.save();
      canvas.clipPath(geometry.reflectedFlapOnCard!);
      final lineFrom =
          fold.foldPoint + fold.foldLineDirection * geometry.extent;
      final lineTo = fold.foldPoint - fold.foldLineDirection * geometry.extent;
      _strokePaint
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.65 * foldRatio * opacity);
      canvas.drawLine(lineFrom, lineTo, _strokePaint);
      final refractOffset = fold.peelDirection * 2.5;
      _strokePaint
        ..strokeWidth = 2.2
        ..color = const Color(
          0xFFBFD8EE,
        ).withValues(alpha: 0.22 * foldRatio * opacity);
      canvas.drawLine(
        lineFrom + refractOffset,
        lineTo + refractOffset,
        _strokePaint,
      );
      canvas.restore();
    }
  }

  bool get _usesFirstTapCheapProfile =>
      renderProfile == AddToCartCometRenderProfile.webMobileFirstTapCheap;

  bool get _usesWebMobileProfile =>
      renderProfile != AddToCartCometRenderProfile.rich;

  void _drawFlyingShadow(
    Canvas canvas,
    RRect rrect, {
    required double opacity,
  }) {
    if (_usesFirstTapCheapProfile) return;

    if (_usesWebMobileProfile) {
      _fillPaint
        ..shader = null
        ..maskFilter = null
        ..color = Colors.black.withValues(alpha: 0.08 * opacity);
      canvas.drawRRect(
        rrect.shift(const Offset(0, 7)).inflate(1.5),
        _fillPaint,
      );
      return;
    }

    _fillPaint
      ..shader = null
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..color = Colors.black.withValues(alpha: 0.16 * opacity);
    canvas.drawRRect(rrect.shift(const Offset(0, 10)), _fillPaint);
    _fillPaint.maskFilter = null;
  }

  void _drawFlapShadow(
    Canvas canvas,
    Path flapOnCard,
    StickerFoldFrame fold, {
    required double opacity,
    required double foldRatio,
  }) {
    if (_usesFirstTapCheapProfile) return;

    final shadowPath = flapOnCard.shift(
      fold.peelDirection * 5 + const Offset(0, 3),
    );

    if (_usesWebMobileProfile) {
      _fillPaint
        ..shader = null
        ..maskFilter = null
        ..color = Colors.black.withValues(alpha: 0.10 * foldRatio * opacity);
      canvas.drawPath(shadowPath, _fillPaint);
      return;
    }

    _fillPaint
      ..shader = null
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
      ..color = Colors.black.withValues(alpha: 0.20 * foldRatio * opacity);
    canvas.drawPath(shadowPath, _fillPaint);
    _fillPaint.maskFilter = null;
  }

  /// Sticker face: product texture (or premium flat gradient fallback), a
  /// subtle diagonal iridescent sweep whose highlight travels with [shineT],
  /// and a thin bright edge simulating the sticker's thickness.
  void _drawFace(
    Canvas canvas,
    Rect rect, {
    required double opacity,
    required double? shineT,
  }) {
    final texture = image.value;
    if (texture != null) {
      _fillPaint
        ..shader = null
        ..maskFilter = null
        ..filterQuality = _usesWebMobileProfile
            ? FilterQuality.low
            : FilterQuality.medium
        ..color = Colors.white.withValues(alpha: opacity);
      canvas.drawImageRect(
        texture,
        Rect.fromLTWH(
          0,
          0,
          texture.width.toDouble(),
          texture.height.toDouble(),
        ),
        rect,
        _fillPaint,
      );
    } else {
      _drawFallbackFace(canvas, rect, opacity: opacity);
    }

    if (shineT != null) {
      _drawTranslatedShine(canvas, rect, shineT: shineT, opacity: opacity);
    }

    _strokePaint
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.5 * opacity);
    canvas.drawRRect(_innerStrokeRRect, _strokePaint);
  }

  void _drawFallbackFace(Canvas canvas, Rect rect, {required double opacity}) {
    void draw() {
      _fillPaint
        ..maskFilter = null
        ..shader = _shaders.fallbackFace
        ..color = Colors.white;
      canvas.drawRect(rect, _fillPaint);
      _fillPaint.shader = null;
    }

    _drawWithOptionalOpacityLayer(canvas, rect, opacity, draw);
  }

  void _drawTranslatedShine(
    Canvas canvas,
    Rect rect, {
    required double shineT,
    required double opacity,
  }) {
    if (opacity <= 0.004) return;

    void draw() {
      // The shader's stops stay fixed around 0.5; translating the canvas while
      // inversely translating the draw rect moves the band without creating a
      // new gradient variant every frame.
      final band = shineT.clamp(0.0, 1.0) * 1.4 - 0.2;
      final travel = rect.bottomRight - rect.topLeft;
      final offset = travel * (band - 0.5);
      canvas.save();
      canvas.clipRect(rect);
      canvas.translate(offset.dx, offset.dy);
      _fillPaint
        ..maskFilter = null
        ..shader = _shaders.shine
        ..color = Colors.white;
      canvas.drawRect(rect.shift(-offset), _fillPaint);
      _fillPaint.shader = null;
      canvas.restore();
    }

    _drawWithOptionalOpacityLayer(canvas, rect, opacity, draw);
  }

  void _drawFoldInnerShadow(
    Canvas canvas,
    Rect rect,
    StickerFoldFrame fold, {
    required double opacity,
  }) {
    if (opacity <= 0.004) return;

    void draw() {
      final length = fold.foldDistance * 1.6 + 1;
      final localExtent = rect.longestSide * 4;
      canvas.save();
      canvas.translate(fold.foldPoint.dx, fold.foldPoint.dy);
      canvas.rotate(fold.peelDirection.direction);
      canvas.scale(length, 1);
      _fillPaint
        ..maskFilter = null
        ..shader = _shaders.foldInnerShadow
        ..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(
          -localExtent / length,
          -localExtent,
          (localExtent * 2) / length,
          localExtent * 2,
        ),
        _fillPaint,
      );
      _fillPaint.shader = null;
      canvas.restore();
    }

    _drawWithOptionalOpacityLayer(canvas, rect, opacity, draw);
  }

  void _drawWithOptionalOpacityLayer(
    Canvas canvas,
    Rect bounds,
    double opacity,
    VoidCallback draw,
  ) {
    if (opacity >= 0.999) {
      draw();
      return;
    }
    _opacityLayerPaint.color = Colors.white.withValues(alpha: opacity);
    canvas.saveLayer(bounds, _opacityLayerPaint);
    draw();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StickerPeelPainter oldDelegate) {
    return !identical(oldDelegate.particles, particles) ||
        oldDelegate.stickerRect != stickerRect ||
        oldDelegate.targetSize != targetSize ||
        oldDelegate.corner != corner ||
        oldDelegate.renderProfile != renderProfile;
  }
}

class _StickerPeelShaders {
  _StickerPeelShaders(Rect rect)
    : fallbackFace = ui.Gradient.linear(rect.topLeft, rect.bottomRight, const [
        Color(0xFFF7F6F3),
        Color(0xFFE8E6E1),
      ]),
      shine = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        const [
          Color(0x00FFFFFF),
          Color(0x24CFE4FF),
          Color(0x38FFFFFF),
          Color(0x1FF3D9FF),
          Color(0x00FFFFFF),
        ],
        const [0.25, 0.40, 0.50, 0.60, 0.75],
      ),
      foldInnerShadow = ui.Gradient.linear(
        Offset.zero,
        const Offset(1, 0),
        const [Color(0x33000000), Color(0x00000000)],
      );

  final ui.Gradient fallbackFace;
  final ui.Gradient shine;
  final ui.Gradient foldInnerShadow;
}

class _StickerFoldPaintGeometry {
  _StickerFoldPaintGeometry({
    required this.rect,
    required this.rrect,
    required Path rrectPath,
    required StickerFoldFrame fold,
  }) : extent = rect.longestSide * 3 {
    if (!fold.isFolded) return;

    final peeled = stickerPeeledHalfPlane(fold, extent);
    final stuck = stickerStuckHalfPlane(fold, extent);
    final flap = Path.combine(PathOperation.intersect, rrectPath, peeled);
    final reflectionMatrix = stickerFoldReflection(fold);

    peeledHalfPlane = peeled;
    stuckHalfPlane = stuck;
    flapOnCard = flap;
    reflection = reflectionMatrix;
    reflectedFlapOnCard = flap.transform(reflectionMatrix.storage);
  }

  final Rect rect;
  final RRect rrect;
  final double extent;

  Path? peeledHalfPlane;
  Path? stuckHalfPlane;
  Path? flapOnCard;
  Matrix4? reflection;
  Path? reflectedFlapOnCard;
}
