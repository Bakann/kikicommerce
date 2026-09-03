import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kiki_commerce/app/catalog_routes.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import '../navigation/commercetools_product_detail_navigation.dart';
import 'commercetools_lab_providers.dart';
import 'package:kiki_commerce/presentation/widgets/product_card.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_layout.dart';

/// Experimental lab page that lists commercetools products fetched from the
/// public Cloudflare Worker, rendered with the real Luxe `ProductCard` grid.
///
/// Mounted inside `MainShell` (storefront chrome / theme) and surfaced as a
/// "Démo commercetools" link at the bottom of the drawer — a technical demo,
/// not the official PocketBase catalog. Cards open an isolated commercetools
/// lab PDP; they are not wired to the PocketBase PDP, cart, or checkout. It
/// does not affect the PocketBase storefront.
class LabCommercetoolsProductsPage extends ConsumerWidget {
  const LabCommercetoolsProductsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(commercetoolsListingItemsProvider);

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: '$error',
        onRetry: () => ref.invalidate(commercetoolsListingItemsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Aucun produit.'));
        }
        return _LuxeProductGrid(items: items);
      },
    );
  }
}

/// A Luxe PLP-style grid that reuses [ProductCard] (editorial presentation),
/// mirroring the storefront grid's columns / spacing / aspect ratio. Tapping a
/// card opens the isolated commercetools lab PDP (not the PocketBase PDP) via
/// [ProductCard.onOpen], reusing the card's exact Hero wiring.
class _LuxeProductGrid extends StatelessWidget {
  final List<CatalogListingItem> items;

  const _LuxeProductGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = StorefrontLayout.productGridColumnsFor(width);
    final spacing = StorefrontLayout.gridSpacingFor(width);
    final aspectRatio = StorefrontLayout.productGridAspectRatioFor(width);
    final outerPadding = StorefrontLayout.outerPaddingFor(
      width,
      maxWidth: StorefrontLayout.productListMaxWidth,
    );
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 48.0;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        outerPadding,
        24,
        outerPadding,
        bottomPadding,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final routeKey = item.productRouteSlug ?? item.productId;
        return ProductCard(
          product: item.product,
          prices: item.prices,
          routeName: CatalogRoutes.labCommercetoolsProductByRouteKey(routeKey),
          enableHeroTransition: true,
          // Open the isolated lab PDP, not the PocketBase PDP.
          onOpen: (openContext) => openCommercetoolsProductDetail(
            context,
            item: item,
            routeName: openContext.routeName,
            heroListingMedia: openContext.heroListingMedia,
            heroEligible: openContext.heroEligible,
            imageHeroTag: openContext.imageHeroTag,
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
