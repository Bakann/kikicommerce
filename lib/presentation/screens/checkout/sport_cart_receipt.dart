import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../application/cart/cart_read_models.dart';
import '../../../domain/cart/cart_entities.dart';

/// Warm off-white thermal-paper tone — deliberately a touch warmer than the
/// neutral backdrop so the ticket separates from the interface, not identical
/// white on white.
const Color _kPaper = Color(0xFFFBFAF5);
const Color _kInk = Color(0xFF1E1E1E);
const Color _kFaint = Color(0xFF828282);

/// Monospace-first stack so the itemised columns line up like a real till
/// print-out. Falls back gracefully where the platform lacks the first family.
const List<String> _kReceiptMono = <String>[
  'Menlo',
  'SFMono-Regular',
  'Courier New',
  'Courier',
  'monospace',
];

const Duration _kReceiptPrintDuration = Duration(milliseconds: 1900);

/// The printer is a compact, centred box (not a full-width bar) — like the
/// reference's 300px unit sitting in the middle of the page. Kept a touch under
/// full width so it breathes on smaller screens.
const double _kPrinterWidth = 300;

/// The printer is two stacked boxes (like the reference `::after` face over the
/// taller `::before` back): the bevelled front face, and a plain back that
/// extends below it as a "chin" framing the slot on its sides and bottom.
const double _kFrontHeight = 80;
const double _kBackHeight = 96;

/// Shared corner radii so the face and the chin behind it line up cleanly
/// (mismatched radii left a visible double edge at the corners).
const double _kBodyRadiusTop = 24;
const double _kBodyRadiusBottom = 20;

/// Y of the slot line — at the façade's base. The paper is clipped here (its
/// top tucked up behind the façade) and the front lip sits across it.
const double _kSlotY = _kFrontHeight;

/// The paper's top edge tucks this far up *behind* the façade, so it is never
/// visible and reads as coming from inside the machine.
const double _kPaperTuck = 12;

/// The front lip is inset this far from the printer sides; the paper is inset a
/// little more so the lip overhangs the ticket by only a hair (~a few %), not a
/// wide margin.
const double _kLipInset = 14;
const double _kPaperInset = 22;

/// A thin front lip — the visible black form is just the slot's front edge, not
/// the whole opening (the depth comes from the cavity/contact shadow behind it).
const double _kSlotLipHeight = 5;

/// Light backdrop the printer sits on — like the reference's white page, so the
/// printer and the emerging paper cast readable shadows (a dark scrim would
/// swallow them).
const Color _kBackdrop = Color(0xF2E6E6E6);

/// The feed-in slides the whole sheet down by this fraction of its own height
/// (like the reference `translateY(-110%) -> translateY(0)`), so the printed
/// text travels out of the mouth with the paper instead of being unveiled in
/// place.
const double _kSlideFraction = 1.08;

