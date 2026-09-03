import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/widgets/landing_asset_loading_backdrop.dart';

void main() {
  Widget host({
    required ValueNotifier<bool> assetsReady,
    required Duration minVisibleDuration,
    required Duration maxVisibleDuration,
    required Duration fadeDuration,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: LandingAssetLoadingBackdrop(
          assetsReady: assetsReady,
          minVisibleDuration: minVisibleDuration,
          maxVisibleDuration: maxVisibleDuration,
          fadeDuration: fadeDuration,
          background: const ColoredBox(color: Colors.blue),
          child: const Text('Landing'),
        ),
      ),
    );
  }

  testWidgets('waits for the explicit critical-asset signal', (tester) async {
    final assetsReady = ValueNotifier(false);
    addTearDown(assetsReady.dispose);

    await tester.pumpWidget(
      host(
        assetsReady: assetsReady,
        minVisibleDuration: Duration.zero,
        maxVisibleDuration: const Duration(seconds: 1),
        fadeDuration: const Duration(milliseconds: 100),
      ),
    );

    expect(find.text('Landing'), findsOneWidget);
    expect(find.byKey(landingAssetLoadingBackdropOverlayKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(landingAssetLoadingBackdropOverlayKey), findsOneWidget);

    assetsReady.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byKey(landingAssetLoadingBackdropOverlayKey),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, closeTo(0.5, 0.01));
    expect(find.byKey(landingAssetLoadingBackdropOverlayKey), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(landingAssetLoadingBackdropOverlayKey), findsNothing);
  });

  testWidgets('keeps the backdrop for its minimum duration', (tester) async {
    final assetsReady = ValueNotifier(true);
    addTearDown(assetsReady.dispose);

    await tester.pumpWidget(
      host(
        assetsReady: assetsReady,
        minVisibleDuration: const Duration(milliseconds: 100),
        maxVisibleDuration: const Duration(seconds: 1),
        fadeDuration: const Duration(milliseconds: 50),
      ),
    );

    await tester.pump(const Duration(milliseconds: 99));
    expect(find.byKey(landingAssetLoadingBackdropOverlayKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(landingAssetLoadingBackdropOverlayKey), findsNothing);
  });

  testWidgets('uses the maximum duration as a safeguard', (tester) async {
    final assetsReady = ValueNotifier(false);
    addTearDown(assetsReady.dispose);

    await tester.pumpWidget(
      host(
        assetsReady: assetsReady,
        minVisibleDuration: Duration.zero,
        maxVisibleDuration: const Duration(milliseconds: 100),
        fadeDuration: Duration.zero,
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(landingAssetLoadingBackdropOverlayKey), findsNothing);
  });

  testWidgets('removes animation timing when reduced motion is enabled', (
    tester,
  ) async {
    final assetsReady = ValueNotifier(false);
    addTearDown(assetsReady.dispose);

    await tester.pumpWidget(
      host(
        assetsReady: assetsReady,
        minVisibleDuration: Duration.zero,
        maxVisibleDuration: const Duration(seconds: 1),
        fadeDuration: const Duration(milliseconds: 100),
        disableAnimations: true,
      ),
    );

    assetsReady.value = true;
    await tester.pump();
    expect(find.byKey(landingAssetLoadingBackdropOverlayKey), findsNothing);
  });

  testWidgets(
    'coordinates a full-page background while a skeleton is mounted',
    (tester) async {
      final showSkeleton = ValueNotifier(true);
      addTearDown(showSkeleton.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingGradientLoadingCoordinator(
            idleBackgroundColor: Colors.white,
            animate: false,
            child: ValueListenableBuilder<bool>(
              valueListenable: showSkeleton,
              builder: (context, show, _) => show
                  ? const LandingGradientLoadingSurface(
                      child: SizedBox.expand(),
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(landingGradientLoadingCoordinatorBackgroundKey),
          matching: find.byType(LandingLowCostGradientFlowBackground),
        ),
        findsOneWidget,
      );

      showSkeleton.value = false;
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(landingGradientLoadingCoordinatorBackgroundKey),
          matching: find.byType(LandingLowCostGradientFlowBackground),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'suppresses the coordinator shader while the startup curtain covers it',
    (tester) async {
      final assetsReady = ValueNotifier(false);
      addTearDown(assetsReady.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingAssetLoadingBackdrop(
            assetsReady: assetsReady,
            minVisibleDuration: const Duration(milliseconds: 100),
            maxVisibleDuration: const Duration(seconds: 1),
            fadeDuration: const Duration(milliseconds: 50),
            background: const ColoredBox(color: Colors.blue),
            child: const LandingGradientLoadingCoordinator(
              idleBackgroundColor: Colors.white,
              animate: false,
              child: LandingGradientLoadingSurface(child: SizedBox.expand()),
            ),
          ),
        ),
      );
      // Let the skeleton surface attach to the coordinator (post-frame), so the
      // coordinator would paint its shader if it were not covered.
      await tester.pump();
      await tester.pump();

      expect(find.byKey(landingAssetLoadingBackdropOverlayKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(landingGradientLoadingCoordinatorBackgroundKey),
          matching: find.byType(LandingLowCostGradientFlowBackground),
        ),
        findsNothing,
        reason: 'curtain occludes the coordinator: no second full-page shader',
      );

      // Once the curtain begins to dismiss it reveals the page, so the
      // coordinator resumes its own shader behind the still-mounted skeleton.
      assetsReady.value = true;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byKey(landingGradientLoadingCoordinatorBackgroundKey),
          matching: find.byType(LandingLowCostGradientFlowBackground),
        ),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
    },
  );
}
