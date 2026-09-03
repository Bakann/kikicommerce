import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/application/storefront/storefront_sport_segment.dart';

void main() {
  group('CatalogRoutes.isCategoryPlpLocation', () {
    test('matches the catalog base and its sub-paths', () {
      expect(CatalogRoutes.isCategoryPlpLocation('/catalog'), isTrue);
      expect(CatalogRoutes.isCategoryPlpLocation('/catalog/shirts'), isTrue);
      expect(
        CatalogRoutes.isCategoryPlpLocation(
          '/catalog/homme-chaussures-toutes-les-chaussures',
        ),
        isTrue,
      );
      // Query forms (categoryById) still resolve to the /catalog path.
      expect(
        CatalogRoutes.isCategoryPlpLocation('/catalog?categoryId=abc'),
        isTrue,
      );
    });

    test('does not match technical or non-catalog destinations', () {
      expect(CatalogRoutes.isCategoryPlpLocation('/'), isFalse);
      expect(CatalogRoutes.isCategoryPlpLocation('/search'), isFalse);
      expect(CatalogRoutes.isCategoryPlpLocation('/sport/homme'), isFalse);
      expect(
        CatalogRoutes.isCategoryPlpLocation('/product?productId=x'),
        isFalse,
      );
      // A path that merely starts with the same letters is not the namespace.
      expect(CatalogRoutes.isCategoryPlpLocation('/catalogue'), isFalse);
    });

    test('matches sport-flow category PLP routes', () {
      expect(
        CatalogRoutes.isCategoryPlpLocation('/sport/femme/les-fleurs'),
        isTrue,
      );
      expect(
        CatalogRoutes.isCategoryPlpLocation('/en/sport/femme/les-fleurs'),
        isTrue,
      );
      expect(
        CatalogRoutes.isCategoryPlpLocation(
          '/sport/homme/summer-essentials?ref=hero',
        ),
        isTrue,
      );
    });

    test('does not match invalid sport category routes', () {
      expect(CatalogRoutes.isCategoryPlpLocation('/sport/foo/shoes'), isFalse);
      expect(
        CatalogRoutes.isCategoryPlpLocation('/sport/femme/shoes/product'),
        isFalse,
      );
    });
  });

  group('CatalogRoutes.pageKeyLocation', () {
    test('maps the commercetools lab page keys to the lab route', () {
      expect(
        CatalogRoutes.pageKeyLocation('lab_commercetools_products'),
        CatalogRoutes.labCommercetoolsProducts,
      );
      expect(
        CatalogRoutes.pageKeyLocation('commercetools_lab'),
        CatalogRoutes.labCommercetoolsProducts,
      );
      expect(
        CatalogRoutes.labCommercetoolsProducts,
        '/lab/commercetools-products',
      );
    });

    test('is case-insensitive for the lab key', () {
      expect(
        CatalogRoutes.pageKeyLocation('LAB_COMMERCETOOLS_PRODUCTS'),
        CatalogRoutes.labCommercetoolsProducts,
      );
    });

    test('keeps the existing special keys intact', () {
      expect(CatalogRoutes.pageKeyLocation(''), CatalogRoutes.home);
      expect(CatalogRoutes.pageKeyLocation('home'), CatalogRoutes.home);
      expect(CatalogRoutes.pageKeyLocation('search'), CatalogRoutes.search);
      expect(CatalogRoutes.pageKeyLocation('admin'), CatalogRoutes.admin);
    });

    test('still routes unknown keys to a /catalog slug', () {
      expect(CatalogRoutes.pageKeyLocation('gifts'), '/catalog/gifts');
      expect(
        CatalogRoutes.pageKeyLocation('mode_homme'),
        '/catalog/mode-homme',
      );
    });
  });

  group('CatalogRoutes.labCommercetoolsProductByRouteKey', () {
    test('builds the lab detail route under the lab base', () {
      expect(
        CatalogRoutes.labCommercetoolsProductByRouteKey('bruno-chair'),
        '/lab/commercetools-products/bruno-chair',
      );
    });

    test('encodes route keys with unsafe characters', () {
      expect(
        CatalogRoutes.labCommercetoolsProductByRouteKey('a b/c'),
        '/lab/commercetools-products/a%20b%2Fc',
      );
    });
  });

  group('CatalogRoutes.sportSegmentLocation', () {
    test('builds canonical Sport segment routes', () {
      expect(
        CatalogRoutes.sportSegmentLocation(StorefrontSportSegment.homme),
        '/sport/homme',
      );
      expect(
        CatalogRoutes.sportSegmentLocation(StorefrontSportSegment.femme),
        '/sport/femme',
      );
      expect(
        CatalogRoutes.sportSegmentLocation(StorefrontSportSegment.enfant),
        '/sport/enfant',
      );
    });

    test('builds canonical Sport product routes', () {
      expect(
        CatalogRoutes.sportProductLocation(
          segment: StorefrontSportSegment.femme,
          categorySlug: 'les fleurs',
          productSlug: 'air/max',
        ),
        '/sport/femme/les%20fleurs/air%2Fmax',
      );
    });
  });

  group('StorefrontSportSegment', () {
    test('parses known segment wire names case-insensitively', () {
      expect(
        StorefrontSportSegment.tryParse(' Femme '),
        StorefrontSportSegment.femme,
      );
      expect(
        StorefrontSportSegment.parse('ENFANT'),
        StorefrontSportSegment.enfant,
      );
    });

    test('falls back to Homme for unknown values', () {
      expect(StorefrontSportSegment.tryParse('kids'), isNull);
      expect(
        StorefrontSportSegment.parse('kids'),
        StorefrontSportSegment.homme,
      );
    });

    test('homepage fallback chain points Femme/Enfant at Homme', () {
      expect(
        StorefrontSportSegment.femme.homepageFallback,
        StorefrontSportSegment.homme,
      );
      expect(
        StorefrontSportSegment.enfant.homepageFallback,
        StorefrontSportSegment.homme,
      );
      expect(StorefrontSportSegment.homme.homepageFallback, isNull);
    });
  });
}
