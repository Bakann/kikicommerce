import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
import 'package:flutter/material.dart';

import '../../data/models/product_foil.dart';

/// Paints the Foil studio 2.5D bundle over the normal PDP image.
///
/// The source, subject mask, reconstructed background and rim are generated at
/// identical dimensions. One shared source crop keeps them aligned for every
/// BoxFit used by the PDP. The original image widget remains underneath as a
/// loading/error fallback and for pixels outside a `contain` destination.
class ProductFoilVolumePainter extends CustomPainter {
  ProductFoilVolumePainter({
    required this.source,
    required this.subjectMask,
    required this.background,
    required this.rim,
    required this.fit,
    required this.alignment,
    required this.depthMesh,
    required this.particles,
    required this.particleTime,
    required this.sweep,
    required this.hover,
    required this.pointer,
    required this.tilt,
    required this.motionEnabled,
    required this.webMobileSafe,
  }) : _sourceShader = _imageShader(source),
       _maskShader = _imageShader(subjectMask),
       _rimShader = _imageShader(rim),
       _meshIndices = _buildIndices(depthMesh),
       super(
         repaint: Listenable.merge([particleTime, sweep, hover, pointer, tilt]),
       );

  final ui.Image source;
  final ui.Image subjectMask;
  final ui.Image background;
  final ui.Image rim;
  final BoxFit fit;
  final Alignment alignment;
  final ProductFoilDepthMesh? depthMesh;
  final List<ProductFoilParticleSeed> particles;
  final ValueListenable<double> particleTime;
  final Animation<double> sweep;
  final Animation<double> hover;
  final ValueListenable<Offset?> pointer;
  final ValueListenable<Offset?> tilt;
  final bool motionEnabled;
  final bool webMobileSafe;

  final ui.ImageShader _sourceShader;
  final ui.ImageShader _maskShader;
  final ui.ImageShader _rimShader;
  final Uint16List? _meshIndices;

  static const double _backgroundScale = 1.025;
  static const double _subjectScale = 1.02;
  static const double _backgroundTravel = 0.020;
  static const double _subjectTravel = 0.012;
  static const double _depthTravel = 0.014;
  static final ui.Gradient _rimReveal = ui.Gradient.radial(
    Offset.zero,
    1,
    const [Colors.white, Color(0x00FFFFFF)],
  );

  @visibleForTesting
  static Offset particleOrbitOffset({
    required int index,
    required double progress,
    required double radius,
  }) {
    final phase = index * 2.399963229728653;
    final turns = 1 + (index % 2);
    final angle = progress * math.pi * 2 * turns + phase;
    return Offset(math.cos(angle), math.sin(angle) * 0.8) * radius;
  }

  @visibleForTesting
  static double particleTwinkle({
    required int index,
    required double progress,
  }) {
    final phase = index * 2.399963229728653;
    final turns = 2 + (index % 3);
    return 0.55 + 0.45 * math.sin(progress * math.pi * 2 * turns + phase);
  }

  static ui.ImageShader _imageShader(ui.Image image) => ui.ImageShader(
    image,
    TileMode.clamp,
    TileMode.clamp,
    Float64List.fromList(Matrix4.identity().storage),
  );

  static Uint16List? _buildIndices(ProductFoilDepthMesh? depth) {
    if (depth == null) return null;
    final indices = Uint16List((depth.columns - 1) * (depth.rows - 1) * 6);
    var at = 0;
    for (var row = 0; row < depth.rows - 1; row++) {
      for (var column = 0; column < depth.columns - 1; column++) {
        final topLeft = row * depth.columns + column;
        final topRight = topLeft + 1;
        final bottomLeft = topLeft + depth.columns;
        final bottomRight = bottomLeft + 1;
        indices[at++] = topLeft;
        indices[at++] = bottomLeft;
        indices[at++] = topRight;
        indices[at++] = topRight;
        indices[at++] = bottomLeft;
        indices[at++] = bottomRight;
      }
    }
    return indices;
  }

  ({Rect source, Rect destination}) _fittedRects(Size size) {
    final bounds = Offset.zero & size;
    final imageSize = Size(source.width.toDouble(), source.height.toDouble());
    final fitted = applyBoxFit(fit, imageSize, size);
    return (
      source: alignment.inscribe(fitted.source, Offset.zero & imageSize),
      destination: alignment.inscribe(fitted.destination, bounds),
    );
  }

  static Rect _scaledAndShifted(Rect rect, double scale, Offset shift) {
    return Rect.fromCenter(
      center: rect.center + shift,
      width: rect.width * scale,
      height: rect.height * scale,
    );
  }

