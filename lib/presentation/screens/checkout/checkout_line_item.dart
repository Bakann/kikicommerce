import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/price_utils.dart';
import '../../../core/utils/string_utils.dart';
import '../../../domain/cart/cart_entities.dart';
import '../../../domain/catalog/catalog_entities.dart';
import '../../providers/product_providers.dart';
import '../../widgets/kiki_image.dart';
import 'checkout_tokens.dart';

class CheckoutLineItem extends ConsumerWidget {
  final CartEntry entry;
  final VoidCallback onEditQuantity;
  final VoidCallback onRemove;
  final bool desktop;

  const CheckoutLineItem({
    super.key,
    required this.entry,
    required this.onEditQuantity,
    required this.onRemove,
    this.desktop = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productState = ref.watch(pdpProvider(entry.productId));
    final detail = productState.value;
    final product = detail?.product;
    final summary = stripHtml(product?.summary ?? '').trim();
    final image = product?.listingMedia;
    final symbol = _currencySymbolFromCode(
      _defaultPriceCurrencyCode(detail?.prices) ?? 'EUR',
    );

    final itemHeight = desktop ? 300.0 : 180.0;
    final imageWidth = desktop ? 280.0 : 162.0;
    final imagePadding = desktop ? 26.0 : 14.0;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: itemHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: imageWidth,
            height: itemHeight,
            child: ColoredBox(
              color: kCheckoutImagePanel,
              child: image == null
                  ? const Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 24,
                        color: Color(0xFFC6C3BC),
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.all(imagePadding),
                      child: KikiImage(
                        imageUrl: image.listingUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: desktop
                  ? const EdgeInsets.fromLTRB(48, 68, 48, 46)
                  : const EdgeInsets.fromLTRB(18, 18, 20, 14),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: desktop ? itemHeight - 114 : 148,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product?.name ?? entry.productNameSnapshot,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: checkoutSans(
                            fontSize: desktop ? 15.5 : 14.5,
                            fontWeight: FontWeight.w500,
                            color: kCheckoutHeading,
                            height: 1.25,
                          ),
                        ),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: checkoutSans(
                              fontSize: desktop ? 14.5 : 13.25,
                              color: kCheckoutMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Column(
                      crossAxisAlignment: desktop
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: desktop
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Wrap(
                            alignment: desktop
                                ? WrapAlignment.start
                                : WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              Text(
                                'Qté : ${entry.quantity}',
                                style: checkoutSans(
                                  fontSize: 13.5,
                                  color: kCheckoutMuted,
                                ),
                              ),
                              TextButton(
                                onPressed: onEditQuantity,
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.only(
                                    left: 6,
                                    bottom: 1,
                                  ),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'modifier',
                                  style: checkoutSans(
                                    fontSize: 13.5,
                                    color: kCheckoutMuted,
                                    decoration: TextDecoration.underline,
                                    decorationColor: kCheckoutMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!desktop)
                          _LineItemMobileActions(
                            onRemove: onRemove,
                            priceLabel: formatPrice(entry.lineTotal, symbol),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (desktop)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 68, 48, 46),
              child: SizedBox(
                width: 116,
                height: itemHeight - 114,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPrice(entry.lineTotal, symbol),
                      style: checkoutSans(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: kCheckoutHeading,
                      ),
                    ),
                    TextButton(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Supprimer',
                        style: checkoutSans(
                          fontSize: 13.5,
                          color: kCheckoutMuted,
                          decoration: TextDecoration.underline,
                          decorationColor: kCheckoutMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LineItemMobileActions extends StatelessWidget {
  final VoidCallback onRemove;
  final String priceLabel;

  const _LineItemMobileActions({
    required this.onRemove,
    required this.priceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onRemove,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Supprimer',
              style: checkoutSans(
                fontSize: 13.5,
                color: kCheckoutMuted,
                decoration: TextDecoration.underline,
                decorationColor: kCheckoutMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            priceLabel,
            style: checkoutSans(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              color: kCheckoutHeading,
            ),
          ),
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

String? _defaultPriceCurrencyCode(List<CatalogPrice>? prices) {
  if (prices == null || prices.isEmpty) {
    return null;
  }
  return getDefaultPrice(prices)?.currencyCode ?? prices.first.currencyCode;
}
