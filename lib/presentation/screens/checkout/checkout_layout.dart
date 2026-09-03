import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/app_providers.dart';
import '../../../application/cart/cart_read_models.dart';
import '../../../application/storefront/storefront_brand_settings.dart';
import '../../../core/utils/price_utils.dart';
import '../../../domain/cart/cart_entities.dart';
import '../../l10n/l10n_extension.dart';
import 'checkout_line_item.dart';
import 'checkout_packaging.dart';
import 'checkout_summary_widgets.dart';
import 'checkout_tokens.dart';

class CheckoutTextScope extends StatelessWidget {
  final Widget child;

  const CheckoutTextScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: checkoutSans(fontSize: 15, height: 1.35),
      child: child,
    );
  }
}

class CheckoutHeader extends ConsumerWidget {
  final VoidCallback onBack;

  const CheckoutHeader({super.key, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandSettingsAsync = ref.watch(storefrontBrandSettingsProvider);
    final brandSettings =
        brandSettingsAsync.value ?? StorefrontBrandSettings.fallback;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 5, 18, 5),
      child: SizedBox(
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: kCheckoutHeading,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.checkoutBack,
                        style: checkoutSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: kCheckoutHeading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 244),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: brandSettingsAsync.isLoading ? 0.0 : 1.0,
                  child: Text(
                    brandSettings.title,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutContent extends ConsumerWidget {
  final CartView view;
  final bool showTotalsSkeleton;
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
  final VoidCallback onCheckout;
  final VoidCallback onPaypal;

  const CheckoutContent({
    super.key,
    required this.view,
    required this.showTotalsSkeleton,
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
    required this.onCheckout,
    required this.onPaypal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalQuantity = view.entries.fold<int>(
      0,
      (total, entry) => total + entry.quantity,
    );
    final symbol = _currencySymbolFromCode(view.cart.currencyCode);
    final taxesLabel = formatPrice(view.cart.totals.taxTotal, symbol);
    final subtotalLabel = formatPrice(view.cart.totals.subtotal, symbol);
    final grandTotalLabel = formatPrice(
      view.cart.totals.grandTotal > 0
          ? view.cart.totals.grandTotal
          : view.cart.totals.subtotal,
      symbol,
    );
    final brandName = ref.watch(
      storefrontBrandSettingsProvider.select(
        (async) => async.value?.title ?? defaultStorefrontBrandTitle,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kCheckoutDesktopBreakpoint;
        final orderSummary = _OrderSummarySection(
          entries: view.entries,
          totalQuantity: totalQuantity,
          onQuantityEdit: onQuantityEdit,
          onRemoveEntry: onRemoveEntry,
          desktop: isDesktop,
        );
        final packaging = _PackagingSection(
          brandName: brandName,
          signaturePackaging: signaturePackaging,
          shoppingBag: shoppingBag,
          giftWrap: giftWrap,
          onSignaturePackagingChanged: onSignaturePackagingChanged,
          onShoppingBagChanged: onShoppingBagChanged,
          onGiftWrapChanged: onGiftWrapChanged,
        );
        final summary = _CheckoutSummaryPanel(
          subtotalLabel: subtotalLabel,
          taxesLabel: taxesLabel,
          grandTotalLabel: grandTotalLabel,
          showTotalsSkeleton: showTotalsSkeleton,
          securePaymentOpen: securePaymentOpen,
          helpOpen: helpOpen,
          shippingOpen: shippingOpen,
          returnsOpen: returnsOpen,
          onSecurePaymentToggle: onSecurePaymentToggle,
          onHelpToggle: onHelpToggle,
          onShippingToggle: onShippingToggle,
          onReturnsToggle: onReturnsToggle,
          onCheckout: onCheckout,
          onPaypal: onPaypal,
          showFooter: !isDesktop,
        );

        if (!isDesktop) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                orderSummary,
                const SizedBox(height: 30),
                packaging,
                const SizedBox(height: 32),
                summary,
              ],
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kCheckoutDesktopMaxWidth,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(64, 58, 64, 56),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        orderSummary,
                        const SizedBox(height: 54),
                        packaging,
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: kCheckoutCardBorder,
                ),
                SizedBox(
                  width: kCheckoutDesktopSummaryWidth,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(48, 58, 48, 56),
                    child: summary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrderSummarySection extends StatelessWidget {
  final List<CartEntry> entries;
  final int totalQuantity;
  final ValueChanged<CartEntry> onQuantityEdit;
  final ValueChanged<CartEntry> onRemoveEntry;
  final bool desktop;

  const _OrderSummarySection({
    required this.entries,
    required this.totalQuantity,
    required this.onQuantityEdit,
    required this.onRemoveEntry,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: context.l10n.checkoutOrderSummary,
          trailing: context.l10n.checkoutItemCount(totalQuantity),
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kCheckoutCardRadius),
            border: Border.all(color: kCheckoutCardBorder),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                CheckoutLineItem(
                  entry: entries[i],
                  onEditQuantity: () => onQuantityEdit(entries[i]),
                  onRemove: () => onRemoveEntry(entries[i]),
                  desktop: desktop,
                ),
                if (i != entries.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: kCheckoutCardBorder,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PackagingSection extends StatelessWidget {
  final String brandName;
  final bool signaturePackaging;
  final bool shoppingBag;
  final bool giftWrap;
  final ValueChanged<bool> onSignaturePackagingChanged;
  final ValueChanged<bool> onShoppingBagChanged;
  final ValueChanged<bool> onGiftWrapChanged;

  const _PackagingSection({
    required this.brandName,
    required this.signaturePackaging,
    required this.shoppingBag,
    required this.giftWrap,
    required this.onSignaturePackagingChanged,
    required this.onShoppingBagChanged,
    required this.onGiftWrapChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: context.l10n.checkoutPackagingTitle,
          trailing: context.l10n.checkoutPackagingFreeOptions,
        ),
        const SizedBox(height: 14),
        PackagingCard(
          brandName: brandName,
          signaturePackaging: signaturePackaging,
          shoppingBag: shoppingBag,
          giftWrap: giftWrap,
          onSignaturePackagingChanged: onSignaturePackagingChanged,
          onShoppingBagChanged: onShoppingBagChanged,
          onGiftWrapChanged: onGiftWrapChanged,
        ),
        const SizedBox(height: 14),
        Text(
          context.l10n.checkoutPackagingNoPricesNote,
          style: const TextStyle(
            fontSize: 14,
            color: kCheckoutMuted,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _CheckoutSummaryPanel extends StatelessWidget {
  final String subtotalLabel;
  final String taxesLabel;
  final String grandTotalLabel;
  final bool showTotalsSkeleton;
  final bool securePaymentOpen;
  final bool helpOpen;
  final bool shippingOpen;
  final bool returnsOpen;
  final VoidCallback onSecurePaymentToggle;
  final VoidCallback onHelpToggle;
  final VoidCallback onShippingToggle;
  final VoidCallback onReturnsToggle;
  final VoidCallback onCheckout;
  final VoidCallback onPaypal;
  final bool showFooter;

  const _CheckoutSummaryPanel({
    required this.subtotalLabel,
    required this.taxesLabel,
    required this.grandTotalLabel,
    required this.showTotalsSkeleton,
    required this.securePaymentOpen,
    required this.helpOpen,
    required this.shippingOpen,
    required this.returnsOpen,
    required this.onSecurePaymentToggle,
    required this.onHelpToggle,
    required this.onShippingToggle,
    required this.onReturnsToggle,
    required this.onCheckout,
    required this.onPaypal,
    required this.showFooter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: context.l10n.checkoutTotal),
        const SizedBox(height: 12),
        SummaryRow(
          label: context.l10n.checkoutSubtotal,
          value: showTotalsSkeleton ? null : subtotalLabel,
          customValue: showTotalsSkeleton ? const SummarySkeleton() : null,
        ),
        const SizedBox(height: 14),
        SummaryRow(
          label: context.l10n.checkoutShipping,
          customValue: Text(
            context.l10n.checkoutShippingEstimate,
            style: checkoutSans(
              fontSize: 14,
              color: kCheckoutMuted,
              decoration: TextDecoration.underline,
              decorationColor: kCheckoutMuted,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SummaryRow(
          label: context.l10n.checkoutTaxesIncluded,
          value: showTotalsSkeleton ? null : taxesLabel,
          customValue: showTotalsSkeleton ? const SummarySkeleton() : null,
        ),
        const SizedBox(height: 26),
        PrimaryCheckoutButton(
          totalLabel: showTotalsSkeleton ? null : grandTotalLabel,
          onPressed: onCheckout,
        ),
        const SizedBox(height: 18),
        InlineDivider(label: context.l10n.checkoutOrPayWith),
        const SizedBox(height: 16),
        WalletButton.applePay(onPressed: onCheckout),
        const SizedBox(height: 10),
        WalletButton.paypal(onPressed: onPaypal),
        const SizedBox(height: 30),
        const Divider(height: 1, thickness: 1, color: kCheckoutCardBorder),
        const SizedBox(height: 34),
        SectionHeader(title: context.l10n.checkoutHelpServices),
        const SizedBox(height: 16),
        ServiceAccordionGroup(
          children: [
            ServiceAccordion(
              title: context.l10n.checkoutServiceSecurePayment,
              icon: Icons.credit_card_outlined,
              isExpanded: securePaymentOpen,
              onTap: onSecurePaymentToggle,
              body: Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.checkoutServiceSecurePaymentBody,
                      style: checkoutSans(
                        fontSize: 13.5,
                        color: kCheckoutMuted,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PaymentBadge(label: 'VISA'),
                        PaymentBadge(label: 'AMEX'),
                        PaymentBadge(label: 'mastercard'),
                        PaymentBadge(label: 'PayPal'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ServiceAccordion(
              title: context.l10n.checkoutServiceHelp,
              icon: Icons.shopping_bag_outlined,
              isExpanded: helpOpen,
              onTap: onHelpToggle,
              body: Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 22, 22),
                child: Text(
                  context.l10n.checkoutServiceHelpBody,
                  style: checkoutSans(
                    fontSize: 13.5,
                    color: kCheckoutMuted,
                    height: 1.55,
                  ),
                ),
              ),
            ),
            ServiceAccordion(
              title: context.l10n.checkoutServiceFreeShipping,
              icon: Icons.local_shipping_outlined,
              isExpanded: shippingOpen,
              onTap: onShippingToggle,
              body: Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 22, 22),
                child: Text(
                  context.l10n.checkoutServiceFreeShippingBody,
                  style: checkoutSans(
                    fontSize: 13.5,
                    color: kCheckoutMuted,
                    height: 1.55,
                  ),
                ),
              ),
            ),
            ServiceAccordion(
              title: context.l10n.checkoutServiceReturns,
              icon: Icons.calendar_today_outlined,
              isExpanded: returnsOpen,
              onTap: onReturnsToggle,
              body: Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 22, 22),
                child: Text(
                  context.l10n.checkoutServiceReturnsBody,
                  style: checkoutSans(
                    fontSize: 13.5,
                    color: kCheckoutMuted,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showFooter) ...[
          const SizedBox(height: 28),
          const Divider(height: 1, thickness: 1, color: kCheckoutCardBorder),
          const SizedBox(height: 24),
          const Center(child: CheckoutFooter()),
        ],
      ],
    );
  }
}

class CheckoutFooter extends StatelessWidget {
  const CheckoutFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          context.l10n.checkoutFooterPersonalData,
          style: checkoutSans(fontSize: 13.5, color: kCheckoutHeading),
        ),
        const SizedBox(height: 14),
        Text(
          context.l10n.checkoutFooterLegalNotice,
          style: checkoutSans(fontSize: 13.5, color: kCheckoutHeading),
        ),
      ],
    );
  }
}

class CheckoutGuestEmailBanner extends StatelessWidget {
  final String email;
  final VoidCallback onEditEmail;

  const CheckoutGuestEmailBanner({
    super.key,
    required this.email,
    required this.onEditEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 34, color: kCheckoutMuted),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              context.l10n.checkoutEmailAddressLabel(email),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                color: kCheckoutMuted,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 14),
          TextButton(
            onPressed: onEditEmail,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              context.l10n.checkoutEditEmail,
              style: const TextStyle(
                fontSize: 16,
                color: kCheckoutMuted,
                decoration: TextDecoration.underline,
                decorationColor: kCheckoutMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CheckoutStepPlaceholder extends StatelessWidget {
  final String title;

  const CheckoutStepPlaceholder({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 166),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 60),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: GoogleFonts.cormorantGaramond(
          fontSize: 32,
          fontWeight: FontWeight.w500,
          color: kCheckoutPlaceholder,
          height: 1,
        ),
      ),
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
