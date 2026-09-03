import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kiki_commerce/application/cart/cart_read_models.dart';
import 'package:kiki_commerce/application/storefront/storefront_sport_segment.dart';
import 'package:kiki_commerce/application/storefront/storefront_theme.dart';
import 'package:kiki_commerce/data/local/last_sport_segment_store.dart';
import 'package:kiki_commerce/domain/cart/cart_entities.dart';
import 'package:kiki_commerce/presentation/providers/cart_provider.dart';
import 'package:kiki_commerce/presentation/providers/sport_segment_providers.dart';
import 'package:kiki_commerce/presentation/providers/storefront_theme_providers.dart';
import 'package:kiki_commerce/presentation/screens/mobile_cart_page.dart';

import '../../support/l10n_harness.dart';

class _EmptyCartController extends CartController {
  @override
  Future<CartView?> build() async => const CartView(
    cart: Cart(id: 'c1', currencyCode: 'EUR'),
    entries: [],
  );
}

class _FakeSegmentStore implements LastSportSegmentStore {
  final StorefrontSportSegment? value;
  const _FakeSegmentStore(this.value);

  @override
  Future<StorefrontSportSegment?> read() async => value;

  @override
  Future<void> write(StorefrontSportSegment segment) async {}
}

void main() {
  testWidgets(
    'empty Sport cart "Acheter" routes to the last visited sport segment',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/cart',
        routes: [
          GoRoute(path: '/cart', builder: (_, _) => const MobileCartPage()),
          GoRoute(
            path: '/fr/sport/:segment',
            builder: (_, state) => Scaffold(
              body: Text('segment:${state.pathParameters['segment']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveStorefrontThemeAsyncProvider.overrideWithValue(
              const AsyncData(StorefrontTheme.nike),
            ),
            cartControllerProvider.overrideWith(_EmptyCartController.new),
            lastSportSegmentStoreProvider.overrideWithValue(
              const _FakeSegmentStore(StorefrontSportSegment.femme),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            locale: const Locale('fr'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ton panier est vide.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Acheter'));
      await tester.pumpAndSettle();

      expect(find.text('segment:femme'), findsOneWidget);
    },
  );
}