/// Presents the cart as a supermarket-style receipt that "prints" out of a
/// horizontal slot at the top of the screen and unrolls downwards.
Future<void> showSportCartReceipt(
  BuildContext context, {
  required CartView view,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer la facture',
    // Transparent barrier: the overlay itself lays down a blurred, light veil so
    // the catalog behind is neutralised (blur) rather than just dimmed.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _SportReceiptOverlay(view: view);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

TextStyle _mono({
  double size = 12,
  FontWeight weight = FontWeight.w400,
  Color color = _kInk,
  double? letterSpacing,
  double height = 1.4,
}) {
  return TextStyle(
    fontFamilyFallback: _kReceiptMono,
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

class _SportReceiptOverlay extends StatefulWidget {
  final CartView view;

  const _SportReceiptOverlay({required this.view});

  @override
  State<_SportReceiptOverlay> createState() => _SportReceiptOverlayState();
}

class _SportReceiptOverlayState extends State<_SportReceiptOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _printController = AnimationController(
    vsync: this,
    duration: _kReceiptPrintDuration,
  );
  late final CurvedAnimation _reveal = CurvedAnimation(
    parent: _printController,
    curve: Curves.easeInOut,
  );

  bool _started = false;
  bool _printed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _printController.value = 1;
      _printed = true;
    } else {
      _printController.forward();
      _printController.addStatusListener(_onPrintStatus);
    }
  }

  void _onPrintStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_printed) {
      setState(() => _printed = true);
    }
  }

  @override
  void dispose() {
    _printController.removeStatusListener(_onPrintStatus);
    _reveal.dispose();
    _printController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final symbol = _currencySymbol(widget.view.cart.currencyCode);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Blurred, light veil over the catalog so it stays as faint context
          // without competing with the receipt (a plain dim left it readable).
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: ColoredBox(color: _kBackdrop.withValues(alpha: 0.86)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _CloseButton(
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: _kPrinterWidth,
                        height: double.infinity,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // 1. Base (chin) — behind everything, carries the
                            // unit's ambient/contact ground shadows. Never over
                            // the paper.
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: _kBackHeight,
                              child: _PrinterChin(),
                            ),
                            // 1b. Cavity — a dark recess at the slot, drawn
                            // *behind* the paper and a touch wider than it, so
                            // the paper hides its centre while it shows in the
                            // small gaps left and right: a distinct opening the
                            // sheet passes through, separate from the front lip.
                            const Positioned(
                              top: _kSlotY - 3,
                              left: _kLipInset,
                              right: _kLipInset,
                              height: 15,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(3),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF0D0D0D),
                                        Color(0xFF1C1C1C),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 2. Paper — its top edge tucks up behind the façade
                            // (clipped, never visible) and slides out through the
                            // slot, then becomes scrollable.
                            Positioned(
                              top: _kSlotY - _kPaperTuck,
                              left: _kPaperInset,
                              right: _kPaperInset,
                              bottom: 0,
                              child: ClipRect(
                                child: _ReceiptFeed(
                                  animation: _reveal,
                                  printed: _printed,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 28),
                                    child: _ReceiptPaper(
                                      view: widget.view,
                                      symbol: symbol,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 3. Façade (cap) — drawn over the paper, masking its
                            // top edge.
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: _PrinterHead(),
                            ),
                            // 4. Contact shadow on the paper — a pinch of shadow
                            // right under the slot: darkest immediately, gone
                            // within ~9px. Paper width only.
                            const Positioned(
                              top: _kSlotY,
                              left: _kPaperInset,
                              right: _kPaperInset,
                              height: 9,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x8C000000),
                                        Color(0x1C000000),
                                        Color(0x00000000),
                                      ],
                                      stops: [0.0, 0.3, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 5. Front lip — a thin graphite bar seated into the
                            // façade's base, in front of the paper. Flatter than
                            // a cylinder: a fine top reflection, graphite (not
                            // pure black) body, and a defined dark under-edge.
                            Positioned(
                              top: _kSlotY - _kSlotLipHeight + 1,
                              left: _kLipInset,
                              right: _kLipInset,
                              height: _kSlotLipHeight,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF313131),
                                      Color(0xFF232323),
                                      Color(0xFF1C1C1C),
                                      Color(0xFF121212),
                                    ],
                                    stops: [0.0, 0.28, 0.75, 1.0],
                                  ),
                                  borderRadius: const BorderRadius.all(
                                    Radius.elliptical(_kSlotLipHeight, 2.2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

/// Light-grey 3D printer body with a dark feed slot at its base — the mouth the
/// receipt exits from. Modelled on a moulded-plastic desktop printer: a top
/// shadow, a bright bevel highlight, then the body tone.
class _PrinterHead extends StatelessWidget {
  const _PrinterHead();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kFrontHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_kBodyRadiusTop),
          bottom: Radius.circular(_kBodyRadiusBottom),
        ),
        // Brushed-aluminium bombé: medium-grey top edge, a *restrained* light
        // band, the body tone, then a darker base. The bright reflection itself
        // is the localized radial highlight below, not this band.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFA8A8A8),
            Color(0xFFDBDBDB),
            Color(0xFFD0D0D0),
            Color(0xFFC7C7C7),
            Color(0xFFA6A6A6),
          ],
          stops: [0.0, 0.18, 0.42, 0.75, 1.0],
        ),
        // No drop shadow here — it would fall onto the paper below. The cap's
        // separation from the base comes from the base being darker.
      ),
      child: Stack(
        children: [
          // Localized top-centre reflection — an ellipse of light, stronger in
          // the middle and fading toward the ends, not a full-width band.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.8),
                  radius: 0.9,
                  colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
          ),
          // Subtle darkening on the left/right edges (rounded moulded sides).
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0x1A000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0x14000000),
                  ],
                  stops: [0.0, 0.10, 0.90, 1.0],
                ),
              ),
            ),
          ),
          // Brand + status LED treated as one functional block on the façade.
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 4.5,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C8A5A),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4C8A5A).withValues(alpha: 0.4),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'ICprint',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                      // Darker, matte grey with a hair of light beneath — reads
                      // as engraved/screen-printed into the shell.
                      color: const Color(0xFF6C6C6C),
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.4),
                          offset: const Offset(0, 0.7),
                        ),
                      ],
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

