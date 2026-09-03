import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import 'cart_theme_tokens.dart';

/// Shows the Sport-themed quantity bottom sheet (Inter, white, black
/// affordances) for [currentQuantity].
///
/// Resolves to the chosen quantity, `0` to remove the line (the Sport line
/// item has no separate "Supprimer" affordance — removal is folded into the
/// quantity sheet to match the mockup), or `null` if dismissed.
Future<int?> showSportQuantitySheet(
  BuildContext context, {
  required int currentQuantity,
  int maxQuantity = 10,
}) {
  final tokens = CartThemeTokens.nike;

  return showModalBottomSheet<int>(
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.cartQuantityTitle,
                  style: tokens.titleStyle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: maxQuantity,
                    itemBuilder: (context, index) {
                      final quantity = index + 1;
                      final selected = quantity == currentQuantity;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          context.l10n.cartQuantityLabelShort(quantity),
                          style: tokens.bodyStyle.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check, color: tokens.primaryText)
                            : null,
                        onTap: () => Navigator.of(context).pop(quantity),
                      );
                    },
                  ),
                ),
                Divider(height: 8, color: tokens.border),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    Icons.delete_outline,
                    color: tokens.primaryText,
                  ),
                  title: Text(
                    context.l10n.cartRemoveItem,
                    style: tokens.bodyStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(0),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
