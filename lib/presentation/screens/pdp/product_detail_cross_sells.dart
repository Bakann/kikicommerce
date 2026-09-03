import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/catalog_routes.dart';
import '../../../core/utils/media_image_support.dart';
import '../../../domain/catalog/catalog_entities.dart';
import '../../l10n/l10n_extension.dart';
import '../../navigation/product_detail_navigation.dart';
import '../../providers/edit_mode_provider.dart';
import '../../providers/product_providers.dart';
import '../../widgets/kiki_image.dart';
import '../../widgets/product_hero_tags.dart';
import '../../widgets/storefront_layout.dart';
import '../product_detail_layout_spec.dart';

class ProductDetailCrossSellArea extends ConsumerStatefulWidget {
  final String? categoryId;
  final String currentProductId;
  // Hero tag of the *current* PDP's main image. Used as the scope seed for
  // cross-sell card Heroes so they cannot pair with PLP cards (which carry
  // a PLP-scoped tag) — only with the destination PDP they push, which
  // receives the same scoped tag through ProductDetailRouteHint.
  final String? currentMainImageHeroTag;

  const ProductDetailCrossSellArea({
    super.key,
    required this.categoryId,
    required this.currentProductId,
    this.currentMainImageHeroTag,
  });

  @override
  ConsumerState<ProductDetailCrossSellArea> createState() =>
      _ProductDetailCrossSellAreaState();
}

class _ProductDetailCrossSellAreaState
    extends ConsumerState<ProductDetailCrossSellArea> {
  Animation<double>? _routeAnimation;
  bool _routeSettled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextAnimation = ModalRoute.of(context)?.animation;
    if (identical(_routeAnimation, nextAnimation)) {
      _routeSettled = _isRouteSettled(nextAnimation);
      return;
    }

    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _routeAnimation = nextAnimation;
    _routeAnimation?.addStatusListener(_handleRouteAnimationStatus);
    _routeSettled = _isRouteSettled(nextAnimation);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    super.dispose();
  }

  bool _isRouteSettled(Animation<double>? animation) {
    return animation == null || animation.status == AnimationStatus.completed;
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    final nextSettled = status == AnimationStatus.completed;
    if (nextSettled == _routeSettled || !mounted) {
      return;
    }
    setState(() {
      _routeSettled = nextSettled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final resolvedCategoryId = widget.categoryId;
    if (resolvedCategoryId == null || resolvedCategoryId.isEmpty) {
      return const SizedBox.shrink();
    }

    // Watch only the resolved items, not the AsyncValue wrapper — the
    // cross-sell area only renders when the PLP has actually settled, and
    // the items list is what drives the candidates filter below. This
    // avoids re-running build on every PLP loading/refresh transition.
    final items = ref.watch(
      plpProvider(resolvedCategoryId).select((async) => async.value?.items),
    );
    if (items == null) {
      return const SizedBox.shrink();
    }

    final candidates = items
        .where((item) => item.productId != widget.currentProductId)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return const SizedBox.shrink();
    }

    final heroScope = productPdpCrossSellHeroScope(
      currentProductId: widget.currentProductId,
      currentMainImageHeroTag: widget.currentMainImageHeroTag,
    );
    final heroProductIds = <String>{};
    List<_PdpCrossSellEntry> buildEntries(
      Iterable<CatalogListingItem> sourceItems,
    ) {
      return [
        for (final item in sourceItems)
          _PdpCrossSellEntry(
            item: item,
            enableHeroTransition:
                _routeSettled && heroProductIds.add(item.productId),
          ),
      ];
    }

    final relatedSource = candidates.take(4).toList(growable: false);
    final relatedProductIds = relatedSource
        .map((item) => item.productId)
        .toSet();
    final recentSource = candidates.reversed
        .where((item) => !relatedProductIds.contains(item.productId))
        .take(5);
    final relatedItems = buildEntries(relatedSource);
    final recentItems = buildEntries(recentSource);

    return StorefrontFullBleed(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            if (relatedItems.isNotEmpty)
              _PdpCrossSellSection(
                title: context.l10n.pdpCrossSellsTitle,
                items: relatedItems,
                mode: _PdpCrossSellMode.grid,
                heroScope: heroScope,
              ),
            if (recentItems.isNotEmpty)
              _PdpCrossSellSection(
                title: context.l10n.pdpRecentlyViewed,
                items: recentItems,
                mode: _PdpCrossSellMode.carousel,
                heroScope: heroScope,
              ),
          ],
        ),
      ),
    );
  }
}

enum _PdpCrossSellMode { grid, carousel }

class _PdpCrossSellEntry {
  final CatalogListingItem item;
  final bool enableHeroTransition;

  const _PdpCrossSellEntry({
    required this.item,
    required this.enableHeroTransition,
  });
}

class _PdpCrossSellSection extends StatelessWidget {
  final String title;
  final List<_PdpCrossSellEntry> items;
  final _PdpCrossSellMode mode;
  final String heroScope;

