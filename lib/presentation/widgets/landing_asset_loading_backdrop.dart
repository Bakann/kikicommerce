import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

const String kLandingGradientFlowLowCostShaderAsset =
    'assets/shaders/landing_gradient_flow_low_cost.frag';

@visibleForTesting
const Key landingAssetLoadingBackdropOverlayKey = Key(
  'landing-asset-loading-backdrop-overlay',
);

@visibleForTesting
const Key landingGradientLoadingCoordinatorBackgroundKey = Key(
  'landing-gradient-loading-coordinator-background',
);

/// A short-lived, non-blocking overlay for a landing page's critical assets.
///
/// [assetsReady] deliberately represents only the exact images required by the
/// initial viewport. Using Flutter's global image-cache counters here would
/// both miss images whose URLs are not known yet and include unrelated
/// background preloads.
class LandingAssetLoadingBackdrop extends StatefulWidget {
  final ValueListenable<bool> assetsReady;
  final Widget child;
  final Widget background;
  final Duration minVisibleDuration;
  final Duration maxVisibleDuration;
  final Duration fadeDuration;

  const LandingAssetLoadingBackdrop({
    super.key,
    required this.assetsReady,
    required this.child,
    this.background = const LandingLowCostGradientFlowBackground(),
    this.minVisibleDuration = const Duration(milliseconds: 520),
    this.maxVisibleDuration = const Duration(milliseconds: 2600),
    this.fadeDuration = const Duration(milliseconds: 180),
  }) : assert(maxVisibleDuration >= minVisibleDuration);

  @override
  State<LandingAssetLoadingBackdrop> createState() =>
      _LandingAssetLoadingBackdropState();
}

class _LandingAssetLoadingBackdropState
    extends State<LandingAssetLoadingBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  Timer? _minVisibleTimer;
  Timer? _maxVisibleTimer;
  bool _minimumElapsed = false;
  bool _isOverlayMounted = true;
  bool _isDismissing = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
      value: 1,
    );
    widget.assetsReady.addListener(_handleAssetsReadyChanged);
    if (widget.minVisibleDuration == Duration.zero) {
      _minimumElapsed = true;
    } else {
      _minVisibleTimer = Timer(widget.minVisibleDuration, () {
        _minimumElapsed = true;
        _scheduleDismissWhenReady();
      });
    }
    _maxVisibleTimer = Timer(widget.maxVisibleDuration, _dismiss);
    _scheduleDismissWhenReady();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(covariant LandingAssetLoadingBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetsReady != widget.assetsReady) {
      oldWidget.assetsReady.removeListener(_handleAssetsReadyChanged);
      widget.assetsReady.addListener(_handleAssetsReadyChanged);
      _scheduleDismissWhenReady();
    }
    if (oldWidget.fadeDuration != widget.fadeDuration) {
      _fadeController.duration = widget.fadeDuration;
    }
  }

  @override
  void dispose() {
    widget.assetsReady.removeListener(_handleAssetsReadyChanged);
    _minVisibleTimer?.cancel();
    _maxVisibleTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _handleAssetsReadyChanged() {
    _scheduleDismissWhenReady();
  }

  void _scheduleDismissWhenReady() {
    if (!widget.assetsReady.value || _isDismissing || !_isOverlayMounted) {
      return;
    }
    if (_minimumElapsed) _dismiss();
  }

  void _dismiss() {
    if (_isDismissing || !_isOverlayMounted) return;
    _minVisibleTimer?.cancel();
    _maxVisibleTimer?.cancel();
    if (_reduceMotion || widget.fadeDuration == Duration.zero) {
      setState(() {
        _isDismissing = true;
        _isOverlayMounted = false;
      });
      return;
    }
    // Flip _isDismissing inside a rebuild so a coordinator covered below can
    // resume its own gradient the moment the curtain starts to reveal it —
    // otherwise a flat idle colour would flash through the fade.
    setState(() => _isDismissing = true);
    _fadeController.reverse().whenComplete(() {
      if (mounted) setState(() => _isOverlayMounted = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topLeft,
      fit: StackFit.expand,
      children: [
        _LandingBackdropCoverage(
          // The curtain is opaque (and fully covering) until a dismiss starts
          // the fade; from then on the page below must paint normally so it is
          // revealed, not a flat colour.
          isCovering: _isOverlayMounted && !_isDismissing,
          child: widget.child,
        ),
        if (_isOverlayMounted)
          Positioned.fill(
            key: landingAssetLoadingBackdropOverlayKey,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _fadeController.drive(Tween<double>(begin: 0, end: 1)),
                child: RepaintBoundary(child: widget.background),
              ),
            ),
          ),
      ],
    );
  }
}

