import 'package:go_router/go_router.dart';

import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/presentation/navigation/pdp_route_transition.dart';
import 'navigation/commercetools_product_detail_navigation.dart';
import 'presentation/lab_commercetools_product_detail_page.dart';
import 'presentation/lab_commercetools_products_page.dart';

/// Internal, GoRouter-aware UI module for the commercetools lab. NOT a portable
/// domain package: its pages reuse Kiki's Luxe UI (`ProductCard`,
/// `PdpHeroContext`, the hero bodies, `StorefrontLayout`).
///
/// It does not import `app_router.dart` or any app composition wiring (the
/// composition root imports this module, not the other way around). It still
/// depends on one shared contract currently living under `lib/app`:
/// `CatalogRoutes` (route paths). Relocating `CatalogRoutes` to a `core/`
/// home is tracked as follow-up debt; the http client provider was already
/// moved to `core/network`.
///
/// [routes] are spread into the app's `ShellRoute` so the lab pages inherit the
/// `MainShell` chrome.
abstract final class CommercetoolsLabModule {
  static List<RouteBase> routes() {
    return [
      // Lab PLP — direct URL and the "Démo commercetools" drawer link.
      GoRoute(
        path: CatalogRoutes.labCommercetoolsProducts,
        builder: (context, state) => const LabCommercetoolsProductsPage(),
      ),
      // Lab PDP — reuses the shared PDP transition + image-Hero mechanism,
      // isolated from pdpProvider / cart / admin.
      GoRoute(
        path: '${CatalogRoutes.labCommercetoolsProducts}/:routeKey',
        pageBuilder: (context, state) {
          final extra = state.extra;
          return pdpTransitionPage(
            key: state.pageKey,
            child: LabCommercetoolsProductDetailPage(
              routeKey: state.pathParameters['routeKey']!,
              hint: extra is CommercetoolsProductDetailRouteHint ? extra : null,
            ),
          );
        },
      ),
    ];
  }
}