  const _PdpCrossSellSection({
    required this.title,
    required this.items,
    required this.mode,
    required this.heroScope,
  });

  @override
  Widget build(BuildContext context) {
    final isCarousel = mode == _PdpCrossSellMode.carousel;
    final isMobile = ProductDetailLayoutSpec.forWidth(
      MediaQuery.sizeOf(context).width,
    ).isMobile;
    return Padding(
      padding: EdgeInsets.only(
        top: isMobile ? (isCarousel ? 124 : 108) : (isCarousel ? 118 : 108),
        bottom: isMobile ? (isCarousel ? 104 : 28) : (isCarousel ? 118 : 28),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerif(
              fontSize: isMobile ? 23 : 31,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF343431),
              height: 1.1,
            ),
          ),
          SizedBox(height: isMobile ? 48 : (isCarousel ? 60 : 54)),
          if (isCarousel || isMobile)
            _PdpCrossSellCarousel(items: items, heroScope: heroScope)
          else
            _PdpCrossSellGrid(items: items, heroScope: heroScope),
        ],
      ),
    );
  }
}

class _PdpCrossSellGrid extends StatelessWidget {
  final List<_PdpCrossSellEntry> items;
  final String heroScope;

  const _PdpCrossSellGrid({required this.items, required this.heroScope});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 48.0;
        const itemSpacing = 14.0;
        final itemCount = items.length;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final contentWidth = (availableWidth - (horizontalPadding * 2)).clamp(
          0.0,
          double.infinity,
        );
        final totalSpacing = itemCount <= 1
            ? 0.0
            : itemSpacing * (itemCount - 1);
        final cardWidth = itemCount == 0
            ? 0.0
            : ((contentWidth - totalSpacing) / itemCount).clamp(0.0, 470.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < itemCount; index++) ...[
                SizedBox(
                  width: cardWidth,
                  child: _PdpCrossSellCard(
                    entry: items[index],
                    heroScope: heroScope,
                  ),
                ),
                if (index < itemCount - 1) const SizedBox(width: itemSpacing),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PdpCrossSellCarousel extends StatefulWidget {
  final List<_PdpCrossSellEntry> items;
  final String heroScope;

  const _PdpCrossSellCarousel({required this.items, required this.heroScope});

  @override
  State<_PdpCrossSellCarousel> createState() => _PdpCrossSellCarouselState();
}

class _PdpCrossSellCarouselState extends State<_PdpCrossSellCarousel> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollNext() {
    if (!_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final cardWidth = _pdpCrossSellCardWidth(context);
    final nextPixels = (position.pixels + cardWidth + 14)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    position.animateTo(
      nextPixels,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ProductDetailLayoutSpec.forWidth(
      MediaQuery.sizeOf(context).width,
    ).isMobile;
    final cardWidth = _pdpCrossSellCardWidth(context);
    final carouselHeight = (cardWidth / 0.67) + (isMobile ? 126 : 138);
    final itemSpacing = isMobile ? 8.0 : 14.0;
    final horizontalPadding = isMobile
        ? ((MediaQuery.sizeOf(context).width - cardWidth) / 2)
              .clamp(14.0, 44.0)
              .toDouble()
        : 14.0;
    return SizedBox(
      height: carouselHeight,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              child: _PdpCrossSellCard(
                entry: widget.items[index],
                heroScope: widget.heroScope,
              ),
            ),
            separatorBuilder: (context, index) => SizedBox(width: itemSpacing),
            itemCount: widget.items.length,
          ),
          if (!isMobile && widget.items.length > 4)
            Positioned(
              right: 22,
              child: _PdpCrossSellArrowButton(onPressed: _scrollNext),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: _PdpCrossSellProgressBar(
                controller: _controller,
                itemCount: widget.items.length,
                visibleItemCount: isMobile ? 1 : 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _pdpCrossSellCardWidth(BuildContext context) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  if (ProductDetailLayoutSpec.forWidth(screenWidth).isMobile) {
    return (screenWidth - 44).clamp(260.0, 430.0).toDouble();
  }
  final target = (screenWidth - 96 - 42) / 4;
  return target.clamp(320.0, 470.0).toDouble();
}

class _PdpCrossSellCard extends ConsumerWidget {
  final _PdpCrossSellEntry entry;
  final String heroScope;

  const _PdpCrossSellCard({required this.entry, required this.heroScope});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = entry.item;
    final product = item.product;
    final media = product.listingMedia;
    final primaryPdpMedia =
        product.picture ??
        (product.gallery.isNotEmpty
            ? product.gallery.first
            : product.thumbnail);
    final category = item.category;
    final routeName = CatalogRoutes.productLocation(
      category: category,
      product: product,
      productSlug: item.productRouteSlug,
    );
    final width = MediaQuery.sizeOf(context).width;
    final pdpHeroImageUrl = primaryPdpMedia?.thumbUrl(
      _pdpHeroThumbSizeForWidth(width),
    );
    final isEditMode = ref.watch(editModeProvider);
    final canUseImageHero =
        entry.enableHeroTransition &&
        media != null &&
        pdpHeroImageUrl != null &&
        media.id == primaryPdpMedia?.id &&
        !isKnownUnsupportedImageFormat(url: media.listingUrl) &&
        !isKnownUnsupportedImageFormat(url: pdpHeroImageUrl) &&
        !MediaQuery.disableAnimationsOf(context) &&
        !isEditMode;
    // PDP-cross-sell-scoped tag. Cannot collide with the PLP-scoped tag of
    // the same product (so an open PLP underneath this PDP won't trigger a
    // ghost flight on pop), and matches the tag the destination PDP will
    // adopt via ProductDetailRouteHint.imageHeroTag.
    final imageHeroTag = canUseImageHero
        ? productImageHeroTag(product.id, sourceScope: heroScope)
        : null;

    final imageSurface = Container(
      color: const Color(0xFFF6F6F6),
      child: media == null
          ? const Center(
              child: Icon(
                Icons.image_outlined,
                size: 38,
                color: Color(0xFFC8C8C8),
              ),
            )
          : KikiImage(
              imageUrl: media.listingUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
    );
    final productImage = canUseImageHero
        ? Hero(
            tag: imageHeroTag!,
            flightShuttleBuilder: productImageHeroFlightShuttleBuilder(
              imageUrl: media.listingUrl,
              fit: BoxFit.cover,
            ),
            child: imageSurface,
          )
        : imageSurface;
    final shuttleImageUrl = canUseImageHero ? media.listingUrl : null;

    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: 0.67,
          child: Stack(
            children: [
              Positioned.fill(child: productImage),
              Positioned(
                top: 18,
                right: 18,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 18,
                    color: Color(0xFF30302E),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            product.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF30302E),
              height: 1.25,
            ),
          ),
        ),
        if (_subtitle(product) != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              _subtitle(product)!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: productDetailMutedTextColor,
                height: 1.25,
              ),
            ),
          ),
        ],
      ],
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => warmProductHeroShuttleImage(context, shuttleImageUrl),
        onTap: () async {
          await openProductDetail(
            context,
            ref,
            product: product,
            prices: item.prices,
            routeName: routeName,
            category: category,
            heroListingMedia: canUseImageHero ? media : null,
            heroEligible: canUseImageHero,
            imageHeroTag: imageHeroTag,
            source: ProductDetailEntrySource.pdpCrossSell,
          );
        },
        child: card,
      ),
    );
  }

  String _pdpHeroThumbSizeForWidth(double width) {
    return switch (ProductDetailLayoutSpec.forWidth(width).mode) {
      ProductDetailLayoutMode.mobile =>
        CatalogMedia.productDetailMobileThumbSize,
      ProductDetailLayoutMode.split =>
        CatalogMedia.productDetailTabletThumbSize,
      ProductDetailLayoutMode.desktop =>
        CatalogMedia.productDetailDesktopThumbSize,
    };
  }

  String? _subtitle(CatalogProduct product) {
    final productType = product.productType?.trim();
    final brand = product.brand?.trim();
    if (productType != null && productType.isNotEmpty) {
      return brand != null && brand.isNotEmpty
          ? '$productType $brand'
          : productType;
    }
    if (brand != null && brand.isNotEmpty) {
      return brand;
    }
    return null;
  }
}