/// The back box of the printer (the reference `::before`): a plain light-grey
/// panel that extends below the bevelled face to frame the slot, and carries
/// the whole unit's drop shadow.
class _PrinterChin extends StatelessWidget {
  const _PrinterChin();

  @override
  Widget build(BuildContext context) {
    // Container (not a bare DecoratedBox) so the child side-shading gradient is
    // clipped to the rounded shape — otherwise it bleeds into the square corners
    // of the bounding box, showing a grey rectangle around the rounded shell.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Darker than the cap so the base reads as a distinct, slightly
        // recessed second volume rather than blending into the shadow.
        color: const Color(0xFFAEAEAE),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_kBodyRadiusTop),
          bottom: Radius.circular(_kBodyRadiusBottom),
        ),
        // Two-part ground shadow: a tight, darker contact shadow directly under
        // the base, plus a wide, very light ambient one — depth without the
        // diffuse grey mass to the right.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 7,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 34,
            offset: const Offset(2, 18),
          ),
        ],
      ),
      // Subtle side shading so the exposed chin reads as moulded, not flat.
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0x22000000),
              Color(0x00000000),
              Color(0x00000000),
              Color(0x1C000000),
            ],
            stops: [0.0, 0.10, 0.90, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Reveals its child top-to-bottom, so the receipt appears to unroll out of the
/// slot. Uses `Align`'s height factor (no measured height needed) inside a
/// clip, which stays cheap and works within a scroll view.
/// Feeds the whole sheet down out of the slot: during the print it slides the
/// paper (text and all) from fully tucked inside the printer to its resting
/// position, so the printed lines travel out with the paper. Once fed, it hands
/// over to a scroll view so the rest of a long receipt can be read.
class _ReceiptFeed extends StatelessWidget {
  final Animation<double> animation;
  final bool printed;
  final Widget child;

  const _ReceiptFeed({
    required this.animation,
    required this.printed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (printed) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: child,
      );
    }
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final dy = -_kSlideFraction * (1 - animation.value.clamp(0.0, 1.0));
        // OverflowBox relaxes the mouth's height so the sheet lays out at its
        // full intrinsic height; FractionalTranslation then slides it by a
        // fraction of that height (mirrors the reference translateY %).
        return OverflowBox(
          minHeight: 0,
          maxHeight: double.infinity,
          alignment: Alignment.topCenter,
          child: FractionalTranslation(
            translation: Offset(0, dy),
            child: child,
          ),
        );
      },
    );
  }
}

class _ReceiptPaper extends StatelessWidget {
  final CartView view;
  final String symbol;

  const _ReceiptPaper({required this.view, required this.symbol});

