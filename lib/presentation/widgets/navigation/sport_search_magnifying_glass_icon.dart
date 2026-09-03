import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const String _kSportSearchMagnifyingGlassShaderAsset =
    'assets/shaders/sport_search_magnifying_glass.frag';

/// Transparent magnifying-glass effect for the Sport bottom-nav search tile.
///
/// The shader is an ImageFilter adaptation of Emmanuel Keller/Tambako's
/// "Magnifying glass": the lens samples the real backdrop under the nav, bends
/// it through a convex glass profile, then paints the metallic rim and handle.
class SportSearchMagnifyingGlassIcon extends StatefulWidget {
  final Color color;
  final bool isActive;
  final bool shaderEnabled;
  final double size;

  const SportSearchMagnifyingGlassIcon({
    super.key,
    required this.color,
    required this.isActive,
    this.shaderEnabled = true,
    this.size = 56,
  });

  @override
  State<SportSearchMagnifyingGlassIcon> createState() =>
      _SportSearchMagnifyingGlassIconState();
}

class _SportSearchMagnifyingGlassIconState
    extends State<SportSearchMagnifyingGlassIcon> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    if (widget.shaderEnabled) _loadShader();
  }

  Future<void> _loadShader() async {
    if (!widget.shaderEnabled || _shader != null) return;
    try {
      final program = await ui.FragmentProgram.fromAsset(
        _kSportSearchMagnifyingGlassShaderAsset,
      );
      if (!mounted || !widget.shaderEnabled) return;
      setState(() => _shader = program.fragmentShader());
    } catch (_) {
      // Unsupported test surfaces fall back to RawMagnifier below.
    }
  }

  @override
  void didUpdateWidget(SportSearchMagnifyingGlassIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shaderEnabled == widget.shaderEnabled) return;
    if (widget.shaderEnabled) {
      _loadShader();
    } else {
      // The last scene can still reference the shader on skwasm. Drop our
      // reference and let the NativeFinalizer reclaim it once raster work ends.
      _shader = null;
    }
  }

  @override
  void dispose() {
    // Don't synchronously free the shader: it is captured by this tile's
    // BackdropFilter ImageFilter in the last painted frame, which on web
    // (skwasm) may still be rasterizing on the raster worker when this State is
    // torn down. Freeing it — even one frame later — races that raster and
    // traps the worker (`memory access out of bounds` → frozen tab). Drop the
    // reference and let dart:ui's NativeFinalizer reclaim it on GC, once no
    // scene references it. See docs/dev/skwasm_gpu_resource_disposal.md.
    _shader = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = widget.shaderEnabled ? _shader : null;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child:
            _buildShaderLens(shader) ??
            _FallbackMagnifyingGlass(
              color: widget.color,
              isActive: widget.isActive,
            ),
      ),
    );
  }

  Widget? _buildShaderLens(ui.FragmentShader? shader) {
    if (shader == null || !ui.ImageFilter.isShaderFilterSupported) {
      return null;
    }
    try {
      shader
        ..setFloat(2, widget.color.r)
        ..setFloat(3, widget.color.g)
        ..setFloat(4, widget.color.b)
        ..setFloat(5, widget.color.a)
        ..setFloat(6, widget.isActive ? 1 : 0);
      return ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.shader(shader),
          child: const CustomPaint(
            painter: _FilterCoveragePainter(),
            child: SizedBox.expand(),
          ),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

class _FilterCoveragePainter extends CustomPainter {
  const _FilterCoveragePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = const Color.fromARGB(1, 0, 0, 0)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _FilterCoveragePainter oldDelegate) => false;
}

class _FallbackMagnifyingGlass extends StatelessWidget {
  final Color color;
  final bool isActive;

  const _FallbackMagnifyingGlass({required this.color, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.center,
          child: SizedBox.square(
            dimension: 32,
            child: ClipOval(
              child: _GroupedBackdropMagnifier(
                magnificationScale: 1.72,
                child: const CustomPaint(
                  painter: _FilterCoveragePainter(),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        CustomPaint(
          painter: _FallbackHardwarePainter(color: color, isActive: isActive),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

class _GroupedBackdropMagnifier extends SingleChildRenderObjectWidget {
  final double magnificationScale;

  const _GroupedBackdropMagnifier({
    required this.magnificationScale,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderGroupedBackdropMagnifier(
      magnificationScale: magnificationScale,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderGroupedBackdropMagnifier renderObject,
  ) {
    renderObject.magnificationScale = magnificationScale;
  }
}

class _RenderGroupedBackdropMagnifier extends RenderProxyBox {
  double _magnificationScale;

  _RenderGroupedBackdropMagnifier({required double magnificationScale})
    : _magnificationScale = magnificationScale;

  double get magnificationScale => _magnificationScale;
  set magnificationScale(double value) {
    if (value == _magnificationScale) return;
    _magnificationScale = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }

    final center = Alignment.center.alongSize(size) + offset;
    final translateX = magnificationScale * (center.dx * -1) + center.dx;
    final translateY = magnificationScale * (center.dy * -1) + center.dy;
    final matrix = Matrix4.identity()
      ..translateByDouble(translateX, translateY, 0, 1)
      ..scaleByDouble(
        magnificationScale,
        magnificationScale,
        magnificationScale,
        1,
      );
    final filter = ui.ImageFilter.matrix(
      matrix.storage,
      filterQuality: FilterQuality.high,
    );

    layer ??= BackdropFilterLayer();
    layer!
      ..filter = filter
      ..blendMode = BlendMode.srcOver;
    context.pushLayer(layer!, super.paint, offset);
  }
}

class _FallbackHardwarePainter extends CustomPainter {
  final Color color;
  final bool isActive;

  const _FallbackHardwarePainter({required this.color, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.shortestSide;
    final center = size.center(Offset.zero);
    final radius = scale * 0.285;
    final handleStart = center + Offset(radius * 0.70, radius * 0.70);
    final handleEnd = Offset(size.width * 0.82, size.height * 0.84);
    final strokeWidth = scale * 0.095;

    final handlePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white, isActive ? 0.36 : 0.24)!,
          const Color(0xFF2A2B2F),
        ],
      ).createShader(Offset.zero & size)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(handleStart, handleEnd, handlePaint);

    final connectorPaint = Paint()
      ..color = Color.lerp(color, Colors.white, 0.38)!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(handleStart, strokeWidth * 0.62, connectorPaint);

    final rimPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.white,
          Color.lerp(color, Colors.white, 0.62)!,
          Color.lerp(color, Colors.black, 0.20)!,
          Colors.white,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = scale * 0.030
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, rimPaint);

    final glintPaint = Paint()
      ..color = Colors.white.withValues(alpha: isActive ? 0.78 : 0.58)
      ..strokeWidth = scale * 0.018
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      -2.20,
      1.0,
      false,
      glintPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FallbackHardwarePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isActive != isActive;
  }
}
