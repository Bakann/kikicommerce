import 'dart:ui';

import 'package:flutter/rendering.dart' show MatrixUtils;
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/animations/add_to_cart_comet/sticker_peel_geometry.dart';

void main() {
  const rect = Rect.fromLTWH(40, 100, 120, 120);
  const corner = StickerPeelCorner.topRight;

  group('phase mapping', () {
    test('path progress is pinned to the card during the peel', () {
      expect(stickerPathProgress(0, 0.4), 0);
      expect(stickerPathProgress(kStickerPeelEnd, 0.4), 0);
    });

    test('path progress is pinned to the cart during the snap', () {
      expect(stickerPathProgress(kStickerFlightEnd, 0.4), 1);
      expect(stickerPathProgress(1, 0.4), 1);
    });

    test('path progress is monotonic across the whole timeline', () {
      var previous = 0.0;
      for (var i = 0; i <= 100; i++) {
        final value = stickerPathProgress(i / 100, 0.4);
        expect(value, greaterThanOrEqualTo(previous));
        previous = value;
      }
      expect(previous, 1);
    });

    test('local phase progress covers [0, 1] inside each phase', () {
      expect(stickerPeelProgress(0), 0);
      expect(stickerPeelProgress(kStickerPeelEnd), 1);
      expect(stickerFlightLocal(kStickerPeelEnd), 0);
      expect(stickerFlightLocal(kStickerFlightEnd), 1);
      expect(stickerSnapProgress(kStickerFlightEnd), 0);
      expect(stickerSnapProgress(1), 1);
    });
  });

  group('fold geometry', () {
    test('fold point sits on the corner→opposite diagonal', () {
      final fold = buildStickerFold(rect, corner, 30);
      final cornerPoint = stickerCornerPoint(rect, corner);
      expect((fold.foldPoint - cornerPoint).distance, closeTo(30, 1e-9));
      // Direction points inward, toward the opposite corner.
      final toOpposite = rect.bottomLeft - cornerPoint;
      final dot =
          fold.peelDirection.dx * toOpposite.dx +
          fold.peelDirection.dy * toOpposite.dy;
      expect(dot, greaterThan(0));
    });

    test('directions are unit length and perpendicular', () {
      final fold = buildStickerFold(rect, corner, 30);
      expect(fold.peelDirection.distance, closeTo(1, 1e-9));
      expect(fold.foldLineDirection.distance, closeTo(1, 1e-9));
      final dot =
          fold.peelDirection.dx * fold.foldLineDirection.dx +
          fold.peelDirection.dy * fold.foldLineDirection.dy;
      expect(dot.abs(), lessThan(1e-9));
    });

    test('flap tip is the corner mirrored across the fold line', () {
      final fold = buildStickerFold(rect, corner, 30);
      expect((fold.flapTip - fold.corner).distance, closeTo(60, 1e-9));
      // And the reflection matrix agrees with the analytic tip.
      final reflected = MatrixUtils.transformPoint(
        stickerFoldReflection(fold),
        fold.corner,
      );
      expect((reflected - fold.flapTip).distance, lessThan(1e-6));
    });

    test('the fold line is the reflection fixed axis', () {
      final fold = buildStickerFold(rect, corner, 30);
      final onLine = fold.foldPoint + fold.foldLineDirection * 25;
      final reflected = MatrixUtils.transformPoint(
        stickerFoldReflection(fold),
        onLine,
      );
      expect((reflected - onLine).distance, lessThan(1e-6));
    });

    test('fold distance clamps to the intensity-scaled maximum', () {
      final fold = buildStickerFold(rect, corner, 9999, intensity: 1.0);
      expect(fold.foldDistance, fold.maxFoldDistance);
      final wider = buildStickerFold(rect, corner, 9999, intensity: 1.5);
      expect(wider.maxFoldDistance, greaterThan(fold.maxFoldDistance));
    });

    test('half-planes separate the lifted corner from the opposite one', () {
      final fold = buildStickerFold(rect, corner, 30);
      final peeled = stickerPeeledHalfPlane(fold, rect.longestSide * 3);
      final stuck = stickerStuckHalfPlane(fold, rect.longestSide * 3);
      expect(peeled.contains(stickerCornerPoint(rect, corner)), isTrue);
      expect(stuck.contains(stickerCornerPoint(rect, corner)), isFalse);
      expect(stuck.contains(rect.bottomLeft), isTrue);
      expect(peeled.contains(rect.bottomLeft), isFalse);
    });
  });

  group('fold over time', () {
    test('grows through the peel and relaxes to flat mid-flight', () {
      expect(stickerFoldDistanceAt(0, rect, corner), 0);
      final atPeelEnd = stickerFoldDistanceAt(kStickerPeelEnd, rect, corner);
      expect(atPeelEnd, greaterThan(0));
      // Un-curls in the air: gone well before the flight ends.
      expect(stickerFoldDistanceAt(0.7, rect, corner), 0);
    });
  });

  group('glue', () {
    test('opacity is zero at rest and at take-off, positive mid-peel', () {
      expect(stickerGlueOpacity(0), 0);
      expect(stickerGlueOpacity(0.5), greaterThan(0));
      expect(stickerGlueOpacity(1), 0);
    });

    test('glue path spans between the fold line and the flap tip', () {
      final fold = buildStickerFold(rect, corner, 30);
      final bounds = stickerGluePath(fold).getBounds();
      expect(bounds.isEmpty, isFalse);
      expect(bounds.width, lessThan(rect.width * 2));
    });
  });

  group('flight and snap curves', () {
    test('flight scale shrinks from full size toward the cart', () {
      expect(stickerFlightScale(0), 1.0);
      expect(stickerFlightScale(1), closeTo(0.45, 1e-9));
    });

    test('flight scale can end at half the cart icon size', () {
      final targetScale = stickerTargetScale(
        const Size(160, 160),
        const Size(16, 16),
      );

      expect(targetScale, closeTo(0.1, 1e-9));
      expect(
        stickerFlightScale(1, targetScale: targetScale),
        closeTo(targetScale, 1e-9),
      );
    });

    test('squash is zero at both ends of the flight', () {
      expect(stickerFlightSquash(0, 1), closeTo(0, 1e-9));
      expect(stickerFlightSquash(1, 1).abs(), lessThan(1e-9));
      expect(stickerFlightSquash(0.16, 1).abs(), greaterThan(0));
    });

    test('snap slams, rebounds, then vanishes', () {
      expect(stickerSnapScale(0), 1.0);
      final slammed = stickerSnapScale(0.4);
      expect(slammed, closeTo(0.62, 1e-9));
      final rebound = stickerSnapScale(0.68);
      expect(rebound, greaterThan(slammed));
      expect(stickerSnapScale(1), closeTo(0, 1e-9));
    });

    test('snap opacity holds through the rebound then fades out', () {
      expect(stickerSnapOpacity(0), 1.0);
      expect(stickerSnapOpacity(0.5), 1.0);
      expect(stickerSnapOpacity(1), closeTo(0, 1e-9));
    });
  });
}
