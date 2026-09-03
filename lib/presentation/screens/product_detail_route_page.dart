import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/catalog_routes.dart';
import '../../app/locale_route_resolver.dart';
import '../../application/storefront/storefront_chrome_profile.dart';
import '../../application/storefront/storefront_sport_segment.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../providers/product_providers.dart';
import '../providers/storefront_theme_providers.dart';
import '../widgets/error_display.dart';
import '../widgets/navigation/sport_home_icon_loading_publisher.dart';
import 'product_detail_page.dart';

class ProductDetailRouteHint {
  final String productId;
  final CatalogCategory? category;
  // The PLP card's listing media. When set, the destination PDP can mount
  // a Hero with the matching tag during its loading branch so the
  // shared-element flight starts immediately on push (otherwise the
  // destination is just a spinner and Flutter finds no Hero pair).
  final CatalogMedia? listingMedia;
  // Exact Hero tag worn by the source widget that triggered the push. The
  // destination PDP must reuse this tag so the flight pairs only with that
  // single source; otherwise a productId-only tag would also match any other
  // surface still rendering the same product (e.g. a PLP card visible behind
  // a stacked PDP whose cross-sell linked here), causing parallel ghost
  // flights on pop.
  final String? imageHeroTag;

  const ProductDetailRouteHint({
    required this.productId,
    this.category,
    this.listingMedia,
    this.imageHeroTag,
  });
}

class ProductDetailRoutePage extends ConsumerStatefulWidget {
  final String categorySlug;
  final String productSlug;
  final StorefrontSportSegment? sportSegment;
  final ProductDetailRouteHint? hint;

  const ProductDetailRoutePage({
    super.key,
    required this.categorySlug,
    required this.productSlug,
    this.sportSegment,
    this.hint,
  });

  @override
  ConsumerState<ProductDetailRoutePage> createState() =>
      _ProductDetailRoutePageState();
}

class _ProductDetailRoutePageState
    extends ConsumerState<ProductDetailRoutePage> {
  bool _redirectScheduled = false;

  @override
  Widget build(BuildContext context) {
    final usesSportHomeIconLoading =
        widget.sportSegment != null || _usesSportBottomNav(ref);
    final hint = widget.hint;
    if (hint != null && _hintMatchesRequestedCategory(hint)) {
      return ProductDetailPage(
        productId: hint.productId,
        category: hint.category,
        listingMediaHint: hint.listingMedia,
        mainImageHeroTag: hint.imageHeroTag,
        animateSportHomeIconOnLoad: usesSportHomeIconLoading,
      );
    }

    final routeAsync = ref.watch(
      productRouteProvider((
        categorySlug: widget.categorySlug,
        productSlug: widget.productSlug,
      )),
    );

    final isInitialRouteLoading =
        usesSportHomeIconLoading &&
        routeAsync.isLoading &&
        !routeAsync.hasValue;
    final page = routeAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: ErrorDisplay(
          error: error,
          onRetry: () => ref.invalidate(
            productRouteProvider((
              categorySlug: widget.categorySlug,
              productSlug: widget.productSlug,
            )),
          ),
        ),
      ),
      data: (routeData) {
        if (routeData == null) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Produit introuvable pour cette catégorie.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final locale = resolveLocaleRoute(
          GoRouterState.of(context).uri,
        ).pathLocale?.languageCode;
        final canonicalLocation = _canonicalLocation(routeData, locale: locale);
        final localizedRequestedLocation = _requestedLocation(locale: locale);

        if (canonicalLocation != localizedRequestedLocation) {
          _scheduleRedirect(canonicalLocation);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return ProductDetailPage(
          productId: routeData.productId,
          category: routeData.category,
          animateSportHomeIconOnLoad: usesSportHomeIconLoading,
        );
      },
    );
    if (!usesSportHomeIconLoading) {
      return page;
    }
    return SportHomeIconLoadingPublisher(
      isLoading: isInitialRouteLoading,
      child: page,
    );
  }

  bool _usesSportBottomNav(WidgetRef ref) {
    final theme = ref.watch(effectiveStorefrontThemeAsyncProvider).value;
    return theme != null &&
        StorefrontChromeProfile.forTheme(theme).showFloatingBottomNav;
  }

  bool _hintMatchesRequestedCategory(ProductDetailRouteHint hint) {
    final hintCategorySlug = hint.category?.slug?.trim();
    return hintCategorySlug == null ||
        hintCategorySlug.isEmpty ||
        hintCategorySlug == widget.categorySlug;
  }

  String _canonicalLocation(
    CatalogProductRouteData routeData, {
    String? locale,
  }) {
    final canonicalCategorySlug = routeData.category.slug?.trim();
    final sportSegment = widget.sportSegment;
    late final String location;
    if (canonicalCategorySlug != null && canonicalCategorySlug.isNotEmpty) {
      location = sportSegment == null
          ? CatalogRoutes.productBySlugs(
              categorySlug: canonicalCategorySlug,
              productSlug: routeData.productSlug,
            )
          : CatalogRoutes.sportProductLocation(
              segment: sportSegment,
              categorySlug: canonicalCategorySlug,
              productSlug: routeData.productSlug,
            );
    } else {
      location = CatalogRoutes.productById(routeData.productId);
    }

    return locale == null
        ? location
        : CatalogRoutes.localizedLocation(location, locale: locale);
  }

  String _requestedLocation({String? locale}) {
    final sportSegment = widget.sportSegment;
    final location = sportSegment == null
        ? CatalogRoutes.productBySlugs(
            categorySlug: widget.categorySlug,
            productSlug: widget.productSlug,
          )
        : CatalogRoutes.sportProductLocation(
            segment: sportSegment,
            categorySlug: widget.categorySlug,
            productSlug: widget.productSlug,
          );

    return locale == null
        ? location
        : CatalogRoutes.localizedLocation(location, locale: locale);
  }

  void _scheduleRedirect(String routeName) {
    if (_redirectScheduled) {
      return;
    }
    _redirectScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.replace(routeName);
    });
  }
}
