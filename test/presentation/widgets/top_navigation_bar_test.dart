import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/application/admin/admin_backoffice_repository.dart';
import 'package:kiki_commerce/application/admin/catalog_export_result.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_repository.dart';
import 'package:kiki_commerce/application/storefront/storefront_brand_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_navigation_settings.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/data/local/visitor_storefront_theme_store.dart';
import 'package:kiki_commerce/presentation/providers/edit_mode_provider.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_brand_editor_dialog.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_navigation_editor_dialog.dart';
import 'package:kiki_commerce/presentation/widgets/navigation/top_navigation_bar.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_theme_switcher.dart';

import '../../support/l10n_harness.dart';

void main() {
  testWidgets('navbar shows fallback brand while settings load', (
    tester,
  ) async {
    final pendingBrand = Completer<StorefrontBrandSettings>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storefrontBrandSettingsProvider.overrideWith(
            (ref) => pendingBrand.future,
          ),
          storefrontNavigationSettingsProvider.overrideWith(
            (ref) async => StorefrontNavigationSettings.fallback,
          ),
        ],
        child: const _LocalizedMaterialApp(
          home: Scaffold(body: TopNavigationBar()),
        ),
      ),
    );

    await tester.pump();

    expect(find.text(defaultStorefrontBrandTitle), findsOneWidget);

    pendingBrand.complete(
      const StorefrontBrandSettings(
        id: 'settings-id',
        title: 'Atelier Kiki',
        href: '/',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Atelier Kiki'), findsOneWidget);
  });

  testWidgets('navbar renders configured brand title', (tester) async {
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
          storefrontNavigationSettingsProvider.overrideWith(
            (ref) async => StorefrontNavigationSettings.fallback,
          ),
        ],
        child: const _LocalizedMaterialApp(
          home: Scaffold(body: TopNavigationBar()),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Atelier Kiki'), findsOneWidget);
    expect(find.text(defaultStorefrontBrandTitle), findsNothing);
  });

  testWidgets(
    'hideTrailingDestinations removes wishlist / account / cart icons',
    (tester) async {
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
            storefrontNavigationSettingsProvider.overrideWith(
              (ref) async => StorefrontNavigationSettings.fallback,
            ),
          ],
          child: const _LocalizedMaterialApp(
            home: Scaffold(
              body: TopNavigationBar(hideTrailingDestinations: true),
            ),
          ),
        ),
      );

      await tester.pump();

      // Brand title still rendered.
      expect(find.text('Atelier Kiki'), findsOneWidget);
      // Trailing destinations hidden — the Nike landing surfaces these
      // through the floating bottom nav instead.
      expect(find.byTooltip('Favoris'), findsNothing);
      expect(find.byTooltip('Compte'), findsNothing);
      expect(find.byTooltip('Panier'), findsNothing);
    },
  );

  testWidgets('default chrome still shows wishlist / account / cart icons', (
    tester,
  ) async {
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
          storefrontNavigationSettingsProvider.overrideWith(
            (ref) async => StorefrontNavigationSettings.fallback,
          ),
        ],
        child: const _LocalizedMaterialApp(
          home: Scaffold(body: TopNavigationBar()),
        ),
      ),
    );

    await tester.pump();

    expect(find.byTooltip('Favoris'), findsOneWidget);
    expect(find.byTooltip('Compte'), findsOneWidget);
    expect(find.byTooltip('Panier'), findsOneWidget);
  });

  testWidgets('theme switcher in top nav can select Sport from Luxe', (
    tester,
  ) async {
    final store = _MemoryVisitorStorefrontThemeStore(rawValue: 'dior');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visitorStorefrontThemeStoreProvider.overrideWithValue(store),
          activeStorefrontThemeProvider.overrideWith(
            (ref) async =>
                const StorefrontActiveTheme(theme: StorefrontTheme.dior),
          ),
          storefrontBrandSettingsProvider.overrideWith(
            (ref) async => const StorefrontBrandSettings(
              id: 'settings-id',
              title: 'Atelier Kiki',
              href: '/',
            ),
          ),
          storefrontNavigationSettingsProvider.overrideWith(
            (ref) async => StorefrontNavigationSettings.fallback,
          ),
        ],
        child: const _LocalizedMaterialApp(
          home: Scaffold(body: TopNavigationBar()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Sport'));
    await tester.pumpAndSettle();

    expect(store.rawValue, 'nike');
  });

  testWidgets(
    'mobile luxe keeps the logo and leading theme switcher by default',
    (tester) async {
      await _setViewport(tester, const Size(430, 700));
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
            storefrontNavigationSettingsProvider.overrideWith(
              (ref) async => StorefrontNavigationSettings.fallback,
            ),
          ],
          child: const _LocalizedMaterialApp(
            home: Scaffold(body: TopNavigationBar()),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Atelier Kiki'), findsOneWidget);
      expect(find.byType(StorefrontThemeSwitcher), findsOneWidget);
      expect(
        tester.getSize(find.byType(StorefrontThemeSwitcher)).width,
        storefrontThemeSwitcherCompactNavWidth,
      );
      expect(
        tester.getCenter(find.byType(StorefrontThemeSwitcher)).dx,
        lessThan(tester.view.physicalSize.width / 2),
      );
    },
  );

  testWidgets(
    'mobile luxe can replace the centered logo with a centered theme switcher',
    (tester) async {
      await _setViewport(tester, const Size(430, 700));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storefrontBrandSettingsProvider.overrideWith(
              (ref) async => const StorefrontBrandSettings(
                id: 'settings-id',
                title: 'Atelier Kiki',
                href: '/',
                replaceMobileLogoWithThemeSwitcher: true,
              ),
            ),
            storefrontNavigationSettingsProvider.overrideWith(
              (ref) async => StorefrontNavigationSettings.fallback,
            ),
          ],
          child: const _LocalizedMaterialApp(
            home: Scaffold(body: TopNavigationBar()),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Atelier Kiki'), findsOneWidget);
      expect(find.text('Luxe'), findsNothing);
      expect(find.byType(StorefrontThemeSwitcher), findsOneWidget);
      expect(
        tester.getSize(find.byType(StorefrontThemeSwitcher)).width,
        greaterThanOrEqualTo(storefrontThemeSwitcherLogoSlotWidth),
      );
      expect(
        tester.getCenter(find.byType(StorefrontThemeSwitcher)).dx,
        moreOrLessEquals(tester.view.physicalSize.width / 2, epsilon: 0.5),
      );
    },
  );

  testWidgets(
    'mobile luxe replacement keeps storefront settings accessible in edit mode',
    (tester) async {
      await _setViewport(tester, const Size(430, 700));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editModeProvider.overrideWith((ref) => true),
            storefrontBrandSettingsProvider.overrideWith(
              (ref) async => const StorefrontBrandSettings(
                id: 'settings-id',
                title: 'Atelier Kiki',
                href: '/',
                replaceMobileLogoWithThemeSwitcher: true,
              ),
            ),
            storefrontNavigationSettingsProvider.overrideWith(
              (ref) async => StorefrontNavigationSettings.fallback,
            ),
          ],
          child: const _LocalizedMaterialApp(
            home: Scaffold(body: TopNavigationBar()),
          ),
        ),
      );

      await tester.pump();
      expect(find.byTooltip('Réglages storefront'), findsOneWidget);

      await tester.tap(find.byTooltip('Réglages storefront'));
      await tester.pumpAndSettle();

      expect(find.text('Identité de la boutique'), findsOneWidget);
      expect(find.text('Navigation mobile'), findsOneWidget);
      expect(
        tester.getCenter(find.byType(StorefrontThemeSwitcher)).dx,
        moreOrLessEquals(tester.view.physicalSize.width / 2, epsilon: 0.5),
      );
    },
  );

  testWidgets(
    'tablet luxe keeps the centered logo when mobile replacement is enabled',
    (tester) async {
      await _setViewport(tester, const Size(900, 700));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storefrontBrandSettingsProvider.overrideWith(
              (ref) async => const StorefrontBrandSettings(
                id: 'settings-id',
                title: 'Atelier Kiki',
                href: '/',
                replaceMobileLogoWithThemeSwitcher: true,
              ),
            ),
            storefrontNavigationSettingsProvider.overrideWith(
              (ref) async => StorefrontNavigationSettings.fallback,
            ),
          ],
          child: const _LocalizedMaterialApp(
            home: Scaffold(body: TopNavigationBar()),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Atelier Kiki'), findsOneWidget);
      expect(find.byType(StorefrontThemeSwitcher), findsOneWidget);
    },
  );

  testWidgets('brand logo triple tap invokes hidden edit callback', (
    tester,
  ) async {
    var callbackCount = 0;

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
          storefrontNavigationSettingsProvider.overrideWith(
            (ref) async => StorefrontNavigationSettings.fallback,
          ),
        ],
        child: _LocalizedMaterialApp(
          home: Scaffold(
            body: TopNavigationBar(
              onBrandTripleTap: () {
                callbackCount += 1;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Atelier Kiki'));
    await tester.tap(find.text('Atelier Kiki'));
    await tester.tap(find.text('Atelier Kiki'));
    await tester.pump();

    expect(callbackCount, 1);
  });

  testWidgets(
    'edit mode opens brand editor and saves through settings record',
    (tester) async {
      final repository = _RecordingAdminBackofficeRepository();
      var navigationProviderReads = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editModeProvider.overrideWith((ref) => true),
            adminAuthTokenProvider.overrideWith((ref) => 'test-token'),
            adminBackofficeRepositoryProvider.overrideWithValue(repository),
            storefrontBrandSettingsProvider.overrideWith(
              (ref) async => const StorefrontBrandSettings(
                id: 'settings-id',
                title: 'Atelier Kiki',
                href: '/',
              ),
            ),
            storefrontNavigationSettingsProvider.overrideWith((ref) async {
              navigationProviderReads += 1;
              return const StorefrontNavigationSettings(
                id: 'navigation-id',
                mobileMenuStyle: MobileMenuStyle.drawer,
              );
            }),
          ],
          child: const _LocalizedMaterialApp(
            home: Scaffold(body: TopNavigationBar()),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byTooltip('Réglages storefront'));
      await tester.pumpAndSettle();

      expect(find.text('Identité de la boutique'), findsOneWidget);
      expect(find.text('Navigation mobile'), findsOneWidget);

      await tester.tap(_popupItemWithText('Identité de la boutique'));
      await tester.pumpAndSettle();

      expect(find.text('Identité de la boutique'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nom affiché dans la navbar'),
        'Kiki Studio',
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(repository.updatedRecordId, 'settings-id');
      expect(repository.updatedData, {
        'key': storefrontBrandSettingsKey,
        'brandTitle': 'Kiki Studio',
        'brandHref': '/',
        'replaceMobileLogoWithThemeSwitcher': false,
      });
      expect(navigationProviderReads, 1);
    },
  );

  testWidgets('brand editor saves the mobile logo replacement setting', (
    tester,
  ) async {
    final repository = _RecordingAdminBackofficeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuthTokenProvider.overrideWith((ref) => 'test-token'),
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
        ],
        child: const _LocalizedMaterialApp(
          home: Scaffold(
            body: StorefrontBrandEditorDialog(
              initialSettings: StorefrontBrandSettings(
                id: 'settings-id',
                title: 'Atelier Kiki',
                href: '/',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(
      find.text('Remplacer le logo par le switch Sport/Luxe sur mobile'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(repository.updatedRecordId, 'settings-id');
    expect(repository.updatedData, {
      'key': storefrontBrandSettingsKey,
      'brandTitle': 'Atelier Kiki',
      'brandHref': '/',
      'replaceMobileLogoWithThemeSwitcher': true,
    });
  });

  testWidgets('navigation settings dialog saves fullscreenReveal payload', (
    tester,
  ) async {
    final repository = _RecordingAdminBackofficeRepository();
    var navigationProviderReads = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          editModeProvider.overrideWith((ref) => true),
          adminAuthTokenProvider.overrideWith((ref) => 'test-token'),
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
          storefrontNavigationSettingsProvider.overrideWith((ref) async {
            navigationProviderReads += 1;
            return const StorefrontNavigationSettings(
              id: 'navigation-id',
              mobileMenuStyle: MobileMenuStyle.drawer,
            );
          }),
        ],
        child: _LocalizedMaterialApp(
          home: Scaffold(
            body: Stack(
              children: const [
                StorefrontNavigationEditorDialog(
                  initialSettings: StorefrontNavigationSettings(
                    id: 'navigation-id',
                    mobileMenuStyle: MobileMenuStyle.drawer,
                  ),
                ),
                _NavigationSettingsWatcher(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Drawer classique'), findsOneWidget);
    expect(find.text('Plein écran premium'), findsOneWidget);

    await tester.tap(find.text('Plein écran premium'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(repository.updatedRecordId, 'navigation-id');
    expect(repository.updatedData, {
      'key': storefrontNavigationSettingsKey,
      'mobileMenuStyle': 'fullscreenReveal',
      'categorySplitDisplayMode': 'tabs',
    });
    expect(navigationProviderReads, 2);
  });

  testWidgets('navigation settings dialog saves category split display mode', (
    tester,
  ) async {
    final repository = _RecordingAdminBackofficeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuthTokenProvider.overrideWith((ref) => 'test-token'),
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
        ],
        child: const _LocalizedMaterialApp(
          home: Scaffold(
            body: StorefrontNavigationEditorDialog(
              initialSettings: StorefrontNavigationSettings(
                id: 'navigation-id',
                mobileMenuStyle: MobileMenuStyle.drawer,
                categorySplitDisplayMode: CategorySplitDisplayMode.tabs,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.ensureVisible(find.text('Expansible'));
    await tester.tap(find.text('Expansible'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(repository.updatedRecordId, 'navigation-id');
    expect(repository.updatedData, {
      'key': storefrontNavigationSettingsKey,
      'mobileMenuStyle': 'drawer',
      'categorySplitDisplayMode': 'expansible',
    });
  });

  testWidgets('edit mode menu opens navigation settings dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          editModeProvider.overrideWith((ref) => true),
          storefrontBrandSettingsProvider.overrideWith(
            (ref) async => const StorefrontBrandSettings(
              id: 'settings-id',
              title: 'Atelier Kiki',
              href: '/',
            ),
          ),
          storefrontNavigationSettingsProvider.overrideWith(
            (ref) async => const StorefrontNavigationSettings(
              id: 'navigation-id',
              mobileMenuStyle: MobileMenuStyle.drawer,
            ),
          ),
        ],
        child: const _LocalizedMaterialApp(
          home: Scaffold(body: TopNavigationBar()),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('Réglages storefront'));
    await tester.pumpAndSettle();
    await tester.tap(_popupItemWithText('Navigation mobile'));
    await tester.pumpAndSettle();

    expect(find.text('Navigation mobile'), findsOneWidget);
    expect(find.text('Drawer classique'), findsOneWidget);
    expect(find.text('Plein écran premium'), findsOneWidget);
  });

  testWidgets(
    'navigation settings dialog uses existing record when id absent',
    (tester) async {
      final repository = _RecordingAdminBackofficeRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthTokenProvider.overrideWith((ref) => 'test-token'),
            adminBackofficeRepositoryProvider.overrideWithValue(repository),
          ],
          child: const _LocalizedMaterialApp(
            home: Scaffold(
              body: StorefrontNavigationEditorDialog(
                initialSettings: StorefrontNavigationSettings(
                  mobileMenuStyle: MobileMenuStyle.drawer,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Drawer classique'), findsOneWidget);
      expect(find.text('Plein écran premium'), findsOneWidget);

      await tester.tap(find.text('Plein écran premium'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(repository.updatedRecordId, 'navigation-id');
      expect(repository.createdData, isNull);
    },
  );

  testWidgets('navigation settings dialog cancel does not save', (
    tester,
  ) async {
    final repository = _RecordingAdminBackofficeRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuthTokenProvider.overrideWith((ref) => 'test-token'),
          adminBackofficeRepositoryProvider.overrideWithValue(repository),
        ],
        child: const _LocalizedMaterialApp(
          home: Scaffold(
            body: StorefrontNavigationEditorDialog(
              initialSettings: StorefrontNavigationSettings(
                id: 'navigation-id',
                mobileMenuStyle: MobileMenuStyle.drawer,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Plein écran premium'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Annuler'));
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(repository.updatedData, isNull);
    expect(repository.createdData, isNull);
  });

  testWidgets('menu delegates tap immediately to parent', (tester) async {
    var openCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storefrontNavigationSettingsProvider.overrideWith(
            (ref) async => StorefrontNavigationSettings.fallback,
          ),
          drawerNavigationRepositoryProvider.overrideWithValue(
            const _TopNavDrawerNavigationRepository(),
          ),
        ],
        child: _LocalizedMaterialApp(
          home: Scaffold(body: TopNavigationBar(onMenuTap: (_) => openCount++)),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('Ouvrir le menu'));
    expect(openCount, 1);

    await tester.pumpAndSettle();
  });

  testWidgets('cart tap navigates to cart with fallback routing', (
    tester,
  ) async {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: TopNavigationBar()),
        ),
        GoRoute(
          path: CatalogRoutes.cart,
          builder: (context, state) => const Scaffold(body: Text('Cart')),
        ),
      ],
    );
    addTearDown(router.dispose);

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
          storefrontNavigationSettingsProvider.overrideWith(
            (ref) async => StorefrontNavigationSettings.fallback,
          ),
        ],
        child: _localizedRouterApp(router),
      ),
    );

    await tester.pump();
    await tester.tap(find.byTooltip('Panier'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/cart');
    expect(find.text('Cart'), findsOneWidget);
  });

  testWidgets(
    'destination callback still intercepts cart fallback navigation',
    (tester) async {
      var selectedIndex = -1;

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
            storefrontNavigationSettingsProvider.overrideWith(
              (ref) async => StorefrontNavigationSettings.fallback,
            ),
          ],
          child: _LocalizedMaterialApp(
            home: Scaffold(
              body: TopNavigationBar(
                onDestinationSelected: (index) {
                  selectedIndex = index;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byTooltip('Panier'));

      expect(selectedIndex, TopNavDestination.cart.index);
    },
  );
}

class _LocalizedMaterialApp extends StatelessWidget {
  final Widget home;

  const _LocalizedMaterialApp({required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      locale: const Locale('fr'),
      home: home,
    );
  }
}

Widget _localizedRouterApp(GoRouter router) {
  return MaterialApp.router(
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: testSupportedLocales,
    locale: const Locale('fr'),
    routerConfig: router,
  );
}

Finder _popupItemWithText(String text) {
  return find.byWidgetPredicate((widget) {
    return widget is PopupMenuItem &&
        widget.child is Text &&
        (widget.child as Text).data == text;
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _NavigationSettingsWatcher extends ConsumerWidget {
  const _NavigationSettingsWatcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(storefrontNavigationSettingsProvider);
    return const SizedBox.shrink();
  }
}

class _TopNavDrawerNavigationRepository implements DrawerNavigationRepository {
  const _TopNavDrawerNavigationRepository();

  @override
  Future<DrawerNavigationLoadResult> fetchMainDrawer({
    required String locale,
    bool includeHidden = false,
  }) async => const DrawerNavigationLoadResult.fallback(
    fallbackReason: DrawerNavigationFallbackReason.menuMissing,
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

class _RecordingAdminBackofficeRepository implements AdminBackofficeRepository {
  String? updatedRecordId;
  Map<String, dynamic>? updatedData;
  Map<String, dynamic>? createdData;

  @override
  Future<Map<String, dynamic>> updateRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
    required Map<String, dynamic> data,
  }) async {
    updatedRecordId = recordId;
    updatedData = Map<String, dynamic>.from(data);
    return {'id': recordId, ...data};
  }

  @override
  Future<String> authenticateSuperuser({
    required String baseUrl,
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> createRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required Map<String, dynamic> data,
  }) {
    createdData = Map<String, dynamic>.from(data);
    return Future.value({'id': 'created-id', ...data});
  }

  @override
  Future<void> deleteRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    required String recordId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CatalogExportResult> exportCatalogCsv({
    required String baseUrl,
    required String authToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CatalogImportReport> importCatalogCsv({
    required String baseUrl,
    required String authToken,
    required String csvContent,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> listRecords({
    required String baseUrl,
    required String authToken,
    required String collection,
    String sort = '-created',
    int perPage = 500,
    int page = 1,
    String? filter,
  }) {
    return Future.value([
      if (filter == 'key = "$storefrontNavigationSettingsKey"')
        {'id': 'navigation-id'},
    ]);
  }

  @override
  Future<Map<String, dynamic>> uploadMediaFromBytes({
    required String baseUrl,
    required String authToken,
    required Uint8List fileBytes,
    required String filename,
    String? mimeType,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> upsertMediaRecord({
    required String baseUrl,
    required String authToken,
    required String collection,
    String? recordId,
    required Map<String, dynamic> data,
    String? mediaSource,
    required String fallbackFilename,
    String? mimeType,
  }) {
    throw UnimplementedError();
  }
}
