import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_shaders/flutter_shaders.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/cart/cart_read_models.dart';
import '../../../domain/cart/cart_entities.dart';
import '../../widgets/navigation/sport_bottom_nav_overlay.dart';
import 'cart_theme_tokens.dart';
import 'sport_cart_checkout_bar.dart';
import 'sport_cart_delivery_section.dart';
import 'sport_cart_line_item.dart';
import 'sport_cart_receipt.dart';

const String _kSportCartBurnShaderAsset =
    'assets/shaders/cart_burning_texture_fade.frag';
const Duration _kSportCartBurnDuration = Duration(milliseconds: 1650);

/// Lead-in that dims the frozen cart to a dark stage before the burn shader
/// runs, so the shader's embers read as bright fire against black instead of
/// washing out on the white page.
const Duration _kSportCartDarkenDuration = Duration(milliseconds: 900);

/// How far toward black the pre-burn dim pushes the cart (1.0 == pure black).
/// Kept just shy of black so a whisper of the cart's form survives the dim.
const double _kSportCartDarkenStrength = 0.85;

/// Fade that eases the empty-cart "Acheter" CTA in once the burn has finished,
/// so it doesn't pop into place on the reveal frame.
const Duration _kSportCartCtaRevealDuration = Duration(milliseconds: 450);

/// Sport (Nike) apparence of the cart page.
///
/// White canvas, left-aligned "Panier" wordmark, bold Inter type, and a
/// self-mounted [SportBottomNavOverlay] — `/cart` lives outside the
/// `ShellRoute`, so the floating bottom nav isn't inherited from `MainShell`
/// and has to be rendered here.
///
/// Structure is dedicated (not a reskin of the luxe `CheckoutContent`): each
/// line item is followed by its own static pickup block. The order summary
/// stays in the scrollable content after the last item, while only the
/// "Paiement" CTA remains pinned at the bottom.
class SportCartView extends StatefulWidget {
  final AsyncValue<CartView?> cartState;
  final bool isCartSyncing;
  final CartThemeTokens tokens;

  /// Empty-state CTA target (the last Sport segment the visitor browsed).
  final VoidCallback onShop;
  final ValueChanged<CartEntry> onQuantityEdit;
  final Future<bool> Function() onClearCart;
  final VoidCallback onCheckout;
  final VoidCallback? onHomeTripleTap;

  const SportCartView({
    super.key,
    required this.cartState,
    required this.isCartSyncing,
    required this.tokens,
    required this.onShop,
    required this.onQuantityEdit,
    required this.onClearCart,
    required this.onCheckout,
    this.onHomeTripleTap,
  });

  @override
  State<SportCartView> createState() => _SportCartViewState();
}

