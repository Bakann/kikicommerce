import 'dart:collection';

import '../../core/utils/price_utils.dart';
import '../../domain/catalog/catalog_entities.dart';
import 'cms_models.dart';

sealed class MixedGridItem {
  const MixedGridItem();
}

class MixedGridProductItem extends MixedGridItem {
  final CatalogListingItem listingItem;

  const MixedGridProductItem(this.listingItem);
}

class MixedGridInsertItem extends MixedGridItem {
  final GridInsertConfig insert;

  const MixedGridInsertItem(this.insert);
}

class MixedProductGridComposer {
  const MixedProductGridComposer._();

  static List<MixedGridItem> compose({
    required List<CatalogListingItem> products,
    required MixedProductGridConfig config,
    required String activeSort,
    DateTime? now,
  }) {
    final excluded = config.excludedProductIds.toSet();
    final eligibleProducts = products
        .where((item) => !excluded.contains(item.productId))
        .where((item) => _isOnline(item.product, now ?? DateTime.now()))
        .toList(growable: false);
    final inserts = _usableInserts(config.inserts);

    if (activeSort != 'manual') {
      return _withInserts(
        _sortProducts(eligibleProducts, activeSort),
        inserts,
        reservedProductPositions: const {},
      );
    }

    final pinnedPlacements = <int, CatalogListingItem>{};
    final pinnedProductIds = <String>{};
    final productsById = {
      for (final item in eligibleProducts) item.productId: item,
    };

    for (final pin in config.pinnedProducts) {
      final pinnedProduct = productsById[pin.productId];
      if (pinnedProduct == null) continue;
      var target = pin.slotPosition;
      while (pinnedPlacements.containsKey(target)) {
        target++;
      }
      pinnedPlacements[target] = pinnedProduct;
      pinnedProductIds.add(pin.productId);
    }

    final remainingProducts = eligibleProducts
        .where((item) => !pinnedProductIds.contains(item.productId))
        .toList(growable: false);
    final productStream = <CatalogListingItem>[];
    var remainingIndex = 0;

    for (
      var position = 0;
      productStream.length < eligibleProducts.length;
      position++
    ) {
      final pinned = pinnedPlacements[position];
      if (pinned != null) {
        productStream.add(pinned);
        continue;
      }
      if (remainingIndex < remainingProducts.length) {
        productStream.add(remainingProducts[remainingIndex]);
        remainingIndex++;
      }
    }

    return _withInserts(
      productStream,
      inserts,
      reservedProductPositions: pinnedPlacements.keys.toSet(),
    );
  }

  static List<GridInsertConfig> _usableInserts(List<GridInsertConfig> inserts) {
    return inserts
        .where((insert) {
          return switch (insert) {
            CategoryTileInsert(:final isUsable) => isUsable,
            EditorialCampaignInsert(:final isUsable) => isUsable,
            UniverseInsert(:final isUsable) => isUsable,
            UnknownGridInsert() => false,
          };
        })
        .toList(growable: false);
  }

  static List<MixedGridItem> _withInserts(
    List<CatalogListingItem> products,
    List<GridInsertConfig> inserts, {
    required Set<int> reservedProductPositions,
  }) {
    final insertsByPosition = SplayTreeMap<int, List<GridInsertConfig>>();
    for (final insert in inserts) {
      var target = insert.slotPosition;
      while (reservedProductPositions.contains(target)) {
        target++;
      }
      insertsByPosition.putIfAbsent(target, () => []).add(insert);
    }

    final out = <MixedGridItem>[];
    var productCount = 0;

    void appendInsertsFor(int count) {
      final atPosition = insertsByPosition.remove(count);
      if (atPosition == null) return;
      out.addAll(atPosition.map(MixedGridInsertItem.new));
    }

    appendInsertsFor(0);
    for (final product in products) {
      out.add(MixedGridProductItem(product));
      productCount++;
      appendInsertsFor(productCount);
    }

    for (final remaining in insertsByPosition.values) {
      out.addAll(remaining.map(MixedGridInsertItem.new));
    }

    return out;
  }

  static List<CatalogListingItem> _sortProducts(
    List<CatalogListingItem> products,
    String activeSort,
  ) {
    final sorted = products.toList(growable: false);
    sorted.sort((left, right) {
      final comparison = switch (activeSort) {
        'newest' => _compareNewest(left, right),
        'price_asc' => _comparePrice(left, right),
        'price_desc' => _comparePrice(right, left),
        _ => _comparePosition(left, right),
      };
      if (comparison != 0) return comparison;
      return left.productId.compareTo(right.productId);
    });
    return sorted;
  }

  static int _compareNewest(CatalogListingItem left, CatalogListingItem right) {
    final leftDate = left.product.onlineDate;
    final rightDate = right.product.onlineDate;
    if (leftDate == null && rightDate == null) {
      return _comparePosition(left, right);
    }
    if (leftDate == null) return 1;
    if (rightDate == null) return -1;
    return rightDate.compareTo(leftDate);
  }

  static int _comparePrice(CatalogListingItem left, CatalogListingItem right) {
    final leftPrice = getDefaultPrice(left.prices)?.price;
    final rightPrice = getDefaultPrice(right.prices)?.price;
    if (leftPrice == null && rightPrice == null) {
      return _comparePosition(left, right);
    }
    if (leftPrice == null) return 1;
    if (rightPrice == null) return -1;
    return leftPrice.compareTo(rightPrice);
  }

  static int _comparePosition(
    CatalogListingItem left,
    CatalogListingItem right,
  ) {
    final leftPosition = left.position;
    final rightPosition = right.position;
    if (leftPosition == null && rightPosition == null) return 0;
    if (leftPosition == null) return 1;
    if (rightPosition == null) return -1;
    return leftPosition.compareTo(rightPosition);
  }

  static bool _isOnline(CatalogProduct product, DateTime now) {
    final onlineDate = product.onlineDate;
    if (onlineDate != null && onlineDate.isAfter(now)) return false;
    final offlineDate = product.offlineDate;
    if (offlineDate != null && !offlineDate.isAfter(now)) return false;
    return product.isActive;
  }
}
