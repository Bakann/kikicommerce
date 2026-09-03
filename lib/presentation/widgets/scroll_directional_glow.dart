import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_shaders/flutter_shaders.dart';

const String _kDirectionalGlowShaderAsset =
    'assets/shaders/directional_glow.frag';
const String _kDirectionalGlowNoiseAsset = 'assets/directional_glow_noise.png';

/// Wraps [child] in a directional volumetric glow ("light scattering" / god
/// rays). The principle and the shader come from Selman Ay's "Let it Glow!"
/// pen, where the light source follows the mouse; here it is driven
/// automatically, in one of two modes:
///
///  * default — the source slides vertically as the nearest [Scrollable]
///    scrolls, so the rays sweep direction with the page;
///  * [sweep] — a one-shot intro: a focused point travels once horizontally
///    across the glyphs ([sweepFromPx]…[sweepToPx]) over [sweepPeriod],
///    illuminating each letter, then the glow fades out and the shader is
///    dropped. It plays automatically on appear, independent of scroll.
///
/// [child] should be the *bright* artwork to scatter (e.g. the label drawn
/// white); the shader replaces the child's own painting with the scattered
/// result, so callers that need a legible label paint a crisp copy on top. The
/// scattered light is tinted from [glowColor] near the source toward
/// [falloffColor] with distance (set [falloff] > 0 to enable the gradient).
///
/// Falls back to painting [child] untouched under reduced motion, before the
/// noise texture has loaded, or when no shader is available.
class ScrollDirectionalGlow extends StatefulWidget {
  const ScrollDirectionalGlow({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFFFFE6B0),
    this.falloffColor = const Color(0xFFFFE6B0),
    this.falloff = 0,
    this.sourceX = 0.5,
    this.density = 0.7,
    this.lightStrength = 1.8,
    this.weight = 0.12,
    this.glowStrength = 1.3,
    this.sweep = false,
    this.sweepFromPx = 0,
    this.sweepToPx = 0,
    this.sweepY = 0.5,
    this.sweepPeriod = const Duration(milliseconds: 1500),
    this.onSweepComplete,
  });

  final Widget child;

  /// Tint of the scattered light at the source.
  final Color glowColor;

  /// Tint the scattered light fades toward with distance from the source.
  final Color falloffColor;

  /// How fast the tint shifts from [glowColor] to [falloffColor] (0 = none).
  final double falloff;

  /// Horizontal source position (0…1) in the default scroll mode.
  final double sourceX;

  /// Spread of the scattering march.
  final double density;

  /// Falloff radius of the light. Small values make a focused point (good for
  /// [sweep]); large values keep the whole label lit.
  final double lightStrength;

  /// Per-sample contribution of the scattering.
  final double weight;

  /// Multiplier on the scattered coverage (alpha).
  final double glowStrength;

  /// When true, animate the source horizontally across [sweepFromPx]…
  /// [sweepToPx] instead of tracking the scroll.
  final bool sweep;

  /// Logical-pixel x-range the [sweep] point travels across (relative to the
  /// canvas left). If [sweepToPx] <= [sweepFromPx] the full width is used.
  final double sweepFromPx;
  final double sweepToPx;

  /// Vertical row (0…1) the [sweep] point travels along.
  final double sweepY;

  /// Duration of the one-shot [sweep] pass, after which the glow fades out and
  /// the shader is removed.
  final Duration sweepPeriod;

  /// Called once the [sweep] pass finishes. Used by callers that gate an action
  /// (e.g. opening a drawer) on the scan completing.
  final VoidCallback? onSweepComplete;

  /// Pre-loads the shared noise texture so a later [sweep] starts without a
  /// first-decode delay (e.g. call when a tap-triggered glow is likely). Safe
  /// to call repeatedly.
  static void warmUp() {
    _ScrollDirectionalGlowState._sharedNoise ??=
        _ScrollDirectionalGlowState._loadNoise();
  }

  @override
  State<ScrollDirectionalGlow> createState() => _ScrollDirectionalGlowState();
}

