import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/application/storefront/storefront_brand_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_navigation_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/data/local/visitor_storefront_theme_store.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/brand_segment_section.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/top_navigation_bar.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_theme_switcher.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('legacy Nike/Jordan seed parses as Sport/Luxe themeSwitcher', () {
    final config = BrandSegmentConfig.fromJson({
      'schemaVersion': 1,
      'activeIndex': 0,
      'items': [
        {'label': 'Nike', 'href': '/'},
        {'label': 'Jordan', 'href': '/catalog'},
      ],
    });

    expect(config.mode, BrandSegmentMode.themeSwitcher);
    expect(config.items.map((item) => item.label), ['Sport', 'Luxe']);
    expect(config.items.map((item) => item.theme), [
      StorefrontTheme.nike,
      StorefrontTheme.dior,
    ]);
  });

  testWidgets('themeSwitcher tap Sport persists nike', (tester) async {
    final store = _MemoryVisitorStorefrontThemeStore();
    await _pumpThemeSwitcher(tester, store: store);

    await tester.tap(find.text('Sport'));
    await tester.pumpAndSettle();

    expect(store.rawValue, 'nike');
  });

  testWidgets('themeSwitcher tap brand title persists dior', (tester) async {
    final store = _MemoryVisitorStorefrontThemeStore();
    await _pumpThemeSwitcher(tester, store: store, brandTitle: "Kiki's Co");

    await tester.tap(find.text("Kiki's Co"));
    await tester.pumpAndSettle();

    expect(store.rawValue, 'dior');
  });

  testWidgets('themeSwitcher active item follows effective theme', (
    tester,
  ) async {
    final store = _MemoryVisitorStorefrontThemeStore(rawValue: 'nike');
    await _pumpThemeSwitcher(
      tester,
      store: store,
      activeIndex: 1,
      brandTitle: "Kiki's Co",
    );

    final sport = tester.widget<Text>(find.text('Sport'));
    final luxe = tester.widget<Text>(find.text("Kiki's Co"));

    expect(sport.style?.fontWeight, FontWeight.w700);
    expect(luxe.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('themeSwitcher displays the navbar brand title for Dior', (
    tester,
  ) async {
    final store = _MemoryVisitorStorefrontThemeStore();
    await _pumpThemeSwitcher(tester, store: store, brandTitle: "Kiki's Co");

    expect(find.text("Kiki's Co"), findsOneWidget);
    expect(find.text('Luxe'), findsNothing);
  });

  testWidgets('themeSwitcher expands to the navbar brand title on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final store = _MemoryVisitorStorefrontThemeStore(rawValue: 'nike');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitorStorefrontThemeStoreProvider.overrideWithValue(store),
          activeStorefrontThemeProvider.overrideWith(
            (ref) async =>
                const StorefrontActiveTheme(theme: StorefrontTheme.nike),
          ),
          storefrontBrandSettingsProvider.overrideWith(
            (ref) async => const StorefrontBrandSettings(
              id: 'settings-id',
              title: "Kiki's Co",
              href: '/',
            ),
          ),
          storefrontNavigationSettingsProvider.overrideWith(
            (ref) async => StorefrontNavigationSettings.fallback,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const TopNavigationBar(),
                BrandSegmentSection(config: _themeSwitcherConfig()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navbarSwitcher = find.descendant(
      of: find.byType(TopNavigationBar),
      matching: find.byType(StorefrontThemeSwitcher),
    );
    final cmsSwitcher = find.descendant(
      of: find.byType(BrandSegmentSection),
      matching: find.byType(StorefrontThemeSwitcher),
    );
    expect(navbarSwitcher, findsOneWidget);
    expect(cmsSwitcher, findsOneWidget);
    final cmsRect = tester.getRect(cmsSwitcher);

    expect(find.text("Kiki's Co"), findsWidgets);
    expect(
      cmsRect.width,
      greaterThanOrEqualTo(storefrontThemeSwitcherCompactNavWidth),
    );
  });

  testWidgets('links mode keeps href navigation', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: BrandSegmentSection(
              config: BrandSegmentConfig(
                items: const [
                  BrandSegmentItem(label: 'Sport', href: '/target'),
                  BrandSegmentItem(label: 'Luxe', href: '/catalog'),
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

    await tester.tap(find.text('Sport'));
    await tester.pumpAndSettle();

    expect(find.text('Target route'), findsOneWidget);
  });
}

Future<void> _pumpThemeSwitcher(
  WidgetTester tester, {
  required _MemoryVisitorStorefrontThemeStore store,
  int activeIndex = 0,
  String? brandTitle,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        visitorStorefrontThemeStoreProvider.overrideWithValue(store),
        activeStorefrontThemeProvider.overrideWith(
          (ref) async =>
              const StorefrontActiveTheme(theme: StorefrontTheme.dior),
        ),
        storefrontBrandSettingsProvider.overrideWith(
          (ref) async => StorefrontBrandSettings(
            title: brandTitle ?? StorefrontBrandSettings.fallback.title,
            href: StorefrontBrandSettings.fallback.href,
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: BrandSegmentSection(
            config: _themeSwitcherConfig(activeIndex: activeIndex),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BrandSegmentConfig _themeSwitcherConfig({int activeIndex = 0}) {
  return BrandSegmentConfig(
    mode: BrandSegmentMode.themeSwitcher,
    activeIndex: activeIndex,
    items: const [
      BrandSegmentItem(
        label: 'Sport',
        href: '/ignored',
        theme: StorefrontTheme.nike,
      ),
      BrandSegmentItem(
        label: 'Luxe',
        href: '/ignored',
        theme: StorefrontTheme.dior,
      ),
    ],
  );
}

class _MemoryVisitorStorefrontThemeStore
    implements VisitorStorefrontThemeStore {
  String? rawValue;

  _MemoryVisitorStorefrontThemeStore({this.rawValue});

  @override
  Future<StorefrontTheme?> readOverride() async {
    return StorefrontTheme.tryFromWireName(rawValue);
  }

  @override
  Future<void> writeOverride(StorefrontTheme theme) async {
    rawValue = theme.wireName;
  }

  @override
  Future<void> clearOverride() async {
    rawValue = null;
  }
}
