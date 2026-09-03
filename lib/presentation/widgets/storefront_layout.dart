import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit, RenderProxyBox;

class StorefrontLayout {
  static const double tabletBreakpoint = 768;
  static const double desktopBreakpoint = 1100;
  static const double wideDesktopBreakpoint = 1440;
  static const double maxContentWidth = 1360;
  static const double productListMaxWidth = 1140;
  static const double productDetailTabletMaxWidth = 944;
  static const double productDetailMaxWidth = 1120;

  static bool isMobile(double width) => width < tabletBreakpoint;

  static bool isTablet(double width) => width >= tabletBreakpoint;

  static bool isTabletOnly(double width) =>
      width >= tabletBreakpoint && width < desktopBreakpoint;

  static bool isDesktop(double width) => width >= desktopBreakpoint;

  static double horizontalPaddingFor(double width) {
    if (width >= desktopBreakpoint) {
      return 32;
    }
    if (width >= tabletBreakpoint) {
      return 12; // Reduced from 24
    }
    return 4; // Reduced from 16 to be almost edge-to-edge Dior-style
  }

  static double outerPaddingFor(
    double width, {
    double maxWidth = maxContentWidth,
    double? minHorizontalPadding,
  }) {
    final actualHorizontalPadding =
        minHorizontalPadding ?? horizontalPaddingFor(width);
    if (width >= wideDesktopBreakpoint) {
      return math.max(actualHorizontalPadding, (width - maxWidth) / 2);
    }
    return actualHorizontalPadding;
  }

  static double nikeContentPaddingFor(double width) {
    if (width >= desktopBreakpoint) {
      return outerPaddingFor(width, minHorizontalPadding: 32);
    }
    if (width >= tabletBreakpoint) {
      return 28;
    }
    return 26;
  }

  static double gridSpacingFor(double width) {
    if (width >= desktopBreakpoint) {
      return 20;
    }
    if (width >= tabletBreakpoint) {
      return 8; // Reduced from 16
    }
    return 4; // Reduced from 12 to match the tight Dior grid
  }

  static int productGridColumnsFor(double width) {
    if (width >= desktopBreakpoint) {
      return 4;
    }
    if (width >= tabletBreakpoint) {
      return 3;
    }
    return 2;
  }

  static double productGridAspectRatioFor(double width) {
    return 0.48; // Dior-style tall card: 2:3 image + centered text + safety for badges
  }
}

class StorefrontPageSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final double? minHorizontalPadding;

  const StorefrontPageSection({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.maxWidth = StorefrontLayout.maxContentWidth,
    this.minHorizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidePadding = StorefrontLayout.outerPaddingFor(
      screenWidth,
      maxWidth: maxWidth,
      minHorizontalPadding: minHorizontalPadding,
    );
    final basePadding = padding.resolve(Directionality.of(context));

    return Padding(
      padding: basePadding.add(EdgeInsets.symmetric(horizontal: sidePadding)),
      child: child,
    );
  }
}

class StorefrontFullBleed extends StatelessWidget {
  final Widget child;

  const StorefrontFullBleed({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return OverflowBox(
      alignment: Alignment.center,
      fit: OverflowBoxFit.deferToChild,
      minWidth: screenWidth,
      maxWidth: screenWidth,
      child: SizedBox(width: screenWidth, child: child),
    );
  }
}

class StorefrontStickySidebar extends StatefulWidget {
  final Widget child;
  final double topOffset;

  const StorefrontStickySidebar({
    super.key,
    required this.child,
    this.topOffset = 24,
  });

