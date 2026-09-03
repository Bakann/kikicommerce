import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import 'checkout_tokens.dart';

class PackagingCard extends StatelessWidget {
  final String brandName;
  final bool signaturePackaging;
  final bool shoppingBag;
  final bool giftWrap;
  final ValueChanged<bool> onSignaturePackagingChanged;
  final ValueChanged<bool> onShoppingBagChanged;
  final ValueChanged<bool> onGiftWrapChanged;

  const PackagingCard({
    super.key,
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
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(kCheckoutCardRadius),
            border: Border.all(color: kCheckoutCardBorder),
          ),
          child: Column(
            children: [
              const _PackagingMoodBoard(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                child: Column(
                  children: [
                    _PackagingRadioOption(
                      selected: signaturePackaging,
                      title: context.l10n.checkoutPackagingSignatureTitle(
                        brandName,
                      ),
                      subtitle: context.l10n.checkoutPackagingSignatureSubtitle(
                        brandName,
                      ),
                      onTap: () => onSignaturePackagingChanged(true),
                    ),
                    const SizedBox(height: 10),
                    _PackagingRadioOption(
                      selected: !signaturePackaging,
                      title: context.l10n.checkoutPackagingEcoTitle,
                      onTap: () => onSignaturePackagingChanged(false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _OptionToggleCard(
          value: shoppingBag,
          onChanged: onShoppingBagChanged,
          title: context.l10n.checkoutAddShoppingBag(brandName),
          preview: const _SoftPreviewPanel(
            label: 'KIKI',
            variant: _SoftPreviewVariant.bag,
          ),
        ),
        const SizedBox(height: 12),
        _OptionToggleCard(
          value: giftWrap,
          onChanged: onGiftWrapChanged,
          title: context.l10n.checkoutGiftWrapTitle,
          subtitle: context.l10n.checkoutGiftWrapSubtitle,
          preview: const _SoftPreviewPanel(
            label: 'KIKI',
            variant: _SoftPreviewVariant.gift,
          ),
        ),
      ],
    );
  }
}

class _PackagingMoodBoard extends StatelessWidget {
  const _PackagingMoodBoard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 154,
      child: Row(
        children: const [
          Expanded(child: _MoodPanel(variant: _MoodPanelVariant.boxes)),
          VerticalDivider(width: 1, thickness: 1, color: Colors.white),
          Expanded(child: _MoodPanel(variant: _MoodPanelVariant.book)),
          VerticalDivider(width: 1, thickness: 1, color: Colors.white),
          Expanded(child: _MoodPanel(variant: _MoodPanelVariant.card)),
        ],
      ),
    );
  }
}

enum _MoodPanelVariant { boxes, book, card }

class _MoodPanel extends StatelessWidget {
  final _MoodPanelVariant variant;

  const _MoodPanel({required this.variant});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE9E9E9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF2F2F2), Color(0xFFD8D8D8)],
              ),
            ),
          ),
          switch (variant) {
            _MoodPanelVariant.boxes => const _MoodBoxesComposition(),
            _MoodPanelVariant.book => const _MoodBookComposition(),
            _MoodPanelVariant.card => const _MoodCardComposition(),
          },
        ],
      ),
    );
  }
}

class _MoodBoxesComposition extends StatelessWidget {
  const _MoodBoxesComposition();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 16,
          bottom: 18,
          child: _PackageBlock(width: 48, height: 42, label: 'KIKI'),
        ),
        Positioned(
          right: 18,
          bottom: 20,
          child: _PackageBlock(width: 36, height: 86, label: 'KIKI'),
        ),
        Positioned(
          left: 56,
          bottom: 36,
          child: _PackageBlock(width: 32, height: 64, label: 'KIKI'),
        ),
        Positioned(
          right: 34,
          top: 26,
          child: _PackageBlock(width: 34, height: 44, label: 'KIKI'),
        ),
      ],
    );
  }
}

class _MoodBookComposition extends StatelessWidget {
  const _MoodBookComposition();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 28,
          top: 18,
          child: Transform.rotate(
            angle: -0.28,
            child: _PackageBlock(width: 66, height: 112, label: 'KIKI'),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: Transform.rotate(
            angle: -0.28,
            child: _PackageBlock(width: 46, height: 50, label: 'KIKI'),
          ),
        ),
      ],
    );
  }
}

