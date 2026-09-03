import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sensors/foil_tilt.dart';
import '../../data/models/product_foil.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../l10n/l10n_extension.dart';
import '../providers/product_foil_provider.dart';
import 'product_foil_volume_painter.dart';

const double _mobileFoilTiltTravel = 0.35;

/// User-visible state of the mobile orientation interaction.
enum HoloFoilMotionState {
  disabled,
  permissionRequired,
  starting,
  active,
  unavailable,
}

/// Hosts the pointer state for [HoloFoilOverlay] descendants. Mounted at the
/// hero image panel level, where hover and direct-touch events reliably arrive
/// — intermediate image widgets (fade/placeholder states) don't always claim
/// hit-tests, so listening directly on the image is fragile.
class HoloFoilPointerScope extends StatefulWidget {
  final Widget child;
  final bool enableMobileTilt;
  final FoilTiltSourceFactory? tiltSourceFactory;

  const HoloFoilPointerScope({
    super.key,
    required this.child,
    this.enableMobileTilt = false,
    this.tiltSourceFactory,
  });

  /// Global pointer position while hovering or touching inside the scope, null
  /// after exit/release. Returns null when no scope is present (the overlay
  /// then simply never shows its interactive shine).
  static ValueListenable<Offset?>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_HoloFoilPointerInherited>()
      ?.pointer;

  /// Normalised light position driven by device tilt on a mobile viewport.
  /// Values stay inside the image-safe `[0.15, 0.85]` range. Returns null
  /// when motion is disabled, unavailable, or has not been authorised yet.
  static ValueListenable<Offset?>? maybeTiltOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_HoloFoilPointerInherited>()
      ?.tilt;

  /// Whether mobile motion is ready or still needs an explicit permission tap.
  static ValueListenable<HoloFoilMotionState>? maybeMotionStateOf(
    BuildContext context,
  ) => context
      .dependOnInheritedWidgetOfExactType<_HoloFoilPointerInherited>()
      ?.motionState;

  /// Explicit motion-permission action used by the accessible iOS affordance.
  static VoidCallback? maybeRequestMotionOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_HoloFoilPointerInherited>()
      ?.requestMotion;

  @override
  State<HoloFoilPointerScope> createState() => _HoloFoilPointerScopeState();
}

