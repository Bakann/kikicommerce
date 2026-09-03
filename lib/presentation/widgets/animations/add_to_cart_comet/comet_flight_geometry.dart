import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;

/// Pure geometry and look tables for the add-to-cart comet trail.
///
/// The trail mechanics are a faithful adaptation of the CodePen
/// "Circular trail" by enxaneta: a FIXED list of particles is pre-sampled
/// once per flight (the CodePen's array `p`), and each frame only moves a
/// read-window over that list behind an animated head index. Nothing here
/// creates particles per frame or simulates physics. The one deliberate
/// difference: the CodePen loops with `% n`, but a product → cart flight is
/// not a loop, so negative indices are skipped instead (the tail runs off
/// the start of the path and vanishes naturally).
///
/// Everything in this file is widget-free and deterministic so it can be
/// unit-tested without a widget tree.

/// Number of particles pre-sampled along the flight path (CodePen `n`).
const int kCometParticleCount = 260;

/// Reduced count for CanvasKit, where the per-particle blur is pricier.
const int kCometParticleCountWeb = 128;

/// Extra-light first-tap count for web mobile while shader warm-up is still
/// completing. Later taps use [kCometParticleCountWeb].
const int kCometParticleCountWebFirstTap = 96;

/// Trail read-window length behind the head (CodePen `l = ~~(3*n/4)`).
int cometTrailWindowLength(int n) => (3 * n) ~/ 4;

/// Stable per-particle pseudo-random in [0, 1) (CodePen `o.rnd` equivalent).
///
/// Same seed → same value, forever: the dispersion/hue/size/alpha of a given
/// particle never flickers between frames.
double seededRandom(int seed) {
  final x = (seed * 108013 + 2531011) & 0xffffffff;
  return ((x >> 16) % 32869) / 32869.0;
}

/// Minimum climb above the card so even a card sitting higher than the
/// screen centre still gets a visible ascent before the drop.
const double kCometMinClimbAboveStart = 90.0;

/// Fraction of the flight DURATION spent on the climb to the crest; the
/// remaining time is the gravity drop into the cart.
const double kCometClimbTimeShare = 0.62;

/// The roller-coaster flight path plus where its crest sits along the arc
/// length — [cometCoasterProgress] needs that fraction to pace the climb
/// and the drop independently of the geometry.
class CometFlightPath {
  const CometFlightPath({required this.path, required this.crestFraction});

  final Path path;

  /// Arc-length fraction [0, 1] at which the crest (apex) sits.
  final double crestFraction;
}

/// Crest of the coaster: horizontally on the screen centre (the flight
/// "passes through the middle of the screen"), vertically at the screen
/// centre or high enough above the card to always read as a climb.
Offset cometFlightApex(Offset start, Offset screenCenter) {
  final apexY = math.min(screenCenter.dy, start.dy - kCometMinClimbAboveStart);
  return Offset(screenCenter.dx, math.max(apexY, 20.0));
}

/// Roller-coaster path from the product image centre to the cart icon:
/// a progressive climb to a crest near the screen centre, then a
/// parabola-like dive that arrives almost vertically into the cart.
///
/// Both cubics share a horizontal tangent at the crest, so the clone tips
/// over the top like a coaster car; the dive's last control point sits
/// straight above the target, so it falls INTO the basket.
CometFlightPath buildCartFlightPath(
  Offset start,
  Offset end, {
  required Offset screenCenter,
}) {
  final apex = cometFlightApex(start, screenCenter);

  // Climb: gentle initial slope off the card, flattening into the crest.
  final climbC1 = Offset(
    start.dx + (apex.dx - start.dx) * 0.25,
    start.dy - (start.dy - apex.dy) * 0.20,
  );
  final climbC2 = Offset(start.dx + (apex.dx - start.dx) * 0.72, apex.dy);

  // Dive: launches horizontally off the crest, then bends steeply down;
  // the tangent at the end is vertical (diveC2 sits right above the cart).
  final diveC1 = Offset(apex.dx + (end.dx - apex.dx) * 0.42, apex.dy);
  final diveC2 = Offset(end.dx, apex.dy + (end.dy - apex.dy) * 0.55);

  final path = Path()
    ..moveTo(start.dx, start.dy)
    ..cubicTo(climbC1.dx, climbC1.dy, climbC2.dx, climbC2.dy, apex.dx, apex.dy)
    ..cubicTo(diveC1.dx, diveC1.dy, diveC2.dx, diveC2.dy, end.dx, end.dy);

  // Measure each segment once to locate the crest along the arc length.
  final climbLength = _contourLength(
    Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        climbC1.dx,
        climbC1.dy,
        climbC2.dx,
        climbC2.dy,
        apex.dx,
        apex.dy,
      ),
  );
  final diveLength = _contourLength(
    Path()
      ..moveTo(apex.dx, apex.dy)
      ..cubicTo(diveC1.dx, diveC1.dy, diveC2.dx, diveC2.dy, end.dx, end.dy),
  );
  final total = climbLength + diveLength;
  return CometFlightPath(
    path: path,
    crestFraction: total > 0 ? climbLength / total : 0.5,
  );
}

double _contourLength(Path path) {
  var length = 0.0;
  for (final metric in path.computeMetrics()) {
    length += metric.length;
  }
  return length;
}

