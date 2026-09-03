import 'package:flutter/material.dart';

import 'cart_theme_tokens.dart';

/// Per-item "same-day pickup" block shown under each Sport line item.
///
/// Intentionally **static and non-interactive**: there is no store-stock or
/// click-&-collect backend yet, so this only communicates intent. It does not
/// expose a tappable affordance that would promise functionality the app
/// can't deliver. The store line is a placeholder label, not live stock.
class SportCartDeliverySection extends StatelessWidget {
  final CartThemeTokens tokens;

  const SportCartDeliverySection({super.key, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Retrait le jour même',
          style: tokens.bodyStyle.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Indisponible à Nikelab P75 Paris',
          style: tokens.bodyStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Option « click and collect » disponible lors du paiement',
          style: tokens.captionStyle.copyWith(fontSize: 15, height: 1.35),
        ),
      ],
    );
  }
}
