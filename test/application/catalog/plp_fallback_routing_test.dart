import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/catalog/plp_fallback_routing.dart';

void main() {
  group('PlpFallbackRouting.urlOnlyFallbackParentLocation', () {
    test('fallback removes the last path segment', () {
      expect(
        PlpFallbackRouting.urlOnlyFallbackParentLocation(
          Uri.parse('/sport/homme/boots'),
        ),
        '/sport/homme',
      );
      expect(
        PlpFallbackRouting.urlOnlyFallbackParentLocation(
          Uri.parse('/sport/homme/boots/running'),
        ),
        '/sport/homme/boots',
      );
    });

    test('fallback returns null for root and single-segment routes', () {
      expect(
        PlpFallbackRouting.urlOnlyFallbackParentLocation(Uri.parse('/')),
        isNull,
      );
      expect(
        PlpFallbackRouting.urlOnlyFallbackParentLocation(Uri.parse('/sport')),
        isNull,
      );
      expect(
        PlpFallbackRouting.urlOnlyFallbackParentLocation(Uri.parse('/catalog')),
        isNull,
      );
    });

    test('fallback preserves only default portable query params', () {
      final location = PlpFallbackRouting.urlOnlyFallbackParentLocation(
        Uri.parse('/sport/homme/boots?sort=price&view=grid&size=42&surface=fg'),
      );

      expect(location, isNotNull);
      final uri = Uri.parse(location!);
      expect(uri.path, '/sport/homme');
      expect(uri.queryParameters, {'sort': 'price', 'view': 'grid'});
    });

    test('fallback drops unknown query params when defaults do not match', () {
      expect(
        PlpFallbackRouting.urlOnlyFallbackParentLocation(
          Uri.parse('/catalog/summer/shirts?size=42&surface=fg'),
        ),
        '/catalog/summer',
      );
    });

    test('fallback can use route-specific preserved query params', () {
      final location = PlpFallbackRouting.urlOnlyFallbackParentLocation(
        Uri.parse('/catalog/summer/shirts?source=drawer&view=grid&sort=price'),
        preservedQueryKeys: const {'source', 'view'},
      );

      expect(location, isNotNull);
      final uri = Uri.parse(location!);
      expect(uri.path, '/catalog/summer');
      expect(uri.queryParameters, {'source': 'drawer', 'view': 'grid'});
    });

    test('fallback can preserve no query params', () {
      expect(
        PlpFallbackRouting.urlOnlyFallbackParentLocation(
          Uri.parse('/catalog/summer/shirts?q=linen&sort=price'),
          preservedQueryKeys: const {},
        ),
        '/catalog/summer',
      );
    });

    test('fallback preserves repeated portable query params', () {
      final location = PlpFallbackRouting.urlOnlyFallbackParentLocation(
        Uri.parse('/sport/homme/boots?sort=price&sort=newest&size=42'),
      );

      expect(location, isNotNull);
      final uri = Uri.parse(location!);
      expect(uri.path, '/sport/homme');
      expect(uri.queryParametersAll, {
        'sort': ['price', 'newest'],
      });
    });

    test('fallback drops fragments', () {
      expect(
        PlpFallbackRouting.urlOnlyFallbackParentLocation(
          Uri.parse('/sport/homme/boots?sort=price#reviews'),
        ),
        '/sport/homme?sort=price',
      );
    });

    test('fallback keeps encoded parent slugs', () {
      expect(
        PlpFallbackRouting.urlOnlyFallbackParentLocation(
          Uri.parse('/sport/homme/caf%C3%A9/running'),
        ),
        '/sport/homme/caf%C3%A9',
      );
    });
  });
}
