import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/price_utils.dart';
import '../../../domain/catalog/catalog_entities.dart';
import '../../l10n/l10n_extension.dart';
import '../product_detail_layout_spec.dart';

const bool _kRainbowPastelEnabled = bool.fromEnvironment(
  'PDP_LOADING_RAINBOW_PASTEL',
);

const bool _kDebugStrongPdpShimmer = bool.fromEnvironment(
  'DEBUG_STRONG_PDP_SHIMMER',
);

class ProductDetailLoadingSkeleton extends StatefulWidget {
  final ProductDetailLayoutSpec layout;
  final Widget? commerceSlot;
  final CatalogProduct? loadingProduct;

  const ProductDetailLoadingSkeleton({
    super.key,
    required this.layout,
    this.commerceSlot,
    this.loadingProduct,
  });

  @override
  State<ProductDetailLoadingSkeleton> createState() =>
      _ProductDetailLoadingSkeletonState();
}

class _ProductDetailLoadingSkeletonState
    extends State<ProductDetailLoadingSkeleton> {
  Timer? _motionTimer;
  Timer? _longLoadingHintTimer;
  bool _showMotion = false;
  bool _showLongLoadingHint = false;

  @override
  void initState() {
    super.initState();
    _motionTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _showMotion = true);
      }
    });
    _longLoadingHintTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() => _showLongLoadingHint = true);
      }
    });
  }

  @override
  void dispose() {
    _motionTimer?.cancel();
    _longLoadingHintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final motionActive = !disableAnimations && _showMotion;
    final rainbowActive = motionActive && _kRainbowPastelEnabled;

    final skeleton = KeyedSubtree(
      key: const ValueKey('pdp-loading-details-skeleton'),
      child: widget.layout.isMobile
          ? _MobileLoadingSkeleton(
              layout: widget.layout,
              commerceSlot: widget.commerceSlot,
              loadingProduct: widget.loadingProduct,
            )
          : _WideLoadingSkeleton(
              layout: widget.layout,
              commerceSlot: widget.commerceSlot,
              loadingProduct: widget.loadingProduct,
            ),
    );

    Widget skeletonZone;
    if (!motionActive) {
      skeletonZone = ExcludeSemantics(child: skeleton);
    } else {
      skeletonZone = ExcludeSemantics(
        child: RepaintBoundary(
          child: _SkeletonMotionScope(
            child: KeyedSubtree(
              key: const ValueKey('pdp-loading-skeleton-shimmer'),
              child: rainbowActive
                  ? _RainbowPastelBackdropHost(child: skeleton)
                  : skeleton,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        skeletonZone,
        if (_showLongLoadingHint) ...[
          const SizedBox(height: 18),
          const ExcludeSemantics(child: _LongLoadingHint()),
        ],
      ],
    );
  }
}

class _PremiumSkeletonTheme {
  static const Color fill = Color(0xFFEDEAE3);
  static const Color fillStrong = Color(0xFFE4E0D8);
  static const Color stroke = Color(0xFFE0DED9);
  // The moving band is intentionally dark: light-on-light shimmer was too
  // subtle on real devices, while a dark pass remains visible on ivory fills.
  static const Color highlight = Color(0x80000000);
  static const Color highlightStrong = Color(0x80000000);
}

class _SkeletonMotionScope extends StatefulWidget {
  final Widget child;

  const _SkeletonMotionScope({required this.child});

  static Animation<double>? of(BuildContext context) {
    final inh = context
        .dependOnInheritedWidgetOfExactType<_SkeletonMotionInherited>();
    return inh?.animation;
  }

  @override
  State<_SkeletonMotionScope> createState() => _SkeletonMotionScopeState();
}

class _SkeletonMotionScopeState extends State<_SkeletonMotionScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonMotionInherited(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _SkeletonMotionInherited extends InheritedWidget {
  final Animation<double> animation;

  const _SkeletonMotionInherited({
    required this.animation,
    required super.child,
  });

  @override
  bool updateShouldNotify(_SkeletonMotionInherited old) =>
      old.animation != animation;
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

class _SkeletonShimmer extends StatelessWidget {
  final Animation<double> animation;
  final Color baseColor;
  final Color highlightColor;
  final Widget child;

  const _SkeletonShimmer({
    required this.animation,
    required this.baseColor,
    required this.highlightColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final lowlightColor = Color.alphaBlend(const Color(0x2E8F7F61), baseColor);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        // Sweep the highlight band from off-screen left to off-screen right.
        final slide = (animation.value * 2.0) - 1.0;
        final colors = _kDebugStrongPdpShimmer
            ? const [Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFF000000)]
            : [
                baseColor,
                lowlightColor,
                highlightColor,
                lowlightColor,
                baseColor,
              ];
        final stops = _kDebugStrongPdpShimmer
            ? const [0.35, 0.5, 0.65]
            : const [0.0, 0.43, 0.5, 0.57, 1.0];
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: colors,
              stops: stops,
              transform: _SlidingGradientTransform(slide),
            ).createShader(rect);
          },
          child: child,
        );
      },
    );
  }
}

