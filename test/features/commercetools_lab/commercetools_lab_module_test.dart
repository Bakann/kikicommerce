import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/features/commercetools_lab/commercetools_lab_module.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('CommercetoolsLabModule.routes', () {
    test('exposes a builder-based PLP and a pageBuilder-based PDP route', () {
      final routes = CommercetoolsLabModule.routes()
          .whereType<GoRoute>()
          .toList();
      final byPath = {for (final r in routes) r.path: r};

      final plp = byPath['/lab/commercetools-products'];
      expect(plp, isNotNull);
      expect(plp!.builder, isNotNull);

      // The detail route is keyed on a generic route key (slug/key/id), not a
      // strict slug, and uses the shared PDP page transition (pageBuilder).
      final pdp = byPath['/lab/commercetools-products/:routeKey'];
      expect(pdp, isNotNull);
      expect(pdp!.pageBuilder, isNotNull);
    });
  });
}