  Offset _normalisedMotion(Size size) {
    if (!motionEnabled) return const Offset(0.5, 0.5);
    final pointerPosition = pointer.value;
    if (pointerPosition != null && !size.isEmpty) {
      return Offset(
        (pointerPosition.dx / size.width).clamp(0.0, 1.0),
        (pointerPosition.dy / size.height).clamp(0.0, 1.0),
      );
    }
    final tiltPosition = tilt.value;
    if (tiltPosition != null) return tiltPosition;
    // Let the initial light sweep briefly reveal the layer separation.
    if (sweep.status == AnimationStatus.forward) {
      return Offset(
        (sweep.value * 1.4 - 0.2).clamp(0.0, 1.0),
        (0.25 + sweep.value * 0.5).clamp(0.0, 1.0),
      );
    }
    return const Offset(0.5, 0.5);
  }

  double get _motionEnergy {
    if (!motionEnabled) return 0;
    final sweepEnergy = sweep.status == AnimationStatus.forward
        ? math.sin(math.pi * sweep.value)
        : 0.0;
    return math.max(
      sweepEnergy,
      math.max(hover.value, tilt.value == null ? 0.0 : 1.0),
    );
  }

  void _drawImage(
    Canvas canvas,
    ui.Image image,
    Rect sourceRect,
    Rect destinationRect,
    Paint paint,
  ) {
    canvas.drawImageRect(image, sourceRect, destinationRect, paint);
  }

  void _drawShadow(
    Canvas canvas,
    Rect bounds,
    Rect sourceRect,
    Rect destinationRect, {
    required double sigma,
    required double alpha,
  }) {
    if (alpha <= 0) return;
    canvas.saveLayer(
      bounds,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
    _drawImage(
      canvas,
      subjectMask,
      sourceRect,
      destinationRect,
      Paint()
        ..colorFilter = ColorFilter.mode(
          Colors.black.withValues(alpha: alpha),
          BlendMode.srcIn,
        ),
    );
    canvas.restore();
  }

  ui.Vertices? _subjectVertices(
    Rect sourceRect,
    Rect destinationRect,
    Offset motion,
    double energy,
  ) {
    final depth = depthMesh;
    final indices = _meshIndices;
    if (depth == null || indices == null || energy <= 0.01) return null;

    final count = depth.columns * depth.rows;
    final positions = Float32List(count * 2);
    final textureCoordinates = Float32List(count * 2);
    final direction = motion - const Offset(0.5, 0.5);
    final amplitude = destinationRect.width * _depthTravel * energy;

    for (var row = 0; row < depth.rows; row++) {
      final v = row / (depth.rows - 1);
      final sourceY = sourceRect.top + sourceRect.height * v;
      for (var column = 0; column < depth.columns; column++) {
        final u = column / (depth.columns - 1);
        final sourceX = sourceRect.left + sourceRect.width * u;
        final displacement =
            direction *
            (amplitude *
                depth.sample(sourceX / source.width, sourceY / source.height));
        final index = row * depth.columns + column;
        positions[index * 2] =
            destinationRect.left + destinationRect.width * u + displacement.dx;
        positions[index * 2 + 1] =
            destinationRect.top + destinationRect.height * v + displacement.dy;
        textureCoordinates[index * 2] = sourceX;
        textureCoordinates[index * 2 + 1] = sourceY;
      }
    }
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: textureCoordinates,
      indices: indices,
    );
  }

  void _drawMesh(
    Canvas canvas,
    ui.Vertices vertices,
    ui.ImageShader shader, {
    BlendMode compositeMode = BlendMode.srcOver,
    ColorFilter? colorFilter,
  }) {
    final paint = Paint()
      ..shader = shader
      ..filterQuality = FilterQuality.medium
      ..blendMode = compositeMode;
    if (colorFilter != null) paint.colorFilter = colorFilter;
    canvas.drawVertices(vertices, BlendMode.src, paint);
  }

