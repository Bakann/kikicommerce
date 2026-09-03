import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/catalog/catalog_entities.dart';
import '../../widgets/pdp_purchase_bar.dart';
import '../product_detail_layout_spec.dart';
import 'product_detail_purchase.dart';

/// Add-to-cart affordance rendered inside the PDP loading skeleton. It stays
/// disabled until the route-enter animation completes (or a fallback timer
/// fires) so a tap cannot fire mid-flight.
@visibleForTesting
class PdpLoadingQuickAddSection extends StatefulWidget {
  final ProductDetailLayoutSpec layout;
  final CatalogPrice defaultPrice;
  final String symbol;
  final Future<bool> Function() onAddToCart;

  const PdpLoadingQuickAddSection({
    super.key,
    required this.layout,
    required this.defaultPrice,
    required this.symbol,
    required this.onAddToCart,
  });

  @override
  State<PdpLoadingQuickAddSection> createState() =>
      _PdpLoadingQuickAddSectionState();
}

class _PdpLoadingQuickAddSectionState extends State<PdpLoadingQuickAddSection> {
  static const _routeFlightFallback = Duration(milliseconds: 560);

  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeStatusListener;
  Timer? _routeFlightFallbackTimer;
  bool _routeReady = false;
  bool _isAdding = false;

  bool get _canSubmit => _routeReady && !_isAdding;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachRouteReadinessGuard();
  }

  @override
  void dispose() {
    _detachRouteAnimation();
    _routeFlightFallbackTimer?.cancel();
    super.dispose();
  }

  void _attachRouteReadinessGuard() {
    if (_routeReady ||
        _routeAnimation != null ||
        _routeFlightFallbackTimer != null) {
      return;
    }

    final animation = ModalRoute.of(context)?.animation;
    if (animation?.status == AnimationStatus.completed) {
      _routeReady = true;
      return;
    }

    if (animation != null) {
      _routeAnimation = animation;
      _routeStatusListener = (status) {
        if (status == AnimationStatus.completed) {
          _markRouteReady();
        }
      };
      animation.addStatusListener(_routeStatusListener!);
    }

    _routeFlightFallbackTimer = Timer(_routeFlightFallback, _markRouteReady);
  }

  void _detachRouteAnimation() {
    final listener = _routeStatusListener;
    final animation = _routeAnimation;
    if (animation != null && listener != null) {
      animation.removeStatusListener(listener);
    }
    _routeAnimation = null;
    _routeStatusListener = null;
  }

  void _markRouteReady() {
    if (_routeReady) {
      return;
    }
    _detachRouteAnimation();
    _routeFlightFallbackTimer?.cancel();
    _routeFlightFallbackTimer = null;
    if (!mounted) {
      return;
    }
    setState(() => _routeReady = true);
  }

  Future<bool> _handleTap() => _handleAddToCart();

  Future<bool> _handleAddToCart() async {
    if (!_canSubmit) {
      return false;
    }
    setState(() => _isAdding = true);
    try {
      return await widget.onAddToCart();
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = const ValueKey('pdp-loading-quick-add');

    if (widget.layout.isMobile) {
      return KeyedSubtree(
        key: key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PdpPaymentBadges(),
            const SizedBox(height: 14),
            AbsorbPointer(
              absorbing: !_canSubmit,
              child: PdpPurchaseBar(
                key: const ValueKey('pdp-loading-quick-add-button'),
                defaultPrice: widget.defaultPrice,
                symbol: widget.symbol,
                onAddToCart: _handleTap,
                includeSafeArea: false,
                height: kMobilePurchaseBarHeight,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      );
    }

    final desktopButton = HeroPurchaseButton(
      key: const ValueKey('pdp-loading-quick-add-button'),
      defaultPrice: widget.defaultPrice,
      symbol: widget.symbol,
      onPressed: _canSubmit ? _handleTap : null,
    );

    if (widget.layout.isDesktop) {
      return KeyedSubtree(
        key: key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PdpPaymentBadges(compact: true),
            const SizedBox(height: 14),
            desktopButton,
          ],
        ),
      );
    }

    return KeyedSubtree(key: key, child: desktopButton);
  }
}
