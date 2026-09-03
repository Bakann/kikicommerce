import 'package:flutter/material.dart';

enum ProductDetailLayoutMode { mobile, split, desktop }

const productDetailImageSurfaceColor = Color(0xFFF7F7F4);
const productDetailDividerColor = Color(0xFFE6E3DD);
const productDetailMutedTextColor = Color(0xFF7B7F82);
const productDetailBannerColor = Color(0xFF807B74);
const productDetailMobileHeroAspectRatio = 0.95;

class ProductDetailLayoutSpec {
  final ProductDetailLayoutMode mode;
  final double maxWidth;
  final double horizontalPadding;
  final double heroTopPadding;
  final double heroGap;
  final double heroAspectRatio;
  final int heroImageFlex;
  final int heroTextFlex;
  final EdgeInsets imagePanelPadding;
  final EdgeInsets detailsPanelPadding;
  final double titleFontSize;
  final double subtitleFontSize;
  final double referenceFontSize;
  final double priceFontSize;

  const ProductDetailLayoutSpec({
    required this.mode,
    required this.maxWidth,
    required this.horizontalPadding,
    required this.heroTopPadding,
    required this.heroGap,
    required this.heroAspectRatio,
    required this.heroImageFlex,
    required this.heroTextFlex,
    required this.imagePanelPadding,
    required this.detailsPanelPadding,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.referenceFontSize,
    required this.priceFontSize,
  });

  factory ProductDetailLayoutSpec.forWidth(double width) {
    if (width <= 600) {
      return const ProductDetailLayoutSpec(
        mode: ProductDetailLayoutMode.mobile,
        maxWidth: 720,
        horizontalPadding: 0,
        heroTopPadding: 0,
        heroGap: 0,
        heroAspectRatio: productDetailMobileHeroAspectRatio,
        heroImageFlex: 0,
        heroTextFlex: 0,
        imagePanelPadding: EdgeInsets.zero,
        detailsPanelPadding: EdgeInsets.fromLTRB(22, 38, 22, 0),
        titleFontSize: 24,
        subtitleFontSize: 14,
        referenceFontSize: 12,
        priceFontSize: 18,
      );
    }

    if (width < 1024) {
      return const ProductDetailLayoutSpec(
        mode: ProductDetailLayoutMode.split,
        maxWidth: 1440,
        horizontalPadding: 0,
        heroTopPadding: 0,
        heroGap: 0,
        heroAspectRatio: 0.78,
        heroImageFlex: 12,
        heroTextFlex: 12,
        imagePanelPadding: EdgeInsets.zero,
        detailsPanelPadding: EdgeInsets.fromLTRB(44, 72, 44, 32),
        titleFontSize: 30,
        subtitleFontSize: 16,
        referenceFontSize: 12,
        priceFontSize: 18,
      );
    }

    return const ProductDetailLayoutSpec(
      mode: ProductDetailLayoutMode.desktop,
      maxWidth: 1440,
      horizontalPadding: 0,
      heroTopPadding: 0,
      heroGap: 0,
      heroAspectRatio: 0.78,
      heroImageFlex: 12,
      heroTextFlex: 12,
      imagePanelPadding: EdgeInsets.zero,
      detailsPanelPadding: EdgeInsets.fromLTRB(74, 0, 74, 40),
      titleFontSize: 31,
      subtitleFontSize: 14,
      referenceFontSize: 12,
      priceFontSize: 15,
    );
  }

  bool get isMobile => mode == ProductDetailLayoutMode.mobile;
  bool get isSplit => mode == ProductDetailLayoutMode.split;
  bool get isDesktop => mode == ProductDetailLayoutMode.desktop;
  bool get isWide => !isMobile;
  double get stickyTopOffset => isDesktop ? 24 : 20;
  double stickyTopOffsetForViewport(double viewportHeight) {
    if (!isDesktop) return stickyTopOffset;
    return (viewportHeight * 0.25).clamp(170.0, 285.0).toDouble();
  }

  EdgeInsets get summaryPadding =>
      EdgeInsets.fromLTRB(0, isDesktop ? 8 : 0, 0, 0);
}
