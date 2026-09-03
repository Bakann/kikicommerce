import 'package:flutter/material.dart';

import '../../../core/utils/price_utils.dart';
import '../../../domain/catalog/catalog_entities.dart';
import '../../l10n/l10n_extension.dart';
import '../../widgets/pdp_purchase_bar.dart';
import '../product_detail_layout_spec.dart';

/// Mobile purchase bar height — shared between the in-flow anchor and the
/// floating bar that pins it to the bottom of the screen.
const kMobilePurchaseBarHeight = 58.0;

class MobilePurchaseAnchor extends StatelessWidget {
  final Widget? child;

  const MobilePurchaseAnchor({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: kMobilePurchaseBarHeight,
      child: child,
    );
  }
}

class NoVariantMobileCommerceSection extends StatelessWidget {
  final CatalogPrice? defaultPrice;
  final String symbol;
  final Future<bool> Function()? onAddToCart;
  final GlobalKey? purchaseAnchorKey;

  const NoVariantMobileCommerceSection({
    super.key,
    required this.defaultPrice,
    required this.symbol,
    required this.onAddToCart,
    required this.purchaseAnchorKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PdpPaymentBadges(),
        const SizedBox(height: 14),
        if (purchaseAnchorKey != null)
          MobilePurchaseAnchor(
            key: purchaseAnchorKey,
            child: PdpPurchaseBar(
              defaultPrice: defaultPrice,
              symbol: symbol,
              onAddToCart: onAddToCart ?? () async => false,
              includeSafeArea: false,
              height: kMobilePurchaseBarHeight,
              borderRadius: BorderRadius.circular(8),
            ),
          )
        else
          PdpPurchaseBar(
            defaultPrice: defaultPrice,
            symbol: symbol,
            onAddToCart: onAddToCart ?? () async => false,
            includeSafeArea: false,
            height: kMobilePurchaseBarHeight,
            borderRadius: BorderRadius.circular(8),
          ),
        const SizedBox(height: 14),
        const BoutiqueReservationButton(),
      ],
    );
  }
}

class PdpPaymentBadges extends StatelessWidget {
  final bool compact;

  const PdpPaymentBadges({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 8.0 : 12.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PdpPaymentBadge(label: 'VISA', compact: compact),
        SizedBox(width: gap),
        _MastercardMark(compact: compact),
        SizedBox(width: gap),
        _PdpPaymentBadge(label: 'AMEX', boxed: true, compact: compact),
        SizedBox(width: gap),
        _PdpPaymentBadge(label: 'Pay', compact: compact),
        SizedBox(width: gap),
        _PdpPaymentBadge(label: 'PayPal', compact: compact),
      ],
    );
  }
}

class _PdpPaymentBadge extends StatelessWidget {
  final String label;
  final bool boxed;
  final bool compact;

  const _PdpPaymentBadge({
    required this.label,
    this.boxed = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: TextStyle(
        fontSize: compact ? 7 : 10,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF58656C),
        height: 1,
      ),
    );

    if (!boxed) {
      return child;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF58656C), width: 1),
      ),
      child: child,
    );
  }
}

class _MastercardMark extends StatelessWidget {
  final bool compact;

  const _MastercardMark({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final width = compact ? 15.0 : 22.0;
    final height = compact ? 10.0 : 14.0;
    final dot = compact ? 8.0 : 11.0;
    final side = compact ? 2.0 : 3.0;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: side,
            child: Container(
              width: dot,
              height: dot,
              decoration: const BoxDecoration(
                color: Color(0xFF7B858A),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: side,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: const Color(0xFF7B858A).withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BoutiqueReservationButton extends StatelessWidget {
  const BoutiqueReservationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2D2D2A),
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: Color(0xFFE0DED9)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Text(context.l10n.pdpReserveInStore),
    );
  }
}

class DesktopPurchaseServices extends StatelessWidget {
  const DesktopPurchaseServices({super.key});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 14,
      color: productDetailMutedTextColor,
      height: 1.35,
      fontWeight: FontWeight.w400,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Livraison estimée à partir du 11 Mai', style: textStyle),
        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            style: textStyle,
            children: [
              TextSpan(
                text:
                    'Nos Conseillers sont ravis de répondre à vos questions. Contactez-nous au ',
              ),
              TextSpan(
                text: '+33 (0)1 40 73 73 73',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  color: productDetailMutedTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HeroPurchaseButton extends StatelessWidget {
  final CatalogPrice? defaultPrice;
  final String symbol;

  /// Adds to cart and resolves `true`/`false`. As this button has no inline
  /// error UI (unlike [PdpPurchaseBar]), a failure is surfaced via a SnackBar.
  final Future<bool> Function()? onPressed;

  const HeroPurchaseButton({
    super.key,
    required this.defaultPrice,
    required this.symbol,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final priceLabel = defaultPrice == null
        ? 'Prix indisponible'
        : formatPrice(defaultPrice!.price, symbol);

    final onAdd = onPressed;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2D2D2A),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        onPressed: onAdd == null
            ? null
            : () async {
                final ok = await onAdd();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.pdpCartAddFailed)),
                  );
                }
              },
        child: Row(
          children: [
            Expanded(child: Text(context.l10n.pdpAddToCart)),
            Text(
              priceLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpressPurchaseHint extends StatelessWidget {
  const ExpressPurchaseHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFF2F1EE),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.pdpExpressCheckout,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9C9C98),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(
            'Apple Pay  PayPal',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFB0B0AC),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
