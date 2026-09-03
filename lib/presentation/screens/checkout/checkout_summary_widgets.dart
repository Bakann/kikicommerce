import 'package:flutter/material.dart';

import 'checkout_tokens.dart';

class PrimaryCheckoutButton extends StatelessWidget {
  final String? totalLabel;
  final VoidCallback onPressed;

  const PrimaryCheckoutButton({
    super.key,
    required this.totalLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kCheckoutPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kCheckoutCardRadius),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Finaliser ma commande',
                style: checkoutSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            if (totalLabel case final label?)
              Text(
                label,
                style: checkoutSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              )
            else
              const SummarySkeleton(
                width: 92,
                height: 18,
                color: Colors.white24,
              ),
          ],
        ),
      ),
    );
  }
}

enum WalletButtonKind { applePay, paypal }

class WalletButton extends StatelessWidget {
  final WalletButtonKind kind;
  final VoidCallback onPressed;

  const WalletButton._({
    super.key,
    required this.kind,
    required this.onPressed,
  });

  const WalletButton.applePay({Key? key, required VoidCallback onPressed})
    : this._(key: key, kind: WalletButtonKind.applePay, onPressed: onPressed);

  const WalletButton.paypal({Key? key, required VoidCallback onPressed})
    : this._(key: key, kind: WalletButtonKind.paypal, onPressed: onPressed);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: kCheckoutCardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kCheckoutCardRadius),
          ),
        ),
        child: switch (kind) {
          WalletButtonKind.applePay => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.apple, size: 22, color: Colors.black),
              const SizedBox(width: 2),
              Text(
                'Pay',
                style: checkoutSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          WalletButtonKind.paypal => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'P',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF253B80),
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(width: 2),
              Text(
                'ay',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF179BD7),
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(width: 2),
              Text(
                'Pal',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF253B80),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}

class InlineDivider extends StatelessWidget {
  final String label;

  const InlineDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(height: 1, thickness: 1, color: kCheckoutCardBorder),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: checkoutSans(fontSize: 13.5, color: kCheckoutMuted),
          ),
        ),
        const Expanded(
          child: Divider(height: 1, thickness: 1, color: kCheckoutCardBorder),
        ),
      ],
    );
  }
}

class ServiceAccordionGroup extends StatelessWidget {
  final List<ServiceAccordion> children;

  const ServiceAccordionGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kCheckoutCardRadius),
        border: Border.all(color: kCheckoutCardBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(
                height: 1,
                thickness: 1,
                color: kCheckoutCardBorder,
              ),
          ],
        ],
      ),
    );
  }
}

class ServiceAccordion extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget? body;

  const ServiceAccordion({
    super.key,
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onTap,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 22, 22),
            child: Row(
              children: [
                Icon(icon, size: 18, color: kCheckoutMuted),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    title,
                    style: checkoutSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: kCheckoutHeading,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: kCheckoutHeading,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) body ?? const SizedBox.shrink(),
      ],
    );
  }
}

class PaymentBadge extends StatelessWidget {
  final String label;

  const PaymentBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return switch (label) {
      'AMEX' => Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF49A4C9),
          borderRadius: BorderRadius.circular(1),
        ),
        child: const Text(
          'AMEX',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
      'mastercard' => const SizedBox(
        width: 28,
        height: 15,
        child: Stack(
          children: [
            Positioned(
              left: 4,
              top: 2,
              child: CircleAvatar(
                radius: 6,
                backgroundColor: Color(0xFFE84435),
              ),
            ),
            Positioned(
              left: 12,
              top: 2,
              child: CircleAvatar(
                radius: 6,
                backgroundColor: Color(0xFFF3A32D),
              ),
            ),
          ],
        ),
      ),
      'PayPal' => const Text(
        'PayPal',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF244B9A),
          fontStyle: FontStyle.italic,
          height: 1,
        ),
      ),
      _ => const Text(
        'VISA',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF214E9F),
          fontStyle: FontStyle.italic,
          height: 1,
        ),
      ),
    };
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: checkoutSerif(
              fontSize: 23.5,
              fontWeight: FontWeight.w500,
              color: kCheckoutHeading,
              height: 1.08,
            ),
          ),
        ),
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              trailing!,
              style: checkoutSans(fontSize: 14.5, color: kCheckoutMuted),
            ),
          ),
      ],
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? customValue;

  const SummaryRow({
    super.key,
    required this.label,
    this.value,
    this.customValue,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = switch ((customValue, value)) {
      (final widget?, _) => widget,
      (_, final text?) => Text(
        text,
        textAlign: TextAlign.right,
        style: checkoutSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: kCheckoutHeading,
        ),
      ),
      _ => const SizedBox.shrink(),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: checkoutSans(fontSize: 15, color: kCheckoutHeading),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: trailing),
        ),
      ],
    );
  }
}

class SummarySkeleton extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const SummarySkeleton({
    super.key,
    this.width = 120,
    this.height = 18,
    this.color = const Color(0xFFE5E1D9),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
