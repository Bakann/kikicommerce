class CatalogImportIndexes {
  final Map<String, Map<String, dynamic>> categoriesByCode;
  final Map<String, Map<String, dynamic>> productsByCode;
  final Map<String, Map<String, dynamic>> currenciesByIsoCode;
  final Map<String, Map<String, dynamic>> unitsByCode;
  final Map<String, Map<String, dynamic>> mediasByCode;
  final Map<String, Map<String, dynamic>> mediaContainersByCode;
  final Map<String, Map<String, dynamic>> mediaContainersById;
  final Map<String, Map<String, dynamic>> categoryProductsByKey;
  final Map<String, Map<String, dynamic>> priceRowsByKey;
  final Map<String, Map<String, dynamic>> narrativeChaptersByProductAndMedia;

  const CatalogImportIndexes({
    required this.categoriesByCode,
    required this.productsByCode,
    required this.currenciesByIsoCode,
    required this.unitsByCode,
    required this.mediasByCode,
    required this.mediaContainersByCode,
    required this.mediaContainersById,
    required this.categoryProductsByKey,
    required this.priceRowsByKey,
    required this.narrativeChaptersByProductAndMedia,
  });

  factory CatalogImportIndexes.fromCollections(
    Map<String, List<Map<String, dynamic>>> collections,
  ) {
    return CatalogImportIndexes(
      categoriesByCode: {
        for (final record in collections['categories'] ?? const [])
          if ((record['code'] as String?)?.isNotEmpty ?? false)
            record['code'] as String: record,
      },
      productsByCode: {
        for (final record in collections['products'] ?? const [])
          if ((record['code'] as String?)?.isNotEmpty ?? false)
            record['code'] as String: record,
      },
      currenciesByIsoCode: {
        for (final record in collections['currencies'] ?? const [])
          if ((record['isocode'] as String?)?.isNotEmpty ?? false)
            record['isocode'] as String: record,
      },
      unitsByCode: {
        for (final record in collections['units'] ?? const [])
          if ((record['code'] as String?)?.isNotEmpty ?? false)
            record['code'] as String: record,
      },
      mediasByCode: {
        for (final record in collections['medias'] ?? const [])
          if ((record['code'] as String?)?.isNotEmpty ?? false)
            record['code'] as String: record,
      },
      mediaContainersByCode: {
        for (final record in collections['mediaContainers'] ?? const [])
          if ((record['code'] as String?)?.isNotEmpty ?? false)
            record['code'] as String: record,
      },
      mediaContainersById: {
        for (final record in collections['mediaContainers'] ?? const [])
          if ((record['id'] as String?)?.isNotEmpty ?? false)
            record['id'] as String: record,
      },
      categoryProductsByKey: {
        for (final record in collections['categoryProducts'] ?? const [])
          categoryProductKey(
            record['category'] as String? ?? '',
            record['product'] as String? ?? '',
          ): record,
      },
      priceRowsByKey: {
        for (final record in collections['priceRows'] ?? const [])
          priceRowKey(
            productId: record['product'] as String? ?? '',
            currencyId: record['currency'] as String? ?? '',
            unitId: record['unit'] as String?,
            channel: record['channel'] as String?,
            minQuantity: record['minqtd'] as int?,
            startTime: record['startTime'] as String?,
          ): record,
      },
      narrativeChaptersByProductAndMedia: {
        for (final record in collections['narrativeChapters'] ?? const [])
          narrativeChapterKey(
            record['product'] as String? ?? '',
            record['media'] as String? ?? '',
          ): record,
      },
    );
  }

  static String categoryProductKey(String categoryId, String productId) =>
      '$categoryId::$productId';

  static String priceRowKey({
    required String productId,
    required String currencyId,
    String? unitId,
    String? channel,
    int? minQuantity,
    String? startTime,
  }) {
    return [
      productId,
      currencyId,
      unitId ?? '',
      channel ?? '',
      minQuantity?.toString() ?? '',
      startTime ?? '',
    ].join('::');
  }

  static String narrativeChapterKey(String productId, String mediaId) =>
      '$productId::$mediaId';
}