class _PdpCrossSellArrowButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _PdpCrossSellArrowButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(Icons.chevron_right, size: 30),
          color: const Color(0xFF30302E),
          tooltip: 'Suivant',
        ),
      ),
    );
  }
}

class _PdpCrossSellProgressBar extends StatefulWidget {
  final ScrollController controller;
  final int itemCount;
  final int visibleItemCount;

  const _PdpCrossSellProgressBar({
    required this.controller,
    required this.itemCount,
    required this.visibleItemCount,
  });

  @override
  State<_PdpCrossSellProgressBar> createState() =>
      _PdpCrossSellProgressBarState();
}

class _PdpCrossSellProgressBarState extends State<_PdpCrossSellProgressBar> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant _PdpCrossSellProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScroll);
      widget.controller.addListener(_handleScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    if (!widget.controller.hasClients) {
      return;
    }
    final maxScroll = widget.controller.position.maxScrollExtent;
    final nextProgress = maxScroll <= 0
        ? 0.0
        : (widget.controller.offset / maxScroll).clamp(0.0, 1.0).toDouble();
    if ((nextProgress - _progress).abs() < 0.01) {
      return;
    }
    setState(() {
      _progress = nextProgress;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= widget.visibleItemCount) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: 112,
      height: 2,
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: const Color(0xFFC8C8C8))),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.42 + (_progress * 0.58),
            child: Container(color: const Color(0xFF30302E)),
          ),
        ],
      ),
    );
  }
}
