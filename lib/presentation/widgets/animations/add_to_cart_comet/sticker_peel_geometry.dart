import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/rendering.dart' show Matrix4;

import 'comet_flight_geometry.dart';

/// Pure geometry for the sticker-peel flyer (Peel.js adapted to Flutter).
///
/// The flight timeline is one controller in [0, 1], split into three phases:
/// peel (the sticker lifts a corner off the card), flight (it rides the
/// coaster Bézier to the cart, comet trail behind it), snap (it slams into
/// the basket with a micro rebound). Everything here is widget-free and
/// deterministic so the fold/phase maths can be unit-tested.

/// Phase boundaries on the raw controller time.
const double kStickerPeelEnd = 0.28;
const double kStickerFlightEnd = 0.82;

/// How far the corner folds back at full peel, as a fraction of the sticker
/// diagonal (scaled by `intensity`).
const double kStickerPeelMaxDiagonalFraction = 0.42;

/// Maximum tilt of the flying sticker away from the path tangent.
const double kStickerMaxTilt = 10 * math.pi / 180;

/// Which sticker corner lifts first.
enum StickerPeelCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Local peel progress in [0, 1] (eased so the lift is readable early).
double stickerPeelProgress(double t) {
  final u = (t / kStickerPeelEnd).clamp(0.0, 1.0);
  return stickerEaseOutCubic(u);
}

/// Local flight progress in [0, 1].
double stickerFlightLocal(double t) {
  return ((t - kStickerPeelEnd) / (kStickerFlightEnd - kStickerPeelEnd)).clamp(
    0.0,
    1.0,
  );
}

/// Local snap progress in [0, 1].
double stickerSnapProgress(double t) {
  return ((t - kStickerFlightEnd) / (1.0 - kStickerFlightEnd)).clamp(0.0, 1.0);
}

/// Raw time → arc-length progress along the flight path.
///
/// 0 while the sticker is still peeling on the card, coaster pacing (climb +
/// gravity drop, [cometCoasterProgress]) across the flight phase, pinned at 1
/// during the snap. This is what the trail painter and the flyer both read.
double stickerPathProgress(double t, double crestFraction) {
  if (t <= kStickerPeelEnd) return 0.0;
  if (t >= kStickerFlightEnd) return 1.0;
  return cometCoasterProgress(stickerFlightLocal(t), crestFraction);
}

/// Manual easeOutCubic so this file keeps zero Flutter animation imports.
double stickerEaseOutCubic(double u) {
  final inv = 1.0 - u.clamp(0.0, 1.0);
  return 1.0 - inv * inv * inv;
}

/// Everything the painter needs to draw one peel state, computed once per
/// frame from the sticker rect, the lifted corner and the peel progress.
class StickerFoldFrame {
  const StickerFoldFrame({
    required this.corner,
    required this.foldPoint,
    required this.peelDirection,
    required this.foldLineDirection,
    required this.flapTip,
    required this.foldDistance,
    required this.maxFoldDistance,
  });

  /// The lifted corner of the sticker rect, before any fold.
  final Offset corner;

  /// Point on the fold line, on the corner→opposite-corner diagonal.
  final Offset foldPoint;

  /// Unit vector from the lifted corner toward the opposite corner.
  final Offset peelDirection;

  /// Unit vector along the fold line (perpendicular to [peelDirection]).
  final Offset foldLineDirection;

  /// Where the lifted corner currently sits (its mirror across the fold).
  final Offset flapTip;

  final double foldDistance;
  final double maxFoldDistance;

  bool get isFolded => foldDistance > 0.01;
}

Offset stickerCornerPoint(Rect rect, StickerPeelCorner corner) {
  return switch (corner) {
    StickerPeelCorner.topLeft => rect.topLeft,
    StickerPeelCorner.topRight => rect.topRight,
    StickerPeelCorner.bottomLeft => rect.bottomLeft,
    StickerPeelCorner.bottomRight => rect.bottomRight,
  };
}

