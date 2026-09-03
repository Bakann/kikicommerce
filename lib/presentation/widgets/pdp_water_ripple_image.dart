import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import 'hero_image_back_button.dart';
import 'navigation/premium_shell_navbar.dart';

const String kPdpWaterRippleShaderAsset =
    'assets/shaders/pdp_water_ripple.frag';

const Offset kPdpWaterRippleDefaultOrigin = Offset(0.50, 0.50);

/// Returns the shader-space center of the mobile PDP image back button.
Offset pdpWaterRippleBackButtonOrigin(BuildContext context, Size imageSize) {
  if (imageSize.isEmpty ||
      !imageSize.width.isFinite ||
      !imageSize.height.isFinite) {
    return kPdpWaterRippleDefaultOrigin;
  }

  final shellNavbarVisible =
      PremiumShellNavbarMetrics.maybeOf(context)?.isVisible == true;
  final buttonTop = shellNavbarVisible
      ? kHeroImageBackButtonTopGap
      : MediaQuery.paddingOf(context).top + kHeroImageBackButtonTopGap;
  final buttonRadius = kHeroImageBackButtonSize / 2;
  final center = Offset(
    kHeroImageBackButtonLeftGap + buttonRadius,
    buttonTop + buttonRadius,
  );

  return Offset(
    (center.dx / imageSize.width).clamp(0.0, 1.0).toDouble(),
    (center.dy / imageSize.height).clamp(0.0, 1.0).toDouble(),
  );
}

/// Coordinates one PDP ripple pulse with the enclosing route transition.
///
/// Ripple widgets mounted in this scope share one controller. The controller
/// starts only after the route animation completes and at least one enabled
/// [PdpWaterRipple] is mounted. This lets the loading Hero and the loaded
/// carousel hand off without restarting or waiting for the PDP image request.
class PdpWaterRippleRouteScope extends StatefulWidget {
  final Widget child;

  const PdpWaterRippleRouteScope({super.key, required this.child});

  static _PdpWaterRippleRouteScopeState? _maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_PdpWaterRippleRouteInherited>()
        ?.state;
  }

  @override
  State<PdpWaterRippleRouteScope> createState() =>
      _PdpWaterRippleRouteScopeState();
}

class _PdpWaterRippleRouteScopeState extends State<PdpWaterRippleRouteScope>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _routeAnimation;
  bool _routeDependenciesInitialized = false;
  bool _routeSettled = false;
  bool _pulseStartScheduled = false;
  int _attachedRipples = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRouteAnimation = ModalRoute.of(context)?.animation;
    if (_routeDependenciesInitialized &&
        identical(_routeAnimation, nextRouteAnimation)) {
      return;
    }

    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _routeAnimation = nextRouteAnimation;
    _routeDependenciesInitialized = true;
    _routeSettled =
        nextRouteAnimation == null ||
        nextRouteAnimation.status == AnimationStatus.completed;
    nextRouteAnimation?.addStatusListener(_handleRouteStatus);
    _schedulePulseIfReady();
  }

  AnimationController _attachRipple(Duration duration) {
    _attachedRipples += 1;
    final controller = _pulseController ??= AnimationController(
      vsync: this,
      duration: duration,
    );
    if (controller.status == AnimationStatus.dismissed) {
      controller.duration = duration;
    }
    _schedulePulseIfReady();
    return controller;
  }

  void _updateDuration(Duration duration) {
    final controller = _pulseController;
    if (controller?.status == AnimationStatus.dismissed) {
      controller?.duration = duration;
    }
  }

  void _detachRipple() {
    assert(_attachedRipples > 0);
    _attachedRipples -= 1;
  }

  void _handleRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _routeSettled = true;
      _schedulePulseIfReady();
    } else if (_pulseController?.status == AnimationStatus.dismissed) {
      _routeSettled = false;
    }
  }

  void _schedulePulseIfReady() {
    final controller = _pulseController;
    if (!_routeSettled ||
        _attachedRipples == 0 ||
        controller == null ||
        controller.status != AnimationStatus.dismissed ||
        _pulseStartScheduled) {
      return;
    }

    _pulseStartScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pulseStartScheduled = false;
      if (!mounted ||
          !_routeSettled ||
          _attachedRipples == 0 ||
          controller.status != AnimationStatus.dismissed) {
        return;
      }
      unawaited(controller.forward(from: 0));
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PdpWaterRippleRouteInherited(state: this, child: widget.child);
  }
}

class _PdpWaterRippleRouteInherited extends InheritedWidget {
  final _PdpWaterRippleRouteScopeState state;

  const _PdpWaterRippleRouteInherited({
    required this.state,
    required super.child,
  });

  @override
  bool updateShouldNotify(_PdpWaterRippleRouteInherited oldWidget) {
    return !identical(state, oldWidget.state);
  }
}

