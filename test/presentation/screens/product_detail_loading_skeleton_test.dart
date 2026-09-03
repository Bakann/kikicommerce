import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/screens/pdp/product_detail_loading_skeleton.dart';
import 'package:kiki_commerce/presentation/screens/product_detail_layout_spec.dart';

void main() {
  const loadingProduct = CatalogProduct(
    id: 'prod-1',
    code: 'TENSION-SILENCIEUSE-DENIM-ABSOLU',
    name: 'Tension Silencieuse, Denim Absolu',
  );

  Widget buildHarness({
    bool disableAnimations = false,
    CatalogProduct? product,
    Widget? commerceSlot,
    double width = 390,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1400),
          disableAnimations: disableAnimations,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: ProductDetailLoadingSkeleton(
              layout: ProductDetailLayoutSpec.forWidth(width),
              loadingProduct: product,
              commerceSlot: commerceSlot,
            ),
          ),
        ),
      ),
    );
  }

  const shimmerKey = ValueKey('pdp-loading-skeleton-shimmer');

  testWidgets('skeleton starts static before motion delay', (tester) async {
    await tester.pumpWidget(buildHarness());

    expect(find.byKey(shimmerKey), findsNothing);
    expect(find.text('Chargement des détails…'), findsNothing);

    await tester.pump(const Duration(milliseconds: 699));

    expect(find.byKey(shimmerKey), findsNothing);
    expect(find.text('Chargement des détails…'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byKey(shimmerKey), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('active shimmer uses a perceptible source-in shader mask', (
    tester,
  ) async {
    await tester.pumpWidget(buildHarness());

    await tester.pump(const Duration(milliseconds: 700));

    final shaderMasks = tester.widgetList<ShaderMask>(find.byType(ShaderMask));

    expect(shaderMasks, isNotEmpty);
    expect(
      shaderMasks.every((mask) => mask.blendMode == BlendMode.srcIn),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('skeleton shows long-loading hint after delay', (tester) async {
    await tester.pumpWidget(buildHarness());

    expect(find.text('Chargement des détails…'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.text('Chargement des détails…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('skeleton does not pulse when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(buildHarness(disableAnimations: true));

    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(shimmerKey), findsNothing);

    await tester.pump(const Duration(milliseconds: 1800));

    expect(find.byKey(shimmerKey), findsNothing);
    expect(find.text('Chargement des détails…'), findsOneWidget);
  });

  testWidgets('skeleton shimmers around commerce slot after motion delay', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        commerceSlot: const SizedBox(
          key: ValueKey('commerce-slot-probe'),
          height: 58,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(shimmerKey), findsOneWidget);
    expect(find.byType(ShaderMask), findsWidgets);
    expect(find.byKey(const ValueKey('commerce-slot-probe')), findsOneWidget);
  });

  testWidgets('skeleton uses known PLP product text when available', (
    tester,
  ) async {
    await tester.pumpWidget(buildHarness(product: loadingProduct));

    expect(find.text('Tension Silencieuse, Denim Absolu'), findsOneWidget);
    expect(
      find.text('Référence : TENSION-SILENCIEUSE-DENIM-ABSOLU'),
      findsOneWidget,
    );
  });

  testWidgets('known-product skeleton aligns commerce below reference', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        product: loadingProduct,
        commerceSlot: const SizedBox(
          key: ValueKey('commerce-slot-probe'),
          height: 12,
        ),
      ),
    );

    final referenceBottom = tester
        .getBottomLeft(
          find.text('Référence : TENSION-SILENCIEUSE-DENIM-ABSOLU'),
        )
        .dy;
    final commerceTop = tester
        .getTopLeft(find.byKey(const ValueKey('commerce-slot-probe')))
        .dy;

    expect(commerceTop - referenceBottom, closeTo(30, 0.1));
  });

  testWidgets(
    'desktop known-product skeleton aligns commerce below reference',
    (tester) async {
      await tester.pumpWidget(
        buildHarness(
          width: 1440,
          product: loadingProduct,
          commerceSlot: const SizedBox(
            key: ValueKey('desktop-commerce-slot-probe'),
            height: 70,
          ),
        ),
      );

      final referenceBottom = tester
          .getBottomLeft(
            find.text('Référence : TENSION-SILENCIEUSE-DENIM-ABSOLU'),
          )
          .dy;
      final commerceTop = tester
          .getTopLeft(find.byKey(const ValueKey('desktop-commerce-slot-probe')))
          .dy;

      expect(commerceTop - referenceBottom, closeTo(46, 0.1));
    },
  );
}
