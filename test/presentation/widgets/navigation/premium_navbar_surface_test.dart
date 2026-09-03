import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/storefront/storefront_brand_settings.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/premium_navbar_surface.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/scroll_navbar_state_machine.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/top_navigation_bar.dart';

void main() {
  testWidgets('renders TopNavigationBar inside SafeArea', (tester) async {
    await _pumpSurface(
      tester,
      snapshot: const ScrollNavbarSnapshot(isVisible: true, styleProgress: 0),
    );

    expect(find.byType(TopNavigationBar), findsOneWidget);
    expect(find.byType(SafeArea), findsOneWidget);
  });

  testWidgets('becomes non interactive when hidden', (tester) async {
    await _pumpSurface(
      tester,
      snapshot: const ScrollNavbarSnapshot(isVisible: false, styleProgress: 0),
    );

    final ignorePointer = tester.widget<IgnorePointer>(
      find.byKey(PremiumNavbarSurface.ignorePointerKey),
    );
    final excludeSemantics = tester.widget<ExcludeSemantics>(
      find.ancestor(
        of: find.byKey(PremiumNavbarSurface.surfaceKey),
        matching: find.byType(ExcludeSemantics),
      ),
    );

    expect(ignorePointer.ignoring, isTrue);
    expect(excludeSemantics.excluding, isTrue);
  });

  testWidgets('uses transparent white surface at hero progress', (
    tester,
  ) async {
    await _pumpSurface(
      tester,
      snapshot: const ScrollNavbarSnapshot(isVisible: true, styleProgress: 0),
    );

    final decoration = _surfaceDecoration(tester);

    expect(decoration.color, const Color(0x00FFFFFF));
  });

  testWidgets('uses light surface outside hero', (tester) async {
    await _pumpSurface(
      tester,
      snapshot: const ScrollNavbarSnapshot(isVisible: true, styleProgress: 1),
    );

    final decoration = _surfaceDecoration(tester);

    expect(decoration.color, const Color(0xF5FFFFFF));
  });

  testWidgets('respects heroForegroundColor at hero progress', (tester) async {
    const heroForeground = Color(0xFFCCDDFF);

    await _pumpSurface(
      tester,
      snapshot: const ScrollNavbarSnapshot(isVisible: true, styleProgress: 0),
      heroForegroundColor: heroForeground,
    );

    final topNav = tester.widget<TopNavigationBar>(
      find.byType(TopNavigationBar),
    );

    expect(topNav.foregroundColor, heroForeground);
  });
}

BoxDecoration _surfaceDecoration(WidgetTester tester) {
  final surface = tester.widget<AnimatedContainer>(
    find.byKey(PremiumNavbarSurface.surfaceKey),
  );
  return surface.decoration! as BoxDecoration;
}

Future<void> _pumpSurface(
  WidgetTester tester, {
  required ScrollNavbarSnapshot snapshot,
  Color heroForegroundColor = Colors.white,
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
          body: PremiumNavbarSurface(
            snapshot: snapshot,
            heroForegroundColor: heroForegroundColor,
          ),
        ),
      ),
    ),
  );
}
