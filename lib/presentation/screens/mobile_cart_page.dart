import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/catalog_routes.dart';
import '../../application/cart/cart_read_models.dart';
import '../../application/storefront/storefront_sport_segment.dart';
import '../../application/storefront/storefront_theme.dart';
import '../../domain/cart/cart_entities.dart';
import '../providers/cart_provider.dart';
import '../providers/edit_mode_provider.dart';
import '../providers/sport_segment_providers.dart';
import '../providers/storefront_theme_providers.dart';
import 'checkout/cart_theme_tokens.dart';
import 'checkout/checkout_tokens.dart';
import '../l10n/l10n_extension.dart';
import 'checkout/luxe_cart_view.dart';
import 'checkout/sport_cart_quantity_sheet.dart';
import 'checkout/sport_cart_view.dart';

// Both copies of these helpers also exist in `mobile_checkout_page.dart`
// for the funnel pages. They're 4 lines each and have no dependencies —
// duplicating is cheaper than extracting to a shared file for two
// usages. Promote them to a shared module when a third caller appears.
bool _isGuestCart(Cart cart) {
  final userId = cart.userId?.trim();
  return userId == null || userId.isEmpty;
}

void _showCartMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Cart page mounted at `/cart`.
///
/// Container that owns the cart data, the (luxe) packaging/accordion toggle
/// state, and the mutation handlers, then delegates rendering to a per-theme
/// view: [LuxeCartView] (Dior) or [SportCartView] (Nike). The page lives
/// outside the `ShellRoute`, so each view is responsible for its own chrome
/// (the Sport view mounts its own floating bottom nav).
///
/// The "Commander" CTA pushes the actual checkout funnel
/// (`/checkout/access`), which lives in `mobile_checkout_page.dart` under
/// [MobileCheckoutAccessPage].
class MobileCartPage extends ConsumerStatefulWidget {
  const MobileCartPage({super.key});

  @override
  ConsumerState<MobileCartPage> createState() => _MobileCartPageState();
}

