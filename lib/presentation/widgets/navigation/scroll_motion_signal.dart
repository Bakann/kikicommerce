import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Smoothed scroll-velocity signal that drives the [IridescentNavRing] Home lens.
///
/// The host (an enclosing scroll surface, wired in `AdaptiveBottomNav`) feeds
/// raw per-update deltas via [onScrollDelta]. From those this derives two values
/// the shader consumes:
///
///  * [phase] — an accumulated rotation in *turns*, wrapped to `[0, 1)` so the
///    fragment shader's `fract()` stays seamless. It advances at a rate
///    proportional to the current smoothed speed and in the scroll's direction,
///    so the curved arc highlights spin with the page and coast to a stop.
///  * [energy] — the smoothed, normalized `|velocity|` (`0..~1.4`). It lifts the
///    glow and widens the chromatic dispersion.
///
/// Both rest at `0`, so a still page renders exactly as before.
///
/// A [Ticker] runs *only while there is motion*: it starts on the first scroll
/// delta and stops once energy has decayed to rest. Nothing ticks on mount or at
/// rest, which keeps the frame budget free during idle and leaves
/// `pumpAndSettle`-based nav tests unaffected (no scroll → no ticker).
class ScrollMotionSignal extends ChangeNotifier {
  ScrollMotionSignal(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;

  // --- Tuning ---------------------------------------------------------------

  /// Scroll speed (logical px/s) that maps to an energy of 1.0. A brisk flick
  /// sits a little above this; [_maxEnergy] caps the overshoot.
  static const double _refVelocity = 3200.0;
  static const double _maxEnergy = 1.4;

  /// Smoothing time constants (seconds), converted to a per-frame factor via
  /// `1 - e^(-dt/tau)` so the feel is frame-rate independent (a 120Hz screen
  /// coasts the same as 60Hz): a quick attack so the ring reacts at once, a
  /// longer release so it coasts to rest (optical inertia).
  static const double _attackTau = 0.05;
  static const double _releaseTau = 0.13;

  /// Turns/second the arcs sweep at full energy.
  static const double _turnsPerSecAtFull = 0.55;

  /// Surface-clock units/second at full energy. Drives the shader's u_time so
  /// the full procedural animation (the rich one the tap cycle plays — metallic
  /// flow, sparkles, sweep, breathing) also runs while scrolling. The tap cycle
  /// advances u_time at ~1.0/s; a higher rate makes a fast scroll livelier.
  static const double _surfaceFlowRate = 2.5;

  /// Below this the ring is considered at rest and the ticker stops.
  static const double _idleEpsilon = 0.004;

  /// dt guard: ignore absurd frame gaps (first frame, backgrounded tab) so a
  /// long pause can't fling the phase or spike the velocity.
  static const double _minDt = 1.0 / 240.0;
  static const double _maxDt = 1.0 / 20.0;

  // --- State ----------------------------------------------------------------

  double _energy = 0.0;
  double _phase = 0.0;
  double _animTime = 0.0;
  double _lastDir = 1.0;
  double _pendingDelta = 0.0;
  bool _primed = false;
  Duration _lastTick = Duration.zero;

  /// Accumulated rotation in turns, wrapped to `[0, 1)`. Drives arc rotation.
  double get phase => _phase;

  /// Smoothed normalized `|velocity|` (`0..~1.4`). Drives glow + dispersion.
  double get energy => _energy;

  /// Accumulated surface-animation clock (seconds-equivalent), added to the
  /// shader's u_time so the full procedural motion plays while scrolling.
  double get animTime => _animTime;

  /// Feed one scroll update's signed delta (logical px). Starts the ticker on
  /// the first non-zero delta after rest.
  void onScrollDelta(double deltaPixels) {
    if (deltaPixels == 0) return;
    _pendingDelta += deltaPixels;
    if (!_ticker.isActive) {
      _primed = false;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final double dt;
    if (!_primed) {
      _primed = true;
      dt = 1.0 / 60.0;
    } else {
      dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(_minDt, _maxDt);
    }
    _lastTick = elapsed;

    // Average signed velocity over the elapsed interval, normalized.
    final hadInput = _pendingDelta != 0.0;
    final signedNorm = (_pendingDelta / dt / _refVelocity).clamp(
      -_maxEnergy,
      _maxEnergy,
    );
    _pendingDelta = 0.0;
    if (signedNorm != 0.0) _lastDir = signedNorm.sign;

    final targetEnergy = signedNorm.abs();
    final tau = targetEnergy > _energy ? _attackTau : _releaseTau;
    final alpha = 1.0 - math.exp(-dt / tau);
    _energy += (targetEnergy - _energy) * alpha;

    // Advance rotation by the smoothed speed in the last travelled direction, so
    // it keeps spinning (and eases out) after the finger lifts.
    _phase += _lastDir * _energy * _turnsPerSecAtFull * dt;
    _phase -= _phase.floorToDouble(); // wrap to [0, 1), GLSL fract-style.

    // Advance the surface clock so u_time-driven motion (the rich tap-cycle
    // animation) plays while scrolling, scaled by speed. Freezes when the
    // ticker stops at rest; accumulates as a double, so no precision concern.
    _animTime += _energy * _surfaceFlowRate * dt;

    final atRest = _energy < _idleEpsilon && !hadInput;
    if (atRest) _energy = 0.0;

    notifyListeners();

    if (atRest) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
