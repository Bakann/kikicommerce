import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin/screens/admin_backoffice_page.dart';
import '../application/catalog/search_query.dart';
import '../application/storefront/storefront_sport_segment.dart';
import '../application/storefront/storefront_theme.dart';
import '../features/commercetools_lab/commercetools_lab_module.dart';
import '../presentation/l10n/l10n_extension.dart';
import '../presentation/navigation/pdp_route_transition.dart';
import '../presentation/providers/locale_provider.dart';
import '../presentation/screens/mobile_cart_page.dart';
import '../presentation/screens/mobile_checkout_page.dart';
import '../presentation/screens/product_detail_page.dart';
import '../presentation/screens/product_detail_route_page.dart';
import '../presentation/screens/product_list_page.dart';
import '../presentation/screens/search_entry_page.dart';
import '../presentation/screens/search_results_page.dart';
import '../presentation/screens/storefront_home_page.dart';
import '../presentation/screens/storefront_landing_page.dart';
import '../presentation/screens/story_experience_page.dart';
import '../presentation/widgets/navigation/main_shell.dart';
import '../presentation/widgets/navigation/sport_flow_shell.dart';
import 'catalog_routes.dart';
import 'locale_route_resolver.dart';

const _localizedRouteLocales = ['fr', 'en'];

String? _localeRouteRedirect(BuildContext context, GoRouterState state) {
  final (sessionLocale, persistedLocale) = _routeLocalePreferences(context);
  final resolution = resolveLocaleRoute(
    state.uri,
    sessionLocale: sessionLocale,
    persistedLocale: persistedLocale,
  );
  return resolution.shouldRedirect ? resolution.canonicalUri.toString() : null;
}

/// Reads the session (URL override) and persisted UI language so the redirect
/// can send the bare root `/` to the user's language. Non-root public routes
/// ignore these in the resolver, so this only affects the entry point. Falls
/// back to `(null, null)` if the provider scope isn't reachable from [context].
(String?, String?) _routeLocalePreferences(BuildContext context) {
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    return (
      container.read(urlLocaleOverrideProvider)?.languageCode,
      container.read(localeProvider)?.languageCode,
    );
  } catch (_) {
    return (null, null);
  }
}

String _localizedForState(GoRouterState state, String location) {
  final locale = resolveLocaleRoute(state.uri).pathLocale?.languageCode;
  if (locale == null) return location;
  return CatalogRoutes.localizedLocation(location, locale: locale);
}

/// Redirect guard for `/sport/:segment` routes: keeps a valid segment as-is
/// (returns `null` = no redirect) and rewrites anything unrecognized to the
/// fallback segment location.
String? _sportSegmentRedirect(BuildContext context, GoRouterState state) {
  final rawSegment = state.pathParameters['segment'];
  if (StorefrontSportSegment.tryParse(rawSegment) != null) {
    return null;
  }
  return _localizedForState(
    state,
    CatalogRoutes.sportSegmentLocation(StorefrontSportSegment.fallback),
  );
}

/// Redirect guard for `/sport/:segment/:categorySlug`: same segment check as
/// [_sportSegmentRedirect], but on an unknown segment it preserves the
/// requested category so the user lands on the same PLP under the fallback
/// segment (e.g. `/sport/foo/shoes` -> `/sport/homme/shoes`) instead of
/// dropping the category.
String? _sportSegmentCategoryRedirect(
  BuildContext context,
  GoRouterState state,
) {
  final rawSegment = state.pathParameters['segment'];
  if (StorefrontSportSegment.tryParse(rawSegment) != null) {
    return null;
  }
  final categorySlug = state.pathParameters['categorySlug'];
  if (categorySlug == null || categorySlug.isEmpty) {
    return _localizedForState(
      state,
      CatalogRoutes.sportSegmentLocation(StorefrontSportSegment.fallback),
    );
  }
  return _localizedForState(
    state,
    CatalogRoutes.sportCategoryLocation(
      segment: StorefrontSportSegment.fallback,
      categorySlug: categorySlug,
    ),
  );
}

/// Redirect guard for `/sport/:segment/:categorySlug/:productSlug`: preserves
/// both category and product when the segment itself must fall back.
String? _sportSegmentProductRedirect(
  BuildContext context,
  GoRouterState state,
) {
  final rawSegment = state.pathParameters['segment'];
  if (StorefrontSportSegment.tryParse(rawSegment) != null) {
    return null;
  }
  final categorySlug = state.pathParameters['categorySlug'];
  final productSlug = state.pathParameters['productSlug'];
  if (categorySlug == null ||
      categorySlug.isEmpty ||
      productSlug == null ||
      productSlug.isEmpty) {
    return _sportSegmentCategoryRedirect(context, state);
  }
  return _localizedForState(
    state,
    CatalogRoutes.sportProductLocation(
      segment: StorefrontSportSegment.fallback,
      categorySlug: categorySlug,
      productSlug: productSlug,
    ),
  );
}

