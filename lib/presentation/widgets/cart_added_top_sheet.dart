import 'package:flutter/material.dart';

import '../../core/utils/price_utils.dart';
import '../../core/utils/string_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import 'kiki_image.dart';
import 'snap_disintegrate.dart';

Future<void> showCartAddedTopSheet({
  required BuildContext context,
  required CatalogProduct product,
  required CatalogPrice? defaultPrice,
  required String symbol,
  int quantity = 1,
  VoidCallback? onCheckout,
  VoidCallback? onPayWithPaypal,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _CartAddedTopSheet(
        product: product,
        defaultPrice: defaultPrice,
        symbol: symbol,
        quantity: quantity,
        onCheckout: onCheckout,
        onPayWithPaypal: onPayWithPaypal,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _CartAddedTopSheet extends StatefulWidget {
  final CatalogProduct product;
  final CatalogPrice? defaultPrice;
  final String symbol;
  final int quantity;
  final VoidCallback? onCheckout;
  final VoidCallback? onPayWithPaypal;

  const _CartAddedTopSheet({
    required this.product,
    required this.defaultPrice,
    required this.symbol,
    required this.quantity,
    required this.onCheckout,
    required this.onPayWithPaypal,
  });

  @override
  State<_CartAddedTopSheet> createState() => _CartAddedTopSheetState();
}

class _CartAddedTopSheetState extends State<_CartAddedTopSheet> {
  final SnapDisintegrateController _snapController =
      SnapDisintegrateController();

  CatalogMedia? get _thumb => widget.product.listingMedia;

  @override
  Widget build(BuildContext context) {
    final summary = stripHtml(widget.product.summary ?? '').trim();
    final priceLabel = widget.defaultPrice == null
        ? 'Prix indisponible'
        : formatPrice(widget.defaultPrice!.price, widget.symbol);

    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SnapDisintegrate(
                controller: _snapController,
                onDismissed: () {
                  if (mounted) Navigator.of(context).pop();
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE8E8E8),
                      ),
                      _buildProductRow(summary, priceLabel),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE8E8E8),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCheckoutButton(context),
                            const SizedBox(height: 18),
                            _buildOrDivider(),
                            const SizedBox(height: 14),
                            _buildPaypalButton(context),
                            const SizedBox(height: 18),
                            _buildContinueShopping(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Produit ajouté au panier',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E1E1E),
              ),
            ),
          ),
          IconButton(
            onPressed: _snapController.dismiss,
            icon: const Icon(Icons.close, size: 22, color: Color(0xFF1E1E1E)),
            splashRadius: 22,
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(String summary, String priceLabel) {
    final thumb = _thumb;
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 140,
            child: ColoredBox(
              color: const Color(0xFFF3F3F3),
              child: thumb == null
                  ? const SizedBox.shrink()
                  : KikiImage(imageUrl: thumb.listingUrl, fit: BoxFit.contain),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E1E),
                      height: 1.25,
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9A9A9A),
                        height: 1.3,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Qté : ${widget.quantity}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9A9A9A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      priceLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E1E1E),
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

  Widget _buildCheckoutButton(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          Navigator.of(context).pop();
          widget.onCheckout?.call();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D2D2A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        child: const Text('Finaliser ma commande'),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: const [
        Expanded(child: Divider(thickness: 1, color: Color(0xFFE8E8E8))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou payer avec',
            style: TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
          ),
        ),
        Expanded(child: Divider(thickness: 1, color: Color(0xFFE8E8E8))),
      ],
    );
  }

  Widget _buildPaypalButton(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: () {
          Navigator.of(context).pop();
          widget.onPayWithPaypal?.call();
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE2E2E2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          backgroundColor: Colors.white,
        ),
        child: Row(
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
      ),
    );
  }

  Widget _buildContinueShopping(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            'Continuer mes achats',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF1E1E1E),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}
