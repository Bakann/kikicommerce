import 'package:flutter/material.dart';

import '../../../domain/catalog/catalog_entities.dart';
import '../../widgets/navigation/premium_shell_navbar.dart';
import '../../widgets/pdp_purchase_bar.dart';
import 'product_detail_purchase.dart';

class MobilePdpPurchaseSurface extends StatefulWidget {
  final Widget Function(ScrollController controller) scrollBuilder;
  final GlobalKey anchorKey;
  final CatalogPrice? defaultPrice;
  final String symbol;
  final Future<bool> Function() onAddToCart;

  @visibleForTesting
  final VoidCallback? debugOnAnchorMeasured;

  @visibleForTesting
  final ValueChanged<Rect>? debugOnOverlayRectChanged;

  const MobilePdpPurchaseSurface({
    super.key,
    required this.scrollBuilder,
    required this.anchorKey,
    required this.defaultPrice,
    required this.symbol,
    required this.onAddToCart,
    this.debugOnAnchorMeasured,
    this.debugOnOverlayRectChanged,
  });

  @override
  State<MobilePdpPurchaseSurface> createState() =>
      _MobilePdpPurchaseSurfaceState();
}

class _MobilePdpPurchaseSurfaceState extends State<MobilePdpPurchaseSurface> {
  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<Rect?> _overlayRect = ValueNotifier<Rect?>(null);

  Rect? _baseAnchorRect;
  double? _baseScrollPixels;
  bool _measureScheduled = false;

  Size? _lastSize;
  EdgeInsets? _lastPadding;
  double? _lastTopObstruction;

