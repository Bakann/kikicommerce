import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'scroll_motion_signal.dart';

const String _kShaderAsset = 'assets/shaders/iridescent_home_ring.frag';
const String _kExoticParticlesBufferAsset =
    'assets/shaders/exotic_particles_buffer.frag';
const String _kExoticParticlesImageAsset =
    'assets/shaders/exotic_particles_image.frag';

/// Procedural Exotic Particles disc for the Home destination.
///
/// Renders the two-pass Shadertoy feedback shader as a Home ring, an opaque
/// center behind [child], and a soft halo that spills onto the nav surface.
class IridescentNavRing extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final bool isLoading;
  final bool staticFallback;
  final int playToken;
  final double diameter;
  final double visualDiameter;

  /// Live scroll velocity. When supplied, it advances the shader clock while
  /// the user scrolls. Null keeps the resting, scroll-independent look.
  final ScrollMotionSignal? scrollMotion;

  const IridescentNavRing({
    super.key,
    required this.child,
    required this.isActive,
    this.isLoading = false,
    this.staticFallback = false,
    required this.playToken,
    this.scrollMotion,
    this.diameter = 40,
    this.visualDiameter = 128,
  });

  @override
  State<IridescentNavRing> createState() => _IridescentNavRingState();
}

class _IridescentNavRingState extends State<IridescentNavRing>
    with TickerProviderStateMixin {
  static const Duration _cycleDuration = Duration(milliseconds: 6150);
  static const int _feedbackTextureSize = 96;
  static const double _shaderStartTimeSeconds = 4.0;
  static const double _loadingShaderVelocity = 1.15;
  static const double _loadingStartVelocity = 0.45;
  static const double _loadingAccelerationRate = 9.0;
  static const double _loadingDecelerationRate = 2.6;
  static const double _loadingStopVelocity = 0.012;

  late final AnimationController _controller;
  late final Ticker _loadingTicker;

  // Repaints the ring on either its own intro cycle or a scroll-velocity tick.
  late Listenable _repaint;

  ui.FragmentShader? _shader;
  ui.FragmentProgram? _bufferProgram;
  ui.FragmentProgram? _imageProgram;
  ui.Image? _previousBufferImage;
  ui.Image? _displayImage;
  var _feedbackFrame = 0;
  var _feedbackRendering = false;
  var _feedbackRenderQueued = false;
  var _feedbackSeedLoading = false;
  var _latestFeedbackTime = 0.0;
  Duration? _lastLoadingTick;
  double _loadingTimeSeconds = 0.0;
  double _loadingVelocity = 0.0;
  double _loadingTargetVelocity = 0.0;
  bool _startedInitialCycle = false;
  bool _shaderLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycleDuration);
    _loadingTicker = createTicker(_onLoadingTick);
    _controller.addListener(_onFeedbackTick);
    widget.scrollMotion?.addListener(_onFeedbackTick);
    _repaint = _buildRepaintListenable();
    if (!widget.staticFallback) {
      unawaited(_loadShader());
    }
  }

  Listenable _buildRepaintListenable() {
    final motion = widget.scrollMotion;
    return motion == null
        ? _controller
        : Listenable.merge([_controller, motion]);
  }

  Future<void> _loadShader() async {
    if (widget.staticFallback || _shaderLoading || _shader != null) return;
    _shaderLoading = true;
    try {
      final programs = await Future.wait([
        ui.FragmentProgram.fromAsset(_kShaderAsset),
        ui.FragmentProgram.fromAsset(_kExoticParticlesBufferAsset),
        ui.FragmentProgram.fromAsset(_kExoticParticlesImageAsset),
      ]);
      if (!mounted || widget.staticFallback) return;
      setState(() {
        _shader = programs[0].fragmentShader();
        _bufferProgram = programs[1];
        _imageProgram = programs[2];
      });
      unawaited(_ensureFeedbackSeed());
    } catch (_) {
      // Keep the CustomPainter fallback if the shader cannot be compiled in the
      // current surface, including widget tests.
    } finally {
      _shaderLoading = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startInitialCycleIfNeeded();
    _syncLoadingMotion();
  }

  void _startInitialCycleIfNeeded() {
    if (widget.staticFallback ||
        _startedInitialCycle ||
        !widget.isActive ||
        widget.scrollMotion == null) {
      return;
    }
    _startedInitialCycle = true;
    _play();
  }

  @override
  void didUpdateWidget(IridescentNavRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollMotion != oldWidget.scrollMotion) {
      oldWidget.scrollMotion?.removeListener(_onFeedbackTick);
      widget.scrollMotion?.addListener(_onFeedbackTick);
      _repaint = _buildRepaintListenable();
    }
    if (widget.staticFallback != oldWidget.staticFallback) {
      if (widget.staticFallback) {
        _pauseForStaticFallback();
      } else {
        unawaited(_loadShader());
        _startInitialCycleIfNeeded();
        _syncLoadingMotion();
      }
    }
    final becameActive = widget.isActive && !oldWidget.isActive;
    final tapped = widget.playToken != oldWidget.playToken;
    if (becameActive || tapped) _play();
    if (widget.isLoading != oldWidget.isLoading) {
      _syncLoadingMotion();
    }
    if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  void _play() {
    if (!mounted || widget.staticFallback) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  void _onFeedbackTick() {
    if (widget.staticFallback) return;
    final t = _controller.value;
    final motion = widget.scrollMotion;
    final time =
        t * _cycleDuration.inMilliseconds / 1000 +
        _loadingTimeSeconds +
        (motion?.animTime ?? 0);
    _scheduleFeedbackRender(time);
  }

  void _syncLoadingMotion() {
    if (widget.staticFallback || MediaQuery.disableAnimationsOf(context)) {
      _loadingTargetVelocity = 0;
      _loadingVelocity = 0;
      _stopLoadingTicker();
      return;
    }

    _loadingTargetVelocity = widget.isLoading ? _loadingShaderVelocity : 0;
    if (widget.isLoading && _loadingVelocity < _loadingStartVelocity) {
      _loadingVelocity = _loadingStartVelocity;
    }
    _startLoadingTickerIfNeeded();
  }

  void _onLoadingTick(Duration elapsed) {
    final last = _lastLoadingTick;
    _lastLoadingTick = elapsed;
    if (last == null) {
      _onFeedbackTick();
      return;
    }

    final deltaSeconds =
        (elapsed - last).inMicroseconds / Duration.microsecondsPerSecond;
    if (deltaSeconds <= 0) return;

    final rate = _loadingTargetVelocity > _loadingVelocity
        ? _loadingAccelerationRate
        : _loadingDecelerationRate;
    final blend = (deltaSeconds * rate).clamp(0.0, 1.0);
    _loadingVelocity += (_loadingTargetVelocity - _loadingVelocity) * blend;
    if (_loadingTargetVelocity == 0 &&
        _loadingVelocity < _loadingStopVelocity) {
      _loadingVelocity = 0;
    }

    _loadingTimeSeconds += _loadingVelocity * deltaSeconds;
    _onFeedbackTick();

    if (_loadingVelocity == 0 && _loadingTargetVelocity == 0) {
      _stopLoadingTicker();
    }
  }

  void _startLoadingTickerIfNeeded() {
    if (widget.staticFallback || !_canRenderFeedback) return;
    if (_loadingTargetVelocity == 0 &&
        _loadingVelocity <= _loadingStopVelocity) {
      return;
    }
    if (_loadingTicker.isActive) return;
    _lastLoadingTick = null;
    _loadingTicker.start();
  }

  void _stopLoadingTicker() {
    if (_loadingTicker.isActive) {
      _loadingTicker.stop();
    }
    _lastLoadingTick = null;
  }

  void _pauseForStaticFallback() {
    _controller.stop();
    _controller.value = 0;
    _loadingTargetVelocity = 0;
    _loadingVelocity = 0;
    _feedbackRenderQueued = false;
    _startedInitialCycle = false;
    _stopLoadingTicker();
  }

  bool get _canRenderFeedback {
    return _bufferProgram != null &&
        _imageProgram != null &&
        _previousBufferImage != null;
  }

  Future<void> _ensureFeedbackSeed() async {
    if (widget.staticFallback ||
        _previousBufferImage != null ||
        _feedbackSeedLoading) {
      return;
    }
    _feedbackSeedLoading = true;
    final seed = await _renderSolidImage(
      _feedbackTextureSize,
      _feedbackTextureSize,
      const Color(0xFF000000),
    );
    if (!mounted || widget.staticFallback) {
      seed.dispose();
      _feedbackSeedLoading = false;
      return;
    }
    _previousBufferImage = seed;
    _feedbackSeedLoading = false;
    _scheduleFeedbackRender(_latestFeedbackTime);
    _startLoadingTickerIfNeeded();
  }

  Future<ui.Image> _renderSolidImage(int width, int height, Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = color,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  void _scheduleFeedbackRender(double time) {
    _latestFeedbackTime = time;
    if (widget.staticFallback) return;
    if (_feedbackRendering) {
      _feedbackRenderQueued = true;
      return;
    }
    final previous = _previousBufferImage;
    if (_bufferProgram == null || _imageProgram == null || previous == null) {
      return;
    }

    _feedbackRendering = true;
    unawaited(
      _renderFeedbackFrame(
            time: time,
            frame: _feedbackFrame,
            previous: previous,
          )
          .then((frame) {
            if (!mounted || widget.staticFallback) {
              frame.dispose();
              return;
            }
            final oldPrevious = _previousBufferImage;
            final oldDisplay = _displayImage;
            _previousBufferImage = frame.buffer;
            _displayImage = frame.display;
            _feedbackFrame += 1;
            if (oldPrevious != null && oldPrevious != previous) {
              _disposeImageAfterFrame(oldPrevious);
            }
            _disposeImageAfterFrame(previous);
            if (oldDisplay != null) {
              _disposeImageAfterFrame(oldDisplay);
            }
            setState(() {});
          })
          .catchError((_) {
            // Keep the last good feedback texture or the Canvas fallback.
          })
          .whenComplete(() {
            _feedbackRendering = false;
            if (!mounted || widget.staticFallback) return;
            if (!_feedbackRenderQueued) return;
            _feedbackRenderQueued = false;
            _scheduleFeedbackRender(_latestFeedbackTime);
          }),
    );
  }

  Future<_FeedbackFrame> _renderFeedbackFrame({
    required double time,
    required int frame,
    required ui.Image previous,
  }) async {
    final bufferShader = _bufferProgram!.fragmentShader();
    final ui.Image buffer;
    try {
      buffer = await _drawShaderToImage(
        shader: bufferShader
          ..setFloat(0, _feedbackTextureSize.toDouble())
          ..setFloat(1, _feedbackTextureSize.toDouble())
          ..setFloat(2, time + _shaderStartTimeSeconds)
          ..setFloat(3, frame.toDouble())
          ..setImageSampler(0, previous),
        width: _feedbackTextureSize,
        height: _feedbackTextureSize,
      );
    } finally {
      bufferShader.dispose();
    }

    try {
      final imageShader = _imageProgram!.fragmentShader();
      final ui.Image display;
      try {
        display = await _drawShaderToImage(
          shader: imageShader
            ..setFloat(0, _feedbackTextureSize.toDouble())
            ..setFloat(1, _feedbackTextureSize.toDouble())
            ..setImageSampler(0, buffer),
          width: _feedbackTextureSize,
          height: _feedbackTextureSize,
        );
      } finally {
        imageShader.dispose();
      }
      return _FeedbackFrame(buffer: buffer, display: display);
    } catch (_) {
      buffer.dispose();
      rethrow;
    }
  }

  Future<ui.Image> _drawShaderToImage({
    required ui.FragmentShader shader,
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..shader = shader,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  void _disposeImageAfterFrame(ui.Image image) {
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  @override
  void dispose() {
    widget.scrollMotion?.removeListener(_onFeedbackTick);
    _loadingTicker.dispose();
    _controller.dispose();
    // Do NOT synchronously free the shader / feedback images here. On web
    // (skwasm) the raster worker rasterizes asynchronously, so the last scene
    // painted with these objects can still be in flight on that worker when
    // this State is torn down during a (cross-shell) navigation. Freeing them
    // now — or even one frame later via a post-frame callback, which still runs
    // before the worker finishes — races the raster and traps the worker with
    // `memory access out of bounds`; the main thread then blocks on the dead
    // worker (Atomics.wait) and the tab freezes. Drop the references instead
    // and let dart:ui's NativeFinalizer reclaim the native resources on GC,
    // which happens only once no scene references them any more. Any in-flight
    // feedback render still holds `previous` through its closure, so it stays
    // alive until that render completes. See
    // docs/dev/skwasm_gpu_resource_disposal.md.
    _shader = null;
    _previousBufferImage = null;
    _displayImage = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.diameter,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            OverflowBox(
              maxWidth: widget.visualDiameter,
              maxHeight: widget.visualDiameter,
              child: SizedBox.square(
                dimension: widget.visualDiameter,
                child: widget.staticFallback
                    ? CustomPaint(
                        painter: _FallbackLensPainter(
                          glow: widget.isActive ? 1.0 : 0.72,
                        ),
                      )
                    : AnimatedBuilder(
                        animation: _repaint,
                        builder: (context, _) {
                          final glow = widget.isActive ? 1.0 : 0.72;
                          final shader = _shader;
                          final displayImage = _displayImage;
                          if (shader == null || displayImage == null) {
                            return CustomPaint(
                              painter: _FallbackLensPainter(glow: glow),
                            );
                          }
                          return CustomPaint(
                            painter: _ShaderLensPainter(
                              shader: shader,
                              particleImage: displayImage,
                            ),
                          );
                        },
                      ),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _ShaderLensPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final ui.Image particleImage;

  const _ShaderLensPainter({required this.shader, required this.particleImage});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setImageSampler(0, particleImage);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _ShaderLensPainter oldDelegate) {
    return oldDelegate.shader != shader ||
        oldDelegate.particleImage != particleImage;
  }
}

class _FeedbackFrame {
  final ui.Image buffer;
  final ui.Image display;

  const _FeedbackFrame({required this.buffer, required this.display});

  void dispose() {
    buffer.dispose();
    display.dispose();
  }
}

class _FallbackLensPainter extends CustomPainter {
  final double glow;

  const _FallbackLensPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final baseRadius = radius < 28 ? radius : 28.0;
    final outerRadius = baseRadius * 0.9;
    final innerRadius = baseRadius * 0.77;
    final ringRadius = (outerRadius + innerRadius) / 2;
    final ringWidth = outerRadius - innerRadius;
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final centerRect = Rect.fromCircle(center: center, radius: innerRadius);
    final haloRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.95,
      height: size.height * 0.62,
    );

    canvas.drawOval(
      haloRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF64F5FF).withValues(alpha: 0.16 * glow),
            const Color(0xFFFF33C8).withValues(alpha: 0.11 * glow),
            Colors.transparent,
          ],
          stops: const [0.0, 0.46, 1.0],
        ).createShader(haloRect)
        ..blendMode = BlendMode.plus,
    );

    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..shader = SweepGradient(
          colors: [
            const Color(0xFF64F5FF).withValues(alpha: 0.78 * glow),
            const Color(0xFFFF33C8).withValues(alpha: 0.74 * glow),
            const Color(0xFFFFE85A).withValues(alpha: 0.64 * glow),
            const Color(0xFF4434FF).withValues(alpha: 0.78 * glow),
            const Color(0xFF64F5FF).withValues(alpha: 0.78 * glow),
          ],
        ).createShader(centerRect),
    );

    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.38, -0.42),
          radius: 0.92,
          colors: [
            Colors.white.withValues(alpha: 0.24 * glow),
            Colors.white.withValues(alpha: 0.06 * glow),
            Colors.black.withValues(alpha: 0.16 * glow),
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(centerRect),
    );

    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..shader = SweepGradient(
          colors: [
            const Color(0xFF64F5FF).withValues(alpha: glow),
            const Color(0xFF4434FF).withValues(alpha: glow),
            const Color(0xFFFF33C8).withValues(alpha: glow),
            const Color(0xFFFFE85A).withValues(alpha: glow),
            const Color(0xFF64F5FF).withValues(alpha: glow),
          ],
        ).createShader(outerRect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.03),
    );

    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.34 * glow),
            Colors.white.withValues(alpha: 0),
          ],
          stops: [0.0, 0.74],
        ).createShader(centerRect)
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(covariant _FallbackLensPainter oldDelegate) {
    return oldDelegate.glow != glow;
  }
}
