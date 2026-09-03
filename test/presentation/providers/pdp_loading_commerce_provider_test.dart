import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiki_commerce/domain/catalog/catalog_entities.dart';
import 'package:kiki_commerce/presentation/providers/pdp_loading_commerce_provider.dart';

void main() {
  const product = CatalogProduct(id: 'prod-1', code: 'P1', name: 'Product 1');
  const price = CatalogPrice(
    id: 'price-1',
    productId: 'prod-1',
    price: 133,
    isDefault: true,
    currencyCode: 'EUR',
    currencySymbol: '€',
  );
  final capturedAt = DateTime(2026, 5, 21, 15);

  testWidgets('commerce snapshot survives without a listener until ttl', (
    tester,
  ) async {
    final container = ProviderContainer();

    container
        .read(pdpLoadingCommerceSnapshotProvider('prod-1').notifier)
        .state = PdpLoadingCommerceSnapshot(
      product: product,
      prices: const [price],
      capturedAt: capturedAt,
    );

    expect(
      container.read(pdpLoadingCommerceSnapshotProvider('prod-1')),
      isNotNull,
    );

    await tester.pump(
      kPdpLoadingCommerceSnapshotTtl - const Duration(milliseconds: 1),
    );

    expect(
      container.read(pdpLoadingCommerceSnapshotProvider('prod-1')),
      isNotNull,
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(
      container.read(pdpLoadingCommerceSnapshotProvider('prod-1')),
      isNull,
    );
    container.dispose();
  });

  test('snapshot freshness uses the shared ttl', () {
    final snapshot = PdpLoadingCommerceSnapshot(
      product: product,
      prices: const [price],
      capturedAt: capturedAt,
    );

    expect(
      snapshot.isFresh(capturedAt.add(kPdpLoadingCommerceSnapshotTtl)),
      isTrue,
    );
    expect(
      snapshot.isFresh(
        capturedAt
            .add(kPdpLoadingCommerceSnapshotTtl)
            .add(const Duration(milliseconds: 1)),
      ),
      isFalse,
    );
  });
}
