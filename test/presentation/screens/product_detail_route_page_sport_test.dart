import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kiki_commerce/app/app_providers.dart';
import 'package:kiki_commerce/application/catalog/catalog_read_models.dart';
import 'package:kiki_commerce/application/catalog/category_catalog_repository.dart';
import 'package:kiki_commerce/application/storefront/storefront_sport_segment.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_route_page.dart';

void main() {
  testWidgets('sport PDP canonical redirect stays in the sport namespace', (
    tester,
  ) async {
    final previousUrlReflection = GoRouter.optionURLReflectsImperativeAPIs;
    GoRouter.optionURLReflectsImperativeAPIs = true;
    addTearDown(
      () => GoRouter.optionURLReflectsImperativeAPIs = previousUrlReflection,
    );

    final router = GoRouter(
      initialLocation: '/fr/sport/femme/wrong/old',
      routes: [
        GoRoute(
          path: '/fr/sport/femme/boots/pegasus',
          builder: (context, state) =>
              const Scaffold(body: Text('canonical sport PDP')),
        ),
        GoRoute(
          path: '/fr/sport/femme/:categorySlug/:productSlug',
          builder: (context, state) => ProductDetailRoutePage(
            categorySlug: state.pathParameters['categorySlug']!,
            productSlug: state.pathParameters['productSlug']!,
            sportSegment: StorefrontSportSegment.femme,
          ),
        ),
        GoRoute(
          path: '/fr/catalog/boots/pegasus',
          builder: (context, state) =>
              const Scaffold(body: Text('catalog PDP')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryCatalogRepositoryProvider.overrideWithValue(
            const _RouteOnlyCategoryRepository(
              routeData: CatalogProductRouteData(
                category: CatalogCategory(
                  id: 'boots',
                  code: 'BOOTS',
                  name: 'Boots',
                  slug: 'boots',
                ),
                productId: 'pegasus',
                productSlug: 'pegasus',
              ),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/fr/sport/femme/boots/pegasus',
    );
    expect(find.text('canonical sport PDP'), findsOneWidget);
    expect(find.text('catalog PDP'), findsNothing);
  });
}

class _RouteOnlyCategoryRepository implements CategoryCatalogRepository {
  final CatalogProductRouteData routeData;

  const _RouteOnlyCategoryRepository({required this.routeData});

  @override
  Future<CatalogCategory?> getDefaultCategory({required String locale}) async =>
      null;

  @override
  Future<List<CatalogCategory>> getActiveCategories({
    required String locale,
    bool includeHidden = false,
  }) async => const <CatalogCategory>[];

  @override
  Future<CatalogCategory?> getCategoryBySlug(
    String slug, {
    required String locale,
  }) async => null;

  @override
  Future<CatalogPageData> getCategoryProducts(
    String categoryId, {
    required String locale,
    int page = 1,
    int perPage = 20,
  }) async => CatalogPageData(
    page: page,
    perPage: perPage,
    totalItems: 0,
    totalPages: 0,
    categoryId: categoryId,
    items: const [],
  );

  @override
  Future<CatalogProductRouteData?> resolveProductRoute({
    required String categorySlug,
    required String productSlug,
    required String locale,
  }) async => routeData;
}