class _MoodCardComposition extends StatelessWidget {
  const _MoodCardComposition();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          right: 28,
          top: 18,
          child: Transform.rotate(
            angle: -0.25,
            child: Container(
              width: 76,
              height: 102,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                border: Border.all(color: const Color(0xFFE2E2E2)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x17000000),
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'KIKI',
                    style: checkoutSerif(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFC4A45A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(
                    6,
                    (index) => Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
                      child: Container(
                        height: 1,
                        color: const Color(0xFFC8C8C8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          bottom: 20,
          child: Transform.rotate(angle: -0.24, child: _GiftNote()),
        ),
      ],
    );
  }
}

class _PackageBlock extends StatelessWidget {
  final double width;
  final double height;
  final String label;

  const _PackageBlock({
    required this.width,
    required this.height,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        border: Border.all(color: const Color(0xFFD7D7D7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            style: checkoutSerif(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFC4A45A),
            ),
          ),
        ),
      ),
    );
  }
}

class _GiftNote extends StatelessWidget {
  const _GiftNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: Container(height: 1, color: const Color(0xFFCFCFCF)),
          ),
        ),
      ),
    );
  }
}

class _PackagingRadioOption extends StatelessWidget {
  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _PackagingRadioOption({
    required this.selected,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kCheckoutCardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RadioDot(selected: selected),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: checkoutSans(
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: kCheckoutHeading,
                      height: 1.25,
                    ),
                  ),
                  if (subtitle case final text?) ...[
                    const SizedBox(height: 12),
                    Text(
                      text,
                      style: checkoutSans(
                        fontSize: 13.75,
                        color: kCheckoutMuted,
                        height: 1.55,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RadioDot extends StatelessWidget {
  final bool selected;

  const RadioDot({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? kCheckoutPrimary : kCheckoutMuted,
          width: 1.25,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: kCheckoutPrimary,
              ),
            )
          : null,
    );
  }
}

class _OptionToggleCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String? subtitle;
  final Widget preview;

  const _OptionToggleCard({
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final height = subtitle == null ? 82.0 : 90.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kCheckoutCardRadius),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(kCheckoutCardRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kCheckoutCardRadius),
            border: Border.all(color: kCheckoutCardBorder),
          ),
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                const SizedBox(width: 22),
                _CheckSquare(selected: value),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: checkoutSans(
                          fontSize: 14.5,
                          color: kCheckoutHeading,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle case final text?) ...[
                        const SizedBox(height: 4),
                        Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: checkoutSans(
                            fontSize: 13,
                            color: kCheckoutMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 82, height: height, child: preview),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckSquare extends StatelessWidget {
  final bool selected;

  const _CheckSquare({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: selected ? kCheckoutPrimary : kCheckoutMuted,
          width: 1.4,
        ),
        color: selected ? kCheckoutPrimary : Colors.transparent,
      ),
      child: selected
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }
}

enum _SoftPreviewVariant { bag, gift }

class _SoftPreviewPanel extends StatelessWidget {
  final String label;
  final _SoftPreviewVariant variant;

  const _SoftPreviewPanel({required this.label, required this.variant});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDEDED), Color(0xFFD8D8D8)],
        ),
      ),
      child: Center(
        child: switch (variant) {
          _SoftPreviewVariant.bag => _ShoppingBagPreview(label: label),
          _SoftPreviewVariant.gift => _GiftWrapPreview(label: label),
        },
      ),
    );
  }
}

class _ShoppingBagPreview extends StatelessWidget {
  final String label;

  const _ShoppingBagPreview({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 50,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 3,
            child: Container(
              width: 18,
              height: 14,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD3D3D3), width: 1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                border: Border.all(color: const Color(0xFFE4E4E4)),
              ),
              child: Text(
                label,
                style: checkoutSerif(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFC4A45A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftWrapPreview extends StatelessWidget {
  final String label;

  const _GiftWrapPreview({required this.label});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 54,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
          ),
          Container(width: 54, height: 7, color: const Color(0xFFEFEFEF)),
          Container(width: 7, height: 58, color: const Color(0xFFEFEFEF)),
          Positioned(
            bottom: 9,
            child: Text(
              label,
              style: checkoutSerif(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFC4A45A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
