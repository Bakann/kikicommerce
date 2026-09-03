import 'package:flutter/material.dart';

import '../../../core/utils/price_utils.dart';
import '../../../domain/cart/cart_entities.dart';
import 'cart_theme_tokens.dart';

/// Scrollable order summary for the Sport cart.
///
/// The summary is derived from [CartTotals] so it can't silently drop a
/// non-zero shipping / tax / discount into the total — lines appear when
/// their amount is non-zero. While the cart is syncing the amounts show "—"
/// because uncertain totals must not be presented as final.
class SportCartSummary extends StatelessWidget {
  final CartThemeTokens tokens;
  final CartTotals totals;
  final String symbol;
  final bool isCartSyncing;

  const SportCartSummary({
    super.key,
    required this.tokens,
    required this.totals,
    required this.symbol,
    required this.isCartSyncing,
  });

  String? _amount(double value) =>
      isCartSyncing ? null : formatPrice(value, symbol);

  @override
  Widget build(BuildContext context) {
    final grandTotal = totals.grandTotal > 0
        ? totals.grandTotal
        : totals.subtotal;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          children: [
            _SportSummaryRow(
              label: 'Sous-total',
              value: _amount(totals.subtotal),
              tokens: tokens,
            ),
            if (totals.discountTotal > 0) ...[
              const SizedBox(height: 6),
              _SportSummaryRow(
                label: 'Remise',
                value: isCartSyncing
                    ? null
                    : '-${formatPrice(totals.discountTotal, symbol)}',
                tokens: tokens,
              ),
            ],
            const SizedBox(height: 6),
            _SportSummaryRow(
              label: 'Livraison',
              value: totals.shippingTotal > 0
                  ? _amount(totals.shippingTotal)
                  : 'Standard - Gratuit',
              tokens: tokens,
            ),
            if (totals.taxTotal > 0) ...[
              const SizedBox(height: 6),
              _SportSummaryRow(
                label: 'Taxes incluses',
                value: _amount(totals.taxTotal),
                tokens: tokens,
              ),
            ],
            const SizedBox(height: 6),
            _SportSummaryRow(
              label: 'Total estimé',
              value: _amount(grandTotal),
              tokens: tokens,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned bottom bar of the Sport cart: "Paiement" CTA only.
class SportCartCheckoutBar extends StatelessWidget {
  final CartThemeTokens tokens;
  final bool isCartSyncing;
  final VoidCallback onCheckout;

  const SportCartCheckoutBar({
    super.key,
    required this.tokens,
    required this.isCartSyncing,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.background,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: SportPrimaryButton(
        label: 'Paiement',
        // Uncertain totals ("—") must not be payable.
        onPressed: isCartSyncing ? null : onCheckout,
        tokens: tokens,
      ),
    );
  }
}

class _SportSummaryRow extends StatelessWidget {
  final String label;

  /// Null renders an em dash placeholder (used while the cart is syncing).
  final String? value;
  final CartThemeTokens tokens;
  final bool emphasized;

  const _SportSummaryRow({
    required this.label,
    required this.value,
    required this.tokens,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = emphasized
        ? tokens.bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700)
        : tokens.captionStyle.copyWith(fontSize: 15.5);
    final valueStyle = emphasized
        ? tokens.bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700)
        : tokens.bodyStyle.copyWith(
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
          );

    return Row(
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: 16),
        Text(value ?? '—', textAlign: TextAlign.right, style: valueStyle),
      ],
    );
  }
}

/// Full-width black pill CTA. A null [onPressed] renders the disabled state.
class SportPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final CartThemeTokens tokens;

  const SportPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primaryButtonBackground,
          foregroundColor: tokens.primaryButtonForeground,
          disabledBackgroundColor: const Color(0xFFBDBDBD),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
