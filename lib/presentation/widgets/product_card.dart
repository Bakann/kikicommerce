import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/catalog_routes.dart';
import '../../application/storefront/storefront_plp_profile.dart';
import '../../core/utils/media_image_support.dart';
import '../../core/utils/price_utils.dart';
import '../../domain/cart/cart_exceptions.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../l10n/l10n_extension.dart';
import '../navigation/product_detail_navigation.dart';
import '../providers/cart_flight_coordinator_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/edit_mode_provider.dart';
import '../screens/product_detail_layout_spec.dart';
import 'animations/add_to_cart_comet/add_to_cart_comet.dart';
import 'cart_added_top_sheet.dart';
import 'hero_image_back_button.dart';
import 'kiki_image.dart';
import 'product_hero_tags.dart';
import 'storefront_layout.dart';

/// Hero/navigation metadata a [ProductCard] computed for its tap, handed to a
/// [ProductCardOpenCallback] so a non-PocketBase surface can open its own
/// detail route while reusing the card's exact Hero wiring.
class ProductCardOpenContext {
  final CatalogProduct product;
  final List<CatalogPrice> prices;
  final CatalogCategory? category;
  final String routeName;
  final CatalogMedia? heroListingMedia;
  final bool heroEligible;
  final String? imageHeroTag;

  const ProductCardOpenContext({
    required this.product,
    required this.prices,
    required this.category,
    required this.routeName,
    required this.heroListingMedia,
    required this.heroEligible,
    required this.imageHeroTag,
  });
}

typedef ProductCardOpenCallback =
    Future<void> Function(ProductCardOpenContext openContext);

/// Scroll math for the sport PLP image action.
///
/// The PLP computes these values from fixed grid metrics, then the card derives
/// its icon translation from the scroll offset. This keeps the action following
/// the image like the PLP hero back button without per-card geometry reads on
/// the scroll hot path.
class ProductCardStickyImageActionSpec {
  final ScrollController scrollController;
  final double imageScrollOffset;
  final double imageExtent;
  final double viewportPinTop;

  const ProductCardStickyImageActionSpec({
    required this.scrollController,
    required this.imageScrollOffset,
    required this.imageExtent,
    required this.viewportPinTop,
  });
}

class ProductCard extends ConsumerWidget {
  final CatalogProduct product;
  final List<CatalogPrice> prices;
  final String routeName;
  final CatalogCategory? category;
  final bool enableHeroTransition;
  final ProductCardPresentation presentation;

  /// Optional override for the tap action. Receives the Hero metadata the card
  /// computed. When null, the default PocketBase [openProductDetail] path runs
  /// and opens the product detail route. Surfaces without a PocketBase product
  /// — e.g. the commercetools lab PLP — pass this to push their own detail
  /// route without touching `pdpProvider`/cart.
  final ProductCardOpenCallback? onOpen;

  /// Optional PLP-only scroll spec used by the sport image action.
  final ProductCardStickyImageActionSpec? stickyImageActionSpec;

