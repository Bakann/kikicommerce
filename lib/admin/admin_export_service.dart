import '../application/admin/catalog_csv_format.dart';
import '../application/admin/catalog_export_result.dart';
import 'admin_client.dart';
import 'admin_collection_schema.dart';

class CatalogCsvExportService {
  final PocketBaseAdminClient client;

  const CatalogCsvExportService({required this.client});

  Future<CatalogExportResult> exportCatalogCsv() async {
    final collections = <String, List<Map<String, dynamic>>>{};

    for (final definition in adminCollectionDefinitions) {
      collections[definition.name] = await client.listRecords(
        definition.name,
        sort: definition.sort,
        perPage: 500,
      );
    }

    return _CatalogExportContext(
      client: client,
      collections: collections,
    ).build();
  }
}

class _CatalogExportContext {
  final PocketBaseAdminClient client;
  final Map<String, List<Map<String, dynamic>>> collections;
  final _WarningCollector warnings = _WarningCollector();
  final _UsedReferences used = _UsedReferences();

  late final List<Map<String, dynamic>> categories =
      collections['categories'] ?? const [];
  late final List<Map<String, dynamic>> products =
      collections['products'] ?? const [];
  late final List<Map<String, dynamic>> categoryProducts =
      collections['categoryProducts'] ?? const [];
  late final List<Map<String, dynamic>> priceRows =
      collections['priceRows'] ?? const [];
  late final List<Map<String, dynamic>> currencies =
      collections['currencies'] ?? const [];
  late final List<Map<String, dynamic>> units =
      collections['units'] ?? const [];
  late final List<Map<String, dynamic>> medias =
      collections['medias'] ?? const [];
  late final List<Map<String, dynamic>> mediaContainers =
      collections['mediaContainers'] ?? const [];
  late final List<Map<String, dynamic>> narrativeChapters =
      collections['narrativeChapters'] ?? const [];

  late final Map<String, Map<String, dynamic>> categoriesById = _mapById(
    categories,
  );
  late final Map<String, Map<String, dynamic>> productsById = _mapById(
    products,
  );
  late final Map<String, Map<String, dynamic>> currenciesById = _mapById(
    currencies,
  );
  late final Map<String, Map<String, dynamic>> unitsById = _mapById(units);
  late final Map<String, Map<String, dynamic>> mediasById = _mapById(medias);
  late final Map<String, Map<String, dynamic>> mediaContainersById = _mapById(
    mediaContainers,
  );
  late final Map<String, List<Map<String, dynamic>>>
  narrativeChaptersByProduct = _groupByString(narrativeChapters, 'product');

  late final Map<String, List<Map<String, dynamic>>>
  categoryProductsByCategory = _groupByString(categoryProducts, 'category');
  late final Map<String, List<Map<String, dynamic>>> categoryProductsByProduct =
      _groupByString(categoryProducts, 'product');
  late final Map<String, List<Map<String, dynamic>>> priceRowsByProduct =
      _groupByString(priceRows, 'product');

  _CatalogExportContext({required this.client, required this.collections});

