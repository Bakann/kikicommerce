import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/storefront/storefront_brand_settings.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/premium_scroll_navbar.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/top_navigation_bar.dart';

void main() {
  testWidgets('renders TopNavigationBar inside SafeArea', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpNavbar(tester, controller: controller);
    await tester.pump();

    expect(find.byType(TopNavigationBar), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
  });

  testWidgets('becomes non interactive when hidden', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpNavbar(tester, controller: controller);
    await tester.pump();

    controller.jumpTo(48);
    await tester.pump();

    final ignorePointer = tester.widget<IgnorePointer>(
      find.byKey(PremiumScrollNavbar.ignorePointerKey),
    );
    expect(ignorePointer.ignoring, isTrue);
  });

  testWidgets('uses light surface outside the hero', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpNavbar(tester, controller: controller, heroHeight: 400);
    await tester.pump();

    controller.jumpTo(360);
    await tester.pump();

    final surface = tester.widget<AnimatedContainer>(
      find.byKey(PremiumScrollNavbar.surfaceKey),
    );
    final decoration = surface.decoration! as BoxDecoration;

    expect(decoration.color, const Color(0xF5FFFFFF));
  });

  testWidgets('does not read offset while controller has multiple positions', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storefrontBrandSettingsProvider.overrideWith(
            (ref) async => const StorefrontBrandSettings(
              id: 'settings-id',
              title: 'Atelier Kiki',
              href: '/',
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ListView(controller: controller),
                ListView(controller: controller),
                PremiumScrollNavbar(
                  scrollController: controller,
                  heroHeight: 600,
                  forceVisibleLight: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('delegates menu taps to parent', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var taps = 0;

    await _pumpNavbar(tester, controller: controller, onMenuTap: (_) => taps++);
    await tester.pump();

    await tester.tap(find.byTooltip('Ouvrir le menu'));

    expect(taps, 1);
  });
}

Future<void> _pumpNavbar(
  WidgetTester tester, {
  required ScrollController controller,
  double heroHeight = 600,
  NavRevealTapCallback? onMenuTap,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        storefrontBrandSettingsProvider.overrideWith(
          (ref) async => const StorefrontBrandSettings(
            id: 'settings-id',
            title: 'Atelier Kiki',
            href: '/',
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ListView(
                controller: controller,
                children: const [
                  SizedBox(
                    height: 1600,
                    child: ColoredBox(color: Colors.black),
                  ),
                ],
              ),
              PremiumScrollNavbar(
                scrollController: controller,
                heroHeight: heroHeight,
                onMenuTap: onMenuTap,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