  @override
  Widget build(BuildContext context) {
    // A soft, offsetless drop shadow following the paper's torn silhouette
    // (mirrors the mouth's `drop-shadow(0 0 15px)`), painted behind the sheet
    // and moving with it as it feeds out — so the emerging paper casts a shadow
    // on the page behind it.
    return CustomPaint(
      painter: const _PaperShadowPainter(),
      child: PhysicalShape(
        clipper: const _ScallopedPaperClipper(),
        color: _kPaper,
        elevation: 0,
        child: Padding(
          // Blank leading paper before the logo, so a plain edge feeds out of
          // the slot and the content isn't crammed right under the dark lip.
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
          child: _ReceiptBody(view: view, symbol: symbol),
        ),
      ),
    );
  }
}

class _PaperShadowPainter extends CustomPainter {
  const _PaperShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = const _ScallopedPaperClipper().getClip(size);
    void drop(double dx, double dy, double sigma, double alpha) {
      canvas
        ..save()
        ..translate(dx, dy)
        ..drawPath(
          path,
          Paint()
            ..color = Colors.black.withValues(alpha: alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
        )
        ..restore();
    }

    // A tight, near-symmetric edge shadow that hugs the silhouette — it gives
    // the vertical sides definition (paper thickness) rather than flat edges...
    drop(0, 2, 4, 0.15);
    // ...plus a wider, softer, diffuse ambient falling down and to the right.
    drop(5, 10, 15, 0.11);
  }

  @override
  bool shouldRepaint(_PaperShadowPainter oldDelegate) => false;
}

class _ReceiptBody extends StatelessWidget {
  final CartView view;
  final String symbol;

  const _ReceiptBody({required this.view, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final totals = view.cart.totals;
    final entries = view.entries;
    final itemCount = entries.fold<int>(0, (sum, e) => sum + e.quantity);
    final stamp = _formatStamp(
      view.cart.updated ?? view.cart.created ?? DateTime.now(),
    );
    final orderRef = _orderRef(view.cart.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(LucideIcons.shoppingBasket, size: 30, color: _kInk),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'KIKI MARKET',
            style: _mono(size: 20, weight: FontWeight.w700, letterSpacing: 2),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'TICKET DE CAISSE',
            style: _mono(size: 11, color: _kFaint, letterSpacing: 3),
          ),
        ),
        const SizedBox(height: 18),
        _kv('COMMANDE', orderRef),
        _kv('DATE', stamp),
        _kv('ARTICLES', '$itemCount'),
        const SizedBox(height: 14),
        const _DashedDivider(),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text('ARTICLE', style: _mono(size: 11, color: _kFaint)),
            ),
            SizedBox(
              width: 34,
              child: Text(
                'QTÉ',
                textAlign: TextAlign.center,
                style: _mono(size: 11, color: _kFaint),
              ),
            ),
            SizedBox(
              width: 78,
              child: Text(
                'PRIX',
                textAlign: TextAlign.right,
                style: _mono(size: 11, color: _kFaint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const _DashedDivider(),
        const SizedBox(height: 8),
        for (final entry in entries) _ReceiptLine(entry: entry, symbol: symbol),
        const SizedBox(height: 8),
        const _DashedDivider(),
        const SizedBox(height: 12),
        if (totals.subtotal > 0) _total('SOUS-TOTAL', totals.subtotal, symbol),
        if (totals.discountTotal > 0)
          _total('REMISE', -totals.discountTotal, symbol),
        if (totals.shippingTotal > 0)
          _total('LIVRAISON', totals.shippingTotal, symbol),
        if (totals.taxTotal > 0) _total('DONT TVA', totals.taxTotal, symbol),
        const SizedBox(height: 8),
        _total('TOTAL', totals.grandTotal, symbol, emphasise: true),
        const SizedBox(height: 20),
        const _DashedDivider(),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'MERCI DE VOTRE VISITE',
            style: _mono(size: 12, weight: FontWeight.w600, letterSpacing: 1),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'À BIENTÔT',
            style: _mono(size: 11, color: _kFaint, letterSpacing: 2),
          ),
        ),
        const SizedBox(height: 18),
        _Barcode(seed: orderRef),
        const SizedBox(height: 6),
        Center(
          child: Text(
            orderRef,
            style: _mono(size: 11, color: _kFaint, letterSpacing: 4),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(label, style: _mono(size: 12, color: _kFaint)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: _mono(size: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _total(
    String label,
    double value,
    String symbol, {
    bool emphasise = false,
  }) {
    final style = emphasise
        ? _mono(size: 16, weight: FontWeight.w700)
        : _mono(size: 12.5);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: emphasise ? 2 : 1),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(_money(value, symbol), style: style),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  final CartEntry entry;
  final String symbol;

  const _ReceiptLine({required this.entry, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.productNameSnapshot.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _mono(size: 12.5, height: 1.3),
                ),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '${entry.quantity}',
                  textAlign: TextAlign.center,
                  style: _mono(size: 12.5),
                ),
              ),
              SizedBox(
                width: 78,
                child: Text(
                  _money(entry.lineTotal, symbol),
                  textAlign: TextAlign.right,
                  style: _mono(size: 12.5),
                ),
              ),
            ],
          ),
          if (entry.quantity > 1)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                '${entry.quantity} x ${_money(entry.unitPrice, symbol)}',
                style: _mono(size: 11, color: _kFaint),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(painter: _DashedPainter(), size: Size.infinite),
    );
  }
}