/// Published by [LandingAssetLoadingBackdrop] while its opaque curtain fully
/// covers the page. A [LandingGradientLoadingCoordinator] below reads this to
/// skip its own full-page shader during that window: without it the cold-start
/// frame paints two stacked full-screen shaders (the curtain plus the
/// coordinator's gradient behind the skeleton), and the lower one — completely
/// occluded — is wasted GPU work at the most load-sensitive moment.
class _LandingBackdropCoverage extends InheritedWidget {
  final bool isCovering;

  const _LandingBackdropCoverage({
    required this.isCovering,
    required super.child,
  });

  static bool isCoveringOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_LandingBackdropCoverage>()
            ?.isCovering ??
        false;
  }

  @override
  bool updateShouldNotify(_LandingBackdropCoverage oldWidget) {
    return oldWidget.isCovering != isCovering;
  }
}

class LandingLowCostGradientFlowBackground extends StatefulWidget {
  final bool animate;

  const LandingLowCostGradientFlowBackground({super.key, this.animate = true});

  @override
  State<LandingLowCostGradientFlowBackground> createState() =>
      _LandingLowCostGradientFlowBackgroundState();
}

/// Keeps the landing gradient visible behind a skeleton without obscuring the
/// already-resolved content around it.
class LandingGradientLoadingSurface extends StatefulWidget {
  final Widget child;
  final bool animate;
  final double childOpacity;

  const LandingGradientLoadingSurface({
    super.key,
    required this.child,
    this.animate = true,
    this.childOpacity = 1,
  });

  @override
  State<LandingGradientLoadingSurface> createState() =>
      _LandingGradientLoadingSurfaceState();
}

/// Coordinates every loading surface mounted below it and paints one shared
/// full-page shader while at least one of those surfaces is still present.
class LandingGradientLoadingCoordinator extends StatefulWidget {
  final Widget child;
  final Color idleBackgroundColor;
  final bool animate;

  const LandingGradientLoadingCoordinator({
    super.key,
    required this.child,
    required this.idleBackgroundColor,
    this.animate = true,
  });

  @override
  State<LandingGradientLoadingCoordinator> createState() =>
      _LandingGradientLoadingCoordinatorState();
}

