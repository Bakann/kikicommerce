import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/category_providers.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/providers/navigation_providers.dart';
import 'package:kiki_commerce/presentation/widgets/kiki_image.dart';
import 'package:kiki_commerce/presentation/widgets/landing_asset_loading_backdrop.dart';
import 'package:kiki_commerce/presentation/widgets/scroll_directional_glow.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/category_banner_strip_section.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/category_banner_strip_section_host.dart';

void main() {
  testWidgets('tapping a banner with href navigates', (tester) async {
    final item = CategoryBannerItem.fromJson({
      'title': 'Chaussures',
      'href': '/target',
    });
    await _pumpSection(tester, [item]);

    await tester.tap(find.text('Chaussures'));
    await tester.pumpAndSettle();

    expect(find.text('Target route'), findsOneWidget);
  });

  testWidgets('empty href is a safe no-op', (tester) async {
    final item = CategoryBannerItem.fromJson({
      'title': 'Chaussures',
      'href': '',
    });
    await _pumpSection(tester, [item]);

    await tester.tap(find.text('Chaussures'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Home route'), findsOneWidget);
  });

  testWidgets('empty items list renders nothing visible', (tester) async {
    await _pumpSection(tester, const []);

    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Home route'), findsOneWidget);
  });

  testWidgets('skeleton leaves the shader visible while reserving its layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CategoryBannerStripSkeleton(itemCount: 3)),
      ),
    );
    await tester.pump();

    expect(find.byType(CategoryBannerStripSkeleton), findsOneWidget);
    expect(find.byType(LandingGradientLoadingSurface), findsOneWidget);
  });

  testWidgets('skeleton paints configured banner gradients while loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CategoryBannerStripSkeleton(
            itemCount: 3,
            appearance: [
              CategoryBannerAppearance(
                gradientStartHex: '#60A5FA',
                gradientEndHex: '#60A5FA',
              ),
              CategoryBannerAppearance(
                gradientStartHex: '#1E3A8A',
                gradientEndHex: '#60A5FA',
              ),
              CategoryBannerAppearance(gradientStartHex: '#243E91'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final decorations = _bannerSkeletonDecorations(tester);
    expect(decorations, hasLength(3));
    expect((decorations[0].gradient as LinearGradient).colors, [
      const Color(0xFF60A5FA).withValues(alpha: 0.12),
      const Color(0xFF60A5FA).withValues(alpha: 0.12),
    ]);
    expect((decorations[1].gradient as LinearGradient).colors, [
      const Color(0xFF1E3A8A).withValues(alpha: 0.12),
      const Color(0xFF60A5FA).withValues(alpha: 0.12),
    ]);
    expect(
      decorations[2].color,
      const Color(0xFF243E91).withValues(alpha: 0.12),
    );
  });

  testWidgets('skeleton and resolved section reserve equal height', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CategoryBannerStripSkeleton(itemCount: 3)),
      ),
    );
    await tester.pump();
    final skeletonHeight = tester
        .getSize(find.byType(CategoryBannerStripSkeleton))
        .height;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CategoryBannerStripSection(items: _items(3))),
      ),
    );
    await tester.pump();
    final resolvedHeight = tester
        .getSize(find.byType(CategoryBannerStripSection))
        .height;

    expect(skeletonHeight, resolvedHeight);
  });

  testWidgets('banner paints custom gradient with white text on dark start', (
    tester,
  ) async {
    final item = CategoryBannerItem.fromJson({
      'title': 'Chaussures',
      'href': '',
      'gradientStart': '#2A3038',
      'gradientEnd': '#5A6470',
    });
    await _pumpSection(tester, [item]);

    final ink = tester.widget<Ink>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Ink &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).gradient != null,
      ),
    );
    final gradient =
        (ink.decoration as BoxDecoration).gradient as LinearGradient;
    expect(gradient.colors, const [Color(0xFF2A3038), Color(0xFF5A6470)]);

    final text = tester.widget<Text>(find.text('Chaussures'));
    expect(text.style?.color, Colors.white);
  });

  testWidgets('single light custom color paints flat with dark text', (
    tester,
  ) async {
    final item = CategoryBannerItem.fromJson({
      'title': 'Chaussures',
      'href': '',
      'gradientStart': '#EDEAE3',
    });
    await _pumpSection(tester, [item]);

    final ink = tester.widget<Ink>(
      find.byWidgetPredicate(
        (widget) => widget is Ink && widget.decoration is BoxDecoration,
      ),
    );
    final decoration = ink.decoration as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.color, const Color(0xFFEDEAE3));

    final text = tester.widget<Text>(find.text('Chaussures'));
    expect(text.style?.color, const Color(0xFF111111));
  });

  testWidgets('shared background media only sits behind the first three rows', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      _items(4),
      sharedBackgroundMedia: const CmsMediaRef(
        recordId: 'group-1',
        collectionId: 'medias',
        filename: 'nike-team.jpg',
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is KikiImage &&
            (widget.imageUrl?.contains('nike-team.jpg') ?? false),
      ),
      findsOneWidget,
    );

    final darkStandaloneInks = tester
        .widgetList<Ink>(
          find.byWidgetPredicate(
            (widget) => widget is Ink && widget.decoration is BoxDecoration,
          ),
        )
        .where(
          (ink) =>
              (ink.decoration as BoxDecoration).color ==
              const Color(0xFF2A3038),
        )
        .toList(growable: false);
    expect(darkStandaloneInks, hasLength(1));
    expect(find.byType(InkWell), findsNWidgets(4));
  });

  testWidgets(
    'tapping the first shared banner runs the glow, then the action',
    (tester) async {
      await _pumpSection(
        tester,
        const [
          CategoryBannerItem(title: 'Chaussures', href: '/target'),
          CategoryBannerItem(title: 'Vêtements', href: '/v'),
          CategoryBannerItem(title: 'Sport', href: '/s'),
        ],
        sharedBackgroundMedia: const CmsMediaRef(
          recordId: 'group-1',
          collectionId: 'medias',
          filename: 'nike-team.jpg',
        ),
      );

      // No glow until the banner is tapped.
      expect(find.byType(ScrollDirectionalGlow), findsNothing);

      await tester.tap(find.text('Chaussures'));
      await tester.pump();

      // The scan is running; the action has not fired yet.
      expect(find.byType(ScrollDirectionalGlow), findsOneWidget);
      expect(find.text('Target route'), findsNothing);

      // Advance past the scan (the noise texture does not decode in a widget
      // test, so the safety fallback is what completes it here) → the action
      // runs and the glow is removed.
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
      expect(find.byType(ScrollDirectionalGlow), findsNothing);
      expect(find.text('Target route'), findsOneWidget);
    },
  );

  testWidgets('host applies bannerAppearance overrides to drawer banners', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      config: const CategoryBannerStripConfig(
        bannerAppearance: {
          'jean': CategoryBannerAppearance(
            gradientStartHex: '#101418',
            gradientEndHex: '#3A444E',
          ),
        },
      ),
      categories: [
        const CatalogCategory(id: 'jean', code: 'JEAN', name: 'Jean'),
        const CatalogCategory(id: 'fleurs', code: 'FLEURS', name: 'Fleurs'),
      ],
    );

    final gradientInks = tester
        .widgetList<Ink>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Ink &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).gradient != null,
          ),
        )
        .toList();
    expect(gradientInks, hasLength(1));
    final gradient =
        (gradientInks.single.decoration as BoxDecoration).gradient
            as LinearGradient;
    expect(gradient.colors, const [Color(0xFF101418), Color(0xFF3A444E)]);
  });

  testWidgets('host shows skeleton while drawer navigation is loading', (
    tester,
  ) async {
    final pendingDrawer = Completer<DrawerNavigationLoadResult>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mainDrawerNavigationProvider.overrideWith(
            (_) => pendingDrawer.future,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CategoryBannerStripSectionHost(
              config: CategoryBannerStripConfig(skeletonItemCount: 3),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CategoryBannerStripSkeleton), findsOneWidget);

    pendingDrawer.complete(
      const DrawerNavigationLoadResult.fallback(
        fallbackReason: DrawerNavigationFallbackReason.menuMissing,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CategoryBannerStripSkeleton), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('host shows skeleton while category-backed drawer loads', (
    tester,
  ) async {
    final pendingCategories = Completer<List<CatalogCategory>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mainDrawerNavigationProvider.overrideWith(
            (_) async => _categoriesDrawerResult(),
          ),
          drawerCategoriesProvider.overrideWith(
            (_) => pendingCategories.future,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CategoryBannerStripSectionHost(
              config: CategoryBannerStripConfig(skeletonItemCount: 3),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CategoryBannerStripSkeleton), findsOneWidget);

    pendingCategories.complete([
      const CatalogCategory(id: 'jean', code: 'jean', name: 'Jean De Nîmes'),
      const CatalogCategory(id: 'fleurs', code: 'fleurs', name: 'Les fleurs'),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.byType(CategoryBannerStripSkeleton), findsNothing);
    expect(find.text('Jean De Nîmes'), findsOneWidget);
    expect(find.text('Les fleurs'), findsOneWidget);
  });

  testWidgets('host loading skeleton uses configured banner appearance', (
    tester,
  ) async {
    final pendingCategories = Completer<List<CatalogCategory>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mainDrawerNavigationProvider.overrideWith(
            (_) async => _categoriesDrawerResult(),
          ),
          drawerCategoriesProvider.overrideWith(
            (_) => pendingCategories.future,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CategoryBannerStripSectionHost(
              config: CategoryBannerStripConfig(
                skeletonItemCount: 2,
                bannerAppearance: {
                  'shoes': CategoryBannerAppearance(
                    gradientStartHex: '#60A5FA',
                    gradientEndHex: '#60A5FA',
                  ),
                  'clothes': CategoryBannerAppearance(
                    gradientStartHex: '#1E3A8A',
                    gradientEndHex: '#60A5FA',
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CategoryBannerStripSkeleton), findsOneWidget);
    final decorations = _bannerSkeletonDecorations(tester);
    expect(decorations, hasLength(2));
    expect((decorations[0].gradient as LinearGradient).colors, [
      const Color(0xFF60A5FA).withValues(alpha: 0.12),
      const Color(0xFF60A5FA).withValues(alpha: 0.12),
    ]);
    expect((decorations[1].gradient as LinearGradient).colors, [
      const Color(0xFF1E3A8A).withValues(alpha: 0.12),
      const Color(0xFF60A5FA).withValues(alpha: 0.12),
    ]);
  });

  testWidgets('host can render children of configured source category', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      config: const CategoryBannerStripConfig(
        sourceMode: CategoryBannerStripSourceMode.categoryChildren,
        sourceCategoryId: 'homme',
      ),
      categories: [
        const CatalogCategory(id: 'homme', code: 'HOMME', name: 'Homme'),
        const CatalogCategory(
          id: 'running',
          code: 'RUNNING',
          name: 'Running',
          slug: 'running',
          parentId: 'homme',
          position: 20,
        ),
        const CatalogCategory(
          id: 'training',
          code: 'TRAINING',
          name: 'Training',
          slug: 'training',
          parentId: 'homme',
          position: 10,
        ),
        const CatalogCategory(
          id: 'hidden',
          code: 'HIDDEN',
          name: 'Hidden',
          parentId: 'homme',
          isHidden: true,
        ),
      ],
    );

    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Hidden'), findsNothing);
    expect(find.text('Homme'), findsNothing);
  });

  testWidgets('host renders CMS configured banners without drawer data', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CategoryBannerStripSectionHost(
              config: CategoryBannerStripConfig(
                sourceMode: CategoryBannerStripSourceMode.configuredBanners,
                configuredBanners: [
                  CategoryBannerItem(title: 'Chaussures', href: '/catalog'),
                  CategoryBannerItem(title: 'Vêtements', href: '/catalog'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Chaussures'), findsOneWidget);
    expect(find.text('Vêtements'), findsOneWidget);
    expect(find.byType(CategoryBannerStripSkeleton), findsNothing);
  });

  testWidgets('configured banner href still navigates', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: CategoryBannerStripSectionHost(
              config: CategoryBannerStripConfig(
                sourceMode: CategoryBannerStripSourceMode.configuredBanners,
                configuredBanners: [
                  CategoryBannerItem(title: 'Chaussures', href: '/target'),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/target',
          builder: (context, state) =>
              const Scaffold(body: Text('Target route')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();

    await tester.tap(find.text('Chaussures'));
    await tester.pumpAndSettle();

    expect(find.text('Target route'), findsOneWidget);
  });

  testWidgets('host falls back to roots without warning in storefront', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      config: const CategoryBannerStripConfig(
        sourceMode: CategoryBannerStripSourceMode.categoryChildren,
        sourceCategoryId: 'missing',
      ),
      categories: [
        const CatalogCategory(id: 'homme', code: 'HOMME', name: 'Homme'),
        const CatalogCategory(id: 'femme', code: 'FEMME', name: 'Femme'),
      ],
    );

    expect(find.text('Homme'), findsOneWidget);
    expect(find.text('Femme'), findsOneWidget);
    expect(find.textContaining('Aucune sous-catégorie'), findsNothing);
  });

  testWidgets(
    'categoryChildren: switching sourceCategoryId with cached categories never '
    'flashes the skeleton',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mainDrawerNavigationProvider.overrideWith(
              (_) async => _categoriesDrawerResult(),
            ),
            drawerCategoriesProvider.overrideWith((_) async => _segmentTree()),
          ],
          child: const MaterialApp(home: Scaffold(body: _SegmentHostHarness())),
        ),
      );
      // First real load: categories resolve once (a skeleton here is expected
      // and fine — it is the genuine first paint).
      await tester.pumpAndSettle();
      expect(find.byType(CategoryBannerStripSkeleton), findsNothing);
      expect(find.text('ChaussuresHomme'), findsOneWidget);
      expect(find.text('SportFemme'), findsNothing);

      // Switch segment: sourceCategoryId homme → femme. Categories are already
      // cached in this scope, so the strip must resolve the new banners without
      // ever returning to the skeleton — not even for a single frame.
      await tester.tap(find.text('switch-to-femme'));
      await tester.pump();
      expect(find.byType(CategoryBannerStripSkeleton), findsNothing);
      expect(find.text('SportFemme'), findsOneWidget);
      expect(find.text('ChaussuresHomme'), findsNothing);
    },
  );

  testWidgets('host shows inline warning for children fallback in edit mode', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      config: const CategoryBannerStripConfig(
        sourceMode: CategoryBannerStripSourceMode.categoryChildren,
      ),
      categories: [
        const CatalogCategory(id: 'homme', code: 'HOMME', name: 'Homme'),
        const CatalogCategory(id: 'femme', code: 'FEMME', name: 'Femme'),
      ],
      editMode: true,
    );

    expect(find.text('Homme'), findsOneWidget);
    expect(find.text('Femme'), findsOneWidget);
    expect(
      find.textContaining('Aucune sous-catégorie configurée'),
      findsOneWidget,
    );
  });
}

List<BoxDecoration> _bannerSkeletonDecorations(WidgetTester tester) {
  return tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((widget) => widget.decoration)
      .whereType<BoxDecoration>()
      .where(
        (decoration) =>
            decoration.color ==
                const Color(0xFF243E91).withValues(alpha: 0.12) ||
            decoration.gradient is LinearGradient,
      )
      .toList(growable: false);
}

List<CategoryBannerItem> _items(int count) {
  return List.generate(
    count,
    (index) => CategoryBannerItem.fromJson({
      'title': 'Banner ${index + 1}',
      'href': '',
    }),
  );
}

List<CatalogCategory> _segmentTree() {
  return const [
    CatalogCategory(id: 'homme', code: 'HOMME', name: 'Homme', slug: 'homme'),
    CatalogCategory(id: 'femme', code: 'FEMME', name: 'Femme', slug: 'femme'),
    CatalogCategory(
      id: 'h-ch',
      code: 'HOMME_CH',
      name: 'ChaussuresHomme',
      slug: 'h-ch',
      parentId: 'homme',
      position: 10,
    ),
    CatalogCategory(
      id: 'f-sp',
      code: 'FEMME_SP',
      name: 'SportFemme',
      slug: 'f-sp',
      parentId: 'femme',
      position: 10,
    ),
  ];
}

/// Renders the host in categoryChildren mode and lets the test flip the source
/// category id (simulating a Homme → Femme segment switch) within the SAME
/// ProviderScope, so the cached categories provider is reused.
class _SegmentHostHarness extends StatefulWidget {
  const _SegmentHostHarness();

  @override
  State<_SegmentHostHarness> createState() => _SegmentHostHarnessState();
}

class _SegmentHostHarnessState extends State<_SegmentHostHarness> {
  String _sourceCategoryId = 'homme';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: () => setState(() => _sourceCategoryId = 'femme'),
          child: const Text('switch-to-femme'),
        ),
        CategoryBannerStripSectionHost(
          config: CategoryBannerStripConfig(
            sourceMode: CategoryBannerStripSourceMode.categoryChildren,
            sourceCategoryId: _sourceCategoryId,
          ),
        ),
      ],
    );
  }
}