class AppRouter {
  const AppRouter();

  GoRouter createRouter({String? initialLocation}) {
    GoRouter.optionURLReflectsImperativeAPIs = true;

    final normalizedInitialLocation = _normalizedLocation(initialLocation);

    return GoRouter(
      initialLocation: normalizedInitialLocation,
      overridePlatformDefaultLocation: normalizedInitialLocation != null,
      redirect: _localeRouteRedirect,
      routes: [
        // Public home + Sport flow under one persistent shell so the floating
        // bottom nav / iridescent Home ring is a SINGLE instance that survives
        // home <-> sport landing/PLP/PDP navigation. The shell renders the nav
        // on home only when the active theme uses Sport chrome; Sport routes
        // always show it. Each child route brings its own Scaffold; the shell
        // owns only the nav.
        ShellRoute(
          builder: (context, state, child) => SportFlowShell(child: child),
          routes: [
            GoRoute(
              path: CatalogRoutes.home,
              builder: (context, state) =>
                  const StorefrontLandingPage(bottomNavHostedByShell: true),
            ),
            for (final locale in _localizedRouteLocales)
              GoRoute(
                path: '/$locale',
                builder: (context, state) =>
                    const StorefrontLandingPage(bottomNavHostedByShell: true),
              ),
            GoRoute(
              path: '${CatalogRoutes.sportBase}/:segment',
              redirect: _sportSegmentRedirect,
              pageBuilder: (context, state) {
                final segment = StorefrontSportSegment.parse(
                  state.pathParameters['segment'],
                );
                // Stable, segment-independent keys: navigating between segments
                // reuses the same page + State so didUpdateWidget fires (driving
                // the in-page content slide) instead of a full-screen Navigator
                // transition. The URL still changes, so deep-linking / back are
                // preserved (one /sport/... entry whose path-param moves).
                return MaterialPage<void>(
                  key: const ValueKey('sport-page'),
                  child: StorefrontLandingPage(
                    key: const ValueKey('sport-landing'),
                    sportSegment: segment,
                    bottomNavHostedByShell: true,
                  ),
                );
              },
            ),
            for (final locale in _localizedRouteLocales)
              GoRoute(
                path: '/$locale${CatalogRoutes.sportBase}/:segment',
                redirect: _sportSegmentRedirect,
                pageBuilder: (context, state) {
                  final segment = StorefrontSportSegment.parse(
                    state.pathParameters['segment'],
                  );
                  return MaterialPage<void>(
                    key: const ValueKey('sport-page'),
                    child: StorefrontLandingPage(
                      key: const ValueKey('sport-landing'),
                      sportSegment: segment,
                      bottomNavHostedByShell: true,
                    ),
                  );
                },
              ),
            GoRoute(
              path: '${CatalogRoutes.sportBase}/:segment/:categorySlug',
              redirect: _sportSegmentCategoryRedirect,
              builder: (context, state) => SportFlowPlpScaffold(
                child: StorefrontHomePage(
                  categorySlug: state.pathParameters['categorySlug'],
                  sportSegment: StorefrontSportSegment.parse(
                    state.pathParameters['segment'],
                  ),
                ),
              ),
            ),
            GoRoute(
              path:
                  '${CatalogRoutes.sportBase}/:segment/:categorySlug/:productSlug',
              redirect: _sportSegmentProductRedirect,
              pageBuilder: (context, state) {
                final extra = state.extra;
                return pdpTransitionPage(
                  key: state.pageKey,
                  child: SportFlowPdpScope(
                    child: ProductDetailRoutePage(
                      categorySlug: state.pathParameters['categorySlug']!,
                      productSlug: state.pathParameters['productSlug']!,
                      sportSegment: StorefrontSportSegment.parse(
                        state.pathParameters['segment'],
                      ),
                      hint: extra is ProductDetailRouteHint ? extra : null,
                    ),
                  ),
                );
              },
            ),
            for (final locale in _localizedRouteLocales)
              GoRoute(
                path:
                    '/$locale${CatalogRoutes.sportBase}/:segment/:categorySlug',
                redirect: _sportSegmentCategoryRedirect,
                builder: (context, state) => SportFlowPlpScaffold(
                  child: StorefrontHomePage(
                    categorySlug: state.pathParameters['categorySlug'],
                    sportSegment: StorefrontSportSegment.parse(
                      state.pathParameters['segment'],
                    ),
                  ),
                ),
              ),
            for (final locale in _localizedRouteLocales)
              GoRoute(
                path:
                    '/$locale${CatalogRoutes.sportBase}/:segment/:categorySlug/:productSlug',
                redirect: _sportSegmentProductRedirect,
                pageBuilder: (context, state) {
                  final extra = state.extra;
                  return pdpTransitionPage(
                    key: state.pageKey,
                    child: SportFlowPdpScope(
                      child: ProductDetailRoutePage(
                        categorySlug: state.pathParameters['categorySlug']!,
                        productSlug: state.pathParameters['productSlug']!,
                        sportSegment: StorefrontSportSegment.parse(
                          state.pathParameters['segment'],
                        ),
                        hint: extra is ProductDetailRouteHint ? extra : null,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        GoRoute(
          path: CatalogRoutes.admin,
          builder: (context, state) => const AdminBackofficePage(),
        ),
        // Full-screen immersive section pager (chrome-less, like /cart it sits
        // outside the MainShell ShellRoute). V1 ships fixed slides.
        GoRoute(
          path: CatalogRoutes.story,
          builder: (context, state) => const StoryExperiencePage(),
        ),
        GoRoute(
          path: CatalogRoutes.cart,
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 420),
            reverseTransitionDuration: const Duration(milliseconds: 320),
            child: const MobileCartPage(),
            transitionsBuilder: (context, animation, _, child) {
              if (MediaQuery.disableAnimationsOf(context)) {
                return child;
              }
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        ),
        // `/checkout` redirects to `/checkout/access` (the actual funnel
        // entry) while preserving query params (e.g. `?email=`) so the
        // identification step can pre-fill or resume. Kept as a redirect
        // rather than a second mount of MobileCheckoutAccessPage so
        // there's exactly one canonical URL for the identification step.
        GoRoute(
          path: CatalogRoutes.checkout,
          redirect: (context, state) {
            final query = state.uri.query;
            return query.isEmpty
                ? CatalogRoutes.checkoutAccess
                : '${CatalogRoutes.checkoutAccess}?$query';
          },
        ),
        GoRoute(
          path: CatalogRoutes.checkoutAccess,
          builder: (context, state) => MobileCheckoutAccessPage(
            initialEmail: state.uri.queryParameters['email'],
          ),
        ),
        GoRoute(
          path: CatalogRoutes.checkoutGuestAddress,
          builder: (context, state) {
            final email = state.uri.queryParameters['email'];
            if (email == null || email.trim().isEmpty) {
              return const MobileCheckoutAccessPage();
            }
            return MobileGuestCheckoutAddressPage(email: email);
          },
        ),
        ShellRoute(
          builder: (context, state, child) => MainShell(
            routeKey: state.uri.toString(),
            forcedTheme: _forcedThemeForShellRoute(state.uri.path),
            child: child,
          ),
          routes: [
            GoRoute(
              path: CatalogRoutes.catalogBase,
              builder: (context, state) {
                final categoryId = state.uri.queryParameters['categoryId'];
                if (categoryId != null && categoryId.isNotEmpty) {
                  return ProductListPage(
                    categoryId: categoryId,
                    heroSlugKey: 'id:$categoryId',
                  );
                }
                return const StorefrontHomePage();
              },
            ),
            for (final locale in _localizedRouteLocales)
              GoRoute(
                path: '/$locale${CatalogRoutes.catalogBase}',
                builder: (context, state) {
                  final categoryId = state.uri.queryParameters['categoryId'];
                  if (categoryId != null && categoryId.isNotEmpty) {
                    return ProductListPage(
                      categoryId: categoryId,
                      heroSlugKey: 'id:$categoryId',
                    );
                  }
                  return const StorefrontHomePage();
                },
              ),
            GoRoute(
              path: '${CatalogRoutes.catalogBase}/:categorySlug',
              builder: (context, state) => StorefrontHomePage(
                categorySlug: state.pathParameters['categorySlug'],
              ),
            ),
            for (final locale in _localizedRouteLocales)
              GoRoute(
                path: '/$locale${CatalogRoutes.catalogBase}/:categorySlug',
                builder: (context, state) => StorefrontHomePage(
                  categorySlug: state.pathParameters['categorySlug'],
                ),
              ),
            GoRoute(
              path: CatalogRoutes.search,
              builder: (context, state) => _searchScreenFor(state.uri),
            ),
            for (final locale in _localizedRouteLocales)
              GoRoute(
                path: '/$locale${CatalogRoutes.search}',
                builder: (context, state) => _searchScreenFor(state.uri),
              ),
            GoRoute(
              path: '${CatalogRoutes.catalogBase}/:categorySlug/:productSlug',
              pageBuilder: (context, state) {
                final extra = state.extra;
                return pdpTransitionPage(
                  key: state.pageKey,
                  child: ProductDetailRoutePage(
                    categorySlug: state.pathParameters['categorySlug']!,
                    productSlug: state.pathParameters['productSlug']!,
                    hint: extra is ProductDetailRouteHint ? extra : null,
                  ),
                );
              },
            ),
            for (final locale in _localizedRouteLocales)
              GoRoute(
                path:
                    '/$locale${CatalogRoutes.catalogBase}/:categorySlug/:productSlug',
                pageBuilder: (context, state) {
                  final extra = state.extra;
                  return pdpTransitionPage(
                    key: state.pageKey,
                    child: ProductDetailRoutePage(
                      categorySlug: state.pathParameters['categorySlug']!,
                      productSlug: state.pathParameters['productSlug']!,
                      hint: extra is ProductDetailRouteHint ? extra : null,
                    ),
                  );
                },
              ),
            GoRoute(
              path: CatalogRoutes.productBase,
              pageBuilder: (context, state) {
                final productId = state.uri.queryParameters['productId'];
                final extra = state.extra;
                final hint = extra is ProductDetailRouteHint ? extra : null;
                final matchingHint = hint?.productId == productId ? hint : null;
                if (productId != null && productId.isNotEmpty) {
                  return pdpTransitionPage(
                    key: state.pageKey,
                    child: ProductDetailPage(
                      productId: productId,
                      category: matchingHint?.category,
                      listingMediaHint: matchingHint?.listingMedia,
                      mainImageHeroTag: matchingHint?.imageHeroTag,
                    ),
                  );
                }
                return const MaterialPage<void>(child: _RouteNotFoundPage());
              },
            ),
            for (final locale in _localizedRouteLocales)
              GoRoute(
                path: '/$locale${CatalogRoutes.productBase}',
                pageBuilder: (context, state) {
                  final productId = state.uri.queryParameters['productId'];
                  final extra = state.extra;
                  final hint = extra is ProductDetailRouteHint ? extra : null;
                  final matchingHint = hint?.productId == productId
                      ? hint
                      : null;
                  if (productId != null && productId.isNotEmpty) {
                    return pdpTransitionPage(
                      key: state.pageKey,
                      child: ProductDetailPage(
                        productId: productId,
                        category: matchingHint?.category,
                        listingMediaHint: matchingHint?.listingMedia,
                        mainImageHeroTag: matchingHint?.imageHeroTag,
                      ),
                    );
                  }
                  return const MaterialPage<void>(child: _RouteNotFoundPage());
                },
              ),
            // Experimental commercetools lab (PLP + isolated PDP), mounted in
            // the shell so it inherits MainShell chrome. Owned by the feature
            // module; surfaced as a "Démo commercetools" drawer link.
            ...CommercetoolsLabModule.routes(),
          ],
        ),
      ],
      errorBuilder: (context, state) => const _RouteNotFoundPage(),
    );
  }

  StorefrontTheme? _forcedThemeForShellRoute(String path) {
    final routePath = resolveLocaleRoute(Uri(path: path)).routePath;
    return routePath.startsWith('${CatalogRoutes.sportBase}/')
        ? StorefrontTheme.nike
        : null;
  }

  String? _normalizedLocation(String? routeName) {
    if (routeName == null || routeName.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(routeName);
    if (uri == null) {
      return CatalogRoutes.home;
    }

    final fragment = uri.fragment.trim();
    if ((uri.path.isEmpty || uri.path == '/') && fragment.isNotEmpty) {
      final normalizedFragment = fragment.startsWith('/')
          ? fragment
          : '/$fragment';
      final fragmentUri = Uri.tryParse(normalizedFragment);
      if (fragmentUri != null) {
        return fragmentUri.toString();
      }
    }

    return uri.toString();
  }
}

/// `/search` with no query is the search entry screen (input + live
/// suggestions); once a query is present it renders the results grid.
Widget _searchScreenFor(Uri uri) {
  final query = searchQueryFromUri(uri);
  final trimmed = query.query?.trim() ?? '';
  if (trimmed.isEmpty) {
    return const SearchEntryPage();
  }
  return SearchResultsPage(query: query);
}

class _RouteNotFoundPage extends StatelessWidget {
  const _RouteNotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.commonRouteNotFound,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