  @override
  State<StorefrontStickySidebar> createState() =>
      _StorefrontStickySidebarState();
}

class _StorefrontStickySidebarState extends State<StorefrontStickySidebar> {
  final GlobalKey _containerKey = GlobalKey();
  final GlobalKey _childKey = GlobalKey();
  ScrollPosition? _scrollPosition;
  bool _measureScheduled = false;
  double? _initialContainerTop;
  double? _initialScrollPixels;
  double _maxOffset = 0;
  final ValueNotifier<double> _translateY = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleMeasure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachScrollPosition();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant StorefrontStickySidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_handleScroll);
    _translateY.dispose();
    super.dispose();
  }

  void _attachScrollPosition() {
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition == nextPosition) {
      return;
    }
    _scrollPosition?.removeListener(_handleScroll);
    _scrollPosition = nextPosition;
    _scrollPosition?.addListener(_handleScroll);
    _initialContainerTop = null;
    _initialScrollPixels = null;
  }

  void _handleScroll() {
    final nextOffset = _computeOffsetFor(_scrollPosition?.pixels);
    if ((nextOffset - _translateY.value).abs() < 0.5) {
      return;
    }

    _translateY.value = nextOffset;
  }

  void _scheduleMeasure() {
    if (!mounted || _measureScheduled) {
      return;
    }
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      _measureStickyBounds();
    });
  }

  void _measureStickyBounds() {
    if (!mounted) {
      return;
    }

    final containerBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    final childBox = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (containerBox == null ||
        childBox == null ||
        !containerBox.hasSize ||
        !childBox.hasSize) {
      return;
    }

    final initialContainerTop = containerBox.localToGlobal(Offset.zero).dy;
    final initialScrollPixels = _scrollPosition?.pixels ?? 0.0;
    final maxOffset = math.max<double>(
      0.0,
      containerBox.size.height - childBox.size.height,
    );
    final nextOffset = _computeOffsetFor(
      initialScrollPixels,
      initialContainerTop: initialContainerTop,
      initialScrollPixelsValue: initialScrollPixels,
      maxOffset: maxOffset,
    );

    _initialContainerTop = initialContainerTop;
    _initialScrollPixels = initialScrollPixels;
    _maxOffset = maxOffset;
    _translateY.value = nextOffset;
  }

  double _computeOffsetFor(
    double? currentPixels, {
    double? initialContainerTop,
    double? initialScrollPixelsValue,
    double? maxOffset,
  }) {
    final startTop = initialContainerTop ?? _initialContainerTop;
    final startScrollPixels = initialScrollPixelsValue ?? _initialScrollPixels;
    final endOffset = maxOffset ?? _maxOffset;
    if (startTop == null || startScrollPixels == null) {
      return 0;
    }

    final resolvedCurrentPixels = currentPixels ?? startScrollPixels;
    final containerTop = startTop - (resolvedCurrentPixels - startScrollPixels);
    return (widget.topOffset - containerTop).clamp(0.0, endOffset).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final stickyChild = Container(key: _childKey, child: widget.child);
    return SizedBox.expand(
      key: _containerKey,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _translateY,
              builder: (context, translateY, child) {
                return Transform.translate(
                  key: const Key('sidebar_transform'),
                  offset: Offset(0, translateY),
                  child: child,
                );
              },
              child: RepaintBoundary(child: stickyChild),
            ),
          ),
        ],
      ),
    );
  }
}

class StorefrontStickyPanels extends StatefulWidget {
  final int leftFlex;
  final int rightFlex;
  final Widget leftChild;
  final Widget rightChild;
  final double topOffset;
  final double fallbackRightHeight;

  const StorefrontStickyPanels({
    super.key,
    required this.leftFlex,
    required this.rightFlex,
    required this.leftChild,
    required this.rightChild,
    required this.fallbackRightHeight,
    this.topOffset = 24,
  });

  @override
  State<StorefrontStickyPanels> createState() => _StorefrontStickyPanelsState();
}

class _StorefrontStickyPanelsState extends State<StorefrontStickyPanels> {
  double? _leftHeight;

  void _handleLeftSizeChange(Size size) {
    if (!mounted) {
      return;
    }
    final nextHeight = size.height;
    if (_leftHeight != null && (_leftHeight! - nextHeight).abs() < 0.5) {
      return;
    }
    setState(() {
      _leftHeight = nextHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sidebarHeight = _leftHeight ?? widget.fallbackRightHeight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: widget.leftFlex,
          child: _StorefrontMeasureSize(
            onChange: _handleLeftSizeChange,
            child: widget.leftChild,
          ),
        ),
        Expanded(
          flex: widget.rightFlex,
          child: SizedBox(
            height: sidebarHeight,
            child: StorefrontStickySidebar(
              topOffset: widget.topOffset,
              child: widget.rightChild,
            ),
          ),
        ),
      ],
    );
  }
}

class _StorefrontMeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const _StorefrontMeasureSize({required this.onChange, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderStorefrontMeasureSize(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderStorefrontMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderStorefrontMeasureSize extends RenderProxyBox {
  _RenderStorefrontMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final nextSize = child?.size;
    if (nextSize == null || _oldSize == nextSize) {
      return;
    }
    _oldSize = nextSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(nextSize);
    });
  }
}