class _LandingGradientLoadingCoordinatorState
    extends State<LandingGradientLoadingCoordinator> {
  final _controller = _LandingGradientLoadingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final isLoading = _controller.isLoading;
        // While the startup curtain is opaque over us, our shader would be fully
        // occluded — paint the cheap idle colour instead of a second full-screen
        // shader. The curtain hides the swap; we resume the moment it reveals.
        final isCovered = _LandingBackdropCoverage.isCoveringOf(context);
        return _LandingGradientLoadingScope(
          controller: _controller,
          isLoading: isLoading,
          child: Stack(
            alignment: Alignment.topLeft,
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                key: landingGradientLoadingCoordinatorBackgroundKey,
                child: isLoading && !isCovered
                    ? RepaintBoundary(
                        child: LandingLowCostGradientFlowBackground(
                          animate: widget.animate,
                        ),
                      )
                    : ColoredBox(color: widget.idleBackgroundColor),
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

/// Paints [idleBackgroundColor] normally, then becomes transparent while the
/// nearest loading coordinator is showing its full-page shader.
class LandingGradientLoadingBackground extends StatelessWidget {
  final Color idleBackgroundColor;
  final Widget child;

  const LandingGradientLoadingBackground({
    super.key,
    required this.idleBackgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context
            .dependOnInheritedWidgetOfExactType<_LandingGradientLoadingScope>()
            ?.isLoading ??
        false;
    return ColoredBox(
      color: isLoading ? Colors.transparent : idleBackgroundColor,
      child: child,
    );
  }
}

class _LandingGradientLoadingSurfaceState
    extends State<LandingGradientLoadingSurface> {
  _LandingGradientLoadingController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = context
        .dependOnInheritedWidgetOfExactType<_LandingGradientLoadingScope>()
        ?.controller;
    if (identical(nextController, _controller)) return;
    _controller?.detach(this);
    _controller = nextController;
    _controller?.attach(this);
  }

  @override
  void dispose() {
    _controller?.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.childOpacity == 1
        ? widget.child
        : Opacity(opacity: widget.childOpacity, child: widget.child);
    if (_controller != null) {
      return ClipRect(child: child);
    }
    return ClipRect(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: LandingLowCostGradientFlowBackground(
                animate: widget.animate,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _LandingGradientLoadingController extends ChangeNotifier {
  final Set<Object> _surfaces = <Object>{};
  bool _notificationScheduled = false;
  bool _disposed = false;

  bool get isLoading => _surfaces.isNotEmpty;

  void attach(Object surface) {
    if (_surfaces.add(surface)) _scheduleNotification();
  }

  void detach(Object surface) {
    if (_surfaces.remove(surface)) _scheduleNotification();
  }

  void _scheduleNotification() {
    if (_notificationScheduled || _disposed) return;
    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _LandingGradientLoadingScope extends InheritedWidget {
  final _LandingGradientLoadingController controller;
  final bool isLoading;

  const _LandingGradientLoadingScope({
    required this.controller,
    required this.isLoading,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LandingGradientLoadingScope oldWidget) {
    return oldWidget.isLoading != isLoading ||
        oldWidget.controller != controller;
  }
}

class _LandingLowCostGradientFlowBackgroundState
    extends State<LandingLowCostGradientFlowBackground>
    with SingleTickerProviderStateMixin {
  static const _loop = Duration(seconds: 18);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _loop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(
    covariant LandingLowCostGradientFlowBackground oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncAnimation();
  }

  void _syncAnimation() {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderBuilder(
      (context, shader, _) => CustomPaint(
        painter: _LandingGradientFlowPainter(
          shader: shader,
          progress: _controller,
          colorPrimary: const Color(0xFFF7F6F2),
          colorSecondary: const Color(0xFFE0DDD4),
          colorAccent1: const Color(0xFFB7C8D6),
          colorAccent2: const Color(0xFF1B3A5C),
        ),
        child: const SizedBox.expand(),
      ),
      assetKey: kLandingGradientFlowLowCostShaderAsset,
      // ShaderBuilder renders its child until the FragmentProgram is ready.
      // This keeps the backdrop visible without starting a duplicate preload.
      child: const _LandingGradientFallback(),
    );
  }
}

class _LandingGradientFallback extends StatelessWidget {
  const _LandingGradientFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7F6F2),
            Color(0xFFE0DDD4),
            Color(0xFFB7C8D6),
            Color(0xFF1B3A5C),
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _LandingGradientFlowPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final Animation<double> progress;
  final Color colorPrimary;
  final Color colorSecondary;
  final Color colorAccent1;
  final Color colorAccent2;

  _LandingGradientFlowPainter({
    required this.shader,
    required this.progress,
    required this.colorPrimary,
    required this.colorSecondary,
    required this.colorAccent1,
    required this.colorAccent2,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, progress.value * 18);
    _setColor(shader, 3, colorPrimary);
    _setColor(shader, 6, colorSecondary);
    _setColor(shader, 9, colorAccent1);
    _setColor(shader, 12, colorAccent2);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  void _setColor(ui.FragmentShader shader, int offset, Color color) {
    shader
      ..setFloat(offset, color.r)
      ..setFloat(offset + 1, color.g)
      ..setFloat(offset + 2, color.b);
  }

  @override
  bool shouldRepaint(covariant _LandingGradientFlowPainter oldDelegate) {
    return oldDelegate.shader != shader ||
        oldDelegate.progress != progress ||
        oldDelegate.colorPrimary != colorPrimary ||
        oldDelegate.colorSecondary != colorSecondary ||
        oldDelegate.colorAccent1 != colorAccent1 ||
        oldDelegate.colorAccent2 != colorAccent2;
  }
}
