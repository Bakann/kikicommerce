import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_drawer_prefetch.dart';

void main() {
  testWidgets('drawer prefetch waits outside initial boot window', (
    tester,
  ) async {
    const beforePrefetchDelay = Duration(milliseconds: 1799);
    final repository = _RecordingDrawerNavigationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drawerNavigationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: StorefrontDrawerPrefetch(child: SizedBox.shrink()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(beforePrefetchDelay);

    expect(repository.calls, isEmpty);
  });

  testWidgets('drawer prefetch does not duplicate the drawer config read', (
    tester,
  ) async {
    final repository = _RecordingDrawerNavigationRepository(
      result: DrawerNavigationLoadResult.success(
        menu: const DrawerNavigationMenuData(
          id: 'menu',
          name: 'Main',
          code: 'main_drawer',
          displayMode: 'drawer',
          isActive: true,
        ),
        normalized: DrawerNavigationNormalizedResult.usable(
          roots: [
            DrawerNavigationNode(
              item: DrawerNavigationItemData(
                id: 'root',
                menuId: 'menu',
                position: 0,
                label: 'Root',
                itemType: DrawerNavigationItemType.page,
                placement: DrawerNavigationPlacement.nav,
                isActive: true,
                isHidden: false,
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drawerNavigationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: StorefrontDrawerPrefetch(child: SizedBox.shrink()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(StorefrontDrawerPrefetch.prefetchDelay);
    await tester.pumpAndSettle();

    expect(repository.calls, [false]);
  });

  testWidgets('drawer prefetch skips when its route is covered before delay', (
    tester,
  ) async {
    final repository = _RecordingDrawerNavigationRepository();
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drawerNavigationRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const StorefrontDrawerPrefetch(
            child: Scaffold(body: Text('Landing')),
          ),
        ),
      ),
    );

    await tester.pump();
    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('PLP')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pump(StorefrontDrawerPrefetch.prefetchDelay);
    await tester.pumpAndSettle();

    expect(find.text('PLP'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });
}

class _RecordingDrawerNavigationRepository
    implements DrawerNavigationRepository {
  final List<bool> calls = [];
  final DrawerNavigationLoadResult result;

  _RecordingDrawerNavigationRepository({
    this.result = const DrawerNavigationLoadResult.fallback(
      fallbackReason: DrawerNavigationFallbackReason.menuMissing,
    ),
  });

  @override
  Future<DrawerNavigationLoadResult> fetchMainDrawer({
    required String locale,
    bool includeHidden = false,
  }) async {
    calls.add(includeHidden);
    return result;
  }
}
