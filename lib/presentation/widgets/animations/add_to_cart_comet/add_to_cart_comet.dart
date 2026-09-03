import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../providers/cart_flight_coordinator_provider.dart';
import '../../kiki_image.dart';
import '../../storefront_layout.dart';
import 'add_to_cart_comet_render_profile.dart';
import 'comet_flight_geometry.dart';
import 'sticker_peel_geometry.dart';
import 'sticker_peel_painter.dart';

/// Handle returned by [AddToCartCometController.launch]; the card's
/// add-to-cart flow reports the async outcome through it so the impact
/// celebration only plays when the add actually succeeded.
class AddToCartCometFlightHandle {
  AddToCartCometFlightHandle._(this._coordinator, this._flightId);

  final CartFlightCoordinator _coordinator;
  final int _flightId;

  /// The optimistic add has been applied to the cart state.
  void notifyAddSucceeded() => _coordinator.onFlightAddLanded(_flightId);

  /// The add threw — the sticker still finishes visually and cleans up, but
  /// the cart icon never celebrates.
  void notifyAddFailed() => _coordinator.onFlightAddFailed(_flightId);
}

/// Launches one sticker-peel flight from a PLP card to the cart icon.
///
/// The sticker (the product image) peels off the card Peel.js-style, rides
/// the coaster Bézier to the cart with the comet trail behind it, and snaps
/// into the basket — one controller, phases derived from raw time (peel
/// 0–0.28, flight 0.28–0.82, snap 0.82–1).
///
/// Everything is resolved ONCE at launch, in the root overlay's coordinate
/// space (source rect from [GlobalKey], target rect from the coordinator's
/// anchor registry, path, and the fixed pre-sampled particle list) — nothing
/// reads geometry per frame. Parallel launches are independent: each gets
/// its own [OverlayEntry] and its own animation controller, and each always
/// tears down (status listener plus a safety timer).
class AddToCartCometController {
  const AddToCartCometController._();

  /// Once per session: the warm-up paints real frames on the real surface via
  /// [AddToCartCometWarmUpLayer].
  static bool _shaderWarmUpStarted = false;
  static bool _shaderWarmUpCompleted = false;
  static bool _firstFlightCompleted = false;

  @visibleForTesting
  static bool get debugShaderWarmUpStarted => _shaderWarmUpStarted;

  @visibleForTesting
  static bool get debugShaderWarmUpDone => _shaderWarmUpCompleted;

  @visibleForTesting
  static void debugResetShaderWarmUpForTest() {
    _shaderWarmUpStarted = false;
    _shaderWarmUpCompleted = false;
    _firstFlightCompleted = false;
  }

  @visibleForTesting
  static AddToCartCometRenderProfile debugResolveRenderProfileForTest(
    Size viewportSize, {
    bool forceWeb = false,
  }) {
    return _resolveRenderProfile(viewportSize, forceWeb: forceWeb);
  }

  @visibleForTesting
  static void debugMarkShaderWarmUpCompletedForTest() {
    _shaderWarmUpStarted = true;
    _shaderWarmUpCompleted = true;
  }

  @visibleForTesting
  static void debugMarkFirstFlightCompletedForTest() {
    _firstFlightCompleted = true;
  }

  static AddToCartCometRenderProfile _resolveRenderProfile(
    Size viewportSize, {
    bool forceWeb = false,
  }) {
    if ((!kIsWeb && !forceWeb) ||
        !StorefrontLayout.isMobile(viewportSize.width)) {
      return AddToCartCometRenderProfile.rich;
    }
    if (!_shaderWarmUpCompleted && !_firstFlightCompleted) {
      return AddToCartCometRenderProfile.webMobileFirstTapCheap;
    }
    return AddToCartCometRenderProfile.webMobileSafe;
  }

  static int _particleCountForProfile(AddToCartCometRenderProfile profile) {
    return switch (profile) {
      AddToCartCometRenderProfile.rich => kCometParticleCount,
      AddToCartCometRenderProfile.webMobileSafe => kCometParticleCountWeb,
      AddToCartCometRenderProfile.webMobileFirstTapCheap =>
        kCometParticleCountWebFirstTap,
    };
  }

