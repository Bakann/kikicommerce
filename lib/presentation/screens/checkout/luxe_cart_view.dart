import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/catalog_routes.dart';
import '../../../application/cart/cart_read_models.dart';
import '../../../domain/cart/cart_entities.dart';
import '../../l10n/l10n_extension.dart';
import 'checkout_layout.dart';
import 'checkout_tokens.dart';

/// Luxe (Dior) apparence of the cart page.
///
/// This is the historical `/cart` rendering, extracted verbatim from
/// [MobileCartPage] so the page container can pick a per-theme view. The
/// luxe look (serif headings, light-grey canvas, centered brand wordmark)
/// still lives in the shared `checkout/*` tokens — this extraction is a
/// pure structural move with no visual change.
class LuxeCartView extends StatelessWidget {
  final AsyncValue<CartView?> cartState;
  final bool isCartSyncing;
  final bool signaturePackaging;
  final bool shoppingBag;
  final bool giftWrap;
  final bool securePaymentOpen;
  final bool helpOpen;
  final bool shippingOpen;
  final bool returnsOpen;
  final ValueChanged<bool> onSignaturePackagingChanged;
  final ValueChanged<bool> onShoppingBagChanged;
  final ValueChanged<bool> onGiftWrapChanged;
  final VoidCallback onSecurePaymentToggle;
  final VoidCallback onHelpToggle;
  final VoidCallback onShippingToggle;
  final VoidCallback onReturnsToggle;
  final ValueChanged<CartEntry> onQuantityEdit;
  final ValueChanged<CartEntry> onRemoveEntry;
  final VoidCallback onBack;
  final VoidCallback onCheckout;
  final VoidCallback onPaypal;

  const LuxeCartView({
    super.key,
    required this.cartState,
    required this.isCartSyncing,
    required this.signaturePackaging,
    required this.shoppingBag,
    required this.giftWrap,
    required this.securePaymentOpen,
    required this.helpOpen,
    required this.shippingOpen,
    required this.returnsOpen,
    required this.onSignaturePackagingChanged,
    required this.onShoppingBagChanged,
    required this.onGiftWrapChanged,
    required this.onSecurePaymentToggle,
    required this.onHelpToggle,
    required this.onShippingToggle,
    required this.onReturnsToggle,
    required this.onQuantityEdit,
    required this.onRemoveEntry,
    required this.onBack,
    required this.onCheckout,
    required this.onPaypal,
  });

  @override
  Widget build(BuildContext context) {
    final cartView = cartState.value;

    return Scaffold(
      backgroundColor: kCheckoutBackground,
      body: SafeArea(
        child: CheckoutTextScope(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop =
                  constraints.maxWidth >= kCheckoutDesktopBreakpoint;
              final shell = Column(
                children: [
                  CheckoutHeader(onBack: onBack),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: kCheckoutCardBorder,
                  ),
                  Expanded(
                    // A non-null cart with no entries (e.g. after removing the
                    // last article) must show the empty state, not an empty
                    // bordered order-summary card.
                    child: cartView == null || cartView.entries.isEmpty
                        ? _buildEmptyOrLoading(context, cartState)
                        : CheckoutContent(
                            view: cartView,
                            showTotalsSkeleton: isCartSyncing,
                            signaturePackaging: signaturePackaging,
                            shoppingBag: shoppingBag,
                            giftWrap: giftWrap,
                            securePaymentOpen: securePaymentOpen,
                            helpOpen: helpOpen,
                            shippingOpen: shippingOpen,
                            returnsOpen: returnsOpen,
                            onSignaturePackagingChanged:
                                onSignaturePackagingChanged,
                            onShoppingBagChanged: onShoppingBagChanged,
                            onGiftWrapChanged: onGiftWrapChanged,
                            onSecurePaymentToggle: onSecurePaymentToggle,
                            onHelpToggle: onHelpToggle,
                            onShippingToggle: onShippingToggle,
                            onReturnsToggle: onReturnsToggle,
                            onQuantityEdit: onQuantityEdit,
                            onRemoveEntry: onRemoveEntry,
                            onCheckout: onCheckout,
                            onPaypal: onPaypal,
                          ),
                  ),
                ],
              );

              if (isDesktop) {
                return shell;
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: shell,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrLoading(
    BuildContext context,
    AsyncValue<CartView?> state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.l10n.checkoutEmptyCartTitle,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 36,
                  fontWeight: FontWeight.w500,
                  color: kCheckoutHeading,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.checkoutEmptyCartSubtitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: kCheckoutMuted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go(
                    CatalogRoutes.localizedLocation(
                      CatalogRoutes.catalogBase,
                      locale: Localizations.localeOf(context).languageCode,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: kCheckoutPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(context.l10n.checkoutContinueShopping),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