/// Plain-image shuttle for the PLP→PDP Hero flight.
///
/// The water-ripple shader is intentionally NOT run during the flight:
/// [AnimatedSampler] snapshots its child to an offscreen image every frame
/// (`toImageSync`), and doing that inside the root Overlay while the route
/// transitions crosses CanvasKit WebGL contexts on web — the source of the
/// `WebGL: INVALID_OPERATION: delete: object does not belong to this context`
/// flood. The ripple runs once the flight lands, on [PdpWaterRipple] around
/// whichever destination image is mounted at that point.
HeroFlightShuttleBuilder pdpHeroFlightShuttleBuilder({
  required String imageUrl,
  required BoxFit fit,
  required Color color,
}) {
  return (
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: color,
        child: Image(
          image: NetworkImage(imageUrl),
          fit: fit,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        ),
      ),
    );
  };
}

/// Plays a single water-ripple pulse over [child] when first mounted, then
/// settles back to painting [child] directly (the offscreen sampler is dropped
/// once the pulse completes, so there is no lingering per-frame cost).
///
/// This is the PDP hero-image entry animation. Under
/// [PdpWaterRippleRouteScope], the loading Hero and loaded carousel share the
/// same pulse, which starts when the route/Hero transition has landed.
class PdpWaterRipple extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Offset origin;
  final Duration duration;
  final double intensity;

  const PdpWaterRipple({
    super.key,
    required this.child,
    this.enabled = true,
    this.origin = kPdpWaterRippleDefaultOrigin,
    // ~1s keeps the entry animation snappy and halves the time spent in the
    // reduced-framerate window (the per-frame shader snapshot drops a 120Hz
    // PDP to ~55-60fps while it runs — see profiling notes). The shader's decay
    // still completes within one pass (_shaderCycleSeconds spans the full wave).
    this.duration = const Duration(milliseconds: 1000),
    this.intensity = 1.0,
  });

  @override
  State<PdpWaterRipple> createState() => _PdpWaterRippleState();
}

class _PdpWaterRippleState extends State<PdpWaterRipple>
    with TickerProviderStateMixin {
  // Seconds of shader time spanned by one controller pass; tuned so the wave
  // has fully decayed (see exp(-decay*time) in pdp_water_ripple.frag) by the
  // time the pulse ends.
  static const double _shaderCycleSeconds = 2.2;

  // A local controller preserves the standalone behavior outside a PDP route
  // scope. Inside the scope, this points to its shared one-shot controller.
  AnimationController? _controller;
  _PdpWaterRippleRouteScopeState? _availableRouteScope;
  bool _ownsController = false;
  bool _attachedToRouteScope = false;

  @override
  void initState() {
    super.initState();
    _precacheIfEnabled();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRouteScope = PdpWaterRippleRouteScope._maybeOf(context);
    if (!identical(_availableRouteScope, nextRouteScope)) {
      _disconnectController();
      _availableRouteScope = nextRouteScope;
    }
    _connectControllerIfNeeded();
  }

  @override
  void didUpdateWidget(PdpWaterRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _disconnectController();
      return;
    }

    _precacheIfEnabled();
    if (!oldWidget.enabled) {
      _connectControllerIfNeeded();
    } else if (oldWidget.duration != widget.duration) {
      if (_attachedToRouteScope) {
        _availableRouteScope?._updateDuration(widget.duration);
      } else if (_ownsController &&
          _controller?.status == AnimationStatus.dismissed) {
        _controller?.duration = widget.duration;
      }
    }
  }

  void _precacheIfEnabled() {
    if (widget.enabled) {
      unawaited(ShaderBuilder.precacheShader(kPdpWaterRippleShaderAsset));
    }
  }

  void _connectControllerIfNeeded() {
    if (!widget.enabled || _controller != null) {
      return;
    }

    final routeScope = _availableRouteScope;
    if (routeScope != null) {
      _controller = routeScope._attachRipple(widget.duration);
      _attachedToRouteScope = true;
      return;
    }

    final controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller = controller;
    _ownsController = true;
    unawaited(controller.forward(from: 0));
  }

  void _disconnectController() {
    if (_attachedToRouteScope) {
      _availableRouteScope?._detachRipple();
    }
    if (_ownsController) {
      _controller?.dispose();
    }
    _controller = null;
    _ownsController = false;
    _attachedToRouteScope = false;
  }

  @override
  void dispose() {
    _disconnectController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!widget.enabled || controller == null) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        if (controller.status != AnimationStatus.forward) {
          return child ?? const SizedBox.shrink();
        }
        final time = controller.value * _shaderCycleSeconds;
        return RepaintBoundary(
          child: ShaderBuilder(
            (context, shader, shaderChild) {
              final sampledChild = shaderChild ?? const SizedBox.shrink();
              return AnimatedSampler((
                ui.Image image,
                Size size,
                ui.Canvas canvas,
              ) {
                if (size.isEmpty) return;
                shader
                  ..setFloat(0, size.width)
                  ..setFloat(1, size.height)
                  ..setFloat(2, widget.origin.dx)
                  ..setFloat(3, widget.origin.dy)
                  ..setFloat(4, time)
                  ..setFloat(5, widget.intensity)
                  ..setImageSampler(0, image);
                canvas.drawRect(
                  Offset.zero & size,
                  ui.Paint()..shader = shader,
                );
              }, child: sampledChild);
            },
            assetKey: kPdpWaterRippleShaderAsset,
            child: child,
          ),
        );
      },
    );
  }
}