  CatalogExportResult build() {
    _collectPreflightWarnings();

    final rows = <Map<String, Object?>>[];
    final exportedNarrativeProducts = <String>{};

    for (final categoryProduct in categoryProducts) {
      final categoryId = _stringOrNull(categoryProduct['category']);
      final productId = _stringOrNull(categoryProduct['product']);

      if (categoryId == null || productId == null) {
        warnings.add(
          'Relation categoryProducts incomplète ignorée: catégorie ou produit manquant.',
        );
        continue;
      }

      final category = categoriesById[categoryId];
      final product = productsById[productId];
      if (category == null || product == null) {
        warnings.add(
          'Relation categoryProducts $categoryId/$productId ignorée: catégorie ou produit introuvable.',
        );
        continue;
      }

      final exportCategory = _buildCategoryExport(
        category: category,
        categoryProduct: categoryProduct,
        product: product,
      );
      if (exportCategory == null) {
        continue;
      }

      final exportProduct = _buildProductExport(product);
      if (exportProduct == null) {
        continue;
      }

      final exportPriceRows = priceRowsByProduct[productId] ?? const [];
      if (exportPriceRows.isEmpty) {
        continue;
      }

      for (final priceRow in exportPriceRows) {
        final exportPrice = _buildPriceExport(
          product: product,
          priceRow: priceRow,
        );
        if (exportPrice == null) {
          continue;
        }

        final includeNarrative = exportedNarrativeProducts.add(productId);

        rows.add({
          ...exportCategory.toRowMap(),
          ...exportProduct.toRowMap(),
          ...(includeNarrative
              ? _buildNarrativeRowMap(product: product)
              : _emptyNarrativeRowMap()),
          ...exportPrice.toRowMap(),
        });

        used.currencies.add(exportPrice.currencyId);
        if (exportPrice.unitId != null) {
          used.units.add(exportPrice.unitId!);
        }
        if (exportProduct.thumbnailId != null) {
          used.medias.add(exportProduct.thumbnailId!);
        }
        if (exportProduct.pictureId != null) {
          used.medias.add(exportProduct.pictureId!);
        }
        if (exportProduct.galleryContainerId != null) {
          used.mediaContainers.add(exportProduct.galleryContainerId!);
        }
        used.medias.addAll(exportProduct.galleryMediaIds);
      }
    }

    _collectUnusedRecordWarnings();

    return CatalogExportResult(
      csvContent: CatalogCsvFormat.encodeRows(rows),
      exportedRows: rows.length,
      warnings: warnings.messages,
    );
  }

  void _collectPreflightWarnings() {
    for (final category in categories) {
      final categoryId = _stringOrNull(category['id']);
      final categoryCode = _stringOrNull(category['code']);
      if (categoryId == null || categoryCode == null) {
        continue;
      }
      if ((categoryProductsByCategory[categoryId] ?? const []).isEmpty) {
        warnings.add(
          'Catégorie $categoryCode ignorée: aucune relation categoryProducts.',
        );
      }
    }

    for (final product in products) {
      final productId = _stringOrNull(product['id']);
      final productCode = _stringOrNull(product['code']);
      if (productId == null || productCode == null) {
        continue;
      }

      if ((categoryProductsByProduct[productId] ?? const []).isEmpty) {
        warnings.add(
          'Produit $productCode ignoré: aucune relation categoryProducts.',
        );
      }

      if ((priceRowsByProduct[productId] ?? const []).isEmpty) {
        warnings.add(
          'Produit $productCode ignoré: aucune priceRow exportable.',
        );
      }
    }
  }

  void _collectUnusedRecordWarnings() {
    for (final currency in currencies) {
      final id = _stringOrNull(currency['id']);
      final code = _stringOrNull(currency['isocode']);
      if (id == null || code == null || used.currencies.contains(id)) {
        continue;
      }
      warnings.add(
        'Devise $code ignorée: non référencée par une ligne exportable.',
      );
    }

    for (final unit in units) {
      final id = _stringOrNull(unit['id']);
      final code = _stringOrNull(unit['code']);
      if (id == null || code == null || used.units.contains(id)) {
        continue;
      }
      warnings.add(
        'Unité $code ignorée: non référencée par une ligne exportable.',
      );
    }

    for (final media in medias) {
      final id = _stringOrNull(media['id']);
      final code = _stringOrNull(media['code']);
      if (id == null || code == null || used.medias.contains(id)) {
        continue;
      }
      warnings.add(
        'Média $code ignoré: non référencé par une ligne exportable.',
      );
    }

    for (final container in mediaContainers) {
      final id = _stringOrNull(container['id']);
      final code = _stringOrNull(container['code']);
      if (id == null || code == null || used.mediaContainers.contains(id)) {
        continue;
      }
      warnings.add(
        'Media container $code ignoré: non référencé par une ligne exportable.',
      );
    }
  }

