import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/price_utils.dart';
import '../../../core/utils/string_utils.dart';
import '../../../domain/cart/cart_entities.dart';
import '../../l10n/l10n_extension.dart';
import '../../providers/product_providers.dart';
import '../../widgets/kiki_image.dart';
import 'cart_theme_tokens.dart';

/// Sport line item: image + name + description, then a full-width row with the
/// quantity selector and the line price.
///
/// Note: the reference mockup also shows colour ("Multicolore/Noir") and size
/// ("Taille : 40.5"). Those aren't on [CartEntry] (only `skuSnapshot`) nor on
/// the product detail, so they are intentionally omitted rather than
/// fabricated — surfacing them needs a variant-resolution feature first.
class SportCartLineItem extends ConsumerWidget {
  final CartEntry entry;
  final String symbol;
  final CartThemeTokens tokens;

  /// Opens the Sport quantity sheet (which also offers "Retirer l'article").
  final VoidCallback onEditQuantity;

  const SportCartLineItem({
    super.key,
    required this.entry,
    required this.symbol,
    required this.tokens,
    required this.onEditQuantity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productState = ref.watch(pdpProvider(entry.productId));
    final product = productState.value?.product;
    final name = product?.name ?? entry.productNameSnapshot;
    final summary = stripHtml(product?.summary ?? '').trim();
    final image = product?.listingMedia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radius),
              child: Container(
                width: 104,
                height: 104,
                color: const Color(0xFFF4F4F4),
                child: image == null
                    ? Icon(
                        Icons.image_outlined,
                        size: 24,
                        color: tokens.secondaryText,
                      )
                    : KikiImage(imageUrl: image.listingUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.bodyStyle.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.captionStyle.copyWith(
                        fontSize: 14.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _SportQuantitySelector(
              quantity: entry.quantity,
              tokens: tokens,
              onTap: onEditQuantity,
            ),
            const Spacer(),
            Text(
              formatPrice(entry.lineTotal, symbol),
              style: tokens.bodyStyle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SportQuantitySelector extends StatelessWidget {
  final int quantity;
  final CartThemeTokens tokens;
  final VoidCallback onTap;

  const _SportQuantitySelector({
    required this.quantity,
    required this.tokens,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.cartQuantityLabelShort(quantity),
              style: tokens.bodyStyle.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 22,
              color: tokens.primaryText,
            ),
          ],
        ),
      ),
    );
  }
}
