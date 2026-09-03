import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/sensors/foil_tilt.dart';
import 'package:kiki_commerce/presentation/widgets/holo_foil_overlay.dart';

void main() {
  testWidgets('mobile tilt starts automatically when no gesture is required', (
    tester,
  ) async {
    final source = _FakeFoilTiltSource();
    FoilTiltSource sourceFactory() => source;
    late ValueListenable<Offset?> tilt;
    late ValueListenable<HoloFoilMotionState> motionState;

    await tester.pumpWidget(
      _ScopeHarness(
        width: 390,
        enableMobileTilt: true,
        sourceFactory: sourceFactory,
        onTiltReady: (value) => tilt = value,
        onMotionStateReady: (value) => motionState = value,
      ),
    );

    expect(source.startCount, 1);
    expect(motionState.value, HoloFoilMotionState.active);
    source.emit(const FoilTilt(horizontal: 1, vertical: -1));

    // Sensor samples must reach repaint listeners immediately. Deferring
    // through SchedulerBinding can strand the first sample when it arrives
    // after the transient-callback phase of a browser frame.
    expect(tilt.value!.dx, closeTo(0.85, 1e-9));
    expect(tilt.value!.dy, closeTo(0.15, 1e-9));
    await tester.pump();

    expect(tilt.value!.dx, closeTo(0.85, 1e-9));
    expect(tilt.value!.dy, closeTo(0.15, 1e-9));
  });

  testWidgets('a mobile touch publishes its position until release', (
    tester,
  ) async {
    final source = _FakeFoilTiltSource();
    FoilTiltSource sourceFactory() => source;
    late ValueListenable<Offset?> pointer;

    await tester.pumpWidget(
      _ScopeHarness(
        width: 390,
        enableMobileTilt: true,
        sourceFactory: sourceFactory,
        onPointerReady: (value) => pointer = value,
      ),
    );

    final target = find.byKey(_ScopeHarness.targetKey);
    final start = tester.getTopLeft(target) + const Offset(40, 80);
    final gesture = await tester.startGesture(start);
    expect(pointer.value, start);

    await gesture.moveBy(const Offset(120, 90));
    expect(pointer.value, start + const Offset(120, 90));

    await gesture.up();
    expect(pointer.value, isNull);
  });

  testWidgets('mobile tilt waits for a gesture when the platform requires it', (
    tester,
  ) async {
    final source = _FakeFoilTiltSource(requiresUserGesture: true);
    FoilTiltSource sourceFactory() => source;
    late ValueListenable<HoloFoilMotionState> motionState;

    await tester.pumpWidget(
      _ScopeHarness(
        width: 390,
        enableMobileTilt: true,
        sourceFactory: sourceFactory,
        onMotionStateReady: (value) => motionState = value,
      ),
    );

    expect(source.startCount, 0);
    expect(motionState.value, HoloFoilMotionState.permissionRequired);
    await _touchScope(tester);
    await tester.pump();
    expect(source.startCount, 1);
    expect(motionState.value, HoloFoilMotionState.active);
  });

  testWidgets('tilt stays off outside a mobile viewport', (tester) async {
    final source = _FakeFoilTiltSource();
    FoilTiltSource sourceFactory() => source;

    await tester.pumpWidget(
      _ScopeHarness(
        width: 900,
        enableMobileTilt: true,
        sourceFactory: sourceFactory,
      ),
    );
    await _touchScope(tester);
    await tester.pump();

    expect(source.startCount, 0);
  });

  testWidgets('tilt stays off when reduced motion is enabled', (tester) async {
    final source = _FakeFoilTiltSource();
    FoilTiltSource sourceFactory() => source;

    await tester.pumpWidget(
      _ScopeHarness(
        width: 390,
        enableMobileTilt: true,
        disableAnimations: true,
        sourceFactory: sourceFactory,
      ),
    );
    await _touchScope(tester);
    await tester.pump();

    expect(source.startCount, 0);
  });

  testWidgets('tilt stops and clears when the viewport becomes desktop', (
    tester,
  ) async {
    final source = _FakeFoilTiltSource();
    FoilTiltSource sourceFactory() => source;
    late ValueListenable<Offset?> tilt;

    await tester.pumpWidget(
      _ScopeHarness(
        width: 390,
        enableMobileTilt: true,
        sourceFactory: sourceFactory,
        onTiltReady: (value) => tilt = value,
      ),
    );
    await _touchScope(tester);
    await tester.pump();
    expect(source.startCount, 1);
    source.emit(const FoilTilt(horizontal: 0.5, vertical: 0.5));
    await tester.pump();
    expect(tilt.value, isNotNull);

    await tester.pumpWidget(
      _ScopeHarness(
        width: 900,
        enableMobileTilt: true,
        sourceFactory: sourceFactory,
        onTiltReady: (value) => tilt = value,
      ),
    );

    expect(source.stopCount, 1);
    expect(tilt.value, isNull);
  });
}

Future<void> _touchScope(WidgetTester tester) async {
  final target = find.byKey(_ScopeHarness.targetKey);
  final gesture = await tester.startGesture(
    tester.getTopLeft(target) + const Offset(10, 10),
  );
  await gesture.up();
}

class _ScopeHarness extends StatelessWidget {
  static const targetKey = Key('foil-target');

  final double width;
  final bool enableMobileTilt;
  final bool disableAnimations;
  final FoilTiltSourceFactory sourceFactory;
  final ValueChanged<ValueListenable<Offset?>>? onPointerReady;
  final ValueChanged<ValueListenable<Offset?>>? onTiltReady;
  final ValueChanged<ValueListenable<HoloFoilMotionState>>? onMotionStateReady;

  const _ScopeHarness({
    required this.width,
    required this.enableMobileTilt,
    required this.sourceFactory,
    this.disableAnimations = false,
    this.onPointerReady,
    this.onTiltReady,
    this.onMotionStateReady,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        disableAnimations: disableAnimations,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: width,
          height: 400,
          child: HoloFoilPointerScope(
            enableMobileTilt: enableMobileTilt,
            tiltSourceFactory: sourceFactory,
            child: Builder(
              builder: (context) {
                onPointerReady?.call(HoloFoilPointerScope.maybeOf(context)!);
                onTiltReady?.call(HoloFoilPointerScope.maybeTiltOf(context)!);
                onMotionStateReady?.call(
                  HoloFoilPointerScope.maybeMotionStateOf(context)!,
                );
                return const SizedBox.expand(key: targetKey);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FakeFoilTiltSource implements FoilTiltSource {
  @override
  final bool requiresUserGesture;

  FoilTiltListener? _listener;
  int startCount = 0;
  int stopCount = 0;

  _FakeFoilTiltSource({this.requiresUserGesture = false});

  @override
  Future<bool> start(FoilTiltListener listener) async {
    startCount += 1;
    _listener = listener;
    return true;
  }

  void emit(FoilTilt tilt) => _listener?.call(tilt);

  @override
  void stop() {
    stopCount += 1;
    _listener = null;
  }

  @override
  void recenter() {}

  @override
  void dispose() {
    _listener = null;
  }
}