  static Future<ui.Image> _createWarmUpStickerTexture() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(64, 64),
        const [Color(0xFFEFEDEA), Color(0xFFCED8E8), Color(0xFFF6F4EF)],
        const [0.0, 0.48, 1.0],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, 64, 64), paint);
    paint
      ..shader = null
      ..color = Colors.white.withValues(alpha: 0.36)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(10, 48), const Offset(54, 16), paint);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(64, 64);
    } finally {
      picture.dispose();
    }
  }

  /// Returns null — and does nothing — when the flight cannot run: reduced
  /// motion, unresolvable source/target geometry, no root overlay, or a
  /// degenerate path. Callers just skip the animation in that case.
  static AddToCartCometFlightHandle? launch({
    required BuildContext context,
    required GlobalKey sourceKey,
    required CartFlightCoordinator coordinator,
    required String imageUrl,
    Duration duration = const Duration(milliseconds: 1100),
    StickerPeelCorner corner = StickerPeelCorner.topRight,
    Size? stickerSize,
    double intensity = 1.0,
    VoidCallback? onCompleted,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) return null;

    final sourceObject = sourceKey.currentContext?.findRenderObject();
    if (sourceObject is! RenderBox || !sourceObject.hasSize) return null;
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return null;
    final overlayObject = overlayState.context.findRenderObject();
    if (overlayObject is! RenderBox || !overlayObject.hasSize) return null;
    final renderProfile = _resolveRenderProfile(MediaQuery.sizeOf(context));

    // All flight geometry lives in the root overlay's coordinate space (the
    // entry is painted there). In practice the root overlay sits at the
    // global origin, but converting keeps the maths correct if the app is
    // ever embedded with an offset.
    final sourceRect =
        overlayObject.globalToLocal(sourceObject.localToGlobal(Offset.zero)) &
        sourceObject.size;
    final stickerRect = stickerSize == null
        ? sourceRect
        : Rect.fromCenter(
            center: sourceRect.center,
            width: stickerSize.width,
            height: stickerSize.height,
          );
    final globalTargetRect = coordinator.resolveCartTargetRect();
    if (globalTargetRect == null) return null;
    final targetRect =
        overlayObject.globalToLocal(globalTargetRect.topLeft) &
        globalTargetRect.size;

    // Roller-coaster shape: the crest sits near the overlay centre, so the
    // sticker climbs through the middle of the screen before the gravity
    // drop.
    final flightPath = buildCartFlightPath(
      stickerRect.center,
      targetRect.center,
      screenCenter: overlayObject.size.center(Offset.zero),
    );
    final particles = buildCometParticles(
      flightPath.path,
      count: _particleCountForProfile(renderProfile),
    );
    if (particles.length < 2) return null;

    final flightId = coordinator.startFlight();
    var toreDown = false;
    late final OverlayEntry entry;
    // Idempotent: reached from the animation completing, the safety timer,
    // or the overlay being torn down externally (e.g. test teardown) — the
    // coordinator is always released exactly once.
    void teardown({required bool removeFromOverlay}) {
      if (toreDown) return;
      toreDown = true;
      _firstFlightCompleted = true;
      if (removeFromOverlay) {
        entry.remove();
        entry.dispose();
      }
      coordinator.onFlightDisposed(flightId);
      onCompleted?.call();
    }

    entry = OverlayEntry(
      builder: (_) => _AddToCartCometOverlay(
        stickerRect: stickerRect,
        targetSize: targetRect.size * 0.5,
        particles: particles,
        crestFraction: flightPath.crestFraction,
        imageUrl: imageUrl,
        devicePixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0,
        corner: corner,
        intensity: intensity,
        renderProfile: renderProfile,
        duration: duration,
        onImpact: () => coordinator.onFlightImpact(flightId),
        onCompleted: () => teardown(removeFromOverlay: true),
        onTornDown: () => teardown(removeFromOverlay: false),
      ),
    );
    overlayState.insert(entry);
    return AddToCartCometFlightHandle._(coordinator, flightId);
  }
}

/// Full-screen, tap-transparent flight layer: the comet trail (CustomPaint)
/// underneath the peeling/flying sticker.
class _AddToCartCometOverlay extends StatefulWidget {
  const _AddToCartCometOverlay({
    required this.stickerRect,
    required this.targetSize,
    required this.particles,
    required this.crestFraction,
    required this.imageUrl,
    required this.devicePixelRatio,
    required this.corner,
    required this.intensity,
    required this.renderProfile,
    required this.duration,
    required this.onImpact,
    required this.onCompleted,
    required this.onTornDown,
  });

  final Rect stickerRect;
  final Size targetSize;
  final List<SampledCometParticle> particles;

  /// Arc-length fraction of the coaster crest, pacing climb vs drop.
  final double crestFraction;
  final String imageUrl;
  final double devicePixelRatio;
  final StickerPeelCorner corner;
  final double intensity;
  final AddToCartCometRenderProfile renderProfile;
  final Duration duration;

  /// Fired exactly once when the sticker reaches the cart (snap start).
  final VoidCallback onImpact;