  const ProductCard({
    super.key,
    required this.product,
    required this.prices,
    required this.routeName,
    this.category,
    this.enableHeroTransition = false,
    this.presentation = ProductCardPresentation.editorial,
    this.onOpen,
    this.stickyImageActionSpec,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final listingMedia = product.listingMedia;
    final imageUrl = listingMedia?.listingUrl;
    final primaryPdpMedia =
        product.picture ??
        (product.gallery.isNotEmpty
            ? product.gallery.first
            : product.thumbnail);

    final defaultPrice = getDefaultPrice(prices);
    final originalPrice = getOriginalPrice(prices);
    final discount = computeDiscount(defaultPrice, originalPrice);
    final isNew = isNewProduct(product.onlineDate);

    final width = MediaQuery.sizeOf(context).width;
    final isTablet = StorefrontLayout.isTabletOnly(width);
    final isDesktop = StorefrontLayout.isDesktop(width);
    final pdpHeroImageUrl = primaryPdpMedia?.thumbUrl(
      _pdpHeroThumbSizeForWidth(width),
    );
    final isEditMode = ref.watch(editModeProvider);
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final canUseImageHero =
        enableHeroTransition &&
        imageUrl != null &&
        pdpHeroImageUrl != null &&
        listingMedia?.id == primaryPdpMedia?.id &&
        !isKnownUnsupportedImageFormat(url: imageUrl) &&
        !isKnownUnsupportedImageFormat(url: pdpHeroImageUrl) &&
        !animationsDisabled &&
        !isEditMode;
    // Scope the Hero tag to "this PLP" so the card cannot accidentally pair
    // with the same product surfaced elsewhere (e.g. a cross-sell on a PDP
    // stacked over this PLP). The destination PDP receives this exact tag
    // through ProductDetailRouteHint and reuses it for its main image Hero.
    final imageHeroTag = canUseImageHero
        ? productImageHeroTag(
            product.id,
            sourceScope: productListingHeroScope(categoryId: category?.id),
          )
        : null;

    final imageSurface = Container(
      color: const Color(0xFFF5F5F5),
      child: imageUrl != null
          ? KikiImage(
              imageUrl: imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorWidget: _placeholder(),
            )
          : _placeholder(),
    );
    // If reduced motion changes between PLP and PDP, Flutter simply renders
    // the unpaired Hero normally; keep this enablement local and simple.
    final productImage = canUseImageHero
        ? Hero(
            tag: imageHeroTag!,
            flightShuttleBuilder: productImageHeroFlightShuttleBuilder(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
            ),
            child: imageSurface,
          )
        : imageSurface;

    // Non-null only when the Hero flight is actually wired for this card.
    final shuttleImageUrl = canUseImageHero ? imageUrl : null;

    final isSport = presentation == ProductCardPresentation.sportPerformance;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: ValueKey('product_card_${product.id}'),
        onTapDown: (_) => warmProductHeroShuttleImage(context, shuttleImageUrl),
        onTap: () async {
          final onOpen = this.onOpen;
          if (onOpen != null) {
            await onOpen(
              ProductCardOpenContext(
                product: product,
                prices: prices,
                category: category,
                routeName: routeName,
                heroListingMedia: canUseImageHero ? listingMedia : null,
                heroEligible: canUseImageHero,
                imageHeroTag: imageHeroTag,
              ),
            );
            return;
          }
          await openProductDetail(
            context,
            ref,
            product: product,
            prices: prices,
            routeName: routeName,
            category: category,
            heroListingMedia: canUseImageHero ? listingMedia : null,
            heroEligible: canUseImageHero,
            imageHeroTag: imageHeroTag,
            source: ProductDetailEntrySource.plp,
          );
        },
        child: Column(
          crossAxisAlignment: isSport
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: isSport ? 1 : 2 / 3,
              child: _ProductCardImageStack(
                productImage: productImage,
                imageUrl: imageUrl,
                isSport: isSport,
                isNew: isNew,
                isDesktop: isDesktop,
                animationsDisabled: animationsDisabled,
                stickyImageActionSpec: stickyImageActionSpec,
                newBadgeLabel: l10n.productCardNewBadge,
                onAddToCart: (sheetMayOpen, flight) => _addToCartFromCard(
                  context,
                  ref,
                  product: product,
                  defaultPrice: defaultPrice,
                  sheetMayOpen: sheetMayOpen,
                  flight: flight,
                ),
              ),
            ),
            if (isSport)
              _buildSportDetails(
                latestLabel: l10n.productCardLatestReleases,
                isNew: isNew,
                defaultPrice: defaultPrice,
                discount: discount,
              )
            else ...[
              const SizedBox(height: 18),
              _buildName(isSport, isDesktop, isTablet),
              const SizedBox(height: 8),
              if (defaultPrice != null)
                _buildPrice(isSport, isDesktop, isTablet, defaultPrice),
              if (discount != null) ...[
                const SizedBox(height: 10),
                _DiscountBadge(discount: discount),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSportDetails({
    required String latestLabel,
    required bool isNew,
    required CatalogPrice? defaultPrice,
    required int? discount,
  }) {
    final summary = product.summary?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNew) ...[
            Text(
              latestLabel,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFC6482F),
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ],
          Text(
            product.name,
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
              height: 1.24,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              summary,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF777777),
                height: 1.32,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (defaultPrice != null) ...[
            const SizedBox(height: 14),
            Text(
              formatPrice(
                defaultPrice.price,
                defaultPrice.currencySymbol ?? '€',
              ),
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
                height: 1.15,
              ),
            ),
          ],
          if (discount != null) ...[
            const SizedBox(height: 4),
            _DiscountBadge(discount: discount),
          ],
        ],
      ),
    );
  }

  Widget _buildName(bool isSport, bool isDesktop, bool isTablet) {
    if (isSport) {
      return Text(
        product.name,
        textAlign: TextAlign.start,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111111),
          height: 1.24,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text(
      product.name,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: isDesktop ? 15 : (isTablet ? 14.5 : 14),
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: const Color(0xFF1B1B1B),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildPrice(
    bool isSport,
    bool isDesktop,
    bool isTablet,
    CatalogPrice defaultPrice,
  ) {
    final formatted = formatPrice(
      defaultPrice.price,
      defaultPrice.currencySymbol ?? '€',
    );
    if (isSport) {
      return Text(
        formatted,
        textAlign: TextAlign.start,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111111),
        ),
      );
    }
    return Text(
      formatted,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: isDesktop ? 15 : (isTablet ? 14.5 : 14),
        fontWeight: FontWeight.w400,
        color: const Color(0xFF1B1B1B).withValues(alpha: 0.55),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 40, color: Color(0xFFCCCCCC)),
      ),
    );
  }

  Future<void> _addToCartFromCard(
    BuildContext context,
    WidgetRef ref, {
    required CatalogProduct product,
    required CatalogPrice? defaultPrice,
    required Future<void> sheetMayOpen,
    AddToCartCometFlightHandle? flight,
  }) async {
    if (defaultPrice == null) {
      flight?.notifyAddFailed();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.pdpPriceUnavailable)));
      return;
    }

    try {
      await ref
          .read(cartControllerProvider.notifier)
          .addProduct(product: product, price: defaultPrice);
    } on MissingCurrencyException {
      flight?.notifyAddFailed();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.pdpCartMissingCurrency)),
        );
      }
      return;
    } on CurrencyMismatchException {
      flight?.notifyAddFailed();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.pdpCartCurrencyMismatch)),
        );
      }
      return;
    } catch (_) {
      flight?.notifyAddFailed();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.pdpCartAddFailed)));
      }
      return;
    }

    // The comet's impact celebration is gated on the add having landed —
    // report it before any context checks so a card unmounted mid-flight
    // still releases the badge deferral correctly.
    flight?.notifyAddSucceeded();

    if (!context.mounted) return;
    await sheetMayOpen;
    if (!context.mounted) return;

    final symbol = defaultPrice.currencySymbol ?? '€';
    ref.read(cartTopSheetOpenProvider.notifier).state = true;
    unawaited(
      showCartAddedTopSheet(
        context: context,
        product: product,
        defaultPrice: defaultPrice,
        symbol: symbol,
        onCheckout: () => context.push(CatalogRoutes.cart),
      ).whenComplete(() {
        if (context.mounted) {
          ref.read(cartTopSheetOpenProvider.notifier).state = false;
          ref.read(cartBackgroundSyncErrorProvider.notifier).state = null;
        }
      }),
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
}

