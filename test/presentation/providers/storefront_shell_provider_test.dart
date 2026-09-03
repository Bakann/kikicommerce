import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/providers/storefront_shell_provider.dart';

// _ImmersiveHeaderController in cms_product_list_page.dart is private. This wrapper
// mirrors its lifecycle exactly so the regression test exercises the same pattern.
class ImmersiveTestWrapper extends ConsumerStatefulWidget {
  final bool hasHeroAtTop;
  final Widget child;

  const ImmersiveTestWrapper({
    super.key,
    required this.hasHeroAtTop,
    required this.child,
  });

  @override
  ConsumerState<ImmersiveTestWrapper> createState() =>
      _ImmersiveTestWrapperState();
}

class _ImmersiveTestWrapperState extends ConsumerState<ImmersiveTestWrapper> {
  late final StorefrontShellNotifier _shellNotifier;

  @override
  void initState() {
    super.initState();
    _shellNotifier = ref.read(storefrontShellProvider.notifier);
    _updateMode();
  }

  @override
  void didUpdateWidget(covariant ImmersiveTestWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasHeroAtTop != widget.hasHeroAtTop) {
      _updateMode();
    }
  }

  @override
  void dispose() {
    _shellNotifier.setNormalDeferred();
    super.dispose();
  }

  void _updateMode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.hasHeroAtTop) {
        _shellNotifier.setImmersive(
          foregroundColor: Colors.white,
          heroHeight: 480,
        );
      } else {
        _shellNotifier.setNormal();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

void main() {
  test('StorefrontShellNotifier starts in normal mode', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(storefrontShellProvider);

    expect(state.mode, StorefrontShellMode.normal);
    expect(state.isImmersive, isFalse);
    expect(state.headerForegroundColor, isNull);
  });

  test('StorefrontShellNotifier can switch to immersive mode and back', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(storefrontShellProvider.notifier)
        .setImmersive(foregroundColor: Colors.red, heroHeight: 520);

    var state = container.read(storefrontShellProvider);
    expect(state.mode, StorefrontShellMode.immersive);
    expect(state.isImmersive, isTrue);
    expect(state.headerForegroundColor, Colors.red);
    expect(state.heroHeight, 520);

    container.read(storefrontShellProvider.notifier).setNormal();

    state = container.read(storefrontShellProvider);
    expect(state.mode, StorefrontShellMode.normal);
    expect(state.isImmersive, isFalse);
    expect(state.headerForegroundColor, isNull);
    expect(state.heroHeight, isNull);
  });

  test('setImmersive guard fires only when slice changes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(storefrontShellProvider.notifier);
    notifier.setImmersive(foregroundColor: Colors.white, heroHeight: 400);
    final first = container.read(storefrontShellProvider);

    notifier.setImmersive(foregroundColor: Colors.white, heroHeight: 400);
    expect(identical(container.read(storefrontShellProvider), first), isTrue);

    notifier.setImmersive(foregroundColor: Colors.white, heroHeight: 500);
    expect(identical(container.read(storefrontShellProvider), first), isFalse);
    expect(container.read(storefrontShellProvider).heroHeight, 500);
  });

  testWidgets('ImmersiveHeaderController lifecycle test', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 1. Mount the widget with a hero
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ImmersiveTestWrapper(
            hasHeroAtTop: true,
            child: Text('Hero Page'),
          ),
        ),
      ),
    );

    // Run post frame callbacks
    await tester.pump();

    var state = container.read(storefrontShellProvider);
    expect(state.isImmersive, isTrue);

    // 2. Unmount the widget (simulate navigation pop)
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Text('Other Page')),
      ),
    );

    // Run post frame callbacks from dispose
    await tester.pump();

    state = container.read(storefrontShellProvider);
    expect(state.isImmersive, isFalse);
  });
}
