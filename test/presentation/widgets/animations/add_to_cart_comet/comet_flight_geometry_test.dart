import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/animations/add_to_cart_comet/comet_flight_geometry.dart';

void main() {
  group('seededRandom', () {
    test('is deterministic and stays in [0, 1)', () {
      for (var seed = 0; seed < 500; seed++) {
        final value = seededRandom(seed);
        expect(value, seededRandom(seed));
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(1));
      }
    });

    test('varies across seeds', () {
      final values = {
        for (var seed = 0; seed < 100; seed++) seededRandom(seed),
      };
      expect(values.length, greaterThan(50));
    });
  });

  group('buildCartFlightPath (roller coaster)', () {
    const start = Offset(60, 200);
    const end = Offset(320, 700);
    const screenCenter = Offset(200, 400);

    test('starts at the source and ends at the target', () {
      final flight = buildCartFlightPath(
        start,
        end,
        screenCenter: screenCenter,
      );
      final metric = flight.path.computeMetrics().first;

      final first = metric.getTangentForOffset(0)!.position;
      final last = metric.getTangentForOffset(metric.length)!.position;
      expect((first - start).distance, lessThan(0.5));
      expect((last - end).distance, lessThan(0.5));
    });

    test('bows away from the straight line (longer than the chord)', () {
      final flight = buildCartFlightPath(
        start,
        end,
        screenCenter: screenCenter,
      );
      final metric = flight.path.computeMetrics().first;
      expect(metric.length, greaterThan((end - start).distance));
    });

    test('crest sits on the screen-centre x, above the card', () {
      // apexY = min(centre.dy, start.dy - 90) = min(400, 110) = 110.
      final flight = buildCartFlightPath(
        start,
        end,
        screenCenter: screenCenter,
      );
      final particles = buildCometParticles(flight.path);

      var crest = particles.first.position;
      for (final particle in particles) {
        if (particle.position.dy < crest.dy) crest = particle.position;
      }
      expect(crest.dx, closeTo(screenCenter.dx, 3));
      expect(crest.dy, closeTo(110, 3));
    });

    test('a card below the screen centre climbs up to the centre', () {
      // apexY = min(400, 620 - 90) = 400: the flight passes through the
      // middle of the screen even from the bottom of a scrolled grid.
      final flight = buildCartFlightPath(
        const Offset(60, 620),
        end,
        screenCenter: screenCenter,
      );
      final particles = buildCometParticles(flight.path);

      var crestY = particles.first.position.dy;
      for (final particle in particles) {
        crestY = math.min(crestY, particle.position.dy);
      }
      expect(crestY, closeTo(screenCenter.dy, 3));
    });

    test('climbs to the crest, then dives — no second hump', () {
      final flight = buildCartFlightPath(
        start,
        end,
        screenCenter: screenCenter,
      );
      final particles = buildCometParticles(flight.path);

      var crestIndex = 0;
      for (var i = 0; i < particles.length; i++) {
        if (particles[i].position.dy < particles[crestIndex].position.dy) {
          crestIndex = i;
        }
      }
      // y decreases (screen coords: climbs) up to the crest…
      for (var i = 1; i <= crestIndex; i++) {
        expect(
          particles[i].position.dy,
          lessThanOrEqualTo(particles[i - 1].position.dy + 0.5),
        );
      }
      // …then increases (dives) all the way into the cart.
      for (var i = crestIndex + 1; i < particles.length; i++) {
        expect(
          particles[i].position.dy,
          greaterThanOrEqualTo(particles[i - 1].position.dy - 0.5),
        );
      }
    });

    test('arrives nearly vertically — falls INTO the basket', () {
      final flight = buildCartFlightPath(
        start,
        end,
        screenCenter: screenCenter,
      );
      final particles = buildCometParticles(flight.path);
      // Screen-space angle of straight-down is +π/2.
      expect(particles.last.angle, closeTo(math.pi / 2, 0.35));
    });

    test('crestFraction matches the arc-length position of the crest', () {
      final flight = buildCartFlightPath(
        start,
        end,
        screenCenter: screenCenter,
      );
      final particles = buildCometParticles(flight.path);

      var crestIndex = 0;
      for (var i = 0; i < particles.length; i++) {
        if (particles[i].position.dy < particles[crestIndex].position.dy) {
          crestIndex = i;
        }
      }
      expect(flight.crestFraction, greaterThan(0));
      expect(flight.crestFraction, lessThan(1));
      expect(
        crestIndex / (particles.length - 1),
        closeTo(flight.crestFraction, 0.02),
      );
    });
  });

  group('cometCoasterProgress (gravity pacing)', () {
    const crest = 0.4;

    test('starts at 0 and ends at 1', () {
      expect(cometCoasterProgress(0, crest), 0);
      expect(cometCoasterProgress(1, crest), 1);
    });

    test('reaches the crest exactly at the climb time share', () {
      expect(
        cometCoasterProgress(kCometClimbTimeShare, crest),
        closeTo(crest, 1e-9),
      );
    });

    test('is monotonic — the coaster never rolls backwards', () {
      var previous = 0.0;
      for (var i = 1; i <= 100; i++) {
        final value = cometCoasterProgress(i / 100, crest);
        expect(value, greaterThanOrEqualTo(previous));
        previous = value;
      }
    });

    test('the drop accelerates like free fall (increments grow)', () {
      var previousIncrement = 0.0;
      var previous = cometCoasterProgress(kCometClimbTimeShare, crest);
      for (var i = 1; i <= 20; i++) {
        final t = kCometClimbTimeShare + (1 - kCometClimbTimeShare) * i / 20;
        final value = cometCoasterProgress(t, crest);
        final increment = value - previous;
        expect(increment, greaterThanOrEqualTo(previousIncrement - 1e-9));
        previousIncrement = increment;
        previous = value;
      }
    });
  });

  group('buildCometParticles', () {
    final path = buildCartFlightPath(
      const Offset(60, 200),
      const Offset(320, 700),
      screenCenter: const Offset(200, 400),
    ).path;

    test('samples the requested fixed count', () {
      expect(buildCometParticles(path).length, kCometParticleCount);
      expect(
        buildCometParticles(path, count: kCometParticleCountWeb).length,
        kCometParticleCountWeb,
      );
    });

    test('endpoints sit on the path ends', () {
      final particles = buildCometParticles(path);
      expect(
        (particles.first.position - const Offset(60, 200)).distance,
        lessThan(0.5),
      );
      expect(
        (particles.last.position - const Offset(320, 700)).distance,
        lessThan(0.5),
      );
    });

    test('normals are unit length and perpendicular to the tangent', () {
      final particles = buildCometParticles(path);
      for (final particle in particles) {
        expect(particle.normal.distance, closeTo(1.0, 1e-6));
        final tangent = Offset(
          math.cos(particle.angle),
          math.sin(particle.angle),
        );
        final dot =
            tangent.dx * particle.normal.dx + tangent.dy * particle.normal.dy;
        expect(dot.abs(), lessThan(1e-6));
      }
    });

    test('is deterministic: same path, identical samples and seeds', () {
      final a = buildCometParticles(path);
      final b = buildCometParticles(path);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].position, b[i].position);
        expect(a[i].spreadSeed, b[i].spreadSeed);
        expect(a[i].hueSeed, b[i].hueSeed);
        expect(a[i].sizeSeed, b[i].sizeSeed);
        expect(a[i].alphaSeed, b[i].alphaSeed);
        expect(a[i].glowColor, b[i].glowColor);
      }
    });

    test('glow colour is baked from the hue seed at sampling time', () {
      final particles = buildCometParticles(path);
      for (final particle in [particles.first, particles.last]) {
        expect(particle.glowColor, cometParticleColor(particle.hueSeed));
      }
    });

    test('spread seeds span [-1, 1]', () {
      final particles = buildCometParticles(path);
      for (final particle in particles) {
        expect(particle.spreadSeed, greaterThanOrEqualTo(-1));
        expect(particle.spreadSeed, lessThanOrEqualTo(1));
      }
    });

    test('returns empty for an empty path', () {
      expect(buildCometParticles(Path()), isEmpty);
    });
  });

  group('trail window math (CodePen adaptation)', () {
    test('window length matches l = ~~(3n/4)', () {
      expect(cometTrailWindowLength(260), 195);
      expect(cometTrailWindowLength(160), 120);
    });

    test('head index maps progress over the full list', () {
      expect(cometHeadIndex(0, 260), 0);
      expect(cometHeadIndex(1, 260), 259);
      expect(cometHeadIndex(0.5, 260), (0.5 * 259).floor());
      // Out-of-range progress clamps instead of wrapping (no `% n`).
      expect(cometHeadIndex(1.2, 260), 259);
      expect(cometHeadIndex(-0.2, 260), 0);
    });

    test('depth radius grows with depth and clamps', () {
      expect(cometDepthRadius(0), 2.0);
      expect(cometDepthRadius(9), greaterThan(cometDepthRadius(0)));
      expect(cometDepthRadius(1000), 18.0);
    });

    test('depth alpha decreases monotonically toward the tail', () {
      const l = 195;
      var previous = double.infinity;
      for (var depth = 0; depth < l; depth += 10) {
        final alpha = cometDepthAlpha(depth, l, 0.5);
        expect(alpha, lessThanOrEqualTo(previous));
        expect(alpha, greaterThanOrEqualTo(0));
        previous = alpha;
      }
      expect(cometDepthAlpha(l, l, 0.5), 0);
    });

    test('depth spread grows with depth, sign follows the seed', () {
      expect(cometDepthSpread(0, 1), 0);
      expect(cometDepthSpread(100, 1), greaterThan(cometDepthSpread(10, 1)));
      expect(cometDepthSpread(100, -1), lessThan(0));
    });
  });

  group('trail fade', () {
    test('global trail fade ramps out over the last 15%', () {
      expect(cometTrailGlobalFade(0.5), 1.0);
      expect(cometTrailGlobalFade(0.85), 1.0);
      expect(cometTrailGlobalFade(1.0), 0.0);
    });
  });

  group('head sampling', () {
    final particles = buildCometParticles(
      buildCartFlightPath(
        const Offset(60, 200),
        const Offset(320, 700),
        screenCenter: const Offset(200, 400),
      ).path,
    );

    test('head position lerps from start to end', () {
      expect(
        (cometHeadPosition(particles, 0) - const Offset(60, 200)).distance,
        lessThan(0.5),
      );
      expect(
        (cometHeadPosition(particles, 1) - const Offset(320, 700)).distance,
        lessThan(0.5),
      );
    });

    test('head angle matches the head particle tangent', () {
      expect(
        cometHeadAngle(particles, 0.5),
        particles[cometHeadIndex(0.5, particles.length)].angle,
      );
    });
  });
}
