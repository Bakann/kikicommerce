import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/storefront/storefront_navigation_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_sport_segment.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/category_providers.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/category_split_tabs_section.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/misc.dart' show Override;

import '../../../support/l10n_harness.dart';

void main() {
  // ---- tabs design (global setting = tabs) ------------------------------

  testWidgets('uses explicit segment to choose active tab', (tester) async {
    await _pumpTabs(
      tester,
      config: const CategorySplitTabsConfig(
        defaultActiveIndex: 0,
        items: [
          CategorySplitTabItem(
            label: 'Homme',
            href: '/sport/homme',
            segment: 'homme',
          ),
          CategorySplitTabItem(
            label: 'Femme',
            href: '/sport/femme',
            segment: 'femme',
          ),
          CategorySplitTabItem(
            label: 'Enfant',
            href: '/sport/enfant',
            segment: 'enfant',
          ),
        ],
      ),
      activeSportSegment: StorefrontSportSegment.femme,
    );

    expect(_activeText('Femme'), findsOneWidget);
    expect(_activeText('Homme'), findsNothing);
  });

  testWidgets('falls back to href matching when segment is absent', (
    tester,
  ) async {
    await _pumpTabs(
      tester,
      config: const CategorySplitTabsConfig(
        defaultActiveIndex: 0,
        items: [
          CategorySplitTabItem(label: 'Homme', href: '/'),
          CategorySplitTabItem(label: 'Femme', href: '/sport/femme/'),
          CategorySplitTabItem(label: 'Enfant', href: '/sport/enfant'),
        ],
      ),
      activeSportSegment: StorefrontSportSegment.enfant,
    );

    expect(_activeText('Enfant'), findsOneWidget);
    expect(_activeText('Homme'), findsNothing);
  });

  testWidgets('href matching accepts localized public sport URLs', (
    tester,
  ) async {
    await _pumpTabs(
      tester,
      config: const CategorySplitTabsConfig(
        defaultActiveIndex: 0,
        items: [
          CategorySplitTabItem(label: 'Homme', href: '/'),
          CategorySplitTabItem(label: 'Femme', href: '/fr/sport/femme'),
        ],
      ),
      activeSportSegment: StorefrontSportSegment.femme,
    );

    expect(_activeText('Femme'), findsOneWidget);
    expect(_activeText('Homme'), findsNothing);
  });

  testWidgets('uses CMS default when no active route segment is provided', (
    tester,
  ) async {
    await _pumpTabs(
      tester,
      config: const CategorySplitTabsConfig(
        defaultActiveIndex: 2,
        items: [
          CategorySplitTabItem(label: 'Homme', href: '/sport/homme'),
          CategorySplitTabItem(label: 'Femme', href: '/sport/femme'),
          CategorySplitTabItem(label: 'Enfant', href: '/sport/enfant'),
        ],
      ),
    );

    expect(_activeText('Enfant'), findsOneWidget);
  });

  testWidgets('tabs design renders the tab row, not an Expansible', (
    tester,
  ) async {
    await _pumpTabs(
      tester,
      config: const CategorySplitTabsConfig(
        items: [CategorySplitTabItem(label: 'Homme', href: '/sport/homme')],
      ),
    );

    expect(find.byType(Expansible), findsNothing);
    expect(find.text('Homme'), findsOneWidget);
  });

  testWidgets('tab href navigates to sport segment route', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: CategorySplitTabsSection(
              config: CategorySplitTabsConfig(
                items: [
                  CategorySplitTabItem(label: 'Homme', href: '/'),
                  CategorySplitTabItem(label: 'Femme', href: '/sport/femme'),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/sport/femme',
          builder: (context, state) =>
              const Scaffold(body: Text('Femme route')),
        ),
        GoRoute(
          path: '/fr/sport/femme',
          builder: (context, state) =>
              const Scaffold(body: Text('Femme route')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _navOverrides(CategorySplitDisplayMode.tabs),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Femme'));
    await tester.pumpAndSettle();

    expect(find.text('Femme route'), findsOneWidget);
  });

  // ---- expansible design (global setting = expansible) ------------------

  testWidgets('expansible design renders a titled Expansible (collapsed)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _navOverrides(CategorySplitDisplayMode.expansible),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategorySplitTabsSection(
                config: CategorySplitTabsConfig(expansibleTitle: 'Parcourir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Expansible), findsOneWidget);
    expect(find.text('Parcourir'), findsOneWidget);
  });

  testWidgets(
    'legacy section displayMode is used when global setting is absent',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _navOverrides(
            CategorySplitDisplayMode.tabs,
            hasCategorySplitDisplayMode: false,
          ),
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CategorySplitTabsSection(
                  config: CategorySplitTabsConfig(
                    displayMode: 'expansible',
                    expansibleTitle: 'Parcourir',
                  ),
                  activeSportSegment: StorefrontSportSegment.femme,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Expansible), findsOneWidget);
      expect(find.text('Femme'), findsOneWidget);
      expect(find.text('Parcourir'), findsNothing);
    },
  );

  testWidgets('explicit global tabs overrides legacy section expansible mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _navOverrides(CategorySplitDisplayMode.tabs),
        child: const MaterialApp(
          home: Scaffold(
            body: CategorySplitTabsSection(
              config: CategorySplitTabsConfig(
                displayMode: 'expansible',
                items: [
                  CategorySplitTabItem(label: 'Homme', href: '/sport/homme'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Expansible), findsNothing);
    expect(find.text('Homme'), findsOneWidget);
  });

  testWidgets(
    'expansible shows the active segment + its categories/sub-categories',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._navOverrides(CategorySplitDisplayMode.expansible),
            drawerCategoriesProvider.overrideWith((ref) async => _segmentTree),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CategorySplitTabsSection(
                  config: CategorySplitTabsConfig(expansibleTitle: 'Parcourir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Parcourir'));
      await tester.pumpAndSettle();

      // All segments stay visible; the default-active one (Homme) shows its
      // descendants simultaneously.
      expect(find.text('Homme'), findsOneWidget);
      expect(find.text('Femme'), findsOneWidget);
      expect(find.text('Chaussures H'), findsOneWidget);
      expect(find.text('Lifestyle'), findsOneWidget);
      expect(find.text('Chaussures F'), findsNothing);
    },
  );

  testWidgets('expansible collapsed header shows the active segment label', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._navOverrides(CategorySplitDisplayMode.expansible),
          drawerCategoriesProvider.overrideWith((ref) async => _segmentTree),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategorySplitTabsSection(
                config: CategorySplitTabsConfig(expansibleTitle: 'Parcourir'),
                activeSportSegment: StorefrontSportSegment.femme,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Collapsed → the header is the active segment, not the configured title.
    expect(find.text('Femme'), findsOneWidget);
    expect(find.text('Parcourir'), findsNothing);
  });

  testWidgets(
    'expansible collapsed header localizes the active segment label',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _navOverrides(CategorySplitDisplayMode.expansible),
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: CategorySplitTabsSection(
                  config: CategorySplitTabsConfig(expansibleTitle: 'Parcourir'),
                  activeSportSegment: StorefrontSportSegment.homme,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Men'), findsOneWidget);
      expect(find.text('Homme'), findsNothing);
    },
  );

  testWidgets('expansible: tapping a segment opens its sport landing', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/sport/homme',
      routes: [
        GoRoute(
          path: '/sport/homme',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(
              child: CategorySplitTabsSection(
                config: CategorySplitTabsConfig(expansibleTitle: 'Parcourir'),
                activeSportSegment: StorefrontSportSegment.homme,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/sport/femme',
          builder: (context, state) =>
              const Scaffold(body: Text('Femme landing')),
        ),
        GoRoute(
          path: '/fr/sport/femme',
          builder: (context, state) =>
              const Scaffold(body: Text('Femme landing')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._navOverrides(CategorySplitDisplayMode.expansible),
          drawerCategoriesProvider.overrideWith((ref) async => _segmentTree),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          locale: const Locale('fr'),
        ),
      ),
    );
    await tester.pump();
    // Collapsed header shows the active segment (Homme); tap it to expand.
    await tester.tap(find.text('Homme'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Femme'));
    await tester.pumpAndSettle();

    expect(find.text('Femme landing'), findsOneWidget);
  });
}

List<Override> _navOverrides(
  CategorySplitDisplayMode mode, {
  bool hasCategorySplitDisplayMode = true,
}) {
  return [
    storefrontNavigationSettingsProvider.overrideWith(
      (ref) => StorefrontNavigationSettings(
        mobileMenuStyle: MobileMenuStyle.drawer,
        categorySplitDisplayMode: mode,
        hasCategorySplitDisplayMode: hasCategorySplitDisplayMode,
      ),
    ),
  ];
}

const _segmentTree = [
  CatalogCategory(id: 'h', code: 'HOMME', name: 'Homme', slug: 'homme'),
  CatalogCategory(id: 'f', code: 'FEMME', name: 'Femme', slug: 'femme'),
  CatalogCategory(
    id: 'h_ch',
    code: 'HOMME_CH',
    name: 'Chaussures H',
    slug: 'homme-chaussures',
    parentId: 'h',
  ),
  CatalogCategory(
    id: 'h_ch_life',
    code: 'HOMME_CH_LIFE',
    name: 'Lifestyle',
    slug: 'homme-chaussures-lifestyle',
    parentId: 'h_ch',
  ),
  CatalogCategory(
    id: 'f_ch',
    code: 'FEMME_CH',
    name: 'Chaussures F',
    slug: 'femme-chaussures',
    parentId: 'f',
  ),
];

Finder _activeText(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.data == label &&
        widget.style?.fontWeight == FontWeight.w700,
  );
}

Future<void> _pumpTabs(
  WidgetTester tester, {
  required CategorySplitTabsConfig config,
  StorefrontSportSegment? activeSportSegment,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _navOverrides(CategorySplitDisplayMode.tabs),
      child: MaterialApp(
        home: Scaffold(
          body: CategorySplitTabsSection(
            config: config,
            activeSportSegment: activeSportSegment,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
