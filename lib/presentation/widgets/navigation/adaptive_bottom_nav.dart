import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../config/web_renderer_feature_flags.dart';
import 'floating_bottom_nav.dart';
import 'scroll_motion_signal.dart';

/// Glass variant the bottom nav should wear for a given backdrop [luminance]
/// (0 = black, 1 = white): a dark backdrop needs the light-on-dark glass, a
/// bright backdrop the dark-on-light glass. Pure for testing.
Brightness navBrightnessForBackdropLuminance(double luminance) {
  return luminance < 0.5 ? Brightness.dark : Brightness.light;
}

/// Average perceptual luminance (0..1) of the bottom [bandFraction] of a raw
/// RGBA buffer — the strip the floating nav actually sits over. Fully
/// transparent pixels (no content painted there) are ignored; an all-empty
/// band reads as bright so the nav defaults to the light glass.
double averageBottomBandLuminance(
  ByteData rgba,
  int width,
  int height, {
  double bandFraction = 0.16,
}) {
  if (width <= 0 || height <= 0) return 1;
  final startRow = ((1 - bandFraction) * height).floor().clamp(0, height - 1);
  double sum = 0;
  var count = 0;
  for (var y = startRow; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final a = rgba.getUint8(i + 3);
      if (a == 0) continue;
      final r = rgba.getUint8(i);
      final g = rgba.getUint8(i + 1);
      final b = rgba.getUint8(i + 2);
      sum += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
      count++;
    }
  }
  return count == 0 ? 1 : sum / count;
}

/// Inherited handle the bottom nav reads to pick its glass + icon colours.
/// Absent (e.g. in isolation tests) → the light glass, matching the historical
/// default.
class BottomNavBrightness extends InheritedWidget {
  final Brightness brightness;

  const BottomNavBrightness({
    super.key,
    required this.brightness,
    required super.child,
  });

  static Brightness of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<BottomNavBrightness>();
    return inherited?.brightness ?? Brightness.light;
  }

  @override
  bool updateShouldNotify(BottomNavBrightness oldWidget) =>
      oldWidget.brightness != brightness;
}

/// Overlays the [FloatingBottomNav] above [child] and adapts its glass to the
/// real content behind it.
///
/// The page content is wrapped in a [RepaintBoundary]; when scrolling settles
/// (and once on first layout) the strip behind the floating pill is captured at
/// a tiny resolution, its average luminance computed, and the resulting
/// [Brightness] handed to the nav through [BottomNavBrightness]. Sampling runs
/// only on scroll-end (never per frame / never during the scroll hot path) at a
/// 0.08 pixel ratio, so it stays off the jank-sensitive path. Failures keep the
/// last decision.
class AdaptiveBottomNav extends StatefulWidget {
  final Widget child;
  final VoidCallback? onHomeTripleTap;
  final bool homeIconLoading;

  const AdaptiveBottomNav({
    super.key,
    required this.child,
    this.onHomeTripleTap,
    this.homeIconLoading = false,
  });

  @override
  State<AdaptiveBottomNav> createState() => _AdaptiveBottomNavState();
}

class _AdaptiveBottomNavState extends State<AdaptiveBottomNav>
    with SingleTickerProviderStateMixin {
  final GlobalKey _backdropKey = GlobalKey();
  Brightness _brightness = Brightness.light;
  Timer? _debounce;
  bool _sampling = false;

  // Feeds the Home lens shader with the live scroll velocity. Owns a ticker
  // that only runs while there is motion (see ScrollMotionSignal).
  late final ScrollMotionSignal _scrollMotion = ScrollMotionSignal(this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSample());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollMotion.dispose();
    super.dispose();
  }

  void _scheduleSample() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _sample);
  }

  Future<void> _sample() async {
    if (!mounted || _sampling) return;
    final renderObject = _backdropKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary || !renderObject.attached) {
      return;
    }

    // Capturing this boundary composites its LIVE layer tree. On web (skwasm)
    // doing that while the tree is mid-relayout or being torn down — e.g. the
    // debounce firing right as a route transition disposes the page — traps the
    // wasm heap ("memory access out of bounds" inside pictureRecorder /
    // beginRecording) and freezes the tab. The trap is a wasm RuntimeError, NOT
    // a Dart exception, so the try/catch below can never recover from it. The
    // boundary's readiness used to be pre-checked via RenderObject.debugNeedsPaint,
    // but that getter is assert-only (throws LateInitializationError in release).
    //
    // Two guards make the capture safe:
    //  1. Only capture when the frame pipeline is quiescent (no frame scheduled),
    //     i.e. the last painted frame is current and nothing is relaying out.
    //     A pending frame (route transition, animation, relayout) means the
    //     boundary is about to change, so defer instead.
    //  2. Use the SYNCHRONOUS toImageSync: unlike the async toImage it leaves no
    //     window for a navigation to free the layer mid-capture. toByteData then
    //     reads back the already-captured, self-contained image, which is safe.
    if (WidgetsBinding.instance.hasScheduledFrame) {
      _scheduleSample();
      return;
    }

    _sampling = true;
    ui.Image? image;
    try {
      image = renderObject.toImageSync(pixelRatio: 0.08);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null || !mounted) return;
      final luminance = averageBottomBandLuminance(
        data,
        image.width,
        image.height,
      );
      final next = navBrightnessForBackdropLuminance(luminance);
      if (next != _brightness) {
        setState(() => _brightness = next);
      }
    } catch (_) {
      // Read-back / decode failure (not the skwasm trap, which is uncatchable):
      // keep the last decision and retry shortly.
      if (mounted) _scheduleSample();
    } finally {
      image?.dispose();
      _sampling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion: drop the scroll-driven lens animation entirely (the
    // ticker never starts because no deltas are forwarded).
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final delta = notification.scrollDelta;
          if (delta != null &&
              !reduceMotion &&
              WebRendererFeatureFlags.enableNavbarShaders) {
            _scrollMotion.onScrollDelta(delta);
          }
        } else if (notification is ScrollEndNotification) {
          _scheduleSample();
        }
        return false;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(key: _backdropKey, child: widget.child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNavBrightness(
              brightness: _brightness,
              child: FloatingBottomNav(
                onHomeTripleTap: widget.onHomeTripleTap,
                homeIconLoading: widget.homeIconLoading,
                scrollMotion: _scrollMotion,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