/// Time → arc-length pacing of the coaster.
///
/// Climb (first [kCometClimbTimeShare] of the duration): easeInOutSine up to
/// [crestFraction] — the chain lift starts softly, climbs steadily, and
/// stalls at the crest (velocity reaches zero, the classic hang).
/// Drop (remaining time): distance grows with u² — constant acceleration,
/// i.e. free fall — and arrives at full speed in the cart.
double cometCoasterProgress(double t, double crestFraction) {
  final time = t.clamp(0.0, 1.0);
  final crest = crestFraction.clamp(0.05, 0.95);
  if (time <= kCometClimbTimeShare) {
    final u = time / kCometClimbTimeShare;
    return crest * (0.5 - 0.5 * math.cos(math.pi * u));
  }
  final u = (time - kCometClimbTimeShare) / (1.0 - kCometClimbTimeShare);
  return crest + (1.0 - crest) * u * u;
}

/// Index of the comet head into the particle list for a given eased path
/// progress (the CodePen's `~~frames` read cursor).
int cometHeadIndex(double progress, int n) {
  return (progress.clamp(0.0, 1.0) * (n - 1)).floor();
}

/// Head position for a path progress, lerped between adjacent samples for
/// sub-sample smoothness.
Offset cometHeadPosition(
  List<SampledCometParticle> particles,
  double progress,
) {
  final n = particles.length;
  final headT = progress.clamp(0.0, 1.0) * (n - 1);
  final index = headT.floor();
  final next = math.min(index + 1, n - 1);
  return Offset.lerp(
    particles[index].position,
    particles[next].position,
    headT - index,
  )!;
}

/// Screen-space tangent angle at the head (y-down radians).
double cometHeadAngle(List<SampledCometParticle> particles, double progress) {
  return particles[cometHeadIndex(progress, particles.length)].angle;
}

/// Base radius by trail depth (CodePen `o.r = 2 + i/9`): older particles are
/// larger, flaring the tail out behind the head.
double cometDepthRadius(int depth) {
  return (2.0 + depth / 9.0).clamp(1.0, 18.0);
}

/// Signed offset along the path normal (CodePen `o.R = r + i/2 * o.rnd`
/// re-expressed as a spread): grows with depth, scaled by the particle's
/// stable random in [-1, 1] so the tail widens organically.
double cometDepthSpread(int depth, double spreadSeed) {
  return depth / 2.0 * spreadSeed * 0.22;
}

/// Alpha by trail depth (CodePen `o.alpha = (l - i) / l`, with an ease power
/// and a stable per-particle variation so the fade is not mechanical).
double cometDepthAlpha(int depth, int windowLength, double alphaSeed) {
  final fade = ((windowLength - depth) / windowLength).clamp(0.0, 1.0);
  return math.pow(fade, 1.45).toDouble() * (0.75 + alphaSeed * 0.25);
}

/// Glow hue from the particle's stable seed (CodePen `hsla(o.a, 90%, 60%)`
/// re-tuned to a cool 205°–260° band).
Color cometParticleColor(double hueSeed) {
  return HSVColor.fromAHSV(1.0, 205.0 + hueSeed * 55.0, 0.55, 1.0).toColor();
}

/// Whole-trail fade near the end of the flight so the tail is absorbed with
/// the image instead of being cut off when the overlay is removed.
double cometTrailGlobalFade(double progress) {
  if (progress <= 0.85) return 1.0;
  return (1.0 - (progress - 0.85) / 0.15).clamp(0.0, 1.0);
}

/// One pre-sampled particle: the Flutter equivalent of one entry of the
/// CodePen's fixed array `p`, with the path position/tangent baked in so
/// `paint()` never touches [PathMetric].
class SampledCometParticle {
  const SampledCometParticle({
    required this.position,
    required this.angle,
    required this.normal,
    required this.spreadSeed,
    required this.hueSeed,
    required this.sizeSeed,
    required this.alphaSeed,
    required this.glowColor,
  });

  /// On-path point, in the same (global/overlay) space as the flight path.
  final Offset position;

  /// Screen-space tangent angle at [position] (y-down, radians).
  final double angle;

  /// Unit normal to the path at [position].
  final Offset normal;

  /// Stable random in [-1, 1] scaling the normal spread (CodePen `o.rnd`).
  final double spreadSeed;

  /// Stable randoms in [0, 1) for hue / size / alpha variation.
  final double hueSeed;
  final double sizeSeed;
  final double alphaSeed;

  /// Opaque glow colour, baked at sampling time so `paint()` never redoes
  /// the HSV→RGB conversion (only the per-frame alpha is applied there).
  final Color glowColor;
}

/// Pre-samples the fixed particle list along [path] — called ONCE per flight,
/// never from `paint()`. Deterministic: the same path yields the same list.
List<SampledCometParticle> buildCometParticles(
  Path path, {
  int count = kCometParticleCount,
}) {
  assert(count >= 2);
  final iterator = path.computeMetrics().iterator;
  if (!iterator.moveNext()) return const <SampledCometParticle>[];
  final metric = iterator.current;
  if (metric.length <= 0) return const <SampledCometParticle>[];

  final particles = <SampledCometParticle>[];
  for (var i = 0; i < count; i++) {
    final t = i / (count - 1);
    final tangent = metric.getTangentForOffset(metric.length * t);
    if (tangent == null) continue;
    final vector = tangent.vector;
    final length = vector.distance;
    final direction = length > 0 ? vector / length : const Offset(1, 0);
    final hueSeed = seededRandom(i + 17);
    particles.add(
      SampledCometParticle(
        position: tangent.position,
        // Screen-space angle (y-down): what Transform.rotate expects, unlike
        // ui.Tangent.angle which is y-up.
        angle: math.atan2(direction.dy, direction.dx),
        normal: Offset(-direction.dy, direction.dx),
        spreadSeed: seededRandom(i) * 2.0 - 1.0,
        hueSeed: hueSeed,
        sizeSeed: seededRandom(i + 31),
        alphaSeed: seededRandom(i + 47),
        glowColor: cometParticleColor(hueSeed),
      ),
    );
  }
  return particles;
}