class _LongLoadingHint extends StatelessWidget {
  const _LongLoadingHint();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Chargement des détails…',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, height: 1.3, color: Color(0xFF8A8780)),
    );
  }
}

class _RainbowPastelBackdropHost extends StatelessWidget {
  final Widget child;

  const _RainbowPastelBackdropHost({required this.child});

  @override
  Widget build(BuildContext context) {
    final animation = _SkeletonMotionScope.of(context);
    if (animation == null) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: _RainbowPastelBackdrop(animation: animation),
          ),
        ),
        child,
      ],
    );
  }
}

class _RainbowPastelBackdrop extends StatelessWidget {
  final Animation<double> animation;

  const _RainbowPastelBackdrop({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        final t = animation.value;
        final shift = t * 0.4;
        return Opacity(
          opacity: 0.06,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + shift, -1.0),
                end: Alignment(1.0 + shift, 1.0),
                colors: const [
                  Color(0xFFFCE4EC),
                  Color(0xFFE3F2FD),
                  Color(0xFFFFF8E1),
                  Color(0xFFE8F5E9),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileLoadingSkeleton extends StatelessWidget {
  final ProductDetailLayoutSpec layout;
  final Widget? commerceSlot;
  final CatalogProduct? loadingProduct;

  const _MobileLoadingSkeleton({
    required this.layout,
    this.commerceSlot,
    this.loadingProduct,
  });

  @override
  Widget build(BuildContext context) {
    final product = loadingProduct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (product == null)
          const _SkeletonProductHeading()
        else
          _KnownProductHeading(
            product: product,
            layout: layout,
            isNew: isNewProduct(product.onlineDate),
          ),
        const SizedBox(height: 30),
        if (commerceSlot == null) ...const [
          _PaymentBadgesSkeleton(),
          SizedBox(height: 14),
          _SkeletonButton(height: 58, radius: 8),
          SizedBox(height: 14),
          _SkeletonOutlineButton(height: 56),
        ] else ...[
          commerceSlot!,
          const SizedBox(height: 14),
          const _SkeletonOutlineButton(height: 56),
        ],
        const SizedBox(height: 54),
        const _MobileAccordionSkeleton(),
      ],
    );
  }
}

class _WideLoadingSkeleton extends StatelessWidget {
  final ProductDetailLayoutSpec layout;
  final Widget? commerceSlot;
  final CatalogProduct? loadingProduct;

  const _WideLoadingSkeleton({
    required this.layout,
    this.commerceSlot,
    this.loadingProduct,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = layout.isDesktop;
    final product = loadingProduct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (product == null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: _SkeletonBlock(width: isDesktop ? 88 : 104, height: 11),
          ),
          SizedBox(height: isDesktop ? 16 : 20),
          _SkeletonProductHeading(iconSize: isDesktop ? 24 : 28),
        ] else
          _KnownProductHeading(
            product: product,
            layout: layout,
            isNew: isNewProduct(product.onlineDate),
          ),
        if (commerceSlot == null) ...[
          SizedBox(height: isDesktop ? 34 : 38),
          const _SkeletonBlock(width: 118, height: 18),
          SizedBox(height: isDesktop ? 38 : 34),
          const _PaymentBadgesSkeleton(compact: true),
          const SizedBox(height: 14),
          const _SkeletonButton(height: 56),
          const SizedBox(height: 14),
          const _SkeletonOutlineButton(height: 56),
          SizedBox(height: isDesktop ? 44 : 34),
        ] else if (isDesktop && product != null) ...[
          const SizedBox(height: 46),
          commerceSlot!,
          const SizedBox(height: 14),
          const _SkeletonOutlineButton(height: 56),
          const SizedBox(height: 22),
          const _DesktopPurchaseServicesSkeleton(),
          const SizedBox(height: 80),
        ] else ...[
          SizedBox(height: isDesktop ? 46 : 38),
          commerceSlot!,
          const SizedBox(height: 14),
          const _SkeletonOutlineButton(height: 56),
          SizedBox(height: isDesktop ? 80 : 34),
        ],
        const _TabsSkeleton(),
      ],
    );
  }
}