class _MobileCartPageState extends ConsumerState<MobileCartPage> {
  bool _signaturePackaging = true;
  bool _shoppingBag = false;
  bool _giftWrap = false;
  bool _securePaymentOpen = true;
  bool _helpOpen = false;
  bool _shippingOpen = false;
  bool _returnsOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(cartControllerProvider);
      if (!state.hasValue || state.value == null) {
        ref.read(cartControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartControllerProvider);
    final isCartSyncing = ref.watch(cartIsSyncingProvider);
    final themeAsync = ref.watch(effectiveStorefrontThemeAsyncProvider);

    // While the visitor's theme choice resolves we render a neutral white
    // shell rather than the luxe view — otherwise a Sport visitor would see a
    // brief luxe flash before the override loads (same reasoning as the
    // neutral shell `MainShell` uses for chrome). The cart data keeps loading
    // underneath; the resolved view picks up its own empty/loading state.
    return themeAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => _buildLuxe(cartState, isCartSyncing),
      data: (theme) => switch (theme) {
        StorefrontTheme.nike => _buildSport(cartState, isCartSyncing),
        StorefrontTheme.dior => _buildLuxe(cartState, isCartSyncing),
      },
    );
  }

  Widget _buildLuxe(AsyncValue<CartView?> cartState, bool isCartSyncing) {
    return LuxeCartView(
      cartState: cartState,
      isCartSyncing: isCartSyncing,
      signaturePackaging: _signaturePackaging,
      shoppingBag: _shoppingBag,
      giftWrap: _giftWrap,
      securePaymentOpen: _securePaymentOpen,
      helpOpen: _helpOpen,
      shippingOpen: _shippingOpen,
      returnsOpen: _returnsOpen,
      onSignaturePackagingChanged: (value) {
        setState(() => _signaturePackaging = value);
      },
      onShoppingBagChanged: (value) {
        setState(() => _shoppingBag = value);
      },
      onGiftWrapChanged: (value) {
        setState(() => _giftWrap = value);
      },
      onSecurePaymentToggle: () {
        setState(() => _securePaymentOpen = !_securePaymentOpen);
      },
      onHelpToggle: () {
        setState(() => _helpOpen = !_helpOpen);
      },
      onShippingToggle: () {
        setState(() => _shippingOpen = !_shippingOpen);
      },
      onReturnsToggle: () {
        setState(() => _returnsOpen = !_returnsOpen);
      },
      onQuantityEdit: (entry) => _editQuantity(context, entry),
      onRemoveEntry: _removeEntry,
      onBack: _handleBack,
      onCheckout: () => _handleCheckout(context, cartState.value),
      onPaypal: () => _showCartMessage(
        context,
        'Le paiement PayPal sera branché avec le checkout.',
      ),
    );
  }

  Widget _buildSport(AsyncValue<CartView?> cartState, bool isCartSyncing) {
    return SportCartView(
      cartState: cartState,
      isCartSyncing: isCartSyncing,
      tokens: CartThemeTokens.nike,
      onShop: _openLastSportSegment,
      onQuantityEdit: (entry) => _editQuantitySport(context, entry),
      onClearCart: _clearCart,
      onCheckout: () => _handleCheckout(context, cartState.value),
      onHomeTripleTap: () {
        ref.read(editControlsVisibleProvider.notifier).state = true;
      },
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(
      CatalogRoutes.localizedLocation(
        CatalogRoutes.home,
        locale: Localizations.localeOf(context).languageCode,
      ),
    );
  }

  Future<void> _editQuantity(BuildContext context, CartEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final updateError = context.l10n.cartUpdateQuantityError;
    final nextQuantity = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.72;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.cartEditQuantityTitle,
                    style: checkoutSerif(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: kCheckoutHeading,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: 10,
                      itemBuilder: (context, index) {
                        final quantity = index + 1;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            context.l10n.cartQuantityLabelLong(quantity),
                            style: checkoutSans(fontSize: 15.5),
                          ),
                          trailing: quantity == entry.quantity
                              ? const Icon(Icons.check, color: kCheckoutPrimary)
                              : null,
                          onTap: () => Navigator.of(context).pop(quantity),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || nextQuantity == null || nextQuantity == entry.quantity) {
      return;
    }

    try {
      await ref
          .read(cartControllerProvider.notifier)
          .updateQuantity(entry: entry, quantity: nextQuantity);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(updateError)));
    }
  }

  /// Sport quantity flow: open the Sport sheet, then apply the result.
  /// `0` means "Retirer l'article" (the Sport line item folds removal into the
  /// quantity sheet); `null` means dismissed.
  Future<void> _editQuantitySport(BuildContext context, CartEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final updateError = context.l10n.cartUpdateQuantityError;
    final result = await showSportQuantitySheet(
      context,
      currentQuantity: entry.quantity,
    );

    if (!mounted || result == null) {
      return;
    }
    if (result == 0) {
      await _removeEntry(entry);
      return;
    }
    if (result == entry.quantity) {
      return;
    }

    try {
      await ref
          .read(cartControllerProvider.notifier)
          .updateQuantity(entry: entry, quantity: result);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(updateError)));
    }
  }

  /// Empty-state CTA: return the visitor to the last Sport segment they
  /// browsed (there is no bare `/sport` route — only `/sport/{segment}`),
  /// defaulting to Homme on a cold start.
  Future<void> _openLastSportSegment() async {
    final segment =
        await ref.read(lastSportSegmentStoreProvider).read() ??
        StorefrontSportSegment.fallback;
    if (!mounted) return;
    if (!context.mounted) return;
    context.go(
      CatalogRoutes.localizedLocation(
        CatalogRoutes.sportSegmentLocation(segment),
        locale: Localizations.localeOf(context).languageCode,
      ),
    );
  }

  Future<void> _removeEntry(CartEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final removeError = context.l10n.cartRemoveItemError;
    try {
      await ref.read(cartControllerProvider.notifier).removeEntry(entry);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(removeError)));
    }
  }

  Future<bool> _clearCart() async {
    final messenger = ScaffoldMessenger.of(context);
    final removeError = context.l10n.cartRemoveItemError;
    try {
      await ref.read(cartControllerProvider.notifier).clearCart();
      return true;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(removeError)));
      return false;
    }
  }

  void _handleCheckout(BuildContext context, CartView? view) {
    if (view == null) {
      return;
    }
    if (_isGuestCart(view.cart)) {
      context.push(CatalogRoutes.checkoutAccessLocation());
      return;
    }

    _showCartMessage(
      context,
      'Le checkout complet arrive à la prochaine étape.',
    );
  }
}