  _ExportCategory? _buildCategoryExport({
    required Map<String, dynamic> category,
    required Map<String, dynamic> categoryProduct,
    required Map<String, dynamic> product,
  }) {
    final categoryId = _stringOrNull(category['id'])!;
    final categoryCode = _stringOrNull(category['code']);
    final categoryName = _stringOrNull(category['name']);
    final productCode = _stringOrNull(product['code']) ?? 'sans-code';

    if (categoryCode == null || categoryName == null) {
      warnings.add(
        'Catégorie $categoryId ignorée pour le produit $productCode: code ou nom manquant.',
      );
      return null;
    }

    final categoryIsActive = _boolValue(
      category['isActive'],
      defaultValue: true,
    );
    final relationIsActive = _boolValue(
      categoryProduct['isActive'],
      defaultValue: true,
    );
    if (categoryIsActive != relationIsActive) {
      warnings.add(
        'Catégorie $categoryCode ignorée pour le produit $productCode: '
        'category.isActive et categoryProducts.isActive divergent.',
      );
      return null;
    }

    final parentId = _stringOrNull(category['parent']);
    String parentCode = '';
    if (parentId != null) {
      final parent = categoriesById[parentId];
      final resolvedParentCode = parent == null
          ? null
          : _stringOrNull(parent['code']);
      if (resolvedParentCode == null) {
        warnings.add(
          'Catégorie $categoryCode ignorée pour le produit $productCode: parent introuvable.',
        );
        return null;
      }
      parentCode = resolvedParentCode;
    }

    return _ExportCategory(
      id: categoryId,
      code: categoryCode,
      name: categoryName,
      description: _stringOrEmpty(category['description']),
      slug: _stringOrEmpty(category['slug']),
      isActive: _boolValue(category['isActive'], defaultValue: true),
      parentCode: parentCode,
      position: categoryProduct['position'],
      isPrimary: _boolValue(categoryProduct['isPrimary'], defaultValue: true),
    );
  }

  _ExportProduct? _buildProductExport(Map<String, dynamic> product) {
    final productId = _stringOrNull(product['id'])!;
    final productCode = _stringOrNull(product['code']);
    final productName = _stringOrNull(product['name']);

    if (productCode == null || productName == null) {
      warnings.add('Produit $productId ignoré: code ou nom manquant.');
      return null;
    }

    final thumbnail = _resolveMedia(
      product: product,
      mediaId: _stringOrNull(product['thumbnail']),
      role: 'miniature',
    );
    if (thumbnail == null && _stringOrNull(product['thumbnail']) != null) {
      return null;
    }

    final picture = _resolveMedia(
      product: product,
      mediaId: _stringOrNull(product['picture']),
      role: 'image principale',
    );
    if (picture == null && _stringOrNull(product['picture']) != null) {
      return null;
    }

    final galleryContainerIds = _asStringList(product['galleryImages']);
    if (galleryContainerIds.length > 1) {
      warnings.add(
        'Produit $productCode ignoré: plusieurs gallery containers ne sont pas représentables.',
      );
      return null;
    }

    _ExportGalleryContainer? gallery;
    if (galleryContainerIds.isNotEmpty) {
      gallery = _resolveGalleryContainer(
        product: product,
        containerId: galleryContainerIds.first,
      );
      if (gallery == null) {
        return null;
      }
    }

    return _ExportProduct(
      id: productId,
      code: productCode,
      name: productName,
      slug: _stringOrEmpty(product['slug']),
      summary: _stringOrEmpty(product['summary']),
      description: _stringOrEmpty(product['description']),
      ean: _stringOrEmpty(product['ean']),
      gender: _stringOrEmpty(product['gender']),
      type: _stringOrEmpty(product['productType']),
      brand: _stringOrEmpty(product['brand']),
      isActive: _boolValue(product['isActive'], defaultValue: true),
      onlineDate: _stringOrEmpty(product['onlineDate']),
      offlineDate: _stringOrEmpty(product['offlineDate']),
      thumbnail: thumbnail,
      picture: picture,
      gallery: gallery,
    );
  }

