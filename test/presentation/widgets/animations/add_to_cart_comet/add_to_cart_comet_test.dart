import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/providers/cart_flight_coordinator_provider.dart';
import 'package:kiki_commerce/presentation/providers/cart_provider.dart';
import 'package:kiki_commerce/presentation/widgets/animations/add_to_cart_comet/add_to_cart_comet.dart';
import 'package:kiki_commerce/presentation/widgets/animations/add_to_cart_comet/add_to_cart_comet_render_profile.dart';
import 'package:kiki_commerce/presentation/widgets/animations/add_to_cart_comet/sticker_peel_painter.dart';

/// The comet clone is a KikiImage; an empty URL renders its error widget
/// immediately — no network, no cache-manager timers in the test.
const _kNoImage = '';

final Finder _cometPaint = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is CometTrailPainter,
);
final Finder _stickerPaint = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is StickerPeelPainter,
);

void main() {
  late ProviderContainer container;
  final sourceKey = GlobalKey();
  final secondSourceKey = GlobalKey();

  Future<BuildContext> pumpHarness(
    WidgetTester tester, {
    bool disableAnimations = false,
    bool registerAnchor = true,
    VoidCallback? onUnderlyingTap,
  }) async {
    container = ProviderContainer(
      overrides: [liveCartItemCountProvider.overrideWithValue(0)],
    );
    addTearDown(container.dispose);

    late BuildContext launchContext;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Scaffold(
              // SizedBox.expand: without it the Stack would size itself to its
              // only non-positioned child (the shrunk Builder) and hit-testing
              // on the positioned children would fail.
              body: SizedBox.expand(
                child: Stack(
                  children: [
                    Positioned(
                      left: 40,
                      top: 100,
                      child: SizedBox(key: sourceKey, width: 80, height: 80),
                    ),
                    Positioned(
                      left: 160,
                      top: 100,
                      child: SizedBox(
                        key: secondSourceKey,
                        width: 80,
                        height: 80,
                      ),
                    ),
                    Positioned(
                      left: 100,
                      top: 300,
                      child: ElevatedButton(
                        onPressed: onUnderlyingTap,
                        child: const Text('underneath'),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        launchContext = context;
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Let the initial route's entrance transition finish: while it runs, the
    // route subtree sits behind an IgnorePointer and would eat test taps.
    await tester.pumpAndSettle();

    if (registerAnchor) {
      container
          .read(cartFlightCoordinatorProvider.notifier)
          .registerCartAnchor(
            'test-anchor',
            () => const Rect.fromLTWH(300, 560, 24, 24),
          );
    }
    return launchContext;
  }

  AddToCartCometFlightHandle? launch(BuildContext context, GlobalKey key) {
    return AddToCartCometController.launch(
      context: context,
      sourceKey: key,
      coordinator: container.read(cartFlightCoordinatorProvider.notifier),
      imageUrl: _kNoImage,
    );
  }

  // Mounts the freshly inserted entry, then lets its ticker take its first
  // tick (which pins the animation's start time at t = 0).
  Future<void> settleLaunch(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('inserts one overlay flight and removes it at the end', (
    tester,
  ) async {
    final context = await pumpHarness(tester);

    final handle = launch(context, sourceKey);
    expect(handle, isNotNull);
    await settleLaunch(tester);
    expect(_cometPaint, findsOneWidget);
    expect(_stickerPaint, findsOneWidget);

    // Past the full flight (strictly, so the completed status has fired)
    // plus one frame for the entry removal rebuild.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    expect(_cometPaint, findsNothing);
    expect(_stickerPaint, findsNothing);
    expect(tester.takeException(), isNull);
    // No stray safety timer left behind.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('overlay never blocks input (IgnorePointer contract)', (
    tester,
  ) async {
    var taps = 0;
    final context = await pumpHarness(tester, onUnderlyingTap: () => taps++);

    launch(context, sourceKey);
    await settleLaunch(tester);
    expect(_cometPaint, findsOneWidget);

    await tester.tap(find.text('underneath'));
    expect(taps, 1);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
  });

  testWidgets('reduced motion: launch is a no-op returning null', (
    tester,
  ) async {
    final context = await pumpHarness(tester, disableAnimations: true);

    expect(launch(context, sourceKey), isNull);
    await tester.pump();
    expect(_cometPaint, findsNothing);
  });

  testWidgets('real-surface warm-up paints its frames then goes dormant', (
    tester,
  ) async {
    addTearDown(AddToCartCometController.debugResetShaderWarmUpForTest);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AddToCartCometWarmUpLayer(armed: true)),
      ),
    );
    // initState defers one frame, the texture resolves asynchronously, then
    // the four warm frames paint back-to-back (one per pumped frame).
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(AddToCartCometController.debugShaderWarmUpDone, isTrue);
    // The warm-up delegates to the real painters internally but never mounts
    // the flight overlay's CustomPaints.
    expect(_cometPaint, findsNothing);
    expect(_stickerPaint, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warm-up layer is a no-op once the session latch is set', (
    tester,
  ) async {
    addTearDown(AddToCartCometController.debugResetShaderWarmUpForTest);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AddToCartCometWarmUpLayer(armed: true)),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(AddToCartCometController.debugShaderWarmUpDone, isTrue);

    // Remount armed: the session latch prevents any second run.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AddToCartCometWarmUpLayer(armed: true)),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  });

  test('web mobile render profile starts cheap, then settles safe', () {
    addTearDown(AddToCartCometController.debugResetShaderWarmUpForTest);

    expect(
      AddToCartCometController.debugResolveRenderProfileForTest(
        const Size(390, 844),
        forceWeb: true,
      ),
      AddToCartCometRenderProfile.webMobileFirstTapCheap,
    );

    AddToCartCometController.debugMarkShaderWarmUpCompletedForTest();
    expect(
      AddToCartCometController.debugResolveRenderProfileForTest(
        const Size(390, 844),
        forceWeb: true,
      ),
      AddToCartCometRenderProfile.webMobileSafe,
    );

    expect(
      AddToCartCometController.debugResolveRenderProfileForTest(
        const Size(900, 844),
        forceWeb: true,
      ),
      AddToCartCometRenderProfile.rich,
    );
  });

  testWidgets('unresolvable target: launch is a no-op returning null', (
    tester,
  ) async {
    final context = await pumpHarness(tester, registerAnchor: false);

    expect(launch(context, sourceKey), isNull);
    await tester.pump();
    expect(_cometPaint, findsNothing);
    expect(
      container.read(cartFlightCoordinatorProvider).pendingBadgeDeferrals,
      0,
    );
  });

  testWidgets('parallel flights run and tear down independently', (
    tester,
  ) async {
    final context = await pumpHarness(tester);

    launch(context, sourceKey);
    await settleLaunch(tester);
    await tester.pump(const Duration(milliseconds: 200));
    launch(context, secondSourceKey);
    await settleLaunch(tester);
    expect(_cometPaint, findsNWidgets(2));

    // First flight (at t=200ms) ends while the second is still flying.
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pump();
    expect(_cometPaint, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(_cometPaint, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful add defers the badge until impact, then pops', (
    tester,
  ) async {
    final context = await pumpHarness(tester);

    final handle = launch(context, sourceKey)!;
    await settleLaunch(tester);
    handle.notifyAddSucceeded();
    var state = container.read(cartFlightCoordinatorProvider);
    expect(state.pendingBadgeDeferrals, 1);
    expect(state.impactTick, 0);

    // The impact fires at the snap start (raw t = 0.82 → 902 ms of the
    // 1100 ms sticker timeline).
    await tester.pump(const Duration(milliseconds: 920));
    state = container.read(cartFlightCoordinatorProvider);
    expect(state.pendingBadgeDeferrals, 0);
    expect(state.impactTick, 1);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(_cometPaint, findsNothing);
  });

  testWidgets('failed add: overlay still cleans up, no tick, no deferral', (
    tester,
  ) async {
    final context = await pumpHarness(tester);

    final handle = launch(context, sourceKey)!;
    await settleLaunch(tester);
    handle.notifyAddFailed();

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    expect(_cometPaint, findsNothing);

    final state = container.read(cartFlightCoordinatorProvider);
    expect(state.impactTick, 0);
    expect(state.pendingBadgeDeferrals, 0);
    expect(tester.takeException(), isNull);
  });
}
