import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/cms/forms/category_tiles_form.dart';
import 'package:kiki_commerce/presentation/widgets/cms/forms/featured_products_form.dart';
import 'package:kiki_commerce/presentation/widgets/cms/forms/hero_campaign_form.dart';
import 'package:kiki_commerce/presentation/widgets/cms/forms/horizontal_tile_carousel_form.dart';
import 'package:kiki_commerce/presentation/widgets/cms/forms/service_cards_form.dart';

Future<void> _pumpForm(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(body: SizedBox(width: 1024, height: 760, child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('section forms', () {
    testWidgets('HeroCampaignForm emits a parseable edited config', (
      tester,
    ) async {
      final initial = {
        'title': 'Old hero',
        'mediaType': 'image',
        'textAlign': 'center',
        'heightMode': 'xl',
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        HeroCampaignForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Old hero'),
        'New hero',
      );
      await tester.pumpAndSettle();

      final parsed = HeroCampaignConfig.fromJson(latest);
      expect(parsed.title, 'New hero');
      expect(parsed.textAlign, 'center');
      expect(parsed.heightMode, 'xl');
    });

    testWidgets('CategoryTilesForm emits a parseable edited config', (
      tester,
    ) async {
      final initial = {
        'title': 'Categories',
        'columnsMobile': 2,
        'columnsDesktop': 4,
        'tiles': [
          {'label': 'Sacs', 'href': '/bags'},
        ],
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        CategoryTilesForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Categories'),
        'Collections',
      );
      await tester.pumpAndSettle();

      final parsed = CategoryTilesConfig.fromJson(latest);
      expect(parsed.title, 'Collections');
      expect(parsed.columnsDesktop, 4);
      expect(parsed.tiles.single.label, 'Sacs');
      expect(find.text('tiles JSON'), findsNothing);
      expect(find.text('Tile — Sacs'), findsOneWidget);
    });

    testWidgets('CategoryTilesForm adds a marketer-friendly tile', (
      tester,
    ) async {
      final initial = {
        'title': 'Categories',
        'columnsMobile': 2,
        'columnsDesktop': 4,
        'tiles': <Map<String, dynamic>>[],
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        CategoryTilesForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      expect(find.text('Aucune tuile'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Ajouter une tuile'));
      await tester.pumpAndSettle();

      expect(find.text('Tile — Nouvelle tuile'), findsOneWidget);
      final parsed = CategoryTilesConfig.fromJson(latest);
      expect(parsed.tiles, hasLength(1));
      expect(parsed.tiles.single.label, 'Nouvelle tuile');
      expect(parsed.tiles.single.href, '/catalog');
    });

    testWidgets('FeaturedProductsForm emits a parseable edited config', (
      tester,
    ) async {
      final initial = {
        'title': 'Selection',
        'productIds': ['p1', 'p2'],
        'layout': 'grid4',
        'showPrices': true,
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        FeaturedProductsForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      await tester.tap(find.text('Afficher les prix'));
      await tester.pumpAndSettle();

      final parsed = FeaturedProductsConfig.fromJson(latest);
      expect(parsed.productIds, ['p1', 'p2']);
      expect(parsed.layout, 'grid4');
      expect(parsed.showPrices, isFalse);
    });

    testWidgets('ServiceCardsForm emits a parseable edited config', (
      tester,
    ) async {
      final initial = {
        'title': 'Services',
        'cards': [
          {'title': 'Livraison', 'href': '/shipping'},
        ],
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        ServiceCardsForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Services'),
        'Aide & services',
      );
      await tester.pumpAndSettle();

      final parsed = ServiceCardsConfig.fromJson(latest);
      expect(parsed.title, 'Aide & services');
      expect(parsed.cards.single.title, 'Livraison');
    });

    testWidgets('HorizontalTileCarouselForm emits a parseable edited title', (
      tester,
    ) async {
      final initial = {
        'schemaVersion': 1,
        'title': 'En ce moment',
        'items': [
          {'label': 'Articles', 'href': '/catalog'},
        ],
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        HorizontalTileCarouselForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'En ce moment'),
        'Tendances',
      );
      await tester.pumpAndSettle();

      final parsed = HorizontalTileCarouselConfig.fromJson(latest);
      expect(parsed.title, 'Tendances');
      expect(parsed.items.single.label, 'Articles');
      // Existing tile is shown with its label in the card header.
      expect(find.text('Tuile — Articles'), findsOneWidget);
    });

    testWidgets('HorizontalTileCarouselForm switches the layout to feature', (
      tester,
    ) async {
      final initial = {
        'schemaVersion': 1,
        'title': 'En ce moment',
        'layout': 'tiles',
        'items': [
          {'label': 'Articles', 'href': '/catalog'},
        ],
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        HorizontalTileCarouselForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      expect(HorizontalTileCarouselConfig.fromJson(latest).layout, 'tiles');

      await tester.tap(find.text('Tuiles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grandes cartes').last);
      await tester.pumpAndSettle();

      final parsed = HorizontalTileCarouselConfig.fromJson(latest);
      expect(parsed.layout, 'feature');
      expect(parsed.items.single.label, 'Articles');
    });

    testWidgets('HorizontalTileCarouselForm adds a tile', (tester) async {
      final initial = {
        'schemaVersion': 1,
        'title': 'En ce moment',
        'items': <Map<String, dynamic>>[],
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        HorizontalTileCarouselForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      expect(find.text('Aucune tuile'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Ajouter une tuile'));
      await tester.pumpAndSettle();

      final parsed = HorizontalTileCarouselConfig.fromJson(latest);
      expect(parsed.items, hasLength(1));
      expect(parsed.items.single.label, 'Nouvelle tuile');
      expect(parsed.items.single.href, '/catalog');
    });

    testWidgets('HorizontalTileCarouselForm removes a tile', (tester) async {
      final initial = {
        'schemaVersion': 1,
        'title': 'En ce moment',
        'items': [
          {'label': 'A', 'href': '/a'},
          {'label': 'B', 'href': '/b'},
        ],
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        HorizontalTileCarouselForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      // Two cards, two delete buttons. Tap the first.
      final deleteButtons = find.byTooltip('Supprimer');
      expect(deleteButtons, findsNWidgets(2));
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      final parsed = HorizontalTileCarouselConfig.fromJson(latest);
      expect(parsed.items, hasLength(1));
      expect(parsed.items.single.label, 'B');
    });

    testWidgets('HorizontalTileCarouselForm duplicates a tile', (tester) async {
      final initial = {
        'schemaVersion': 1,
        'title': 'En ce moment',
        'items': [
          {'label': 'A', 'href': '/a'},
        ],
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        HorizontalTileCarouselForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      await tester.tap(find.byTooltip('Dupliquer').first);
      await tester.pumpAndSettle();

      final parsed = HorizontalTileCarouselConfig.fromJson(latest);
      expect(parsed.items, hasLength(2));
      expect(parsed.items.map((i) => i.label).toList(), ['A', 'A']);
      expect(parsed.items.map((i) => i.href).toList(), ['/a', '/a']);
    });

    testWidgets('HorizontalTileCarouselForm moves a tile down', (tester) async {
      final initial = {
        'schemaVersion': 1,
        'title': 'En ce moment',
        'items': [
          {'label': 'A', 'href': '/a'},
          {'label': 'B', 'href': '/b'},
          {'label': 'C', 'href': '/c'},
        ],
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        HorizontalTileCarouselForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      // First card's "Descendre" button.
      await tester.tap(find.byTooltip('Descendre').first);
      await tester.pumpAndSettle();

      final parsed = HorizontalTileCarouselConfig.fromJson(latest);
      expect(parsed.items.map((i) => i.label).toList(), ['B', 'A', 'C']);
    });

    testWidgets('HorizontalTileCarouselForm moves a tile up', (tester) async {
      final initial = {
        'schemaVersion': 1,
        'title': 'En ce moment',
        'items': [
          {'label': 'A', 'href': '/a'},
          {'label': 'B', 'href': '/b'},
          {'label': 'C', 'href': '/c'},
        ],
      };
      Map<String, dynamic> latest = Map<String, dynamic>.from(initial);

      await _pumpForm(
        tester,
        HorizontalTileCarouselForm(
          initialConfig: initial,
          onChanged: (next) => latest = next,
        ),
      );

      // The last card sits below the test viewport in the scrollable
      // form, so we have to scroll it into view before tapping.
      final lastMonter = find.byTooltip('Monter').last;
      await tester.ensureVisible(lastMonter);
      await tester.pumpAndSettle();
      await tester.tap(lastMonter);
      await tester.pumpAndSettle();

      final parsed = HorizontalTileCarouselConfig.fromJson(latest);
      expect(parsed.items.map((i) => i.label).toList(), ['A', 'C', 'B']);
    });
  });
}
