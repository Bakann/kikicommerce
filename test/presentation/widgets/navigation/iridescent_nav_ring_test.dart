import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kiki_commerce/presentation/widgets/navigation/iridescent_nav_ring.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/scroll_motion_signal.dart';

// These tests guard the Dart-side teardown CONTRACT of the ring: mounting it
// active/loading with a live scroll signal and then unmounting it must throw
// nothing and flush cleanly. They deliberately do NOT (and cannot) reproduce
// the web-only skwasm `memory access out of bounds` crash the fix targets:
// FragmentProgram.fromAsset never compiles on the widget-test surface, so the
// ring stays on its CustomPainter fallback and the feedback render path never
// runs. The skwasm hazard is validated on a real web build. See
// docs/dev/skwasm_gpu_resource_disposal.md.
class _RingHarness extends StatefulWidget {
  const _RingHarness({
    required this.isActive,
    required this.isLoading,
    this.staticFallback = false,
  });

  final bool isActive;
  final bool isLoading;
  final bool staticFallback;

  @override
  State<_RingHarness> createState() => _RingHarnessState();
}

class _RingHarnessState extends State<_RingHarness>
    with SingleTickerProviderStateMixin {
  late final ScrollMotionSignal _motion = ScrollMotionSignal(this);

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IridescentNavRing(
      isActive: widget.isActive,
      isLoading: widget.isLoading,
      staticFallback: widget.staticFallback,
      playToken: 0,
      scrollMotion: _motion,
      child: const SizedBox.square(dimension: 24),
    );
  }
}

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('unmounting an active, loading ring throws nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const _RingHarness(isActive: true, isLoading: true)),
    );
    await tester.pump(const Duration(milliseconds: 32));

    // Replace the ring with a plain widget: this disposes the ring's State
    // while it is active + loading, exercising the retire-on-dispose path.
    await tester.pumpWidget(wrap(const SizedBox.square(dimension: 24)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('toggling loading then unmounting throws nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const _RingHarness(isActive: true, isLoading: false)),
    );
    await tester.pump();
    await tester.pumpWidget(
      wrap(const _RingHarness(isActive: true, isLoading: true)),
    );
    await tester.pump(const Duration(milliseconds: 16));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('static fallback survives activation and resize-style toggles', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const _RingHarness(
          isActive: false,
          isLoading: false,
          staticFallback: true,
        ),
      ),
    );

    await tester.pumpWidget(
      wrap(
        const _RingHarness(
          isActive: true,
          isLoading: true,
          staticFallback: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    await tester.pumpWidget(
      wrap(
        const _RingHarness(
          isActive: true,
          isLoading: true,
          staticFallback: true,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