  _ExportPrice? _buildPriceExport({
    required Map<String, dynamic> product,
    required Map<String, dynamic> priceRow,
  }) {
    final productCode = _stringOrNull(product['code']) ?? 'sans-code';
    final currencyId = _stringOrNull(priceRow['currency']);

    if (currencyId == null) {
      warnings.add(
        'Price row du produit $productCode ignorée: devise manquante.',
      );
      return null;
    }

    final currency = currenciesById[currencyId];
    final currencyCode = currency == null
        ? null
        : _stringOrNull(currency['isocode']);
    final currencySymbol = currency == null
        ? null
        : _stringOrNull(currency['symbol']);
    if (currency == null || currencyCode == null || currencySymbol == null) {
      warnings.add(
        'Price row du produit $productCode ignorée: devise introuvable ou incomplète.',
      );
      return null;
    }

    final unitId = _stringOrNull(priceRow['unit']);
    Map<String, dynamic>? unit;
    if (unitId != null) {
      unit = unitsById[unitId];
      if (unit == null || _stringOrNull(unit['code']) == null) {
        warnings.add(
          'Price row du produit $productCode ignorée: unité introuvable.',
        );
        return null;
      }
    }

    return _ExportPrice(
      currencyId: currencyId,
      unitId: unitId,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
      currencyName: _stringOrEmpty(currency['name']),
      currencyDigits: currency['digits'],
      currencyIsActive: _boolValue(currency['isActive'], defaultValue: true),
      unitCode: unit == null ? '' : _stringOrEmpty(unit['code']),
      unitName: unit == null ? '' : _stringOrEmpty(unit['name']),
      unitSymbol: unit == null ? '' : _stringOrEmpty(unit['symbol']),
      unitIsActive: unit == null
          ? ''
          : CatalogCsvFormat.stringify(
              _boolValue(unit['isActive'], defaultValue: true),
            ),
      price: priceRow['price'],
      minQuantity: priceRow['minqtd'],
      net: _boolValue(priceRow['net'], defaultValue: false),
      startTime: _stringOrEmpty(priceRow['startTime']),
      endTime: _stringOrEmpty(priceRow['endTime']),
      channel: _stringOrEmpty(priceRow['channel']),
      isDefault: _boolValue(priceRow['isDefault'], defaultValue: true),
      isActive: _boolValue(priceRow['isActive'], defaultValue: true),
    );
  }

  Map<String, Object?> _buildNarrativeRowMap({
    required Map<String, dynamic> product,
  }) {
    final productId = _stringOrNull(product['id'])!;
    final productCode = _stringOrNull(product['code']) ?? 'sans-code';
    final chapters = [...(narrativeChaptersByProduct[productId] ?? const [])]
      ..sort((a, b) {
        final aPos = (a['position'] as num?)?.toInt() ?? 0;
        final bPos = (b['position'] as num?)?.toInt() ?? 0;
        return aPos.compareTo(bPos);
      });

    if (chapters.isEmpty) {
      return _emptyNarrativeRowMap();
    }

    final allowedMediaIds = _allowedNarrativeMediaIds(product);
    final exportChapters = <_ExportNarrativeChapter>[];
    for (final chapter in chapters) {
      final mediaId = _stringOrNull(chapter['media']);
      if (mediaId == null) {
        warnings.add(
          'Produit $productCode: chapitre narratif ignoré, média manquant.',
        );
        continue;
      }
      if (!allowedMediaIds.contains(mediaId)) {
        warnings.add(
          'Produit $productCode: chapitre narratif ignoré, média hors galerie visible.',
        );
        continue;
      }

      final media = mediasById[mediaId];
      final mediaCode = media == null ? null : _stringOrNull(media['code']);
      if (media == null || mediaCode == null) {
        warnings.add(
          'Produit $productCode: chapitre narratif ignoré, média introuvable.',
        );
        continue;
      }

      exportChapters.add(
        _ExportNarrativeChapter(
          mediaCode: mediaCode,
          position: (chapter['position'] as num?)?.toInt() ?? 0,
          headline: _stringOrEmpty(chapter['headline']),
          story: _stringOrEmpty(chapter['story']),
          ctaLabel: _stringOrEmpty(chapter['ctaLabel']),
          ctaAction: _stringOrEmpty(chapter['ctaAction']),
          isActive: _boolValue(chapter['isActive'], defaultValue: true),
        ),
      );
    }

    if (exportChapters.isEmpty) {
      return _emptyNarrativeRowMap();
    }

    return {
      'chapter_positions': CatalogCsvFormat.joinListPreserveEmpty(
        exportChapters.map((chapter) => chapter.position),
      ),
      'chapter_media_codes': CatalogCsvFormat.joinListPreserveEmpty(
        exportChapters.map((chapter) => chapter.mediaCode),
      ),
      'chapter_headlines': CatalogCsvFormat.joinListPreserveEmpty(
        exportChapters.map((chapter) => chapter.headline),
      ),
      'chapter_stories': CatalogCsvFormat.joinListPreserveEmpty(
        exportChapters.map((chapter) => chapter.story),
      ),
      'chapter_cta_labels': CatalogCsvFormat.joinListPreserveEmpty(
        exportChapters.map((chapter) => chapter.ctaLabel),
      ),
      'chapter_cta_actions': CatalogCsvFormat.joinListPreserveEmpty(
        exportChapters.map((chapter) => chapter.ctaAction),
      ),
      'chapter_is_active': CatalogCsvFormat.joinListPreserveEmpty(
        exportChapters.map(
          (chapter) => CatalogCsvFormat.stringify(chapter.isActive),
        ),
      ),
    };
  }