class _KnownProductHeading extends StatelessWidget {
  final CatalogProduct product;
  final ProductDetailLayoutSpec layout;
  final bool isNew;

  const _KnownProductHeading({
    required this.product,
    required this.layout,
    required this.isNew,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = layout.isMobile;
    final subtitle = _subtitleText;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNew)
          Text(
            'Nouveauté',
            style: TextStyle(
              fontSize: layout.referenceFontSize,
              fontWeight: FontWeight.w400,
              color: productDetailMutedTextColor,
            ),
          ),
        if (isNew) SizedBox(height: isMobile ? 10 : 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: Text(product.name, style: _titleStyle))],
        ),
        if (layout.isDesktop) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Expanded(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: layout.subtitleFontSize,
                      color: const Color(0xFF6F6F6B),
                      height: 1.24,
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 18),
              Text(
                context.l10n.pdpReference(product.code),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: layout.referenceFontSize,
                  color: productDetailMutedTextColor,
                  height: 1.24,
                ),
              ),
            ],
          ),
        ] else ...[
          if (subtitle != null) ...[
            SizedBox(height: isMobile ? 2 : 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: layout.subtitleFontSize,
                color: const Color(0xFF6F6F6B),
                height: isMobile ? 1.18 : 1.24,
              ),
            ),
          ],
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            context.l10n.pdpReference(product.code),
            style: TextStyle(
              fontSize: layout.referenceFontSize,
              color: productDetailMutedTextColor,
              height: isMobile ? 1.2 : 1.24,
            ),
          ),
        ],
      ],
    );

    return Padding(padding: layout.summaryPadding, child: content);
  }

  TextStyle get _titleStyle => TextStyle(
    fontSize: layout.titleFontSize,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF2F2F2C),
    height: layout.isMobile ? 0.98 : 1.08,
    letterSpacing: 0,
    fontFamily: layout.isMobile
        ? GoogleFonts.cormorantGaramond().fontFamily
        : GoogleFonts.notoSerif().fontFamily,
  );

  String? get _subtitleText {
    final brand = product.brand?.trim();
    final productType = product.productType?.trim();
    if (brand != null && brand.isNotEmpty) {
      return productType != null && productType.isNotEmpty
          ? '$productType • $brand'
          : brand;
    }
    if (productType != null && productType.isNotEmpty) {
      return productType;
    }
    return null;
  }
}

class _SkeletonProductHeading extends StatelessWidget {
  final double iconSize;

  const _SkeletonProductHeading({this.iconSize = 28});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBlock(width: 224, height: 28),
              SizedBox(height: 8),
              _SkeletonBlock(width: 172, height: 14),
            ],
          ),
        ),
        const SizedBox(width: 18),
        _SkeletonIcon(size: iconSize),
      ],
    );
  }
}