const double _kSportImageActionGap = 10.0;
// Keep the dialog barrier off the screen until the sticker flight has landed
// (1100 ms) and the cart-icon pop has begun.
const Duration _kProductCardCartSheetDelay = Duration(milliseconds: 1250);
const Duration _kProductCardBubbleLeadIn = Duration(milliseconds: 320);

class _DiscountBadge extends StatelessWidget {
  final int discount;

  const _DiscountBadge({required this.discount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F1EE),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '-$discount%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF595956),
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.info_outline, size: 13, color: Colors.grey.shade600),
        ],
      ),
    );
  }
}

class _ProductCardImageStack extends ConsumerStatefulWidget {
  final Widget productImage;
  final String? imageUrl;
  final bool isSport;
  final bool isNew;
  final bool isDesktop;
  final bool animationsDisabled;
  final ProductCardStickyImageActionSpec? stickyImageActionSpec;
  final String newBadgeLabel;
  final Future<void> Function(
    Future<void> sheetMayOpen,
    AddToCartCometFlightHandle? flight,
  )
  onAddToCart;

  const _ProductCardImageStack({
    required this.productImage,
    required this.imageUrl,
    required this.isSport,
    required this.isNew,
    required this.isDesktop,
    required this.animationsDisabled,
    required this.stickyImageActionSpec,
    required this.newBadgeLabel,
    required this.onAddToCart,
  });

  @override
  ConsumerState<_ProductCardImageStack> createState() =>
      _ProductCardImageStackState();
}