  /// Fired when the flight is over (animation completed or safety timer) —
  /// the launcher removes the entry.
  final VoidCallback onCompleted;

  /// Fired from dispose so an externally torn-down overlay (route/tree
  /// destruction) still releases its flight in the coordinator.
  final VoidCallback onTornDown;

  @override
  State<_AddToCartCometOverlay> createState() => _AddToCartCometOverlayState();
}

class _AddToCartCometOverlayState extends State<_AddToCartCometOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// Raw time → arc-length progress feeding the trail painter: 0 during the
  /// peel, coaster pacing (chain-lift climb + u² gravity drop) across the
  /// flight phase, pinned at 1 during the snap.
  late final Animation<double> _pathProgress = _controller.drive(
    Animatable<double>.fromCallback(
      (t) => stickerPathProgress(t, widget.crestFraction),
    ),
  );

  /// Product texture for the sticker face; the painter falls back to a flat
  /// premium gradient until (or unless) it resolves.
  final ValueNotifier<ui.Image?> _stickerTexture = ValueNotifier<ui.Image?>(
    null,
  );
  ImageStream? _textureStream;
  ImageStreamListener? _textureListener;
  ImageInfo? _textureInfo;

  Timer? _safetyTimer;
  bool _impactFired = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
    _controller.addListener(_onTick);
    _resolveStickerTexture();
    // Safety net (cf. SnapDisintegrate): if the ticker never reaches
    // `completed`, the entry must still be removed.
    _safetyTimer = Timer(
      widget.duration + const Duration(milliseconds: 600),
      widget.onCompleted,
    );
    _controller.forward();
  }

  void _resolveStickerTexture() {
    if (widget.imageUrl.isEmpty) return;
    // Reuse KikiImage's exact provider (memCache size + disk bounds) so, at
    // the default sticker size, the tap hits the card's already-decoded
    // ImageCache entry — no re-decode, no gradient flash on the first frame.
    final provider = KikiImage.cachedProviderFor(
      imageUrl: widget.imageUrl,
      renderSize: widget.stickerRect.size,
      devicePixelRatio: widget.devicePixelRatio,
    );
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        _textureInfo?.dispose();
        _textureInfo = info;
        _stickerTexture.value = info.image;
      },
      onError: (_, _) {
        // Keep the gradient face — the peel must not depend on the network.
      },
    );
    stream.addListener(listener);
    _textureStream = stream;
    _textureListener = listener;
  }

  void _onTick() {
    if (_impactFired) return;
    if (_controller.value >= kStickerFlightEnd) {
      _impactFired = true;
      widget.onImpact();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onCompleted();
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    final textureListener = _textureListener;
    if (textureListener != null) {
      _textureStream?.removeListener(textureListener);
    }
    _textureInfo?.dispose();
    _stickerTexture.dispose();
    _controller.dispose();
    widget.onTornDown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: CometTrailPainter(
                    particles: widget.particles,
                    progress: _pathProgress,
                    renderProfile: widget.renderProfile,
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: StickerPeelPainter(
                    progress: _controller,
                    particles: widget.particles,
                    stickerRect: widget.stickerRect,
                    targetSize: widget.targetSize,
                    crestFraction: widget.crestFraction,
                    corner: widget.corner,
                    intensity: widget.intensity,
                    image: _stickerTexture,
                    renderProfile: widget.renderProfile,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CodePen-faithful trail renderer.
///
/// Reads the fixed pre-sampled particle list through a moving window behind
/// the head — it never allocates particles, never touches [PathMetric], and
/// repaints via the animation listenable (no widget rebuild per frame).
class CometTrailPainter extends CustomPainter {
  CometTrailPainter({
    required this.particles,
    required this.progress,
    this.renderProfile = AddToCartCometRenderProfile.rich,
  }) : super(repaint: progress);

  final List<SampledCometParticle> particles;
  final Animation<double> progress;
  final AddToCartCometRenderProfile renderProfile;

  // Cached paints: no Paint/list allocations per frame. The only per-frame
  // objects are the small Color values produced by withValues (the glow's
  // HSV→RGB conversion is baked into each particle at sampling time).
  final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final Paint _corePaint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final n = particles.length;
    if (n == 0) return;
    final t = progress.value.clamp(0.0, 1.0);
    final globalFade = cometTrailGlobalFade(t);
    if (globalFade <= 0) return;

    final head = cometHeadIndex(t, n);
    final windowLength = _windowLengthForProfile(n);
    final depthStride =
        renderProfile == AddToCartCometRenderProfile.webMobileFirstTapCheap
        ? 2
        : 1;
    for (var depth = 0; depth < windowLength; depth += depthStride) {
      // The CodePen wraps with `% n`; a one-way flight skips past the path
      // start instead, so the tail dissolves naturally.
      final index = head - depth;
      if (index < 0) break;
      final particle = particles[index];

      final alpha =
          cometDepthAlpha(depth, windowLength, particle.alphaSeed) * globalFade;
      if (alpha <= 0.004) continue;

      final radius = cometDepthRadius(depth) * (0.85 + particle.sizeSeed * 0.3);
      final center =
          particle.position +
          particle.normal * cometDepthSpread(depth, particle.spreadSeed);

      if (renderProfile == AddToCartCometRenderProfile.rich) {
        _corePaint.color = Colors.white.withValues(alpha: alpha * 0.72);
        _glowPaint
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..color = particle.glowColor.withValues(alpha: alpha * 0.28);
        canvas.drawCircle(center, radius * 1.55, _glowPaint);
        canvas.drawCircle(center, radius * 0.32, _corePaint);
        continue;
      }

      final isFirstTapCheap =
          renderProfile == AddToCartCometRenderProfile.webMobileFirstTapCheap;
      _glowPaint
        ..maskFilter = null
        ..color = particle.glowColor.withValues(
          alpha: alpha * (isFirstTapCheap ? 0.18 : 0.42),
        );
      _corePaint.color = Colors.white.withValues(
        alpha: alpha * (isFirstTapCheap ? 0.82 : 0.96),
      );
      canvas.drawCircle(
        center,
        radius * (isFirstTapCheap ? 0.95 : 1.65),
        _glowPaint,
      );
      canvas.drawCircle(
        center,
        radius * (isFirstTapCheap ? 0.38 : 0.54),
        _corePaint,
      );
    }
  }

  int _windowLengthForProfile(int n) {
    return switch (renderProfile) {
      AddToCartCometRenderProfile.rich => cometTrailWindowLength(n),
      AddToCartCometRenderProfile.webMobileSafe => (n * 0.72).round(),
      AddToCartCometRenderProfile.webMobileFirstTapCheap => (n * 0.44).round(),
    };
  }

  @override
  bool shouldRepaint(covariant CometTrailPainter oldDelegate) {
    // Frames are driven by the `repaint` listenable; a rebuild only needs a
    // repaint when it brought a different flight's data.
    return !identical(oldDelegate.particles, particles) ||
        oldDelegate.renderProfile != renderProfile;
  }
}

/// Timeline points painted by the real-surface warm-up, one per frame:
/// folded peel (cast shadow + glue + back face), early flight (fold relaxing
/// + drop shadow), unfolded flight (shine sweep), snap.
const List<double> _kCometWarmUpSteps = <double>[0.16, 0.36, 0.66, 0.80, 0.92];

/// Best-effort CanvasKit warm-up that paints the REAL flight painters through
/// the REAL render pipeline — the screen surface — instead of an offscreen
/// `Picture.toImage`.
///
/// Rationale (S22 Chrome Android, 2026-07-04): the trivial-overlay ablation
/// showed the first-flight stall is the painters' WebGL program compilations,
/// and the offscreen toImage warm-up only recovered part of it because an
/// offscreen surface does not compile the same programs as the screen
/// surface. This layer paints four representative real frames — one per real
/// frame, so no single long task — underneath the opaque page content
/// (Flutter/Skia does no occlusion culling, so the draws still rasterize;
/// the user sees nothing), then goes permanently dormant.
///
/// The host keeps this widget mounted unconditionally so the element tree
/// never reshapes; [armed] flips once after the host's dwell.
class AddToCartCometWarmUpLayer extends StatefulWidget {
  const AddToCartCometWarmUpLayer({super.key, required this.armed});

  /// True once every runtime gate has been resolved by the host (web mobile
  /// sport PLP, data ready, motion allowed, route still current, dwell over).
  final bool armed;

  @override
  State<AddToCartCometWarmUpLayer> createState() =>
      _AddToCartCometWarmUpLayerState();
}

class _AddToCartCometWarmUpLayerState extends State<AddToCartCometWarmUpLayer> {
  final ValueNotifier<double?> _step = ValueNotifier<double?>(null);
  _CometWarmUpScene? _scene;
  _RealSurfaceWarmUpPainter? _painter;
  int _stepIndex = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (widget.armed) {
      // MediaQuery is not readable from initState; defer one frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void didUpdateWidget(covariant AddToCartCometWarmUpLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.armed && !oldWidget.armed) _start();
  }

  void _start() {
    if (_started || !mounted || !widget.armed) return;
    if (AddToCartCometController._shaderWarmUpStarted ||
        AddToCartCometController._shaderWarmUpCompleted) {
      return;
    }
    final size = MediaQuery.sizeOf(context);
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) return;
    _started = true;
    // Latch immediately: even an interrupted warm-up must not re-run later in
    // the session (best-effort optimization, never a retry loop).
    AddToCartCometController._shaderWarmUpStarted = true;
    unawaited(_run(size));
  }

  Future<void> _run(Size size) async {
    final texture =
        await AddToCartCometController._createWarmUpStickerTexture();
    if (!mounted) {
      texture.dispose();
      return;
    }
    final scene = _buildCometWarmUpScene(size, texture);
    if (scene == null) {
      texture.dispose();
      return;
    }
    setState(() {
      _scene = scene;
      _painter = _RealSurfaceWarmUpPainter(step: _step, scene: scene);
    });
    _stepIndex = 0;
    _step.value = _kCometWarmUpSteps[0];
    _scheduleNextStep();
  }

  /// One warm frame per real frame: each advance repaints only this layer's
  /// boundary and lets that frame's raster compile its own programs, instead
  /// of one long blocking task.
  void _scheduleNextStep() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _stepIndex += 1;
      if (_stepIndex >= _kCometWarmUpSteps.length) {
        // Dormant: empty paints from here on. The tiny texture is kept until
        // dispose so the last painted frame never references a disposed image.
        _step.value = null;
        AddToCartCometController._shaderWarmUpCompleted = true;
        return;
      }
      _step.value = _kCometWarmUpSteps[_stepIndex];
      _scheduleNextStep();
    });
  }

  @override
  void dispose() {
    final scene = _scene;
    if (scene != null) {
      scene.texture.value?.dispose();
      scene.texture.dispose();
    }
    _step.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _painter, child: const SizedBox.expand()),
      ),
    );
  }
}