class _HoloFoilPointerScopeState extends State<HoloFoilPointerScope>
    with WidgetsBindingObserver {
  static const double _mobileViewportMaxWidth = 768;
  static const double _tiltSmoothing = 0.18;

  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);
  final ValueNotifier<Offset?> _tilt = ValueNotifier<Offset?>(null);
  final ValueNotifier<HoloFoilMotionState> _motionState =
      ValueNotifier<HoloFoilMotionState>(HoloFoilMotionState.disabled);
  late final _HoloFoilMotionRegistry _motionRegistry;

  FoilTiltSource? _tiltSource;
  Orientation? _orientation;
  bool _canUseTilt = false;
  bool _tiltRequested = false;
  bool _tiltStarting = false;
  bool _tiltActive = false;
  bool _isMobileViewport = false;
  bool _reducedMotion = false;
  bool _hasMotionConsumer = false;
  int? _activeTouchPointer;

  @override
  void initState() {
    super.initState();
    _motionRegistry = _HoloFoilMotionRegistry(_onMotionConsumersChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onMotionConsumersChanged(bool hasConsumers) {
    if (_hasMotionConsumer == hasConsumers) return;
    _hasMotionConsumer = hasConsumers;
    _updateTiltEligibility();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    final orientation = media.orientation;
    if (_orientation != null && _orientation != orientation) {
      _tiltSource?.recenter();
      _tilt.value = null;
    }
    _orientation = orientation;
    _isMobileViewport = media.size.width < _mobileViewportMaxWidth;
    _reducedMotion = media.disableAnimations;
    _updateTiltEligibility();
  }

  void _updateTiltEligibility() {
    final canUseTilt =
        widget.enableMobileTilt &&
        (_hasMotionConsumer || widget.tiltSourceFactory != null) &&
        _isMobileViewport &&
        !_reducedMotion;
    if (_canUseTilt == canUseTilt) {
      if (_canUseTilt) _startTiltWhenAllowed();
      return;
    }
    _canUseTilt = canUseTilt;
    if (!_canUseTilt) {
      _stopTilt();
    } else {
      _startTiltWhenAllowed();
    }
  }

  void _startTiltWhenAllowed() {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final source = _tiltSource ??=
        widget.tiltSourceFactory?.call() ?? createFoilTiltSource();
    if (!_tiltRequested && source.requiresUserGesture) {
      _motionState.value = HoloFoilMotionState.permissionRequired;
      return;
    }
    _tiltRequested = true;
    unawaited(_startTilt());
  }

  @override
  void didUpdateWidget(HoloFoilPointerScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tiltSourceFactory != widget.tiltSourceFactory) {
      _tiltSource?.dispose();
      _tiltSource = null;
      _tiltActive = false;
      _tiltStarting = false;
      _tilt.value = null;
      _motionState.value = HoloFoilMotionState.disabled;
      _canUseTilt = false;
    }
    if (oldWidget.enableMobileTilt != widget.enableMobileTilt ||
        oldWidget.tiltSourceFactory != widget.tiltSourceFactory) {
      _updateTiltEligibility();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_canUseTilt && _tiltRequested) unawaited(_startTilt());
      return;
    }
    _stopTilt();
  }

  void _requestTiltFromGesture() {
    if (!_canUseTilt || _tiltActive || _tiltStarting) return;
    _tiltRequested = true;
    // Keep this call synchronous with the pointer event: iOS Safari only
    // accepts DeviceOrientationEvent.requestPermission from a user gesture.
    unawaited(_startTilt());
  }

  Future<void> _startTilt() async {
    if (!_canUseTilt || _tiltActive || _tiltStarting || !mounted) return;
    _tiltStarting = true;
    _motionState.value = HoloFoilMotionState.starting;
    final source = _tiltSource ??=
        widget.tiltSourceFactory?.call() ?? createFoilTiltSource();
    final started = await source.start(_onTiltSample);
    if (!mounted || !_canUseTilt) {
      source.stop();
      if (mounted) {
        _tiltStarting = false;
        _motionState.value = HoloFoilMotionState.disabled;
      }
      return;
    }
    _tiltStarting = false;
    _tiltActive = started;
    _motionState.value = started
        ? HoloFoilMotionState.active
        : HoloFoilMotionState.unavailable;
    if (!started) {
      _tilt.value = null;
    }
  }

  void _onTiltSample(FoilTilt? sample) {
    if (!mounted || !_canUseTilt) return;
    if (sample == null) {
      _tiltActive = false;
      _tilt.value = null;
      _motionState.value = HoloFoilMotionState.unavailable;
      return;
    }
    final target = Offset(
      0.5 + sample.horizontal * _mobileFoilTiltTravel,
      0.5 + sample.vertical * _mobileFoilTiltTravel,
    );
    // ValueNotifier invalidations are coalesced by RenderCustomPaint into the
    // next paint. Publishing here avoids a scheduler deadlock where the first
    // browser sensor event can queue a transient callback after that phase of
    // the current frame has already run, leaving the tilt permanently null.
    _tilt.value = Offset.lerp(_tilt.value ?? target, target, _tiltSmoothing);
  }

  void _stopTilt() {
    _tiltSource?.stop();
    _tiltStarting = false;
    _tiltActive = false;
    _tilt.value = null;
    _motionState.value = HoloFoilMotionState.disabled;
  }

  bool _isDirectTouch(PointerEvent event) =>
      event.kind == ui.PointerDeviceKind.touch ||
      event.kind == ui.PointerDeviceKind.stylus ||
      event.kind == ui.PointerDeviceKind.invertedStylus;

  void _onPointerDown(PointerDownEvent event) {
    _requestTiltFromGesture();
    if (!_isMobileViewport || _reducedMotion || !_isDirectTouch(event)) return;
    _activeTouchPointer ??= event.pointer;
    if (_activeTouchPointer == event.pointer) {
      _pointer.value = event.position;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activeTouchPointer == event.pointer) {
      _pointer.value = event.position;
    }
  }

  void _onPointerEnd(PointerEvent event) {
    if (_activeTouchPointer != event.pointer) return;
    _activeTouchPointer = null;
    _pointer.value = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tiltSource?.dispose();
    _pointer.dispose();
    _tilt.dispose();
    _motionState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HoloFoilPointerInherited(
      pointer: _pointer,
      tilt: _tilt,
      motionState: _motionState,
      requestMotion: _requestTiltFromGesture,
      motionRegistry: _motionRegistry,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        onPointerHover: (event) {
          if (_activeTouchPointer == null) _pointer.value = event.position;
        },
        child: MouseRegion(
          opaque: false,
          onExit: (_) {
            if (_activeTouchPointer == null) _pointer.value = null;
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _HoloFoilPointerInherited extends InheritedWidget {
  final ValueNotifier<Offset?> pointer;
  final ValueNotifier<Offset?> tilt;
  final ValueNotifier<HoloFoilMotionState> motionState;
  final VoidCallback requestMotion;
  final _HoloFoilMotionRegistry motionRegistry;

  const _HoloFoilPointerInherited({
    required this.pointer,
    required this.tilt,
    required this.motionState,
    required this.requestMotion,
    required this.motionRegistry,
    required super.child,
  });

  @override
  bool updateShouldNotify(_HoloFoilPointerInherited oldWidget) =>
      pointer != oldWidget.pointer;
}

class _HoloFoilMotionRegistry {
  final ValueChanged<bool> _onChanged;
  final Set<Object> _consumers = <Object>{};

  _HoloFoilMotionRegistry(this._onChanged);

  void register(Object consumer) {
    if (_consumers.add(consumer) && _consumers.length == 1) {
      _onChanged(true);
    }
  }

  void unregister(Object consumer) {
    if (_consumers.remove(consumer) && _consumers.isEmpty) {
      _onChanged(false);
    }
  }
}

/// Decorative holo-foil overlay for PDP product images, replaying the
/// `product_foils` record saved from the Foil studio on top of the original
/// image: a light sweep on mount, then a pointer-driven shine on hover.
///
/// Cost model (PDP is jank-sensitive):
/// - No foil record, media mismatch, or textures not loaded → returns the
///   child untouched, zero paint cost.
/// - Classic foil idle after the sweep → the painter early-returns (opacity 0)
///   and no ticker runs. A published 2.5D bundle keeps its layered photo
///   visible but only deforms while pointer/tilt input is active.
/// - Pointer moves repaint through the painter's `repaint` listenable — the
///   widget tree never rebuilds per frame.
/// - The sweep is gated on `MediaQuery.disableAnimationsOf` (reduced
///   motion), per the repo motion rules.
///
/// Renderer safety: paint uses gradients, `drawImageRect` and `saveLayer`
/// only — none of the web-renderer-fatal APIs (no `toImage`, no
/// `FragmentShader`, no live-tree capture).
class HoloFoilOverlay extends ConsumerStatefulWidget {
  final String productId;
  final CatalogMedia media;
  final BoxFit fit;
  final Alignment alignment;
  final Widget child;

  const HoloFoilOverlay({
    super.key,
    required this.productId,
    required this.media,
    required this.fit,
    required this.alignment,
    required this.child,
  });

  @override
  ConsumerState<HoloFoilOverlay> createState() => _HoloFoilOverlayState();
}

class _HoloFoilOverlayState extends ConsumerState<HoloFoilOverlay>
    with TickerProviderStateMixin {
  // Decoded textures are shared across PDP visits and bounded because a 2.5D
  // bundle includes the product-sized source/background layers. URLs embed
  // the record's `updated` stamp, so a newly published bundle gets new keys.
  static final Map<String, Future<ui.Image?>> _textureCache = {};
  static const int _maxTextureCacheEntries = 48;

  static Future<ui.Image?> _loadTexture(String url) {
    final cached = _textureCache.remove(url);
    if (cached != null) {
      _textureCache[url] = cached;
      return cached;
    }
    final future = () async {
      try {
        final completer = Completer<ui.Image>();
        final stream = CachedNetworkImageProvider(
          url,
        ).resolve(ImageConfiguration.empty);
        late final ImageStreamListener listener;
        listener = ImageStreamListener(
          (info, _) {
            if (!completer.isCompleted) completer.complete(info.image);
            stream.removeListener(listener);
          },
          onError: (error, stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
            stream.removeListener(listener);
          },
        );
        stream.addListener(listener);
        return await completer.future;
      } catch (_) {
        return null;
      }
    }();
    _textureCache[url] = future;
    future.then((image) {
      if (image == null && identical(_textureCache[url], future)) {
        _textureCache.remove(url);
      }
    });
    if (_textureCache.length > _maxTextureCacheEntries) {
      // Drop the cache reference only; a live painter may still own the image.
      // dart:ui finalizers reclaim it after the last consumer releases it.
      _textureCache.remove(_textureCache.keys.first);
    }
    return future;
  }

  // Created eagerly in initState: a lazy `late final` controller would
  // otherwise be instantiated by dispose() itself (ticker creation on a
  // deactivated element throws).
  late final AnimationController _sweep;
  late final AnimationController _hover;
  late final AnimationController _particleClock;
  final ValueNotifier<Offset?> _pointer = ValueNotifier<Offset?>(null);
  final ValueNotifier<Offset?> _fallbackTilt = ValueNotifier<Offset?>(null);
  final ValueNotifier<HoloFoilMotionState> _fallbackMotionState =
      ValueNotifier<HoloFoilMotionState>(HoloFoilMotionState.disabled);

  String? _loadedTextureSignature;
  ui.Image? _foilImage;
  ui.Image? _maskImage;
  ui.Image? _sourceImage;
  ui.Image? _subjectMaskImage;
  ui.Image? _backgroundCleanImage;
  ui.Image? _rimImage;
  bool _sweepPlayed = false;
  ValueListenable<Offset?>? _scopePointer;
  ValueListenable<Offset?>? _scopeTilt;
  ValueListenable<HoloFoilMotionState>? _scopeMotionState;
  _HoloFoilMotionRegistry? _motionRegistry;
  bool _motionRegistered = false;
  bool _motionRegistrationScheduled = false;
  bool _pendingMotionEligibility = false;
  bool _particleAnimationActive = false;
  bool _particleAnimationScheduled = false;
  bool _pendingParticleAnimation = false;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _hover = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 450),
    );
    _particleClock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = HoloFoilPointerScope.maybeOf(context);
    if (!identical(scope, _scopePointer)) {
      _scopePointer?.removeListener(_onScopePointer);
      _scopePointer = scope;
      _scopePointer?.addListener(_onScopePointer);
    }
    final tilt = HoloFoilPointerScope.maybeTiltOf(context);
    if (!identical(tilt, _scopeTilt)) {
      _scopeTilt?.removeListener(_onScopeTilt);
      _scopeTilt = tilt;
      _scopeTilt?.addListener(_onScopeTilt);
    }
    _scopeMotionState = HoloFoilPointerScope.maybeMotionStateOf(context);
    final motionRegistry = context
        .dependOnInheritedWidgetOfExactType<_HoloFoilPointerInherited>()
        ?.motionRegistry;
    if (!identical(motionRegistry, _motionRegistry)) {
      if (_motionRegistered) _motionRegistry?.unregister(this);
      _motionRegistry = motionRegistry;
      _motionRegistered = false;
    }
  }

  void _onScopePointer() {
    if (!mounted) return;
    final global = _scopePointer?.value;
    if (global == null) {
      _pointer.value = null;
      _onExit();
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final local = box.globalToLocal(global);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > box.size.width ||
        local.dy > box.size.height) {
      _pointer.value = null;
      _onExit();
      return;
    }
    _pointer.value = local;
    if (_hover.status != AnimationStatus.forward &&
        _hover.status != AnimationStatus.completed) {
      _hover.forward();
    }
  }

  void _onScopeTilt() {
    if (!mounted) return;
    if (_scopeTilt?.value == null) {
      if (_pointer.value == null) _onExit();
      return;
    }
    if (_hover.status != AnimationStatus.forward &&
        _hover.status != AnimationStatus.completed) {
      _hover.forward();
    }
  }

  void _scheduleMotionRegistration(bool eligible) {
    _pendingMotionEligibility = eligible;
    if (_motionRegistrationScheduled || _motionRegistered == eligible) return;
    _motionRegistrationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _motionRegistrationScheduled = false;
      if (!mounted) return;
      final shouldRegister = _pendingMotionEligibility;
      if (_motionRegistered == shouldRegister) return;
      if (shouldRegister) {
        _motionRegistry?.register(this);
        _motionRegistered = _motionRegistry != null;
      } else {
        _motionRegistry?.unregister(this);
        _motionRegistered = false;
      }
    });
  }

  void _scheduleParticleAnimation(bool active) {
    _pendingParticleAnimation = active;
    if (_particleAnimationScheduled || _particleAnimationActive == active) {
      return;
    }
    _particleAnimationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _particleAnimationScheduled = false;
      if (!mounted) return;
      final shouldAnimate = _pendingParticleAnimation;
      if (_particleAnimationActive == shouldAnimate) return;
      _particleAnimationActive = shouldAnimate;
      if (shouldAnimate) {
        _particleClock.repeat();
      } else {
        _particleClock.stop(canceled: false);
      }
    });
  }

  @override
  void dispose() {
    _scopePointer?.removeListener(_onScopePointer);
    _scopeTilt?.removeListener(_onScopeTilt);
    if (_motionRegistered) _motionRegistry?.unregister(this);
    _sweep.dispose();
    _hover.dispose();
    _particleClock.dispose();
    _pointer.dispose();
    _fallbackTilt.dispose();
    _fallbackMotionState.dispose();
    super.dispose();
  }

  void _ensureTextures(ProductFoil foil) {
    final foilUrl = foil.foilUrl;
    if (foilUrl == null) return;
    final maskUrl = foil.maskUrl;
    final wantsParallax = foil.hasParallaxBundle;
    final sourceUrl = wantsParallax
        ? (foil.productImageUrl ?? foil.sourceImage)
        : null;
    final subjectMaskUrl = wantsParallax ? foil.subjectMaskUrl : null;
    final backgroundCleanUrl = wantsParallax ? foil.backgroundCleanUrl : null;
    final rimUrl = wantsParallax ? foil.rimUrl : null;
    final signature = [
      foilUrl,
      maskUrl ?? '',
      sourceUrl ?? '',
      subjectMaskUrl ?? '',
      backgroundCleanUrl ?? '',
      rimUrl ?? '',
    ].join('|');
    if (_loadedTextureSignature == signature) return;
    _loadedTextureSignature = signature;
    _sweepPlayed = false;
    _foilImage = null;
    _maskImage = null;
    _sourceImage = null;
    _subjectMaskImage = null;
    _backgroundCleanImage = null;
    _rimImage = null;
    Future.wait<ui.Image?>([
      _loadTexture(foilUrl),
      if (maskUrl != null) _loadTexture(maskUrl) else Future.value(null),
      if (sourceUrl != null) _loadTexture(sourceUrl) else Future.value(null),
      if (subjectMaskUrl != null)
        _loadTexture(subjectMaskUrl)
      else
        Future.value(null),
      if (backgroundCleanUrl != null)
        _loadTexture(backgroundCleanUrl)
      else
        Future.value(null),
      if (rimUrl != null) _loadTexture(rimUrl) else Future.value(null),
    ]).then((images) {
      if (!mounted || _loadedTextureSignature != signature) return;
      setState(() {
        _foilImage = images[0];
        _maskImage = images[1];
        _sourceImage = images[2];
        _subjectMaskImage = images[3];
        _backgroundCleanImage = images[4];
        _rimImage = images[5];
      });
      _maybePlaySweep();
    });
  }

  void _maybePlaySweep() {
    if (_sweepPlayed || _foilImage == null || !mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _sweepPlayed = true;
    _sweep.forward(from: 0);
  }

  void _onExit() {
    if (!mounted) return;
    if (_scopeTilt?.value != null) return;
    _hover.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final foil = ref
        .watch(productFoilProvider(widget.productId))
        .maybeWhen(data: (value) => value, orElse: () => null);
    if (foil == null ||
        foil.foilUrl == null ||
        !foil.matchesMediaId(widget.media.id)) {
      _scheduleMotionRegistration(false);
      _scheduleParticleAnimation(false);
      return widget.child;
    }
    _ensureTextures(foil);
    final foilImage = _foilImage;
    if (foilImage == null) {
      _scheduleMotionRegistration(false);
      _scheduleParticleAnimation(false);
      return widget.child;
    }
    _scheduleMotionRegistration(true);
    final tilt = _scopeTilt ?? _fallbackTilt;
    final motionState = _scopeMotionState ?? _fallbackMotionState;
    final requestMotion = HoloFoilPointerScope.maybeRequestMotionOf(context);
    final sourceImage = _sourceImage;
    final subjectMaskImage = _subjectMaskImage;
    final backgroundCleanImage = _backgroundCleanImage;
    final rimImage = _rimImage;
    final volumeReady =
        foil.hasParallaxBundle &&
        sourceImage != null &&
        subjectMaskImage != null &&
        backgroundCleanImage != null &&
        rimImage != null;
    final motionEnabled = !MediaQuery.disableAnimationsOf(context);
    _scheduleParticleAnimation(
      volumeReady && foil.hasParticleBundle && motionEnabled,
    );
    final touchEnabled =
        motionEnabled && MediaQuery.sizeOf(context).width < 768;

    // Pointer is driven by the enclosing HoloFoilPointerScope (hover/direct
    // touch captured at the hero panel level and forwarded here); the overlay
    // itself is fully non-interactive so carousel swipes, taps and scrolls
    // behave exactly as without it.
    final visual = RepaintBoundary(
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: volumeReady
                      ? ProductFoilVolumePainter(
                          source: sourceImage,
                          subjectMask: subjectMaskImage,
                          background: backgroundCleanImage,
                          rim: rimImage,
                          fit: widget.fit,
                          alignment: widget.alignment,
                          depthMesh: foil.hasVolumeBundle
                              ? foil.depthMesh
                              : null,
                          particles: foil.hasParticleBundle
                              ? foil.particles
                              : const [],
                          particleTime: _particleClock,
                          sweep: _sweep,
                          hover: _hover,
                          pointer: _pointer,
                          tilt: tilt,
                          motionEnabled: motionEnabled,
                          webMobileSafe:
                              kIsWeb && MediaQuery.sizeOf(context).width < 768,
                        )
                      : _HoloFoilPainter(
                          foil: foilImage,
                          mask: _maskImage,
                          fit: widget.fit,
                          alignment: widget.alignment,
                          intensity: foil.intensity.clamp(0.0, 1.5),
                          sweep: _sweep,
                          hover: _hover,
                          pointer: _pointer,
                          // Listen to the scope notifier directly so sensor
                          // samples repaint without a mutable bridge.
                          tilt: tilt,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Stack(
      children: [
        _MobileFoilPose(
          pointer: _pointer,
          tilt: tilt,
          touchEnabled: touchEnabled,
          child: visual,
        ),
        Positioned(
          top: 18,
          right: 18,
          child: _HoloFoilTiltHint(
            pointer: _pointer,
            tilt: tilt,
            motionState: motionState,
            requestMotion: requestMotion,
            touchEnabled: touchEnabled,
          ),
        ),
      ],
    );
  }
}

/// A PDP adaptation of the expressive Pokémon card pose: the whole product
/// visual rotates with the foil, while dynamic overscan keeps the full-bleed
/// hero free of exposed corners. Transform hit-testing is disabled so
/// horizontal carousel swipes retain their original gesture geometry.
class _MobileFoilPose extends StatelessWidget {
  // Exact Pokémon pointer mapping: `(position - 50) / 3.5` reaches ±14.2857°
  // on both axes, with the same 600 px perspective. Full-bleed PDP overscan is
  // retained solely to hide the corners exposed by that stronger rotation.
  static const double _maxRotationDegrees = 50 / 3.5;
  static const double _perspectiveDepth = 600;
  static const double _maxOverscan = 0.08;

  final ValueListenable<Offset?> pointer;
  final ValueListenable<Offset?> tilt;
  final bool touchEnabled;
  final Widget child;

  const _MobileFoilPose({
    required this.pointer,
    required this.tilt,
    required this.touchEnabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ValueListenableBuilder<Offset?>(
        valueListenable: pointer,
        builder: (context, pointerPosition, _) =>
            ValueListenableBuilder<Offset?>(
              valueListenable: tilt,
              builder: (context, tiltPosition, _) {
                final canMapPointer =
                    touchEnabled &&
                    pointerPosition != null &&
                    constraints.maxWidth > 0 &&
                    constraints.maxHeight > 0 &&
                    constraints.maxWidth.isFinite &&
                    constraints.maxHeight.isFinite;
                final target = canMapPointer
                    ? Offset(
                        (pointerPosition.dx / constraints.maxWidth).clamp(
                          0.0,
                          1.0,
                        ),
                        (pointerPosition.dy / constraints.maxHeight).clamp(
                          0.0,
                          1.0,
                        ),
                      )
                    : tiltPosition == null
                    ? const Offset(0.5, 0.5)
                    : Offset(
                        0.5 +
                            ((tiltPosition.dx - 0.5) / _mobileFoilTiltTravel)
                                    .clamp(-1.0, 1.0) *
                                0.5,
                        0.5 +
                            ((tiltPosition.dy - 0.5) / _mobileFoilTiltTravel)
                                    .clamp(-1.0, 1.0) *
                                0.5,
                      );
                return TweenAnimationBuilder<Offset>(
                  tween: Tween(end: target),
                  duration: canMapPointer
                      ? const Duration(milliseconds: 90)
                      : const Duration(milliseconds: 450),
                  curve: canMapPointer ? Curves.easeOutCubic : Curves.easeOut,
                  child: child,
                  builder: (context, position, child) {
                    final horizontal = ((position.dx - 0.5) * 2).clamp(
                      -1.0,
                      1.0,
                    );
                    final vertical = ((position.dy - 0.5) * 2).clamp(-1.0, 1.0);
                    final amplitude = math.max(
                      horizontal.abs(),
                      vertical.abs(),
                    );
                    final overscan = 1 + amplitude * _maxOverscan;
                    final matrix = Matrix4.identity()
                      ..setEntry(3, 2, 1 / _perspectiveDepth)
                      ..rotateX(-vertical * _maxRotationDegrees * math.pi / 180)
                      ..rotateY(
                        horizontal * _maxRotationDegrees * math.pi / 180,
                      )
                      ..scaleByDouble(overscan, overscan, 1, 1);
                    return Transform(
                      alignment: Alignment.center,
                      transform: matrix,
                      transformHitTests: false,
                      child: child,
                    );
                  },
                );
              },
            ),
        child: child,
      ),
    );
  }
}

/// Short-lived affordance: it explains both direct touch and device motion,
/// then gets out of the product photography after the first interaction.
class _HoloFoilTiltHint extends StatefulWidget {
  final ValueListenable<Offset?> pointer;
  final ValueListenable<Offset?> tilt;
  final ValueListenable<HoloFoilMotionState> motionState;
  final VoidCallback? requestMotion;
  final bool touchEnabled;

  const _HoloFoilTiltHint({
    required this.pointer,
    required this.tilt,
    required this.motionState,
    required this.requestMotion,
    required this.touchEnabled,
  });

  @override
  State<_HoloFoilTiltHint> createState() => _HoloFoilTiltHintState();
}

class _HoloFoilTiltHintState extends State<_HoloFoilTiltHint> {
  static const Duration _autoHideDelay = Duration(seconds: 6);
  static const double _understoodDistance = 0.055;

  Timer? _autoHideTimer;
  bool _gestureUnderstood = false;
  bool _hiddenByTimeout = false;
  late HoloFoilMotionState _lastMotionState;

  @override
  void initState() {
    super.initState();
    _lastMotionState = widget.motionState.value;
    widget.pointer.addListener(_onInteractionChanged);
    widget.tilt.addListener(_onInteractionChanged);
    widget.motionState.addListener(_onInteractionChanged);
    _syncAutoHideTimer();
  }

  @override
  void didUpdateWidget(_HoloFoilTiltHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pointer, widget.pointer)) {
      oldWidget.pointer.removeListener(_onInteractionChanged);
      widget.pointer.addListener(_onInteractionChanged);
    }
    if (!identical(oldWidget.tilt, widget.tilt)) {
      oldWidget.tilt.removeListener(_onInteractionChanged);
      widget.tilt.addListener(_onInteractionChanged);
    }
    if (!identical(oldWidget.motionState, widget.motionState)) {
      oldWidget.motionState.removeListener(_onInteractionChanged);
      widget.motionState.addListener(_onInteractionChanged);
    }
    _syncAutoHideTimer();
  }

  void _onInteractionChanged() {
    final motionState = widget.motionState.value;
    final stateChanged = motionState != _lastMotionState;
    _lastMotionState = motionState;
    final position = widget.tilt.value;
    var understoodNow = false;
    if (((widget.touchEnabled && widget.pointer.value != null) ||
            (position != null &&
                (position - const Offset(0.5, 0.5)).distance >=
                    _understoodDistance)) &&
        !_gestureUnderstood) {
      _gestureUnderstood = true;
      understoodNow = true;
      _autoHideTimer?.cancel();
      _autoHideTimer = null;
    }
    _syncAutoHideTimer();
    if (mounted && (stateChanged || understoodNow)) setState(() {});
  }

  void _syncAutoHideTimer() {
    if (!widget.touchEnabled &&
        widget.motionState.value != HoloFoilMotionState.active) {
      _autoHideTimer?.cancel();
      _autoHideTimer = null;
      return;
    }
    if (_gestureUnderstood || _hiddenByTimeout || _autoHideTimer != null) {
      return;
    }
    _autoHideTimer = Timer(_autoHideDelay, () {
      _autoHideTimer = null;
      if (!mounted) return;
      setState(() => _hiddenByTimeout = true);
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    widget.pointer.removeListener(_onInteractionChanged);
    widget.tilt.removeListener(_onInteractionChanged);
    widget.motionState.removeListener(_onInteractionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.motionState.value;
    final needsPermission = state == HoloFoilMotionState.permissionRequired;
    final visible =
        !_gestureUnderstood &&
        !_hiddenByTimeout &&
        (widget.touchEnabled ||
            needsPermission ||
            state == HoloFoilMotionState.starting ||
            state == HoloFoilMotionState.active);
    final label = needsPermission
        ? context.l10n.pdpFoilEnableMotionHint
        : context.l10n.pdpFoilTiltHint;

    return Semantics(
      liveRegion: needsPermission,
      button: needsPermission,
      label: label,
      onTap: needsPermission ? widget.requestMotion : null,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xB82C2C2A),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x2EFFFFFF)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    needsPermission
                        ? Icons.touch_app_outlined
                        : Icons.pan_tool_alt_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoloFoilPainter extends CustomPainter {
  final ui.Image foil;
  final ui.Image? mask;
  final BoxFit fit;
  final Alignment alignment;
  final double intensity;
  final Animation<double> sweep;
  final Animation<double> hover;
  final ValueListenable<Offset?> pointer;
  final ValueListenable<Offset?> tilt;

  _HoloFoilPainter({
    required this.foil,
    required this.mask,
    required this.fit,
    required this.alignment,
    required this.intensity,
    required this.sweep,
    required this.hover,
    required this.pointer,
    required this.tilt,
  }) : super(repaint: Listenable.merge([sweep, hover, pointer, tilt]));

  @override
  void paint(Canvas canvas, Size size) {
    final sweepT = sweep.value;
    final sweepActive = sweep.status == AnimationStatus.forward;
    // Bell curve: the sweep fades in and out over its run.
    final sweepOpacity = sweepActive ? math.sin(math.pi * sweepT) : 0.0;
    final hoverOpacity = hover.value;
    final tiltPosition = tilt.value;
    final tiltOpacity = tiltPosition == null ? 0.0 : 1.0;
    final interactiveOpacity = math.max(hoverOpacity, tiltOpacity);
    final opacity = (math.max(sweepOpacity, interactiveOpacity) * intensity)
        .clamp(0.0, 1.0);
    if (opacity < 0.02) return;

    final rect = Offset.zero & size;
    final imageSize = Size(foil.width.toDouble(), foil.height.toDouble());
    final fitted = applyBoxFit(fit, imageSize, size);
    final dest = alignment.inscribe(fitted.destination, rect);

    canvas.save();
    canvas.clipRect(dest);

    // Light origin: pointer on hover, travelling point during the sweep.
    final interactivePosition =
        pointer.value ??
        (tiltPosition == null
            ? null
            : Offset(
                dest.left + dest.width * tiltPosition.dx,
                dest.top + dest.height * tiltPosition.dy,
              ));
    final p =
        (hoverOpacity >= sweepOpacity ? interactivePosition : null) ??
        Offset(
          dest.left + dest.width * (sweepT * 1.6 - 0.3),
          dest.top + dest.height * (0.2 + sweepT * 0.6),
        );

    // Pass 1 — the foil relief, colorDodged onto the artwork, revealed
    // around the light origin and stencilled by the mask.
    final reveal = ui.Gradient.radial(
      p,
      dest.longestSide * (tiltPosition == null ? 0.85 : 0.55),
      [
        const Color(0xFFFFFFFF),
        const Color(0xFFFFFFFF),
        const Color(0x00FFFFFF),
      ],
      const [0.0, 0.35, 1.0],
    );
    canvas.saveLayer(
      dest,
      Paint()
        ..blendMode = BlendMode.colorDodge
        ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity * 0.7),
    );
    canvas.drawImageRect(
      foil,
      Rect.fromLTWH(0, 0, imageSize.width, imageSize.height),
      dest,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.drawRect(
      dest,
      Paint()
        ..shader = reveal
        ..blendMode = BlendMode.dstIn,
    );
    final maskImage = mask;
    if (maskImage != null) {
      canvas.drawImageRect(
        maskImage,
        Rect.fromLTWH(
          0,
          0,
          maskImage.width.toDouble(),
          maskImage.height.toDouble(),
        ),
        dest,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..filterQuality = FilterQuality.medium,
      );
    }
    canvas.restore();

    // Pass 2 — a soft white glare that follows the light origin.
    final glare = ui.Gradient.radial(
      p,
      dest.longestSide * 0.7,
      [
        Color.fromRGBO(255, 255, 255, 0.32 * opacity),
        Color.fromRGBO(255, 255, 255, 0.10 * opacity),
        const Color(0x00FFFFFF),
      ],
      const [0.0, 0.35, 1.0],
    );
    canvas.drawRect(
      dest,
      Paint()
        ..shader = glare
        ..blendMode = BlendMode.overlay,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HoloFoilPainter oldDelegate) =>
      oldDelegate.foil != foil ||
      oldDelegate.mask != mask ||
      oldDelegate.fit != fit ||
      oldDelegate.alignment != alignment ||
      oldDelegate.intensity != intensity;
}
