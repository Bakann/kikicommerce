import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../domain/catalog/catalog_entities.dart';

const kPdpLoadingCommerceSnapshotTtl = Duration(seconds: 60);

class PdpLoadingCommerceSnapshot {
  final CatalogProduct product;
  final List<CatalogPrice> prices;
  final DateTime capturedAt;
  final bool hasVariantSelector;

  /// PLP prices are display hints only. The quick-add path is enabled only
  /// when the server cart endpoint re-reads the authoritative price by
  /// [CatalogPrice.id] before writing the cart entry.
  const PdpLoadingCommerceSnapshot({
    required this.product,
    required this.prices,
    required this.capturedAt,
    this.hasVariantSelector = false,
  });

  bool isFresh(DateTime now) {
    return now.difference(capturedAt) <= kPdpLoadingCommerceSnapshotTtl;
  }
}

class PdpLoadingTapTrace {
  final String productId;
  final DateTime tappedAt;
  final bool heroEligible;

  const PdpLoadingTapTrace({
    required this.productId,
    required this.tappedAt,
    required this.heroEligible,
  });
}

final pdpLoadingCommerceSnapshotProvider = StateProvider.autoDispose
    .family<PdpLoadingCommerceSnapshot?, String>((ref, productId) {
      final keepAliveLink = ref.keepAlive();
      final expiryTimer = Timer(kPdpLoadingCommerceSnapshotTtl, () {
        ref.invalidateSelf();
        keepAliveLink.close();
      });
      ref.onDispose(expiryTimer.cancel);
      return null;
    });

final pdpLoadingTapTraceProvider = StateProvider.autoDispose
    .family<PdpLoadingTapTrace?, String>((ref, productId) {
      final keepAliveLink = ref.keepAlive();
      final expiryTimer = Timer(kPdpLoadingCommerceSnapshotTtl, () {
        ref.invalidateSelf();
        keepAliveLink.close();
      });
      ref.onDispose(expiryTimer.cancel);
      return null;
    });