/// Fixed representative flight used by the warm-up: sticker in the upper-left
/// card area, cart target at the bottom-right — the same geometry family as a
/// real PLP flight, sized from the actual screen so every draw lands inside
/// the surface (culled draws compile nothing).
class _CometWarmUpScene {
  const _CometWarmUpScene({
    required this.particles,
    required this.crestFraction,
    required this.stickerRect,
    required this.targetSize,
    required this.texture,
  });

  final List<SampledCometParticle> particles;
  final double crestFraction;
  final Rect stickerRect;
  final Size targetSize;
  final ValueNotifier<ui.Image?> texture;
}

_CometWarmUpScene? _buildCometWarmUpScene(Size size, ui.Image texture) {
  final stickerSide = (size.width * 0.45).clamp(132.0, 176.0).toDouble();
  final stickerRect = Rect.fromLTWH(16, 108, stickerSide, stickerSide);
  final target = Offset(size.width - 46, size.height - 76);
  final flightPath = buildCartFlightPath(
    stickerRect.center,
    target,
    screenCenter: size.center(Offset.zero),
  );
  final particles = buildCometParticles(
    flightPath.path,
    count: kCometParticleCountWeb,
  );
  if (particles.length < 2) return null;
  return _CometWarmUpScene(
    particles: particles,
    crestFraction: flightPath.crestFraction,
    stickerRect: stickerRect,
    targetSize: const Size.square(16),
    texture: ValueNotifier<ui.Image?>(texture),
  );
}

/// Delegates to the real painters at a fixed timeline point; a null step
/// paints nothing (dormant warm-up layer).
class _RealSurfaceWarmUpPainter extends CustomPainter {
  _RealSurfaceWarmUpPainter({required this.step, required this.scene})
    : super(repaint: step);

  final ValueListenable<double?> step;
  final _CometWarmUpScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final t = step.value;
    if (t == null) return;
    CometTrailPainter(
      particles: scene.particles,
      progress: AlwaysStoppedAnimation<double>(
        stickerPathProgress(t, scene.crestFraction),
      ),
      renderProfile: AddToCartCometRenderProfile.webMobileSafe,
    ).paint(canvas, size);
    StickerPeelPainter(
      progress: AlwaysStoppedAnimation<double>(t),
      particles: scene.particles,
      stickerRect: scene.stickerRect,
      targetSize: scene.targetSize,
      crestFraction: scene.crestFraction,
      corner: StickerPeelCorner.topRight,
      intensity: 1.0,
      image: scene.texture,
      renderProfile: AddToCartCometRenderProfile.webMobileSafe,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _RealSurfaceWarmUpPainter oldDelegate) {
    return !identical(oldDelegate.scene, scene);
  }
}