class _ScrollDirectionalGlowState extends State<ScrollDirectionalGlow>
    with SingleTickerProviderStateMixin {
  // The noise texture is identical for every instance, so load it once.
  static Future<ui.Image>? _sharedNoise;

  static Future<ui.Image> _loadNoise() async {
    final data = await rootBundle.load(_kDirectionalGlowNoiseAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  ui.Image? _noise;
  ScrollPosition? _position;
  AnimationController? _sweepController;
  bool _reduceMotion = false;
  bool _sweepStarted = false;
  bool _sweepDone = false;
  // Light source Y in canvas space; 0.5 keeps it centred until the first scroll
  // read lands.
  double _sourceY = 0.5;

  @override
  void initState() {
    super.initState();
    if (widget.sweep) {
      _sweepController =
          AnimationController(vsync: this, duration: widget.sweepPeriod)
            ..addStatusListener((status) {
              // The scan is a one-shot intro: drop the shader once it finishes.
              if (status == AnimationStatus.completed && mounted) {
                setState(() => _sweepDone = true);
                widget.onSweepComplete?.call();
              }
            });
    }
    (_sharedNoise ??= _loadNoise()).then((image) {
      if (!mounted) return;
      setState(() => _noise = image);
      _maybeStartSweep();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.sweep) {
      // The scan plays automatically, independent of any scroll position.
      _maybeStartSweep();
      return;
    }
    final next = Scrollable.maybeOf(context)?.position;
    if (next != _position) {
      _position?.removeListener(_handleScroll);
      _position = next;
      _position?.addListener(_handleScroll);
    }
    // Resolve the initial direction once geometry exists.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _position?.removeListener(_handleScroll);
    _sweepController?.dispose();
    super.dispose();
  }

  // The source follows the canvas's vertical position so the rays sweep as it
  // scrolls through. One coalesced geometry read per scroll notification — the
  // landing scroll is jank-sensitive.
  void _handleScroll() {
    if (!mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    final viewportBox = scrollable?.context.findRenderObject() as RenderBox?;
    if (scrollable == null ||
        box == null ||
        viewportBox == null ||
        !box.hasSize ||
        !viewportBox.hasSize) {
      return;
    }
    final viewport = scrollable.position.viewportDimension;
    if (viewport <= 0) return;
    final topDy = box.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
    final next = ((topDy + box.size.height / 2) / viewport).clamp(-0.5, 1.5);
    if ((next - _sourceY).abs() < 0.002) return;
    setState(() => _sourceY = next);
  }

  // Plays the scan exactly once, as soon as the noise is ready (and motion is
  // allowed). Guarded so it never restarts.
  void _maybeStartSweep() {
    if (!widget.sweep || _sweepStarted || _sweepDone) return;
    final controller = _sweepController;
    if (controller == null || _noise == null || _reduceMotion) return;
    _sweepStarted = true;
    controller.forward(from: 0);
  }

  void _drawGlow(
    ui.FragmentShader shader,
    ui.Image image,
    Size size,
    ui.Canvas canvas,
    ui.Image noise,
  ) {
    if (size.isEmpty) return;
    final double sourceX;
    final double sourceY;
    var glowStrength = widget.glowStrength;
    if (widget.sweep) {
      final to = widget.sweepToPx > widget.sweepFromPx
          ? widget.sweepToPx
          : size.width;
      final t = _sweepController?.value ?? 0.0;
      // The point completes its travel by 85% of the timeline, then the glow
      // fades out over the final 15% so the shader disappears cleanly.
      final travel = (t / 0.85).clamp(0.0, 1.0);
      final x = ui.lerpDouble(widget.sweepFromPx, to, travel)!;
      sourceX = (x / size.width).clamp(0.0, 1.0);
      sourceY = widget.sweepY;
      final fade = t <= 0.85 ? 1.0 : (1.0 - (t - 0.85) / 0.15);
      glowStrength *= fade.clamp(0.0, 1.0);
    } else {
      sourceX = widget.sourceX;
      sourceY = _sourceY;
    }
    final glow = widget.glowColor;
    final fall = widget.falloffColor;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, sourceX)
      ..setFloat(3, sourceY)
      ..setFloat(4, widget.density)
      ..setFloat(5, widget.lightStrength)
      ..setFloat(6, widget.weight)
      ..setFloat(7, glow.r)
      ..setFloat(8, glow.g)
      ..setFloat(9, glow.b)
      ..setFloat(10, fall.r)
      ..setFloat(11, fall.g)
      ..setFloat(12, fall.b)
      ..setFloat(13, widget.falloff)
      ..setFloat(14, glowStrength)
      ..setImageSampler(0, image)
      ..setImageSampler(1, noise);
    canvas.drawRect(Offset.zero & size, ui.Paint()..shader = shader);
  }

  @override
  Widget build(BuildContext context) {
    final noise = _noise;
    if (noise == null || _reduceMotion || _sweepDone) {
      return widget.child;
    }
    final controller = _sweepController;
    return RepaintBoundary(
      child: controller == null
          // Scroll mode: repaints on scroll via setState.
          ? _glowTree(noise)
          // Sweep mode: rebuild the shader subtree every frame of the scan so
          // the AnimatedSampler actually repaints with the live source position
          // (returning a cached subtree would freeze it).
          : AnimatedBuilder(
              animation: controller,
              builder: (context, _) => _glowTree(noise),
            ),
    );
  }

  Widget _glowTree(ui.Image noise) {
    return ShaderBuilder(
      (context, shader, child) {
        return AnimatedSampler((ui.Image image, Size size, ui.Canvas canvas) {
          _drawGlow(shader, image, size, canvas, noise);
        }, child: child ?? const SizedBox.shrink());
      },
      assetKey: _kDirectionalGlowShaderAsset,
      child: widget.child,
    );
  }
}

/// Paints [text] (in its [style] colour) as plain glyphs sized exactly to the
/// laid-out text. Intended as the bright input for [ScrollDirectionalGlow]: it
/// is deliberately not a [Text] widget, so a crisp [Text] copy can stay the
/// only findable/selectable label on top.
class GlyphGlowSource extends StatelessWidget {
  const GlyphGlowSource({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return CustomPaint(size: painter.size, painter: _GlyphPainter(painter));
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.painter);

  final TextPainter painter;

  @override
  void paint(Canvas canvas, Size size) => painter.paint(canvas, Offset.zero);

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.painter != painter;
}
