import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_layout_spec.dart';

void main() {
  test('uses mobile layout at 600 and below', () {
    final spec = ProductDetailLayoutSpec.forWidth(600);

    expect(spec.isMobile, isTrue);
    expect(spec.heroAspectRatio, 0.95);
    expect(spec.horizontalPadding, 0);
    expect(spec.imagePanelPadding, EdgeInsets.zero);
  });

  test('uses split layout between 601 and 1023', () {
    final spec = ProductDetailLayoutSpec.forWidth(900);

    expect(spec.isSplit, isTrue);
    expect(spec.heroImageFlex, 12);
    expect(spec.heroTextFlex, 12);
    expect(spec.heroGap, 0);
  });

  test('uses desktop layout from 1024', () {
    final spec = ProductDetailLayoutSpec.forWidth(1024);

    expect(spec.isDesktop, isTrue);
    expect(spec.heroImageFlex, 12);
    expect(spec.heroTextFlex, 12);
    expect(spec.maxWidth, 1440);
  });
}
