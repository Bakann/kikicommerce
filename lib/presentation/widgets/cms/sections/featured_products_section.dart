import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/catalog_routes.dart';
import '../../../../application/cms/cms_models.dart';
import '../../../../application/cms/featured_products_repository.dart';
import '../../../../core/utils/price_utils.dart';
import '../../../providers/featured_products_provider.dart';
import '../../kiki_image.dart';
import '../../storefront_layout.dart';
import '../cms_href.dart';
import '../cms_legacy_l10n.dart';
import '../cms_text_reveal.dart';

class FeaturedProductsSection extends ConsumerWidget {
  final FeaturedProductsConfig config;
  final bool enableTextReveal;
  final String? textRevealId;

  const FeaturedProductsSection({
    super.key,
    required this.config,
    this.enableTextReveal = true,
    this.textRevealId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (config.productIds.isEmpty && config.placeholderProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = StorefrontLayout.isDesktop(width);
    final isTablet = StorefrontLayout.isTabletOnly(width);
    final isMobile = !isDesktop && !isTablet;
    final isNikeGrid = config.layout == 'nikeGrid3';

    final asyncProducts = config.productIds.isEmpty
        ? null
        : ref.watch(featuredProductsProvider(config.productIds));

    final horizontalPadding = isNikeGrid
        ? StorefrontLayout.nikeContentPaddingFor(width)
        : StorefrontLayout.outerPaddingFor(width);

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        isNikeGrid ? (isMobile ? 58 : 80) : (isMobile ? 48 : 80),
        horizontalPadding,
        isNikeGrid ? (isMobile ? 56 : 80) : (isMobile ? 48 : 80),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: isNikeGrid
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CmsRevealGroup(
                key: textRevealId == null
                    ? null
                    : ValueKey(
                        'cms-featured-products-header-reveal-$textRevealId',
                      ),
                trigger: CmsRevealTrigger.viewport,
                enabled: enableTextReveal,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isNikeGrid
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  if (config.eyebrow != null) ...[
                    CmsRevealText(
                      child: Text(
                        config.eyebrow!,
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6F6F6F),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (config.title != null)
                    CmsRevealText(
                      child: Text(
                        localizedLegacyCmsText(context, config.title!),
                        textAlign: isNikeGrid
                            ? TextAlign.start
                            : TextAlign.center,
                        style: isNikeGrid
                            ? TextStyle(
                                fontFamily: 'Inter',
                                fontSize: isMobile ? 26 : 34,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111111),
                                height: 1.08,
                              )
                            : GoogleFonts.cormorantGaramond(
                                fontSize: isMobile ? 28 : 36,
                                fontWeight: FontWeight.w400,
                              ),
                      ),
                    ),
                  if (config.subtitle != null) ...[
                    const SizedBox(height: 8),
                    CmsRevealText(
                      child: Text(
                        config.subtitle!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6F6F6F),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: isNikeGrid ? (isMobile ? 92 : 44) : 28),
              if (asyncProducts == null)
                _PlaceholderProductsGrid(
                  products: config.placeholderProducts,
                  layout: config.layout,
                  showPrices: config.showPrices,
                  isMobile: isMobile,
                )
              else
                asyncProducts.when(
                  data: (products) {
                    if (products.isEmpty) {
                      return _PlaceholderProductsGrid(
                        products: config.placeholderProducts,
                        layout: config.layout,
                        showPrices: config.showPrices,
                        isMobile: isMobile,
                      );
                    }
                    return _ProductsGrid(
                      products: products,
                      layout: config.layout,
                      showPrices: config.showPrices,
                      isMobile: isMobile,
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, _) => _PlaceholderProductsGrid(
                    products: config.placeholderProducts,
                    layout: config.layout,
                    showPrices: config.showPrices,
                    isMobile: isMobile,
                  ),
                ),
              if (config.primaryCta?.isUsable == true) ...[
                SizedBox(height: isNikeGrid ? 56 : 28),
                CmsRevealGroup(
                  key: textRevealId == null
                      ? null
                      : ValueKey(
                          'cms-featured-products-cta-reveal-$textRevealId',
                        ),
                  trigger: CmsRevealTrigger.viewport,
                  enabled: enableTextReveal,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CmsRevealText(
                      child: Center(
                        child: TextButton(
                          onPressed: () =>
                              launchCmsHref(context, config.primaryCta!.href),
                          style: isNikeGrid
                              ? TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF111111),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                    side: const BorderSide(
                                      color: Color(0xFFD6D6D6),
                                      width: 1.4,
                                    ),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF1B1B1B),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 6,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                          child: isNikeGrid
                              ? Text(
                                  localizedLegacyCmsText(
                                    context,
                                    config.primaryCta!.label,
                                  ),
                                )
                              : DecoratedBox(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFF1B1B1B),
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      localizedLegacyCmsText(
                                        context,
                                        config.primaryCta!.label,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductsGrid extends StatelessWidget {
  final List<FeaturedProductData> products;
  final String layout;
  final bool showPrices;
  final bool isMobile;

  const _ProductsGrid({
    required this.products,
    required this.layout,
    required this.showPrices,
    required this.isMobile,
  });

  int get _columns {
    if (layout == 'nikeGrid3') return 3;
    final desktopCols = switch (layout) {
      'grid2' => 2,
      'grid3' => 3,
      _ => 4,
    };
    return isMobile ? 2 : desktopCols;
  }

  @override
  Widget build(BuildContext context) {
    final isNikeGrid = layout == 'nikeGrid3';
    final spacing = isNikeGrid ? 4.0 : (isMobile ? 12.0 : 20.0);
    final columns = _columns;
    final rowCount = (products.length + columns - 1) ~/ columns;
    final aspectRatio = isNikeGrid ? 0.58 : 0.65;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) ...[
          if (rowIndex > 0) SizedBox(height: spacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var colIndex = 0; colIndex < columns; colIndex++) ...[
                if (colIndex > 0) SizedBox(width: spacing),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: () {
                      final productIndex = rowIndex * columns + colIndex;
                      if (productIndex >= products.length) {
                        return const SizedBox.shrink();
                      }
                      return _ProductTile(
                        data: products[productIndex],
                        showPrice: showPrices,
                        isNikeGrid: isNikeGrid,
                      );
                    }(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  final FeaturedProductData data;
  final bool showPrice;
  final bool isNikeGrid;

  const _ProductTile({
    required this.data,
    required this.showPrice,
    this.isNikeGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    final price = getDefaultPrice(data.prices);
    return InkWell(
      onTap: () =>
          launchCmsHref(context, CatalogRoutes.productById(data.product.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRect(
              child: data.imageUrl == null
                  ? Container(color: const Color(0xFFEDEAE3))
                  : KikiImage(
                      imageUrl: data.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: Container(color: const Color(0xFFEDEAE3)),
                      errorWidget: Container(color: const Color(0xFFEDEAE3)),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: isNikeGrid ? 'Inter' : null,
              fontSize: isNikeGrid ? 17 : 14,
              fontWeight: isNikeGrid ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF1B1B1B),
              height: isNikeGrid ? 1.25 : null,
            ),
          ),
          if (showPrice && price != null) ...[
            const SizedBox(height: 4),
            Text(
              formatPrice(price.price, price.currencySymbol ?? '€'),
              style: TextStyle(
                fontFamily: isNikeGrid ? 'Inter' : null,
                fontSize: isNikeGrid ? 17 : 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6F6F6F),
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceholderProductsGrid extends StatelessWidget {
  final List<FeaturedProductPlaceholder> products;
  final String layout;
  final bool showPrices;
  final bool isMobile;

  const _PlaceholderProductsGrid({
    required this.products,
    required this.layout,
    required this.showPrices,
    required this.isMobile,
  });

  int get _columns {
    if (layout == 'nikeGrid3') return 3;
    final desktopCols = switch (layout) {
      'grid2' => 2,
      'grid3' => 3,
      _ => 4,
    };
    return isMobile ? 2 : desktopCols;
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final isNikeGrid = layout == 'nikeGrid3';
    final spacing = isNikeGrid ? 4.0 : (isMobile ? 12.0 : 20.0);
    final columns = _columns;
    final rowCount = (products.length + columns - 1) ~/ columns;
    final aspectRatio = isNikeGrid ? 0.58 : 0.65;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) ...[
          if (rowIndex > 0) SizedBox(height: isNikeGrid ? 36 : spacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var colIndex = 0; colIndex < columns; colIndex++) ...[
                if (colIndex > 0) SizedBox(width: spacing),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: () {
                      final productIndex = rowIndex * columns + colIndex;
                      if (productIndex >= products.length) {
                        return const SizedBox.shrink();
                      }
                      return _PlaceholderProductTile(
                        data: products[productIndex],
                        showPrice: showPrices,
                        isNikeGrid: isNikeGrid,
                      );
                    }(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _PlaceholderProductTile extends StatelessWidget {
  final FeaturedProductPlaceholder data;
  final bool showPrice;
  final bool isNikeGrid;

  const _PlaceholderProductTile({
    required this.data,
    required this.showPrice,
    required this.isNikeGrid,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (data.href.isNotEmpty) launchCmsHref(context, data.href);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: data.media == null || !data.media!.isUsable
                ? Container(color: const Color(0xFFF3F2F0))
                : KikiImage(
                    imageUrl: data.media!.thumbUrl(size: '600x600f'),
                    fit: BoxFit.cover,
                    placeholder: Container(color: const Color(0xFFF3F2F0)),
                    errorWidget: Container(color: const Color(0xFFF3F2F0)),
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            data.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: isNikeGrid ? 'Inter' : null,
              fontSize: isNikeGrid ? 17 : 14,
              fontWeight: isNikeGrid ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF111111),
              height: 1.25,
            ),
          ),
          if (showPrice && data.price != null) ...[
            const SizedBox(height: 4),
            Text(
              data.price!,
              style: TextStyle(
                fontFamily: isNikeGrid ? 'Inter' : null,
                fontSize: isNikeGrid ? 17 : 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6F6F6F),
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