DrawerNavigationLoadResult _categoriesDrawerResult() {
  return DrawerNavigationLoadResult.success(
    menu: const DrawerNavigationMenuData(
      id: 'menu',
      name: 'Main drawer',
      code: 'main_drawer',
      displayMode: 'categories',
      isActive: true,
    ),
    normalized: DrawerNavigationNormalizedResult.usable(
      roots: [_drawerNode('root')],
    ),
  );
}

DrawerNavigationNode _drawerNode(String id) {
  return DrawerNavigationNode(
    item: DrawerNavigationItemData(
      id: id,
      menuId: 'menu',
      position: 0,
      label: 'Root',
      itemType: DrawerNavigationItemType.category,
      placement: DrawerNavigationPlacement.nav,
      isActive: true,
      isHidden: false,
    ),
  );
}

Future<void> _pumpSection(
  WidgetTester tester,
  List<CategoryBannerItem> items, {
  CmsMediaRef? sharedBackgroundMedia,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const Text('Home route'),
                CategoryBannerStripSection(
                  items: items,
                  sharedBackgroundMedia: sharedBackgroundMedia,
                ),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/target',
        builder: (context, state) => const Scaffold(body: Text('Target route')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pump();
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required CategoryBannerStripConfig config,
  required List<CatalogCategory> categories,
  bool editMode = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mainDrawerNavigationProvider.overrideWith(
          (_) async => _categoriesDrawerResult(),
        ),
        drawerCategoriesProvider.overrideWith((_) async => categories),
        if (editMode) editModeProvider.overrideWith((_) => true),
      ],
      child: MaterialApp(
        home: Scaffold(body: CategoryBannerStripSectionHost(config: config)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
