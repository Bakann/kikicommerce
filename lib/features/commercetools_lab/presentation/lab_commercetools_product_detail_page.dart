import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kiki_commerce/core/utils/price_utils.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import '../navigation/commercetools_product_detail_navigation.dart';
import 'commercetools_lab_providers.dart';
import 'package:kiki_commerce/presentation/widgets/storefront_layout.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_hero.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_info_tabs.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_layout_spec.dart';

/// Luxe-styled detail page for a commercetools lab product. Reuses the real PDP
/// hero components ([PdpHeroContext] + the hero bodies) for visual parity, but
/// is fully isolated from PocketBase: no `pdpProvider`, no cart, no admin/media
/// editing. Admin callbacks are unreachable no-ops (edit mode is always off);
/// add-to-cart shows a "not connected" notice.
class LabCommercetoolsProductDetailPage extends ConsumerWidget {
  /// Route key from the URL — may be a slug, key, or id (see
  /// `CommercetoolsCatalogRepository.getProductByRouteKey`).
  final String routeKey;
  final CommercetoolsProductDetailRouteHint? hint;

  const LabCommercetoolsProductDetailPage({
    super.key,
    required this.routeKey,
    this.hint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hintItem = hint?.listingItem;
    if (hintItem != null) {
      return _DetailBody(item: hintItem, mainImageHeroTag: hint?.imageHeroTag);
    }

    // Deep link / refresh: resolve the product via the repository (matches
    // slug/key/id), already adapted to a CatalogListingItem.
    final itemAsync = ref.watch(
      commercetoolsListingItemByRouteKeyProvider(routeKey),
    );
    return itemAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Message(text: '$error'),
      data: (item) {
        if (item == null) {
          return const _Message(text: 'Produit introuvable.');
        }
        return _DetailBody(item: item);
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  final CatalogListingItem item;
  final String? mainImageHeroTag;

  const _DetailBody({required this.item, this.mainImageHeroTag});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final layout = ProductDetailLayoutSpec.forWidth(width);
    final product = item.product;
    final defaultPrice = getDefaultPrice(item.prices);
    final allMedia = <CatalogMedia>[
      if (product.picture != null) product.picture!,
      ...product.gallery,
    ];

    final heroContext = PdpHeroContext(
      product: product,
      layout: layout,
      pendingMedia: const {},
      isEditMode: false,
      allMedia: allMedia,
      defaultPrice: defaultPrice,
      originalPrice: null,
      discount: null,
      symbol: defaultPrice?.currencySymbol ?? '€',
      isNew: false,
      hasVariantSelector: false,
      heroBreadcrumbOverlay: const SizedBox.shrink(),
      detailTabs: ProductDetailInfoTabs(
        product: product,
        layout: layout,
        visibleSummary: product.description ?? '',
        isEditMode: false,
      ),
      mobilePurchaseAnchorKey: null,
      // Edit mode is always off, so these admin affordances are never shown.
      onPickPhoto: (_, _) {},
      onPickMedia: (_, _) {},
      onRemoveMedia: (_, _) {},
      onMoveMedia: (_, _, _) {},
      onSetFirstMedia: (_, _) {},
      onAddMedia: () {},
      carouselScrollTargetMediaId: null,
      onCarouselScrollTargetHandled: (_) {},
      onEditTranslations: () {},
      onSavePrice: (_) async => false,
      onAddToCart: () async {
        _showCartNotice(context);
        return true;
      },
      onOpenVisionModal: null,
      mainImageHeroTag: mainImageHeroTag,
    );

    final Widget heroBody;
    if (layout.isDesktop) {
      heroBody = DesktopHeroBody(heroContext: heroContext);
    } else if (layout.isSplit) {
      heroBody = SplitHeroBody(heroContext: heroContext);
    } else {
      heroBody = MobileHeroBody(heroContext: heroContext);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: StorefrontPageSection(
            maxWidth: layout.maxWidth,
            minHorizontalPadding: layout.horizontalPadding,
            padding: EdgeInsets.only(
              top: layout.heroTopPadding,
              bottom: layout.isMobile ? 40 : 56,
            ),
            child: heroBody,
          ),
        ),
      ],
    );
  }

  void _showCartNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Panier commercetools non connecté pour cette démo.'),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