class _MobileAccordionSkeleton extends StatelessWidget {
  const _MobileAccordionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkeletonDivider(),
        SizedBox(height: 22),
        Row(
          children: [
            _SkeletonBlock(width: 132, height: 22),
            Spacer(),
            _SkeletonIcon(size: 18, radius: 2),
          ],
        ),
        SizedBox(height: 30),
        _SkeletonBlock(height: 16),
        SizedBox(height: 13),
        _SkeletonBlock(height: 16),
        SizedBox(height: 13),
        _SkeletonBlock(width: 250, height: 16),
      ],
    );
  }
}

class _TabsSkeleton extends StatelessWidget {
  const _TabsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _SkeletonBlock(height: 14)),
            SizedBox(width: 34),
            Expanded(child: _SkeletonBlock(height: 14)),
            SizedBox(width: 34),
            Expanded(child: _SkeletonBlock(height: 14)),
          ],
        ),
        SizedBox(height: 18),
        _SkeletonDivider(),
        SizedBox(height: 30),
        _SkeletonBlock(height: 13),
        SizedBox(height: 12),
        _SkeletonBlock(height: 13),
        SizedBox(height: 12),
        _SkeletonBlock(width: 260, height: 13),
      ],
    );
  }
}

class _DesktopPurchaseServicesSkeleton extends StatelessWidget {
  const _DesktopPurchaseServicesSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBlock(width: 244, height: 14),
        SizedBox(height: 12),
        _SkeletonBlock(width: 560, height: 14),
        SizedBox(height: 8),
        _SkeletonBlock(width: 360, height: 14),
      ],
    );
  }
}

class _PaymentBadgesSkeleton extends StatelessWidget {
  final bool compact;

  const _PaymentBadgesSkeleton({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final widths = compact
        ? const [26.0, 24.0, 34.0, 24.0, 38.0]
        : const [32.0, 30.0, 40.0, 28.0, 44.0];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < widths.length; index++) ...[
          _SkeletonBlock(width: widths[index], height: compact ? 9 : 11),
          if (index != widths.length - 1) SizedBox(width: compact ? 8 : 12),
        ],
      ],
    );
  }
}

class _SkeletonButton extends StatelessWidget {
  final double height;
  final double radius;

  const _SkeletonButton({required this.height, this.radius = 4});

  @override
  Widget build(BuildContext context) {
    return _SkeletonBlock(
      height: height,
      radius: radius,
      color: _PremiumSkeletonTheme.fillStrong,
    );
  }
}

class _SkeletonOutlineButton extends StatelessWidget {
  final double height;

  const _SkeletonOutlineButton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _PremiumSkeletonTheme.stroke),
      ),
      alignment: Alignment.center,
      child: const _SkeletonBlock(width: 172, height: 18),
    );
  }
}

class _SkeletonIcon extends StatelessWidget {
  final double size;
  final double radius;

  const _SkeletonIcon({required this.size, this.radius = 999});

  @override
  Widget build(BuildContext context) {
    return _SkeletonBlock(width: size, height: size, radius: radius);
  }
}

class _SkeletonDivider extends StatelessWidget {
  const _SkeletonDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: ColoredBox(color: _PremiumSkeletonTheme.stroke),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final Color color;

  const _SkeletonBlock({
    this.width,
    required this.height,
    this.radius = 2,
    this.color = _PremiumSkeletonTheme.fill,
  });

  @override
  Widget build(BuildContext context) {
    final animation = _SkeletonMotionScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        final requestedWidth = width;
        final resolvedWidth = requestedWidth == null
            ? fallbackWidth
            : constraints.maxWidth.isFinite
            ? requestedWidth.clamp(0.0, constraints.maxWidth).toDouble()
            : requestedWidth;
        Widget block = Container(
          width: resolvedWidth,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        );
        if (animation != null) {
          final highlight = color == _PremiumSkeletonTheme.fillStrong
              ? _PremiumSkeletonTheme.highlightStrong
              : _PremiumSkeletonTheme.highlight;
          block = _SkeletonShimmer(
            animation: animation,
            baseColor: color,
            highlightColor: highlight,
            child: block,
          );
        }
        return Align(alignment: Alignment.centerLeft, child: block);
      },
    );
  }
}