class _ProductCardImageStackState
    extends ConsumerState<_ProductCardImageStack> {
  final GlobalKey _imageStackKey = GlobalKey();
  AddToCartCometFlightHandle? _activeFlight;

  /// Runs at t = 0 of the add-to-cart tap: the sticker peels off the card
  /// and departs for the cart. The card itself stays untouched — any effect
  /// layered on it here competes with the peel for legibility.
  void _launchStickerFlight() {
    _activeFlight = null;
    if (!widget.isSport || widget.animationsDisabled) return;
    final imageUrl = widget.imageUrl;
    if (imageUrl == null) return;
    _activeFlight = AddToCartCometController.launch(
      context: context,
      sourceKey: _imageStackKey,
      coordinator: ref.read(cartFlightCoordinatorProvider.notifier),
      imageUrl: imageUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _imageStackKey,
      children: [
        Positioned.fill(child: widget.productImage),
        if (widget.isNew && !widget.isSport)
          Positioned(
            top: 14,
            left: 14,
            child: Text(
              widget.newBadgeLabel,
              style: TextStyle(
                fontSize: widget.isDesktop ? 12 : 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
                color: const Color(0xFF1B1B1B),
              ),
            ),
          ),
        if (widget.isSport)
          Positioned(
            top: _kSportImageActionGap,
            right: _kSportImageActionGap,
            child: _StickyImageActionFollower(
              spec: widget.stickyImageActionSpec,
              child: _AddToCartOverlayButton(
                onTap: (sheetMayOpen) {
                  final flight = _activeFlight;
                  _activeFlight = null;
                  return widget.onAddToCart(sheetMayOpen, flight);
                },
                onFlightRequested: _launchStickerFlight,
                sheetDelay: widget.animationsDisabled
                    ? Duration.zero
                    : _kProductCardCartSheetDelay,
              ),
            ),
          ),
      ],
    );
  }
}

class _StickyImageActionFollower extends StatelessWidget {
  final ProductCardStickyImageActionSpec? spec;
  final Widget child;

  const _StickyImageActionFollower({required this.spec, required this.child});

  @override
  Widget build(BuildContext context) {
    final spec = this.spec;
    if (spec == null) {
      return child;
    }

    return AnimatedBuilder(
      animation: spec.scrollController,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final scrollPixels = spec.scrollController.hasClients
            ? spec.scrollController.offset
            : 0.0;
        final rawTop =
            scrollPixels + spec.viewportPinTop - spec.imageScrollOffset;
        final maxShift =
            spec.imageExtent -
            kHeroImageBackButtonSize -
            (_kSportImageActionGap * 2);
        final shift = (rawTop - _kSportImageActionGap)
            .clamp(0.0, maxShift.clamp(0.0, double.infinity))
            .toDouble();

        return Transform.translate(offset: Offset(0, shift), child: child);
      },
    );
  }
}

/// Add-to-cart affordance overlaid on the sport product card image.
///
/// The button consumes the gesture so tapping it never bubbles to the outer
/// product-card tap target, which would open the PDP instead of adding to cart.
class _AddToCartOverlayButton extends StatefulWidget {
  final Future<void> Function(Future<void> sheetMayOpen) onTap;

  /// Fired synchronously at tap time, before the bubble lead-in: launches
  /// the sticker-peel flight from the card.
  final VoidCallback? onFlightRequested;
  final Duration sheetDelay;

  const _AddToCartOverlayButton({
    required this.onTap,
    required this.sheetDelay,
    this.onFlightRequested,
  });

  @override
  State<_AddToCartOverlayButton> createState() =>
      _AddToCartOverlayButtonState();
}

class _AddToCartOverlayButtonState extends State<_AddToCartOverlayButton> {
  bool _isAdding = false;
  bool _isTapLocked = false;
  bool _triggerBubblePop = false;

  Future<void> _handleTap() async {
    if (_isTapLocked) return;
    final sheetOpenGate = _CartSheetOpenGate(widget.sheetDelay);
    widget.onFlightRequested?.call();
    setState(() {
      _isTapLocked = true;
      _triggerBubblePop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _triggerBubblePop = false);
      }
    });
    await Future<void>.delayed(_kProductCardBubbleLeadIn);
    if (!mounted) {
      sheetOpenGate.cancel();
      return;
    }
    setState(() => _isAdding = true);
    try {
      await widget.onTap(sheetOpenGate.future);
    } finally {
      sheetOpenGate.cancel();
      if (mounted) {
        setState(() {
          _isAdding = false;
          _isTapLocked = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HeroImageGlassIconButton(
      tooltip: context.l10n.pdpAddToCart,
      semanticsLabel: context.l10n.pdpAddToCart,
      onPressed: _handleTap,
      triggerBubblePop: _triggerBubblePop,
      icon: _isAdding
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xE6000000),
              ),
            )
          : const Icon(
              Icons.add_shopping_cart_outlined,
              size: 23,
              color: Color(0xE6000000),
            ),
    );
  }
}

class _CartSheetOpenGate {
  final Completer<void> _completer = Completer<void>();
  Timer? _timer;

  _CartSheetOpenGate(Duration delay) {
    if (delay == Duration.zero) {
      _completer.complete();
    } else {
      _timer = Timer(delay, _completer.complete);
    }
  }

  Future<void> get future => _completer.future;

  void cancel() {
    _timer?.cancel();
    _timer = null;
    if (!_completer.isCompleted) _completer.complete();
  }
}
