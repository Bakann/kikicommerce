import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/presentation/providers/cart_provider.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/adaptive_bottom_nav.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/floating_bottom_nav.dart';

import '../../../support/l10n_harness.dart';

ByteData _solidRgba(int width, int height, int v) {
  final bytes = Uint8List(width * height * 4);
  for (var i = 0; i < bytes.length; i += 4) {
    bytes[i] = v;
    bytes[i + 1] = v;
    bytes[i + 2] = v;
    bytes[i + 3] = 255;
  }
  return ByteData.view(bytes.buffer);
}

Brightness _bottomNavBrightness(WidgetTester tester) {
  return BottomNavBrightness.of(tester.element(find.byType(FloatingBottomNav)));
}

Future<void> _pumpUntilBottomNavBrightness(
  WidgetTester tester,
  Brightness expected, {
  Duration timeout = const Duration(seconds: 1),
  Duration pollInterval = const Duration(milliseconds: 50),
}) async {
  var elapsed = Duration.zero;
  while (elapsed < timeout) {
    await tester.pump(pollInterval);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (_bottomNavBrightness(tester) == expected) return;
    elapsed += pollInterval;
  }
}

void main() {
  group('navBrightnessForBackdropLuminance', () {
    test('dark backdrop → dark reading, bright backdrop → light reading', () {
      expect(navBrightnessForBackdropLuminance(0), Brightness.dark);
      expect(navBrightnessForBackdropLuminance(0.49), Brightness.dark);
      expect(navBrightnessForBackdropLuminance(0.5), Brightness.light);
      expect(navBrightnessForBackdropLuminance(1), Brightness.light);
    });
  });

  group('averageBottomBandLuminance', () {
    test('black band → 0, white band → 1', () {
      expect(averageBottomBandLuminance(_solidRgba(8, 20, 0), 8, 20), 0);
      expect(averageBottomBandLuminance(_solidRgba(8, 20, 255), 8, 20), 1);
    });

    test('fully transparent buffer reads as bright (defaults to light)', () {
      final transparent = ByteData.view(Uint8List(8 * 20 * 4).buffer);
      expect(averageBottomBandLuminance(transparent, 8, 20), 1);
    });

    test('only the bottom band is sampled', () {
      // Top half white, bottom half black: a band fraction covering only the
      // bottom rows must read dark, not the whole-image average.
      const w = 4;
      const h = 10;
      final bytes = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        final v = y < 5 ? 255 : 0;
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          bytes[i] = v;
          bytes[i + 1] = v;
          bytes[i + 2] = v;
          bytes[i + 3] = 255;
        }
      }
      final lum = averageBottomBandLuminance(
        ByteData.view(bytes.buffer),
        w,
        h,
        bandFraction: 0.4, // bottom 4 rows → all black
      );
      expect(lum, 0);
    });
  });

  group('_AdaptiveBottomNavState._sample', () {
    // Regression test for a profile/release-only crash: _sample() used to
    // pre-check RenderObject.debugNeedsPaint before capturing the backdrop.
    // That getter's backing field is only ever assigned inside an assert()
    // block, so it throws LateInitializationError once asserts are stripped
    // (profile/release builds) — this test exercises the same scroll-end ->
    // debounce -> capture pipeline the crash occurred on, so a regression
    // that reintroduces a debug-only check here would show up as a flaky/
    // failing capture even in the assert-enabled test environment.
    testWidgets('samples the newly-revealed backdrop after a scroll settles', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: AdaptiveBottomNav(
                child: ListView(
                  children: const [
                    ColoredBox(
                      color: Colors.white,
                      child: SizedBox(height: 2000),
                    ),
                    ColoredBox(
                      color: Colors.black,
                      child: SizedBox(height: 4000),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [liveCartItemCountProvider.overrideWithValue(0)],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: const Locale('fr'),
          ),
        ),
      );
      await tester.pump();

      // Let the mount-time sample resolve against the white backdrop.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(_bottomNavBrightness(tester), Brightness.light);

      // Scroll the black block fully into view and let the scroll-end
      // debounce fire the re-sample.
      await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
      await tester.pumpAndSettle();
      await _pumpUntilBottomNavBrightness(tester, Brightness.dark);

      expect(_bottomNavBrightness(tester), Brightness.dark);
    });
  });
}