  Map<String, Object?> _emptyNarrativeRowMap() {
    return const {
      'chapter_positions': '',
      'chapter_media_codes': '',
      'chapter_headlines': '',
      'chapter_stories': '',
      'chapter_cta_labels': '',
      'chapter_cta_actions': '',
      'chapter_is_active': '',
    };
  }

  _ExportMedia? _resolveMedia({
    required Map<String, dynamic> product,
    required String? mediaId,
    required String role,
  }) {
    if (mediaId == null) {
      return null;
    }

    final productCode = _stringOrNull(product['code']) ?? 'sans-code';
    final media = mediasById[mediaId];
    final mediaCode = media == null ? null : _stringOrNull(media['code']);
    final filename = media == null ? null : _stringOrNull(media['file']);

    if (media == null || mediaCode == null || filename == null) {
      warnings.add(
        'Produit $productCode ignoré: $role introuvable ou sans fichier exportable.',
      );
      return null;
    }

    return _ExportMedia(
      id: mediaId,
      code: mediaCode,
      title: _stringOrEmpty(media['title']),
      altText: _stringOrEmpty(media['altText']),
      source: client.fileUrl('medias', mediaId, filename),
      mimeType: _stringOrEmpty(media['mimeType']),
      isActive: _boolValue(media['isActive'], defaultValue: true),
    );
  }

  _ExportGalleryContainer? _resolveGalleryContainer({
    required Map<String, dynamic> product,
    required String containerId,
  }) {
    final productCode = _stringOrNull(product['code']) ?? 'sans-code';
    final container = mediaContainersById[containerId];
    final containerCode = container == null
        ? null
        : _stringOrNull(container['code']);

    if (container == null || containerCode == null) {
      warnings.add(
        'Produit $productCode ignoré: gallery container introuvable.',
      );
      return null;
    }

    final exportMedias = <_ExportMedia>[];
    for (final mediaId in _asStringList(container['medias'])) {
      final media = _resolveMedia(
        product: product,
        mediaId: mediaId,
        role: 'média de galerie',
      );
      if (media == null) {
        return null;
      }
      exportMedias.add(media);
    }

    return _ExportGalleryContainer(
      id: containerId,
      code: containerCode,
      name: _stringOrEmpty(container['name']),
      isActive: _boolValue(container['isActive'], defaultValue: true),
      medias: exportMedias,
    );
  }

  Set<String> _allowedNarrativeMediaIds(Map<String, dynamic> product) {
    final allowedMediaIds = <String>{};
    final pictureId = _stringOrNull(product['picture']);
    if (pictureId != null) {
      allowedMediaIds.add(pictureId);
    }

    for (final containerId in _asStringList(product['galleryImages'])) {
      final container = mediaContainersById[containerId];
      if (container == null) {
        continue;
      }
      allowedMediaIds.addAll(_asStringList(container['medias']));
    }

    if (allowedMediaIds.isEmpty) {
      final thumbnailId = _stringOrNull(product['thumbnail']);
      if (thumbnailId != null) {
        allowedMediaIds.add(thumbnailId);
      }
    }

    return allowedMediaIds;
  }