Offset _oppositeCornerPoint(Rect rect, StickerPeelCorner corner) {
  return switch (corner) {
    StickerPeelCorner.topLeft => rect.bottomRight,
    StickerPeelCorner.topRight => rect.bottomLeft,
    StickerPeelCorner.bottomLeft => rect.topRight,
    StickerPeelCorner.bottomRight => rect.topLeft,
  };
}

/// Builds the fold state for a given fold distance (in logical px along the
/// peel diagonal from the corner).
StickerFoldFrame buildStickerFold(
  Rect stickerRect,
  StickerPeelCorner corner,
  double foldDistance, {
  double intensity = 1.0,
}) {
  final cornerPoint = stickerCornerPoint(stickerRect, corner);
  final opposite = _oppositeCornerPoint(stickerRect, corner);
  final diagonal = (opposite - cornerPoint).distance;
  final direction = diagonal > 0
      ? (opposite - cornerPoint) / diagonal
      : const Offset(1, 0);
  final maxFold =
      diagonal * kStickerPeelMaxDiagonalFraction * intensity.clamp(0.5, 1.5);
  final fold = foldDistance.clamp(0.0, maxFold);
  final foldPoint = cornerPoint + direction * fold;
  // The corner's mirror image across the fold line: the visible flap tip.
  // Reflection across the line through foldPoint perpendicular to the peel
  // diagonal lands the corner at corner + 2·fold·direction.
  final flapTip = cornerPoint + direction * (fold * 2);
  return StickerFoldFrame(
    corner: cornerPoint,
    foldPoint: foldPoint,
    peelDirection: direction,
    foldLineDirection: Offset(-direction.dy, direction.dx),
    flapTip: flapTip,
    foldDistance: fold,
    maxFoldDistance: maxFold,
  );
}

/// Fold distance over the whole timeline: grows through the peel phase, then
/// relaxes early in the flight so the sticker un-curls in the air.
double stickerFoldDistanceAt(
  double t,
  Rect stickerRect,
  StickerPeelCorner corner, {
  double intensity = 1.0,
}) {
  final cornerPoint = stickerCornerPoint(stickerRect, corner);
  final diagonal =
      (_oppositeCornerPoint(stickerRect, corner) - cornerPoint).distance;
  final maxFold =
      diagonal * kStickerPeelMaxDiagonalFraction * intensity.clamp(0.5, 1.5);
  if (t <= kStickerPeelEnd) {
    return maxFold * stickerPeelProgress(t);
  }
  final relax = 1.0 - stickerFlightLocal(t) * 1.8;
  return maxFold * relax.clamp(0.0, 1.0);
}

/// Reflection matrix across the fold line of [fold] — used to draw the back
/// face: the canvas is mirrored, then the sticker is painted clipped to the
/// peeled half-plane, which lands it exactly on the visible flap.
Matrix4 stickerFoldReflection(StickerFoldFrame fold) {
  final angle = math.atan2(
    fold.foldLineDirection.dy,
    fold.foldLineDirection.dx,
  );
  return Matrix4.identity()
    ..translateByDouble(fold.foldPoint.dx, fold.foldPoint.dy, 0, 1)
    ..rotateZ(angle)
    ..scaleByDouble(1, -1, 1, 1)
    ..rotateZ(-angle)
    ..translateByDouble(-fold.foldPoint.dx, -fold.foldPoint.dy, 0, 1);
}

/// Half-plane polygon covering the peeled side of the fold line (the side
/// containing the lifted corner), large enough to clip the sticker rect.
Path stickerPeeledHalfPlane(StickerFoldFrame fold, double extent) {
  final p = fold.foldPoint;
  final m = fold.foldLineDirection * extent;
  final back = fold.peelDirection * -extent;
  return Path()
    ..moveTo(p.dx + m.dx, p.dy + m.dy)
    ..lineTo(p.dx - m.dx, p.dy - m.dy)
    ..lineTo(p.dx - m.dx + back.dx, p.dy - m.dy + back.dy)
    ..lineTo(p.dx + m.dx + back.dx, p.dy + m.dy + back.dy)
    ..close();
}