  bool _isDraggingOverlay = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_refreshOverlayRect);
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant MobilePdpPurchaseSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorKey != widget.anchorKey) {
      _baseAnchorRect = null;
      _baseScrollPixels = null;
    }
    // Safety: if a pointer-up was lost across a widget update, the flag could
    // permanently disable ScrollEnd recalibration. Reset it here.
    _isDraggingOverlay = false;
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_refreshOverlayRect);
    _scrollController.dispose();
    _overlayRect.dispose();
    super.dispose();
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || notification.depth != 0) {
      return false;
    }

    if (notification is ScrollEndNotification && !_isDraggingOverlay) {
      _scheduleMeasure();
    }
    return false;
  }

  void _scrollBy(double deltaY) {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final nextPixels = (position.pixels - deltaY)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((nextPixels - position.pixels).abs() < 0.5) {
      return;
    }

    position.jumpTo(nextPixels);
  }

  void _handleOverlayPointerMove(PointerMoveEvent event) {
    _isDraggingOverlay = true;
    final deltaY = event.delta.dy;
    if (deltaY.abs() < 0.5) {
      return;
    }

    _scrollBy(deltaY);
  }

  void _handleOverlayPointerUp(PointerUpEvent event) {
    _isDraggingOverlay = false;
    _scheduleMeasure();
  }

  void _handleOverlayPointerCancel(PointerCancelEvent event) {
    _isDraggingOverlay = false;
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) {
        return;
      }
      _measureAnchor();
    });
  }

  void _measureAnchor() {
    assert(() {
      widget.debugOnAnchorMeasured?.call();
      return true;
    }());

    final surfaceObject = context.findRenderObject();
    final anchorObject = widget.anchorKey.currentContext?.findRenderObject();
    if (surfaceObject is! RenderBox ||
        anchorObject is! RenderBox ||
        !surfaceObject.attached ||
        !anchorObject.attached ||
        !surfaceObject.hasSize ||
        !anchorObject.hasSize) {
      return;
    }

    final offset = anchorObject.localToGlobal(
      Offset.zero,
      ancestor: surfaceObject,
    );
    final nextRect = offset & anchorObject.size;
    final currentPixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;

    final previousBase = _baseAnchorRect;
    if (previousBase != null &&
        (previousBase.left - nextRect.left).abs() < 0.5 &&
        (previousBase.top - nextRect.top).abs() < 0.5 &&
        (previousBase.width - nextRect.width).abs() < 0.5 &&
        (previousBase.height - nextRect.height).abs() < 0.5 &&
        _baseScrollPixels != null &&
        (_baseScrollPixels! - currentPixels).abs() < 0.5) {
      return;
    }

    _baseAnchorRect = nextRect;
    _baseScrollPixels = currentPixels;
    _refreshOverlayRect();
  }

  Rect? get _currentAnchorRect {
    if (_baseAnchorRect == null || _baseScrollPixels == null) return null;
    if (!_scrollController.hasClients) return _baseAnchorRect;
    final currentPixels = _scrollController.position.pixels;
    final deltaY = currentPixels - _baseScrollPixels!;
    return _baseAnchorRect!.translate(0, -deltaY);
  }

  Rect _fixedOverlayRect(
    Size size, {
    required double topInset,
    required double bottomInset,
    required bool pinToTop,
  }) {
    final top = pinToTop
        ? topInset + 20
        : size.height - bottomInset - 20 - kMobilePurchaseBarHeight;
    final anchor = _currentAnchorRect;
    if (anchor != null && anchor.width > 0) {
      final width = anchor.width.clamp(120.0, size.width - 32).toDouble();
      final left = anchor.left.clamp(16.0, size.width - width - 16).toDouble();
      return Rect.fromLTWH(left, top, width, kMobilePurchaseBarHeight);
    }

    final initialSide = (size.width * 0.07).clamp(22.0, 48.0).toDouble();
    return Rect.fromLTWH(
      initialSide,
      top,
      size.width - (initialSide * 2),
      kMobilePurchaseBarHeight,
    );
  }

  Rect _purchaseRect(
    Size size,
    EdgeInsets viewPadding, {
    required double topObstruction,
  }) {
    final anchor = _currentAnchorRect;
    if (anchor == null) {
      return _fixedOverlayRect(
        size,
        topInset: topObstruction,
        bottomInset: viewPadding.bottom,
        pinToTop: false,
      );
    }

    final isAnchorFullyVisible =
        anchor.top >= topObstruction &&
        anchor.bottom <= size.height - viewPadding.bottom;
    if (isAnchorFullyVisible) {
      return Rect.fromLTWH(
        anchor.left,
        anchor.top,
        anchor.width,
        anchor.height,
      );
    }

    return _fixedOverlayRect(
      size,
      topInset: topObstruction,
      bottomInset: viewPadding.bottom,
      pinToTop: anchor.top < topObstruction,
    );
  }

  bool _isAnchorFullyVisible(Rect rect, Size size, EdgeInsets viewPadding) {
    final topObstruction = _lastTopObstruction;
    if (topObstruction == null) {
      return false;
    }
    return rect.top >= topObstruction &&
        rect.bottom <= size.height - viewPadding.bottom;
  }

  bool get _anchorPaintsPurchaseBar {
    final widget = this.widget.anchorKey.currentWidget;
    return widget is MobilePurchaseAnchor && widget.child != null;
  }

  void _refreshOverlayRect() {
    final size = _lastSize;
    final padding = _lastPadding;
    final topObstruction = _lastTopObstruction;
    if (size == null || padding == null || topObstruction == null) {
      return;
    }
    final next = _purchaseRect(size, padding, topObstruction: topObstruction);
    final current = _overlayRect.value;
    if (current != null &&
        (current.left - next.left).abs() < 0.5 &&
        (current.top - next.top).abs() < 0.5 &&
        (current.width - next.width).abs() < 0.5 &&
        (current.height - next.height).abs() < 0.5) {
      return;
    }
    _overlayRect.value = next;
    assert(() {
      widget.debugOnOverlayRectChanged?.call(next);
      return true;
    }());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final size = Size(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : mediaSize.width,
          constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : mediaSize.height,
        );
        final viewPadding = MediaQuery.paddingOf(context);
        final shellNavbarMetrics = PremiumShellNavbarMetrics.maybeOf(context);
        final topObstruction =
            shellNavbarMetrics?.visibleReservedHeight ?? viewPadding.top;

        if (_lastSize != size ||
            _lastPadding != viewPadding ||
            _lastTopObstruction != topObstruction) {
          _lastSize = size;
          _lastPadding = viewPadding;
          _lastTopObstruction = topObstruction;
          _scheduleMeasure();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _refreshOverlayRect();
          });
        }

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: widget.scrollBuilder(_scrollController),
            ),
            ValueListenableBuilder<Rect?>(
              valueListenable: _overlayRect,
              child: RepaintBoundary(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerMove: _handleOverlayPointerMove,
                  onPointerUp: _handleOverlayPointerUp,
                  onPointerCancel: _handleOverlayPointerCancel,
                  child: PdpPurchaseBar(
                    defaultPrice: widget.defaultPrice,
                    symbol: widget.symbol,
                    onAddToCart: widget.onAddToCart,
                    includeSafeArea: false,
                    height: kMobilePurchaseBarHeight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              builder: (context, rect, child) {
                if (rect == null) {
                  return const SizedBox.shrink();
                }
                if (_anchorPaintsPurchaseBar &&
                    _isAnchorFullyVisible(rect, size, viewPadding)) {
                  return const SizedBox.shrink();
                }
                final effective = rect;
                return Positioned.fromRect(rect: effective, child: child!);
              },
            ),
          ],
        );
      },
    );
  }
}