  Map<String, Map<String, dynamic>> _mapById(
    List<Map<String, dynamic>> records,
  ) {
    return {
      for (final record in records)
        if (_stringOrNull(record['id']) != null)
          _stringOrNull(record['id'])!: record,
    };
  }

  Map<String, List<Map<String, dynamic>>> _groupByString(
    List<Map<String, dynamic>> records,
    String field,
  ) {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      final key = _stringOrNull(record[field]);
      if (key == null) {
        continue;
      }
      result.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(record);
    }
    return result;
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map(_stringOrNull).whereType<String>().toList();
    }

    final single = _stringOrNull(value);
    return single == null ? const [] : <String>[single];
  }

  String? _stringOrNull(dynamic value) {
    final resolved = '$value'.trim();
    if (value == null || resolved.isEmpty || resolved == 'null') {
      return null;
    }
    return resolved;
  }

  String _stringOrEmpty(dynamic value) => _stringOrNull(value) ?? '';

  bool _boolValue(dynamic value, {required bool defaultValue}) {
    if (value is bool) {
      return value;
    }
    final resolved = _stringOrNull(value);
    if (resolved == null) {
      return defaultValue;
    }
    return switch (resolved.toLowerCase()) {
      'true' || '1' || 'yes' || 'oui' => true,
      'false' || '0' || 'no' || 'non' => false,
      _ => defaultValue,
    };
  }
}

class _ExportCategory {
  final String id;
  final String code;
  final String name;
  final String description;
  final String slug;
  final bool isActive;
  final String parentCode;
  final Object? position;
  final bool isPrimary;

  const _ExportCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.slug,
    required this.isActive,
    required this.parentCode,
    required this.position,
    required this.isPrimary,
  });

  Map<String, Object?> toRowMap() {
    return {
      'category_code': code,
      'category_name': name,
      'category_description': description,
      'category_slug': slug,
      'category_is_active': isActive,
      'category_parent_code': parentCode,
      'category_position': position,
      'category_is_primary': isPrimary,
    };
  }
}

class _ExportProduct {
  final String id;
  final String code;
  final String name;
  final String slug;
  final String summary;
  final String description;
  final String ean;
  final String gender;
  final String type;
  final String brand;
  final bool isActive;
  final String onlineDate;
  final String offlineDate;
  final _ExportMedia? thumbnail;
  final _ExportMedia? picture;
  final _ExportGalleryContainer? gallery;

  const _ExportProduct({
    required this.id,
    required this.code,
    required this.name,
    required this.slug,
    required this.summary,
    required this.description,
    required this.ean,
    required this.gender,
    required this.type,
    required this.brand,
    required this.isActive,
    required this.onlineDate,
    required this.offlineDate,
    required this.thumbnail,
    required this.picture,
    required this.gallery,
  });

  String? get thumbnailId => thumbnail?.id;
  String? get pictureId => picture?.id;
  String? get galleryContainerId => gallery?.id;
  List<String> get galleryMediaIds => [
    for (final media in gallery?.medias ?? const <_ExportMedia>[]) media.id,
  ];