  void _drawParticles(
    Canvas canvas,
    Rect sourceRect,
    Rect subjectRect,
    Offset motion,
    double energy,
  ) {
    if (particles.isEmpty) return;
    final warm = Paint()..blendMode = BlendMode.plus;
    final cool = Paint()..blendMode = BlendMode.plus;
    final maxVisibleParticles = webMobileSafe ? 80 : 180;
    final stride = particles.length > maxVisibleParticles
        ? (particles.length / maxVisibleParticles).ceil()
        : 1;

    for (var index = 0; index < particles.length; index += stride) {
      final seed = particles[index];
      final sourceX = seed.x * source.width;
      final sourceY = seed.y * source.height;
      if (!sourceRect.contains(Offset(sourceX, sourceY))) continue;
      final u = (sourceX - sourceRect.left) / sourceRect.width;
      final v = (sourceY - sourceRect.top) / sourceRect.height;
      var position = Offset(
        subjectRect.left + subjectRect.width * u,
        subjectRect.top + subjectRect.height * v,
      );
      final depth = depthMesh;
      if (depth != null && energy > 0.01) {
        position +=
            (motion - const Offset(0.5, 0.5)) *
            (subjectRect.width *
                _depthTravel *
                energy *
                depth.sample(seed.x, seed.y));
      }
      // A deterministic orbit keeps sparkles floating independently from the
      // subject instead of looking baked into its texture. Pointer/tilt adds
      // a small extra parallax so the particle plane reads in front of it.
      // Whole turn counts make the five-second animation a closed loop:
      // position and brightness at t=1 are identical to those at t=0.
      final driftRadius = subjectRect.width * (0.007 + seed.brightness * 0.004);
      position += particleOrbitOffset(
        index: index,
        progress: particleTime.value,
        radius: driftRadius,
      );
      position +=
          (motion - const Offset(0.5, 0.5)) *
          (subjectRect.width * (0.005 + seed.brightness * 0.003) * energy);

      final twinkle = particleTwinkle(
        index: index,
        progress: particleTime.value,
      );
      final alpha = (0.18 + seed.brightness * 0.5) * twinkle;
      final radius = subjectRect.width * (0.0018 + seed.brightness * 0.0018);
      warm.color = const Color(0xFFFFE9B0).withValues(alpha: alpha);
      cool.color = const Color(0xFFB9E8FF).withValues(alpha: alpha * 0.55);
      canvas.drawCircle(position, radius, warm);
      if (index.isEven) {
        canvas.drawCircle(position, radius * 0.45, cool);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final rects = _fittedRects(size);
    final motion = _normalisedMotion(size);
    final direction = motion - const Offset(0.5, 0.5);
    final energy = _motionEnergy;
    final unit = rects.destination.width;
    final smooth = Paint()..filterQuality = FilterQuality.medium;

    canvas.save();
    canvas.clipRect(bounds);

    final backgroundRect = _scaledAndShifted(
      rects.destination,
      _backgroundScale,
      -direction * (unit * _backgroundTravel),
    );
    _drawImage(canvas, background, rects.source, backgroundRect, smooth);

    final subjectRect = _scaledAndShifted(
      rects.destination,
      _subjectScale,
      direction * (unit * _subjectTravel),
    );
    // Moving blurs are intentionally omitted on web-mobile: skwasm/WebGL can
    // otherwise discover an expensive blur program on the first sensor
    // gesture. The real-surface intro sweep prewarms the remaining mesh/rim
    // path before interaction.
    if (!webMobileSafe) {
      _drawShadow(
        canvas,
        bounds,
        rects.source,
        subjectRect.shift(
          Offset(
            -direction.dx * unit * 0.004,
            -direction.dy * unit * 0.004 + rects.destination.height * 0.003,
          ),
        ),
        sigma: math.max(0.8, unit * 0.006),
        alpha: 0.14 + 0.04 * energy,
      );
      if (energy > 0.01) {
        _drawShadow(
          canvas,
          bounds,
          rects.source,
          subjectRect.shift(
            Offset(
              -direction.dx * unit * 0.016,
              -direction.dy * unit * 0.016 + rects.destination.height * 0.005,
            ),
          ),
          sigma: math.max(1.0, unit * 0.013),
          alpha: 0.14 * energy,
        );
      }
    }

    final vertices = _subjectVertices(
      rects.source,
      subjectRect,
      motion,
      energy,
    );
    canvas.saveLayer(bounds, smooth);
    if (vertices == null) {
      _drawImage(canvas, source, rects.source, subjectRect, smooth);
      _drawImage(
        canvas,
        subjectMask,
        rects.source,
        subjectRect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..filterQuality = FilterQuality.medium,
      );
    } else {
      _drawMesh(canvas, vertices, _sourceShader);
      _drawMesh(canvas, vertices, _maskShader, compositeMode: BlendMode.dstIn);
    }
    canvas.restore();

    if (energy > 0.01) {
      const rimColor = Color(0xFFB9E8FF);
      canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.plus);
      final rimFilter = ColorFilter.mode(
        rimColor.withValues(alpha: 0.35 * energy),
        BlendMode.srcIn,
      );
      if (vertices == null) {
        _drawImage(
          canvas,
          rim,
          rects.source,
          subjectRect,
          Paint()..colorFilter = rimFilter,
        );
      } else {
        _drawMesh(canvas, vertices, _rimShader, colorFilter: rimFilter);
      }
      final center = Offset(
        rects.destination.left + rects.destination.width * motion.dx,
        rects.destination.top + rects.destination.height * motion.dy,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(unit * 0.55, unit * 0.55);
      canvas.drawCircle(
        Offset.zero,
        1,
        Paint()
          ..blendMode = BlendMode.srcIn
          ..shader = _rimReveal,
      );
      canvas.restore();
      canvas.restore();
    }

    _drawParticles(canvas, rects.source, subjectRect, motion, energy);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ProductFoilVolumePainter oldDelegate) =>
      oldDelegate.source != source ||
      oldDelegate.subjectMask != subjectMask ||
      oldDelegate.background != background ||
      oldDelegate.rim != rim ||
      oldDelegate.fit != fit ||
      oldDelegate.alignment != alignment ||
      oldDelegate.depthMesh != depthMesh ||
      oldDelegate.particles != particles ||
      oldDelegate.particleTime != particleTime ||
      oldDelegate.motionEnabled != motionEnabled ||
      oldDelegate.webMobileSafe != webMobileSafe;
}
