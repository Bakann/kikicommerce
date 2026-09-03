import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/category_tiles_section.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/discover_links_section.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/featured_products_section.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/seo_text_section.dart';
import 'package:kiki_commerce/presentation/widgets/cms/sections/service_cards_section.dart';

void main() {
  Future<void> pumpSection(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
  }

  testWidgets('category tiles copy renders when text reveal is disabled', (
    tester,
  ) async {
    await pumpSection(
      tester,
      const CategoryTilesSection(
        config: CategoryTilesConfig(
          title: 'Explorer',
          subtitle: 'Choisis une catégorie',
          tiles: [
            CategoryTileItem(label: 'Chaussures', href: '/catalog/shoes'),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Choisis une catégorie'), findsOneWidget);
    expect(find.text('Chaussures'), findsOneWidget);
  });

  testWidgets('featured products header and CTA render with reveal disabled', (
    tester,
  ) async {
    await pumpSection(
      tester,
      const FeaturedProductsSection(
        config: FeaturedProductsConfig(
          eyebrow: 'Sélection',
          title: 'Les nouveautés',
          subtitle: 'Les pièces du moment',
          primaryCta: CmsCta(label: 'Tout voir', href: '/catalog'),
          placeholderProducts: [
            FeaturedProductPlaceholder(title: 'Produit test', href: '/p/test'),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sélection'), findsOneWidget);
    expect(find.text('Les nouveautés'), findsOneWidget);
    expect(find.text('Les pièces du moment'), findsOneWidget);
    expect(find.text('Tout voir'), findsOneWidget);
    expect(find.text('Produit test'), findsOneWidget);
  });

  testWidgets('service cards copy renders when text reveal is disabled', (
    tester,
  ) async {
    await pumpSection(
      tester,
      const ServiceCardsSection(
        config: ServiceCardsConfig(
          title: 'Services',
          cards: [
            ServiceCardItem(
              title: 'Retrait boutique',
              body: 'Disponible sous deux heures.',
              href: '/services',
              ctaLabel: 'En savoir plus',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Retrait boutique'), findsOneWidget);
    expect(find.text('Disponible sous deux heures.'), findsOneWidget);
    expect(find.text('En savoir plus'), findsOneWidget);
  });

  testWidgets('SEO copy renders when text reveal is disabled', (tester) async {
    await pumpSection(
      tester,
      const SeoTextSection(
        config: SeoTextConfig(
          title: 'Guide de collection',
          body: 'Un texte SEO lisible et stable.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Guide de collection'), findsOneWidget);
    expect(find.text('Un texte SEO lisible et stable.'), findsOneWidget);
  });

  testWidgets('discover links copy renders when text reveal is disabled', (
    tester,
  ) async {
    await pumpSection(
      tester,
      const DiscoverLinksSection(
        config: DiscoverLinksConfig(
          title: 'Découvrir aussi',
          links: [DiscoverLinkItem(label: 'Running', href: '/catalog/running')],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Découvrir aussi'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
  });
}