class _DashedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kFaint
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedPainter oldDelegate) => false;
}

/// Decorative faux barcode, seeded off the order reference so it is stable per
/// cart but varies between them.
class _Barcode extends StatelessWidget {
  final String seed;

  const _Barcode({required this.seed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: CustomPaint(painter: _BarcodePainter(seed), size: Size.infinite),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  final String seed;

  _BarcodePainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _kInk;
    final codes = seed.isEmpty ? const [7] : seed.codeUnits;
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final c = codes[i % codes.length] + i * 7;
      final width = 1.0 + (c % 4);
      final gap = 1.0 + ((c >> 2) % 3);
      if (c.isEven) {
        canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
      }
      x += width + gap;
      i++;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) => oldDelegate.seed != seed;
}

/// Straight top (tucked under the slot), zig-zag "torn" bottom edge.
/// Straight top (behind the mouth) and a scalloped bottom of concave
/// semicircle notches — the reference's `mask: radial-gradient(circle at
/// bottom, transparent, black)`.
class _ScallopedPaperClipper extends CustomClipper<Path> {
  const _ScallopedPaperClipper();

  @override
  Path getClip(Size size) {
    const r = 8.0; // scallop radius (~.5rem)
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height);
    var x = size.width;
    while (x > 0) {
      final nextX = (x - 2 * r).clamp(0.0, size.width);
      path.arcToPoint(
        Offset(nextX, size.height),
        radius: const Radius.circular(r),
        clockwise: false, // bulge up into the sheet (a notch)
      );
      x -= 2 * r;
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_ScallopedPaperClipper oldClipper) => false;
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.06),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            LucideIcons.x,
            size: 20,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

String _money(double value, String symbol) =>
    // French formatting: comma decimal separator on a French receipt.
    '${value.toStringAsFixed(2).replaceAll('.', ',')}$symbol';

String _currencySymbol(String? code) {
  switch ((code ?? 'EUR').toUpperCase()) {
    case 'EUR':
      return ' €';
    case 'USD':
      return r' $';
    case 'GBP':
      return ' £';
    default:
      return ' ${(code ?? 'EUR').toUpperCase()}';
  }
}

String _formatStamp(DateTime date) {
  final local = date.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}  '
      '${two(local.hour)}:${two(local.minute)}';
}

String _orderRef(String id) {
  final cleaned = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  if (cleaned.isEmpty) return '#000000';
  final tail = cleaned.length <= 6
      ? cleaned.padLeft(6, '0')
      : cleaned.substring(cleaned.length - 6);
  return '#$tail';
}