/// Complement half-plane: the part of the sticker still stuck to the card.
Path stickerStuckHalfPlane(StickerFoldFrame fold, double extent) {
  final p = fold.foldPoint;
  final m = fold.foldLineDirection * extent;
  final forward = fold.peelDirection * extent;
  return Path()
    ..moveTo(p.dx + m.dx, p.dy + m.dy)
    ..lineTo(p.dx - m.dx, p.dy - m.dy)
    ..lineTo(p.dx - m.dx + forward.dx, p.dy - m.dy + forward.dy)
    ..lineTo(p.dx + m.dx + forward.dx, p.dy + m.dy + forward.dy)
    ..close();
}

/// Thin translucent glue web between the card and the lifting flap: two
/// quadratic strands from points on the fold line to just short of the flap
/// tip. Fades and snaps before the sticker takes off.
Path stickerGluePath(StickerFoldFrame fold) {
  final anchorSpread = fold.foldDistance * 0.55;
  final a1 = fold.foldPoint + fold.foldLineDirection * anchorSpread;
  final a2 = fold.foldPoint - fold.foldLineDirection * anchorSpread;
  final tip = fold.foldPoint + (fold.flapTip - fold.foldPoint) * 0.72;
  final sag = fold.peelDirection * (fold.foldDistance * 0.18);
  return Path()
    ..moveTo(a1.dx, a1.dy)
    ..quadraticBezierTo(a1.dx + sag.dx, a1.dy + sag.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(a2.dx + sag.dx, a2.dy + sag.dy, a2.dx, a2.dy)
    ..close();
}

/// Glue opacity over the peel: visible mid-peel, gone before take-off.
double stickerGlueOpacity(double peelProgress) {
  if (peelProgress <= 0.1 || peelProgress >= 0.85) return 0.0;
  final u = ((peelProgress - 0.1) / 0.75).clamp(0.0, 1.0);
  return math.sin(u * math.pi) * 0.14;
}

/// Scale needed for a sticker to visually match the cart icon target.
double stickerTargetScale(Size stickerSize, Size targetSize) {
  if (stickerSize.width <= 0 ||
      stickerSize.height <= 0 ||
      targetSize.width <= 0 ||
      targetSize.height <= 0) {
    return 1.0;
  }
  final scale = math.min(
    targetSize.width / stickerSize.width,
    targetSize.height / stickerSize.height,
  );
  return scale.clamp(0.04, 1.0);
}

/// Sticker scale during the flight: leaves the card full-size and shrinks
/// toward the cart icon (the snap keeps shrinking from there).
double stickerFlightScale(double flightLocal, {double targetScale = 0.45}) {
  final u = flightLocal.clamp(0.0, 1.0);
  final end = targetScale.clamp(0.04, 1.0);
  return 1.0 - (1.0 - end) * stickerEaseOutCubic(u) * u;
}

/// Organic squash/stretch along the path tangent during the flight — a small
/// decaying oscillation so the sticker never reads as a rigid card.
double stickerFlightSquash(double flightLocal, double intensity) {
  final u = flightLocal.clamp(0.0, 1.0);
  final decay = 1.0 - u * 0.6;
  return math.sin(u * math.pi * 3) * 0.055 * intensity.clamp(0.5, 1.5) * decay;
}

/// The "clac": fast scale-down into the basket, a micro rebound, then gone.
double stickerSnapScale(double snapLocal) {
  final u = snapLocal.clamp(0.0, 1.0);
  if (u < 0.4) {
    // Fast slam: 1.0 → 0.62.
    final k = stickerEaseOutCubic(u / 0.4);
    return 1.0 - 0.38 * k;
  }
  if (u < 0.68) {
    // Micro rebound: 0.62 → 0.78.
    final k = (u - 0.4) / 0.28;
    return 0.62 + 0.16 * math.sin(k * math.pi / 2);
  }
  // Absorbed: 0.78 → 0.
  final k = (u - 0.68) / 0.32;
  return 0.78 * (1.0 - stickerEaseOutCubic(k));
}

/// Sticker opacity through the snap (fades in the final absorption).
double stickerSnapOpacity(double snapLocal) {
  final u = snapLocal.clamp(0.0, 1.0);
  if (u < 0.55) return 1.0;
  return (1.0 - (u - 0.55) / 0.45).clamp(0.0, 1.0);
}
