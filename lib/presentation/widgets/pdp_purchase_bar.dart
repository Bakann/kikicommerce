import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import '../../core/utils/price_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import '../l10n/l10n_extension.dart';

const String _kPdpHeatmapShaderAsset =
    'assets/shaders/pdp_add_to_cart_heatmap.frag';
const Duration _kPdpHeatmapDuration = Duration(milliseconds: 2400);

/// Visual phase of the bar's add-to-cart flow.
///
/// On tap the heatmap plays immediately ([pending]) as the wait indicator; the
/// label only resolves to [added] or [error] once the server responds.
enum _BarPhase { idle, pending, added, error }

class PdpPurchaseBar extends StatefulWidget {
  final CatalogPrice? defaultPrice;
  final String symbol;

  /// Performs the add-to-cart and resolves to `true` on success, `false` on
  /// failure. Must not throw — failure is reported in-bar, not via exception.
  final Future<bool> Function() onAddToCart;
  final BorderRadiusGeometry borderRadius;
  final bool includeSafeArea;
  final double height;

  const PdpPurchaseBar({
    super.key,
    required this.defaultPrice,
    required this.symbol,
    required this.onAddToCart,
    this.borderRadius = BorderRadius.zero,
    this.includeSafeArea = true,
    this.height = 56,
  });

  @override
  State<PdpPurchaseBar> createState() => _PdpPurchaseBarState();
}

class _PdpPurchaseBarState extends State<PdpPurchaseBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _kPdpHeatmapDuration,
  );

  _BarPhase _phase = _BarPhase.idle;
  Timer? _errorResetTimer;

  @override
  void initState() {
    super.initState();
    unawaited(ShaderBuilder.precacheShader(_kPdpHeatmapShaderAsset));
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    // Once the success reveal finishes, fade back to the price CTA.
    if (status == AnimationStatus.completed && _phase == _BarPhase.added) {
      setState(() => _phase = _BarPhase.idle);
    }
  }

  @override
  void dispose() {
    _errorResetTimer?.cancel();
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    // Only the idle bar is tappable (pending/added/error all block re-entry).
    if (_phase != _BarPhase.idle) return;
    _errorResetTimer?.cancel();

    // Play the heatmap immediately as the wait indicator (no spinner), then
    // await the server in parallel.
    setState(() => _phase = _BarPhase.pending);
    _controller.forward(from: 0);

    bool ok;
    try {
      ok = await widget.onAddToCart();
    } catch (_) {
      ok = false; // defensive: a thrown callback is still a failure
    }
    if (!mounted) return;

    if (ok) {
      // Confirmed: swap the label to "Ajouté". The heatmap keeps playing to its
      // end; if the server outran it, replay a clean reveal under the label.
      setState(() => _phase = _BarPhase.added);
      if (_controller.status == AnimationStatus.completed) {
        _controller.forward(from: 0);
      }
    } else {
      // Stop the heatmap and surface a short error, then fall back to the CTA.
      setState(() => _phase = _BarPhase.error);
      _controller
        ..stop()
        ..value = 0;
      _errorResetTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _phase = _BarPhase.idle);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceLabel = widget.defaultPrice == null
        ? 'Indisponible'
        : formatPrice(widget.defaultPrice!.price, widget.symbol);

    // Bottom layer: the dark bar, replaced by the flowing heatmap on success.
    // The label is NOT in here, so it is never rasterised into the shader
    // texture (that texture sampling is what pixelated the glyphs).
    final heatedBar = _PdpHeatmapEffect(
      controller: _controller,
      child: const ColoredBox(color: Color(0xFF2D2D2A)),
    );

    // Top layer: crisp vector content, tappable, cross-fading between the CTA,
    // a loading spinner, the "Ajouté" confirmation and a short error.
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        // Only enabled while idle: no spam, no re-trigger mid-flight.
        onTap: _phase == _BarPhase.idle ? _handleTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_phase) {
              _BarPhase.added => _AddedLabel(
                label: context.l10n.pdpAddedToCart,
              ),
              _BarPhase.error => _ErrorLabel(
                label: context.l10n.pdpAddToCartRetry,
              ),
              // idle and pending share the CTA; pending just plays the heatmap.
              _BarPhase.idle || _BarPhase.pending => _CtaLabel(
                label: context.l10n.pdpAddToCart,
                price: priceLabel,
              ),
            },
          ),
        ),
      ),
    );

    final button = SizedBox(
      height: widget.height,
      child: Stack(fit: StackFit.expand, children: [heatedBar, content]),
    );

    final clipped = ClipRRect(borderRadius: widget.borderRadius, child: button);
    if (!widget.includeSafeArea) {
      return clipped;
    }

    return SafeArea(top: false, child: clipped);
  }
}

// Soft dark halo so the white text stays legible over the bright heatmap.
const List<Shadow> _kLabelShadows = [
  Shadow(color: Color(0xB3000000), blurRadius: 6),
  Shadow(color: Color(0x80000000), blurRadius: 2),
];

class _CtaLabel extends StatelessWidget {
  final String label;
  final String price;

  const _CtaLabel({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('cta'),
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.1,
              shadows: _kLabelShadows,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            price,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.1,
              shadows: _kLabelShadows,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddedLabel extends StatelessWidget {
  final String label;

  const _AddedLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('added'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 20,
          shadows: _kLabelShadows,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.1,
            shadows: _kLabelShadows,
          ),
        ),
      ],
    );
  }
}

class _ErrorLabel extends StatelessWidget {
  final String label;

  const _ErrorLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('error'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: Colors.white,
          size: 20,
          shadows: _kLabelShadows,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.1,
              shadows: _kLabelShadows,
            ),
          ),
        ),
      ],
    );
  }
}

/// Samples [child] into a texture and runs the heatmap shader over it while
/// [controller] animates, then falls back to the untouched child when idle.
class _PdpHeatmapEffect extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _PdpHeatmapEffect({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final value = controller.value;
        final isActive = controller.isAnimating || (value > 0 && value < 1);
        if (!isActive || child == null) {
          return child ?? const SizedBox.shrink();
        }

        return RepaintBoundary(
          child: ShaderBuilder(
            (context, shader, shaderChild) {
              final sampledChild = shaderChild ?? const SizedBox.shrink();
              return AnimatedSampler((
                ui.Image image,
                Size size,
                ui.Canvas canvas,
              ) {
                if (size.isEmpty) return;
                shader
                  ..setFloat(0, size.width)
                  ..setFloat(1, size.height)
                  ..setFloat(2, value)
                  ..setImageSampler(0, image);
                canvas.drawRect(
                  Offset.zero & size,
                  ui.Paint()..shader = shader,
                );
              }, child: sampledChild);
            },
            assetKey: _kPdpHeatmapShaderAsset,
            child: child,
          ),
        );
      },
    );
  }
}