class _SportCartViewState extends State<SportCartView>
    with TickerProviderStateMixin {
  late final AnimationController _burnController = AnimationController(
    vsync: this,
    duration: _kSportCartBurnDuration,
  );

  // Drives the pre-burn dim; not merged into `_burnController` so its short
  // lead-in can complete before the (longer) burn timeline starts.
  late final AnimationController _darkenController = AnimationController(
    vsync: this,
    duration: _kSportCartDarkenDuration,
  );

  // Fades the empty-cart CTA in after the burn. Starts at 1 so a cart that is
  // already empty (no burn) shows the button straight away; the burn flow
  // replays it from 0.
  late final AnimationController _ctaRevealController = AnimationController(
    vsync: this,
    duration: _kSportCartCtaRevealDuration,
    value: 1,
  );
  late final CurvedAnimation _ctaReveal = CurvedAnimation(
    parent: _ctaRevealController,
    curve: Curves.easeOut,
  );

  CartView? _burningView;
  bool _clearInFlight = false;
  bool _forceEmptyBody = false;
  bool _burnShaderPrecached = false;

  @override
  void initState() {
    super.initState();
    _burnController.addStatusListener(_handleBurnStatus);
  }

  // Warm the burn shader only once the cart actually has something to burn.
  // Precaching it unconditionally on mount compiled the FragmentProgram during
  // an empty cart's first (cold) frame — needless work that, on skwasm, could
  // land in the same frame as text/chrome layout and destabilise the renderer.
  // A cart that can be cleared still warms the shader ahead of the burn.
  void _maybePrecacheBurnShader() {
    if (_burnShaderPrecached) return;
    final view = widget.cartState.value;
    if (view == null || view.entries.isEmpty) return;
    _burnShaderPrecached = true;
    unawaited(ShaderBuilder.precacheShader(_kSportCartBurnShaderAsset));
  }

  @override
  void dispose() {
    _burnController.removeStatusListener(_handleBurnStatus);
    _burnController.dispose();
    _darkenController.dispose();
    _ctaReveal.dispose();
    _ctaRevealController.dispose();
    super.dispose();
  }

  void _handleBurnStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _burnController.status != AnimationStatus.completed) {
        return;
      }
      final revealsEmptyState = !_clearInFlight;
      setState(() {
        _burningView = null;
        if (revealsEmptyState) {
          _forceEmptyBody = false;
        }
      });
      if (revealsEmptyState) {
        // Ease the CTA in now that the burn uncovered the empty state, instead
        // of snapping it onto the reveal frame.
        _ctaRevealController.forward(from: 0);
      }
    });
  }

  Future<void> _handleClearCart() async {
    final cartView = widget.cartState.value;
    if (_clearInFlight || cartView == null || cartView.entries.isEmpty) {
      return;
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion) {
      _burnController.value = 0;
      _darkenController.value = 0;
    }
    setState(() {
      _clearInFlight = true;
      if (!reduceMotion) {
        _burningView = cartView;
      }
    });

    if (!reduceMotion) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      // Start dimming the frozen cart as soon as the snapshot is on screen,
      // overlapping the network clear so the dark stage is (usually) ready by
      // the time the burn fires.
      unawaited(_darkenController.forward(from: 0));
    }

    final cleared = await widget.onClearCart();
    if (!mounted) return;

    if (!cleared) {
      _darkenController.stop();
      _darkenController.value = 0;
      setState(() {
        _burningView = null;
        _clearInFlight = false;
      });
      return;
    }

    if (reduceMotion) {
      setState(() => _clearInFlight = false);
      return;
    }

    setState(() {
      _clearInFlight = false;
      _forceEmptyBody = true;
    });

    // Let the dim reach black before the shader eats the frame, so the
    // darkening reads as a distinct lead-in rather than overlapping the burn.
    if (_darkenController.status == AnimationStatus.forward) {
      await _darkenController.forward();
      if (!mounted) return;
    }
    unawaited(_burnController.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    _maybePrecacheBurnShader();
    final body = _buildBody(context);
    final cartView = widget.cartState.value;
    final showClearCart =
        !_forceEmptyBody && (cartView?.entries.isNotEmpty ?? false);
    final clearCartAction =
        showClearCart && !widget.isCartSyncing && !_clearInFlight
        ? _handleClearCart
        : null;
    // The receipt is read-only, so it stays available even while the cart is
    // syncing — only hidden once the cart is empty or being cleared.
    final receiptAction = showClearCart && !_clearInFlight
        ? _handleShowReceipt
        : null;
    final page = Stack(
      fit: StackFit.expand,
      children: [
        _buildPageChrome(
          body,
          showClearCart: showClearCart,
          onClearCart: clearCartAction,
          onShowReceipt: receiptAction,
        ),
        if (_burningView case final burningView?)
          Positioned.fill(
            child: IgnorePointer(
              child: _SportCartBurnAway(
                controller: _burnController,
                darken: _darkenController,
                child: ColoredBox(
                  color: widget.tokens.background,
                  child: _buildPageChrome(
                    _SportPopulatedCart(
                      view: burningView,
                      tokens: widget.tokens,
                      isCartSyncing: false,
                      onQuantityEdit: widget.onQuantityEdit,
                      onCheckout: widget.onCheckout,
                    ),
                    showClearCart: true,
                    onClearCart: null,
                    onShowReceipt: null,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: widget.tokens.background,
      body: SportBottomNavOverlay(
        onHomeTripleTap: widget.onHomeTripleTap,
        child: page,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cartView = widget.cartState.value;
    // After removing the last article the cart is a non-null CartView with an
    // empty `entries` list — both cases must show the empty state.
    if (_forceEmptyBody || cartView == null || cartView.entries.isEmpty) {
      return _buildEmptyOrLoading(
        context,
        forceEmpty: _forceEmptyBody,
        showPrimaryCta: !(_forceEmptyBody && _burningView != null),
      );
    }

    return _SportPopulatedCart(
      view: cartView,
      tokens: widget.tokens,
      isCartSyncing: widget.isCartSyncing || _clearInFlight,
      onQuantityEdit: widget.onQuantityEdit,
      onCheckout: widget.onCheckout,
    );
  }

  void _handleShowReceipt() {
    final cartView = widget.cartState.value;
    if (cartView == null || cartView.entries.isEmpty) return;
    showSportCartReceipt(context, view: cartView);
  }

  Widget _buildPageChrome(
    Widget body, {
    required bool showClearCart,
    required VoidCallback? onClearCart,
    required VoidCallback? onShowReceipt,
  }) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SportCartHeader(
            tokens: widget.tokens,
            showClearCart: showClearCart,
            onClearCart: onClearCart,
            onShowReceipt: onShowReceipt,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildEmptyOrLoading(
    BuildContext context, {
    bool forceEmpty = false,
    bool showPrimaryCta = true,
  }) {
    if (widget.cartState.isLoading && !forceEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD7D7D7),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 32,
                      color: widget.tokens.primaryText,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Ton panier est vide.',
                    textAlign: TextAlign.center,
                    style: widget.tokens.titleStyle.copyWith(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Les produits ajoutés apparaîtront ici.',
                    textAlign: TextAlign.center,
                    style: widget.tokens.captionStyle.copyWith(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          // Fixed slot so revealing the CTA never resizes the Expanded above
          // it (which would nudge the centred empty-state text). The button is
          // pinned to the same height as the placeholder it replaces.
          SizedBox(
            height: 58,
            child: showPrimaryCta
                ? FadeTransition(
                    opacity: _ctaReveal,
                    child: SportPrimaryButton(
                      label: 'Acheter',
                      onPressed: widget.onShop,
                      tokens: widget.tokens,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _SportCartBurnAway extends StatelessWidget {
  final AnimationController controller;

  /// 0 → 1 pre-burn dim. Applied *inside* the sampled subtree so the shader
  /// samples an already-darkened cart and its embers pop against black.
  final Animation<double> darken;
  final Widget child;

  const _SportCartBurnAway({
    required this.controller,
    required this.darken,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Merge both so the sampler repaints while the dim ramps (the burn
      // controller is idle at 0 during that lead-in).
      animation: Listenable.merge([controller, darken]),
      child: child,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final darkAlpha =
            Curves.easeInOut.transform(darken.value.clamp(0.0, 1.0)) *
            _kSportCartDarkenStrength;
        final staged = darkAlpha <= 0.0
            ? child
            : ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: darkAlpha),
                  BlendMode.srcOver,
                ),
                child: child,
              );
        return RepaintBoundary(
          child: ShaderBuilder(
            (context, shader, shaderChild) {
              final sampledChild = shaderChild ?? const SizedBox.shrink();
              return AnimatedSampler((
                ui.Image image,
                Size size,
                ui.Canvas canvas,
              ) {
                if (size.isEmpty) return;
                shader
                  ..setFloat(0, size.width)
                  ..setFloat(1, size.height)
                  ..setFloat(2, controller.value)
                  ..setImageSampler(0, image);
                canvas.drawRect(
                  Offset.zero & size,
                  ui.Paint()..shader = shader,
                );
              }, child: sampledChild);
            },
            assetKey: _kSportCartBurnShaderAsset,
            child: staged,
          ),
        );
      },
    );
  }
}

class _SportCartHeader extends StatelessWidget {
  final CartThemeTokens tokens;
  final bool showClearCart;
  final VoidCallback? onClearCart;
  final VoidCallback? onShowReceipt;

  const _SportCartHeader({
    required this.tokens,
    required this.showClearCart,
    required this.onClearCart,
    required this.onShowReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (onShowReceipt != null)
        _HeaderIconButton(
          tooltip: 'Voir la facture',
          icon: LucideIcons.receiptText,
          onPressed: onShowReceipt,
          tokens: tokens,
        ),
      if (showClearCart)
        _HeaderIconButton(
          tooltip: 'Vider le panier',
          icon: LucideIcons.trash2,
          onPressed: onClearCart,
          tokens: tokens,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Panier',
              style: tokens.titleStyle.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actions.isEmpty)
            const SizedBox.square(dimension: 40)
          else
            Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final CartThemeTokens tokens;

  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      color: tokens.primaryText,
      disabledColor: tokens.secondaryText.withValues(alpha: 0.45),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(40),
        minimumSize: const Size.square(40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SportPopulatedCart extends StatelessWidget {
  final CartView view;
  final CartThemeTokens tokens;
  final bool isCartSyncing;
  final ValueChanged<CartEntry> onQuantityEdit;
  final VoidCallback onCheckout;

  const _SportPopulatedCart({
    required this.view,
    required this.tokens,
    required this.isCartSyncing,
    required this.onQuantityEdit,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = _currencySymbolFromCode(view.cart.currencyCode);
    final entries = view.entries;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                SportCartLineItem(
                  entry: entries[i],
                  symbol: symbol,
                  tokens: tokens,
                  onEditQuantity: () => onQuantityEdit(entries[i]),
                ),
                const SizedBox(height: 16),
                SportCartDeliverySection(tokens: tokens),
                if (i != entries.length - 1)
                  Divider(height: 40, thickness: 1, color: tokens.border),
              ],
              const SizedBox(height: 22),
              SportCartSummary(
                tokens: tokens,
                totals: view.cart.totals,
                symbol: symbol,
                isCartSyncing: isCartSyncing,
              ),
            ],
          ),
        ),
        SportCartCheckoutBar(
          tokens: tokens,
          isCartSyncing: isCartSyncing,
          onCheckout: onCheckout,
        ),
      ],
    );
  }
}

String _currencySymbolFromCode(String? code) {
  switch ((code ?? 'EUR').toUpperCase()) {
    case 'EUR':
      return ' €';
    case 'USD':
      return ' \$';
    case 'GBP':
      return ' £';
    default:
      return ' ${(code ?? 'EUR').toUpperCase()}';
  }
}