  Map<String, Object?> toRowMap() {
    return {
      'product_code': code,
      'product_name': name,
      'product_slug': slug,
      'product_summary': summary,
      'product_description': description,
      'product_ean': ean,
      'product_gender': gender,
      'product_type': type,
      'product_brand': brand,
      'product_is_active': isActive,
      'product_online_date': onlineDate,
      'product_offline_date': offlineDate,
      'thumbnail_code': thumbnail?.code,
      'thumbnail_title': thumbnail?.title,
      'thumbnail_alt_text': thumbnail?.altText,
      'thumbnail_source': thumbnail?.source,
      'thumbnail_mime_type': thumbnail?.mimeType,
      'thumbnail_is_active': thumbnail?.isActive,
      'picture_code': picture?.code,
      'picture_title': picture?.title,
      'picture_alt_text': picture?.altText,
      'picture_source': picture?.source,
      'picture_mime_type': picture?.mimeType,
      'picture_is_active': picture?.isActive,
      'gallery_container_code': gallery?.code,
      'gallery_container_name': gallery?.name,
      'gallery_container_is_active': gallery?.isActive,
      'gallery_media_codes': gallery?.joined((media) => media.code),
      'gallery_media_titles': gallery?.joined((media) => media.title),
      'gallery_media_alt_texts': gallery?.joined((media) => media.altText),
      'gallery_media_sources': gallery?.joined((media) => media.source),
      'gallery_media_mime_types': gallery?.joined((media) => media.mimeType),
      'gallery_media_is_active': gallery?.joined(
        (media) => CatalogCsvFormat.stringify(media.isActive),
      ),
    };
  }
}

class _ExportPrice {
  final String currencyId;
  final String? unitId;
  final String currencyCode;
  final String currencySymbol;
  final String currencyName;
  final Object? currencyDigits;
  final bool currencyIsActive;
  final String unitCode;
  final String unitName;
  final String unitSymbol;
  final String unitIsActive;
  final Object? price;
  final Object? minQuantity;
  final bool net;
  final String startTime;
  final String endTime;
  final String channel;
  final bool isDefault;
  final bool isActive;

  const _ExportPrice({
    required this.currencyId,
    required this.unitId,
    required this.currencyCode,
    required this.currencySymbol,
    required this.currencyName,
    required this.currencyDigits,
    required this.currencyIsActive,
    required this.unitCode,
    required this.unitName,
    required this.unitSymbol,
    required this.unitIsActive,
    required this.price,
    required this.minQuantity,
    required this.net,
    required this.startTime,
    required this.endTime,
    required this.channel,
    required this.isDefault,
    required this.isActive,
  });

  Map<String, Object?> toRowMap() {
    return {
      'currency_isocode': currencyCode,
      'currency_symbol': currencySymbol,
      'currency_name': currencyName,
      'currency_digits': currencyDigits,
      'currency_is_active': currencyIsActive,
      'unit_code': unitCode,
      'unit_name': unitName,
      'unit_symbol': unitSymbol,
      'unit_is_active': unitIsActive,
      'price': price,
      'price_minqtd': minQuantity,
      'price_net': net,
      'price_start_time': startTime,
      'price_end_time': endTime,
      'price_channel': channel,
      'price_is_default': isDefault,
      'price_is_active': isActive,
    };
  }
}

class _ExportMedia {
  final String id;
  final String code;
  final String title;
  final String altText;
  final String source;
  final String mimeType;
  final bool isActive;

  const _ExportMedia({
    required this.id,
    required this.code,
    required this.title,
    required this.altText,
    required this.source,
    required this.mimeType,
    required this.isActive,
  });
}

class _ExportGalleryContainer {
  final String id;
  final String code;
  final String name;
  final bool isActive;
  final List<_ExportMedia> medias;

  const _ExportGalleryContainer({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.medias,
  });

  String joined(String Function(_ExportMedia media) selector) {
    return CatalogCsvFormat.joinList(medias.map(selector));
  }
}

class _ExportNarrativeChapter {
  final String mediaCode;
  final int position;
  final String headline;
  final String story;
  final String ctaLabel;
  final String ctaAction;
  final bool isActive;

  const _ExportNarrativeChapter({
    required this.mediaCode,
    required this.position,
    required this.headline,
    required this.story,
    required this.ctaLabel,
    required this.ctaAction,
    required this.isActive,
  });
}

class _UsedReferences {
  final Set<String> currencies = <String>{};
  final Set<String> units = <String>{};
  final Set<String> medias = <String>{};
  final Set<String> mediaContainers = <String>{};
}

class _WarningCollector {
  final List<String> _messages = <String>[];
  final Set<String> _dedupe = <String>{};

  void add(String message) {
    if (_dedupe.add(message)) {
      _messages.add(message);
    }
  }

  List<String> get messages => List<String>.unmodifiable(_messages);
}
