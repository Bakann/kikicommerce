import '../application/admin/catalog_import_indexes.dart';
import '../application/admin/catalog_import_report.dart';
import '../core/utils/search_index_utils.dart';
import '../data/csv/catalog_csv_parser.dart';
import 'admin_client.dart';
import 'admin_collection_schema.dart';
import 'services/admin_media_source_loader.dart';

class CatalogCsvImportService {
  final PocketBaseAdminClient client;
  final AdminMediaSourceLoader mediaSourceLoader;

  CatalogCsvImportService({
    required this.client,
    this.mediaSourceLoader = const AdminMediaSourceLoader(),
  });

  Future<CatalogImportReport> importCatalogCsv(String csvContent) async {
    final rows = parseCsvRows(csvContent);
    if (rows.isEmpty) {
      throw Exception('Le CSV est vide.');
    }

    final report = CatalogImportReport(totalRows: rows.length);
    final existingRecords = <String, List<Map<String, dynamic>>>{};
    final collectionSchemas = <String, PocketBaseCollectionSchema>{};

    for (final definition in adminCollectionDefinitions) {
      collectionSchemas[definition.name] = await client.getCollectionSchema(
        definition.name,
      );
      existingRecords[definition.name] = await client.listRecords(
        definition.name,
        sort: definition.sort,
        perPage: 500,
      );
    }

    final indexes = CatalogImportIndexes.fromCollections(existingRecords);

    await _upsertCurrencies(rows, indexes, report, collectionSchemas);
    await _upsertUnits(rows, indexes, report, collectionSchemas);
    await _upsertCategories(rows, indexes, report, collectionSchemas);
    await _upsertMedias(rows, indexes, report, collectionSchemas);
    await _upsertMediaContainers(rows, indexes, report, collectionSchemas);
    await _upsertProducts(rows, indexes, report, collectionSchemas);
    await _upsertNarrativeChapters(rows, indexes, report, collectionSchemas);
    await _upsertCategoryProducts(rows, indexes, report, collectionSchemas);
    await _upsertPriceRows(rows, indexes, report, collectionSchemas);

    return report;
  }

  Future<void> _upsertCurrencies(
    List<CsvRow> rows,
    CatalogImportIndexes indexes,
    CatalogImportReport report,
    Map<String, PocketBaseCollectionSchema> schemas,
  ) async {
    final byIsoCode = <String, CsvRow>{};
    for (final row in rows) {
      final isoCode = row.value('currency_isocode');
      if (isoCode.isNotEmpty) {
        byIsoCode[isoCode] = row;
      }
    }

    for (final entry in byIsoCode.entries) {
      final row = entry.value;
      final data = <String, dynamic>{
        'isocode': entry.key,
        'symbol': row.value('currency_symbol'),
        'name': row.value('currency_name'),
        'digits': row.intValue('currency_digits'),
        'isActive': _csvBoolValue(
          row,
          'currency_is_active',
          defaultValue: true,
          report: report,
        ),
      };

      final normalizedData = _normalizePayload(
        collection: 'currencies',
        data: data,
        schemas: schemas,
      );
      final existing = indexes.currenciesByIsoCode[entry.key];
      final record = existing == null
          ? await client.createRecord('currencies', normalizedData)
          : await client.updateRecord(
              'currencies',
              existing['id'] as String,
              normalizedData,
            );

      indexes.currenciesByIsoCode[entry.key] = record;
      if (existing == null) {
        report.markCreated('currencies');
      } else {
        report.markUpdated('currencies');
      }
    }
  }

  Future<void> _upsertUnits(
    List<CsvRow> rows,
    CatalogImportIndexes indexes,
    CatalogImportReport report,
    Map<String, PocketBaseCollectionSchema> schemas,
  ) async {
    final byCode = <String, CsvRow>{};
    for (final row in rows) {
      final code = row.value('unit_code');
      if (code.isNotEmpty) {
        byCode[code] = row;
      }
    }

    for (final entry in byCode.entries) {
      final row = entry.value;
      final data = <String, dynamic>{
        'code': entry.key,
        'name': row.value('unit_name'),
        'symbol': row.value('unit_symbol'),
        'isActive': _csvBoolValue(
          row,
          'unit_is_active',
          defaultValue: true,
          report: report,
        ),
      };

      final normalizedData = _normalizePayload(
        collection: 'units',
        data: data,
        schemas: schemas,
      );
      final existing = indexes.unitsByCode[entry.key];
      final record = existing == null
          ? await client.createRecord('units', normalizedData)
          : await client.updateRecord(
              'units',
              existing['id'] as String,
              normalizedData,
            );

      indexes.unitsByCode[entry.key] = record;
      if (existing == null) {
        report.markCreated('units');
      } else {
        report.markUpdated('units');
      }
    }
  }

  Future<void> _upsertCategories(
    List<CsvRow> rows,
    CatalogImportIndexes indexes,
    CatalogImportReport report,
    Map<String, PocketBaseCollectionSchema> schemas,
  ) async {
    final byCode = <String, CsvRow>{};
    for (final row in rows) {
      final code = row.value('category_code');
      if (code.isNotEmpty) {
        byCode[code] = row;
      }
    }

    for (final entry in byCode.entries) {
      final row = entry.value;
      final data = <String, dynamic>{
        'code': entry.key,
        'name': row.value('category_name'),
        'description': row.valueOrNull('category_description'),
        'slug': row.valueOrNull('category_slug'),
        'isActive': _csvBoolValue(
          row,
          'category_is_active',
          defaultValue: true,
          report: report,
        ),
      };

      final normalizedData = _normalizePayload(
        collection: 'categories',
        data: data,
        schemas: schemas,
      );
      final existing = indexes.categoriesByCode[entry.key];
      final record = existing == null
          ? await client.createRecord('categories', normalizedData)
          : await client.updateRecord(
              'categories',
              existing['id'] as String,
              normalizedData,
            );

      indexes.categoriesByCode[entry.key] = record;
      if (existing == null) {
        report.markCreated('categories');
      } else {
        report.markUpdated('categories');
      }
    }

    for (final entry in byCode.entries) {
      final parentCode = entry.value.value('category_parent_code');
      if (parentCode.isEmpty) {
        continue;
      }
      final category = indexes.categoriesByCode[entry.key];
      final parent = indexes.categoriesByCode[parentCode];
      if (category == null || parent == null) {
        report.errors.add(
          'Catégorie ${entry.key}: parent introuvable "$parentCode".',
        );
        continue;
      }

      final updated = await client.updateRecord(
        'categories',
        category['id'] as String,
        _normalizePayload(
          collection: 'categories',
          data: {'parent': parent['id']},
          schemas: schemas,
        ),
      );
      indexes.categoriesByCode[entry.key] = updated;
      report.markUpdated('categories');
    }
  }

  Future<void> _upsertMedias(
    List<CsvRow> rows,
    CatalogImportIndexes indexes,
    CatalogImportReport report,
    Map<String, PocketBaseCollectionSchema> schemas,
  ) async {
    final mediaSeeds = <String, MediaSeed>{};

    for (final row in rows) {
      _addMediaSeed(
        mediaSeeds,
        code: row.value('thumbnail_code'),
        title: row.value('thumbnail_title'),
        altText: row.value('thumbnail_alt_text'),
        source: row.value('thumbnail_source'),
        mimeType: row.value('thumbnail_mime_type'),
        isActive: _csvBoolValue(
          row,
          'thumbnail_is_active',
          defaultValue: true,
          report: report,
        ),
      );
      _addMediaSeed(
        mediaSeeds,
        code: row.value('picture_code'),
        title: row.value('picture_title'),
        altText: row.value('picture_alt_text'),
        source: row.value('picture_source'),
        mimeType: row.value('picture_mime_type'),
        isActive: _csvBoolValue(
          row,
          'picture_is_active',
          defaultValue: true,
          report: report,
        ),
      );

      final galleryCodes = row.pipeValues('gallery_media_codes');
      final galleryTitles = row.pipeValues('gallery_media_titles');
      final galleryAltTexts = row.pipeValues('gallery_media_alt_texts');
      final gallerySources = row.pipeValues('gallery_media_sources');
      final galleryMimeTypes = row.pipeValues('gallery_media_mime_types');
      final galleryActive = row.pipeValues('gallery_media_is_active');

      for (var index = 0; index < galleryCodes.length; index += 1) {
        _addMediaSeed(
          mediaSeeds,
          code: galleryCodes[index],
          title: index < galleryTitles.length
              ? galleryTitles[index]
              : galleryCodes[index],
          altText: index < galleryAltTexts.length
              ? galleryAltTexts[index]
              : galleryCodes[index],
          source: index < gallerySources.length ? gallerySources[index] : '',
          mimeType: index < galleryMimeTypes.length
              ? galleryMimeTypes[index]
              : '',
          isActive: index < galleryActive.length
              ? _parseCsvBoolValue(
                  galleryActive[index],
                  lineNumber: row.lineNumber,
                  fieldName: 'gallery_media_is_active',
                  defaultValue: true,
                  report: report,
                )
              : true,
        );
      }
    }

    for (final seed in mediaSeeds.values) {
      try {
        final filePayload = await mediaSourceLoader.load(
          seed.source,
          fallbackFilename: seed.code,
          mimeType: seed.mimeType,
        );

        final data = <String, dynamic>{
          'code': seed.code,
          'title': seed.title,
          'altText': seed.altText,
          'mimeType': seed.mimeType,
          'isActive': seed.isActive,
        };

        final normalizedData = _normalizePayload(
          collection: 'medias',
          data: data,
          schemas: schemas,
        );
        final existing = indexes.mediasByCode[seed.code];
        final record = await client.upsertMultipartRecord(
          collection: 'medias',
          recordId: existing?['id'] as String?,
          data: normalizedData,
          fileBytes: filePayload?.bytes,
          filename: filePayload?.filename,
          mimeType: seed.mimeType,
        );

        indexes.mediasByCode[seed.code] = record;
        if (existing == null) {
          report.markCreated('medias');
        } else {
          report.markUpdated('medias');
        }
      } catch (error) {
        report.errors.add('Media ${seed.code}: $error');
      }
    }
  }

  Future<void> _upsertMediaContainers(
    List<CsvRow> rows,
    CatalogImportIndexes indexes,
    CatalogImportReport report,
    Map<String, PocketBaseCollectionSchema> schemas,
  ) async {
    final byCode = <String, CsvRow>{};
    for (final row in rows) {
      final code = row.value('gallery_container_code');
      if (code.isNotEmpty) {
        byCode[code] = row;
      }
    }

    for (final entry in byCode.entries) {
      final row = entry.value;
      final mediaIds = row
          .pipeValues('gallery_media_codes')
          .map((code) => indexes.mediasByCode[code]?['id'] as String?)
          .whereType<String>()
          .toList();

      final data = <String, dynamic>{
        'code': entry.key,
        'name': row.valueOrNull('gallery_container_name'),
        'medias': mediaIds,
        'isActive': _csvBoolValue(
          row,
          'gallery_container_is_active',
          defaultValue: true,
          report: report,
        ),
      };

      final normalizedData = _normalizePayload(
        collection: 'mediaContainers',
        data: data,
        schemas: schemas,
      );
      final existing = indexes.mediaContainersByCode[entry.key];
      final record = existing == null
          ? await client.createRecord('mediaContainers', normalizedData)
          : await client.updateRecord(
              'mediaContainers',
              existing['id'] as String,
              normalizedData,
            );

      indexes.mediaContainersByCode[entry.key] = record;
      if (existing == null) {
        report.markCreated('mediaContainers');
      } else {
        report.markUpdated('mediaContainers');
      }
    }
  }

  Future<void> _upsertProducts(
    List<CsvRow> rows,
    CatalogImportIndexes indexes,
    CatalogImportReport report,
    Map<String, PocketBaseCollectionSchema> schemas,
  ) async {
    final byCode = <String, CsvRow>{};
    for (final row in rows) {
      final code = row.value('product_code');
      if (code.isNotEmpty) {
        byCode[code] = row;
      }
    }

    for (final entry in byCode.entries) {
      final row = entry.value;
      final pictureId = indexes.mediasByCode[row.value('picture_code')]?['id'];
      final thumbnailId =
          indexes.mediasByCode[row.value('thumbnail_code')]?['id'];
      final galleryContainerId = indexes
          .mediaContainersByCode[row.value('gallery_container_code')]?['id'];

      final data = <String, dynamic>{
        'code': entry.key,
        'name': row.value('product_name'),
        'slug': row.valueOrNull('product_slug'),
        'summary': row.valueOrNull('product_summary'),
        'description': row.valueOrNull('product_description'),
        'ean': row.valueOrNull('product_ean'),
        'gender': row.valueOrNull('product_gender'),
        'productType': row.valueOrNull('product_type'),
        'brand': row.valueOrNull('product_brand'),
        'isActive': _csvBoolValue(
          row,
          'product_is_active',
          defaultValue: true,
          report: report,
        ),
        'onlineDate': row.valueOrNull('product_online_date'),
        'offlineDate': row.valueOrNull('product_offline_date'),
        'picture': pictureId,
        'thumbnail': thumbnailId,
        'galleryImages': galleryContainerId == null
            ? <String>[]
            : <String>[galleryContainerId as String],
      };

      final normalizedData = _normalizePayload(
        collection: 'products',
        data: data,
        schemas: schemas,
      );
      normalizedData['searchIndex'] = buildProductSearchIndex(data);
      final existing = indexes.productsByCode[entry.key];
      final record = existing == null
          ? await client.createRecord('products', normalizedData)
          : await client.updateRecord(
              'products',
              existing['id'] as String,
              normalizedData,
            );

      indexes.productsByCode[entry.key] = record;
      if (existing == null) {
        report.markCreated('products');
      } else {
        report.markUpdated('products');
      }
    }
  }

  Future<void> _upsertCategoryProducts(
    List<CsvRow> rows,
    CatalogImportIndexes indexes,
    CatalogImportReport report,
    Map<String, PocketBaseCollectionSchema> schemas,
  ) async {
    for (final row in rows) {
      final category = indexes.categoriesByCode[row.value('category_code')];
      final product = indexes.productsByCode[row.value('product_code')];
      if (category == null || product == null) {
        report.errors.add(
          'Ligne ${row.lineNumber}: relation categoryProducts incomplète.',
        );
        continue;
      }

      final key = CatalogImportIndexes.categoryProductKey(
        category['id'] as String,
        product['id'] as String,
      );
      final data = <String, dynamic>{
        'category': category['id'],
        'product': product['id'],
        'position': row.intValue('category_position'),
        'isPrimary': _csvBoolValue(
          row,
          'category_is_primary',
          defaultValue: true,
          report: report,
        ),
        'isActive': _csvBoolValue(
          row,
          'category_is_active',
          defaultValue: true,
          report: report,
        ),
      };

      final normalizedData = _normalizePayload(
        collection: 'categoryProducts',
        data: data,
        schemas: schemas,
      );
      final existing = indexes.categoryProductsByKey[key];
      final record = existing == null
          ? await client.createRecord('categoryProducts', normalizedData)
          : await client.updateRecord(
              'categoryProducts',
              existing['id'] as String,
              normalizedData,
            );

      indexes.categoryProductsByKey[key] = record;
      if (existing == null) {
        report.markCreated('categoryProducts');
      } else {
        report.markUpdated('categoryProducts');
      }
    }
  }

  Future<void> _upsertNarrativeChapters(
    List<CsvRow> rows,
    CatalogImportIndexes indexes,
    CatalogImportReport report,
    Map<String, PocketBaseCollectionSchema> schemas,
  ) async {
    final rowsByProduct = <String, NarrativeCsvBlock>{};

    for (final row in rows) {
      final productCode = row.value('product_code');
      if (productCode.isEmpty || !hasNarrativeData(row)) {
        continue;
      }

      final nextBlock = NarrativeCsvBlock.fromRow(row);
      final existingBlock = rowsByProduct[productCode];
      if (existingBlock == null) {
        rowsByProduct[productCode] = nextBlock;
        continue;
      }

      if (!existingBlock.hasSameRawValues(nextBlock)) {
        report.errors.add(
          'Produit $productCode: ligne ${row.lineNumber} contient des données '
          'narratives ignorées (première occurrence ligne ${existingBlock.lineNumber}).',
        );
      }
    }

    for (final entry in rowsByProduct.entries) {
      final productCode = entry.key;
      final block = entry.value;
      final product = indexes.productsByCode[productCode];
      if (product == null) {
        report.errors.add(
          'Produit $productCode: chapitres narratifs ignorés, produit introuvable.',
        );
        continue;
      }

      final parsedBlock = block.parse(report);
      if (parsedBlock == null) {
        continue;
      }

      final productId = product['id'] as String;
      final allowedMediaIds = _allowedNarrativeMediaIds(
        product: product,
        indexes: indexes,
      );
      final importedKeys = <String>{};
      var canDeleteObsolete = true;

      for (var index = 0; index < parsedBlock.mediaCodes.length; index += 1) {
        final mediaCode = parsedBlock.mediaCodes[index];
        final media = indexes.mediasByCode[mediaCode];
        if (media == null) {
          report.errors.add(
            'Produit $productCode: média narratif "$mediaCode" introuvable.',
          );
          canDeleteObsolete = false;
          continue;
        }

        final mediaId = media['id'] as String;
        if (!allowedMediaIds.contains(mediaId)) {
          report.errors.add(
            'Produit $productCode: le média narratif "$mediaCode" '
            'n’appartient pas à la galerie visible du produit.',
          );
          canDeleteObsolete = false;
          continue;
        }

        final key = CatalogImportIndexes.narrativeChapterKey(
          productId,
          mediaId,
        );
        if (!importedKeys.add(key)) {
          report.errors.add(
            'Produit $productCode: doublon narratif pour le média "$mediaCode".',
          );
          canDeleteObsolete = false;
          continue;
        }

        final data = <String, dynamic>{
          'product': productId,
          'media': mediaId,
          'position': parsedBlock.positions[index],
          'headline': parsedBlock.headlines[index],
          'story': parsedBlock.stories[index].isEmpty
              ? null
              : parsedBlock.stories[index],
          'ctaLabel': parsedBlock.ctaLabels[index].isEmpty
              ? null
              : parsedBlock.ctaLabels[index],
          'ctaAction': parsedBlock.ctaActions[index].isEmpty
              ? null
              : parsedBlock.ctaActions[index],
          'isActive': parsedBlock.isActive[index],
        };

        final normalizedData = _normalizePayload(
          collection: 'narrativeChapters',
          data: data,
          schemas: schemas,
        );
        final existing = indexes.narrativeChaptersByProductAndMedia[key];
        final record = existing == null
            ? await client.createRecord('narrativeChapters', normalizedData)
            : await client.updateRecord(
                'narrativeChapters',
                existing['id'] as String,
                normalizedData,
              );

        indexes.narrativeChaptersByProductAndMedia[key] = record;
        if (existing == null) {
          report.markCreated('narrativeChapters');
        } else {
          report.markUpdated('narrativeChapters');
        }
      }

      if (!canDeleteObsolete) {
        continue;
      }

      final existingProductKeys = indexes
          .narrativeChaptersByProductAndMedia
          .entries
          .where((entry) => entry.value['product'] == productId)
          .map((entry) => entry.key)
          .toList();
      for (final key in existingProductKeys) {
        if (importedKeys.contains(key)) {
          continue;
        }

        final record = indexes.narrativeChaptersByProductAndMedia.remove(key);
        if (record == null) {
          continue;
        }
        await client.deleteRecord('narrativeChapters', record['id'] as String);
      }
    }
  }

  Future<void> _upsertPriceRows(
    List<CsvRow> rows,
    CatalogImportIndexes indexes,
    CatalogImportReport report,
    Map<String, PocketBaseCollectionSchema> schemas,
  ) async {
    for (final row in rows) {
      final product = indexes.productsByCode[row.value('product_code')];
      final currency =
          indexes.currenciesByIsoCode[row.value('currency_isocode')];
      final unit = indexes.unitsByCode[row.value('unit_code')];

      if (product == null || currency == null) {
        report.errors.add(
          'Ligne ${row.lineNumber}: price row invalide, produit ou devise manquant.',
        );
        continue;
      }

      final key = CatalogImportIndexes.priceRowKey(
        productId: product['id'] as String,
        currencyId: currency['id'] as String,
        unitId: unit?['id'] as String?,
        channel: row.valueOrNull('price_channel'),
        minQuantity: row.intValue('price_minqtd'),
        startTime: row.valueOrNull('price_start_time'),
      );

      final data = <String, dynamic>{
        'product': product['id'],
        'currency': currency['id'],
        'unit': unit?['id'],
        'price': row.doubleValue('price'),
        'minqtd': row.intValue('price_minqtd'),
        'net': _csvBoolValue(
          row,
          'price_net',
          defaultValue: false,
          report: report,
        ),
        'startTime': row.valueOrNull('price_start_time'),
        'endTime': row.valueOrNull('price_end_time'),
        'channel': row.valueOrNull('price_channel'),
        'isDefault': _csvBoolValue(
          row,
          'price_is_default',
          defaultValue: true,
          report: report,
        ),
        'isActive': _csvBoolValue(
          row,
          'price_is_active',
          defaultValue: true,
          report: report,
        ),
      };

      final normalizedData = _normalizePayload(
        collection: 'priceRows',
        data: data,
        schemas: schemas,
      );
      final existing = indexes.priceRowsByKey[key];
      final record = existing == null
          ? await client.createRecord('priceRows', normalizedData)
          : await client.updateRecord(
              'priceRows',
              existing['id'] as String,
              normalizedData,
            );

      indexes.priceRowsByKey[key] = record;
      if (existing == null) {
        report.markCreated('priceRows');
      } else {
        report.markUpdated('priceRows');
      }
    }
  }

  void _addMediaSeed(
    Map<String, MediaSeed> seeds, {
    required String code,
    required String title,
    required String altText,
    required String source,
    required String mimeType,
    required bool isActive,
  }) {
    if (code.isEmpty || source.isEmpty) {
      return;
    }

    seeds[code] = MediaSeed(
      code: code,
      title: title,
      altText: altText,
      source: source,
      mimeType: mimeType,
      isActive: isActive,
    );
  }

  Set<String> _allowedNarrativeMediaIds({
    required Map<String, dynamic> product,
    required CatalogImportIndexes indexes,
  }) {
    final allowedMediaIds = <String>{};
    final pictureId = product['picture'] as String?;
    if (pictureId != null && pictureId.isNotEmpty) {
      allowedMediaIds.add(pictureId);
    }

    final galleryContainerIds =
        (product['galleryImages'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty);
    for (final containerId in galleryContainerIds) {
      final container = indexes.mediaContainersById[containerId];
      if (container == null) {
        continue;
      }
      for (final mediaId
          in (container['medias'] as List<dynamic>? ?? const [])) {
        final resolvedId = mediaId.toString();
        if (resolvedId.isNotEmpty) {
          allowedMediaIds.add(resolvedId);
        }
      }
    }

    if (allowedMediaIds.isEmpty) {
      final thumbnailId = product['thumbnail'] as String?;
      if (thumbnailId != null && thumbnailId.isNotEmpty) {
        allowedMediaIds.add(thumbnailId);
      }
    }

    return allowedMediaIds;
  }

  bool _csvBoolValue(
    CsvRow row,
    String fieldName, {
    required bool defaultValue,
    required CatalogImportReport report,
  }) {
    return _parseCsvBoolValue(
      row.value(fieldName),
      lineNumber: row.lineNumber,
      fieldName: fieldName,
      defaultValue: defaultValue,
      report: report,
    );
  }

  bool _parseCsvBoolValue(
    String rawValue, {
    required int lineNumber,
    required String fieldName,
    required bool defaultValue,
    required CatalogImportReport report,
  }) {
    try {
      return parseCsvBool(rawValue, defaultValue: defaultValue);
    } on FormatException {
      report.errors.add(
        'Ligne $lineNumber: booléen CSV invalide pour $fieldName "$rawValue".',
      );
      return defaultValue;
    }
  }

  Map<String, dynamic> _normalizePayload({
    required String collection,
    required Map<String, dynamic> data,
    required Map<String, PocketBaseCollectionSchema> schemas,
  }) {
    final schema = schemas[collection];
    if (schema == null) {
      return data;
    }

    final normalized = <String, dynamic>{};
    for (final entry in data.entries) {
      final field = schema.fieldsByName[entry.key];
      if (field == null) {
        continue;
      }

      normalized[entry.key] = _normalizeFieldValue(
        collection: collection,
        field: field,
        value: entry.value,
      );
    }
    return normalized;
  }

  dynamic _normalizeFieldValue({
    required String collection,
    required PocketBaseFieldSchema field,
    required dynamic value,
  }) {
    if (value == null) {
      return null;
    }

    switch (field.type) {
      case 'select':
        if (value is List) {
          return value
              .where((item) => item != null && '$item'.trim().isNotEmpty)
              .map(
                (item) => _matchSelectValue(
                  collection: collection,
                  field: field,
                  rawValue: '$item',
                ),
              )
              .toList();
        }

        final rawValue = '$value'.trim();
        if (rawValue.isEmpty) {
          return null;
        }
        return _matchSelectValue(
          collection: collection,
          field: field,
          rawValue: rawValue,
        );
      case 'relation':
        if (field.isMultiple) {
          if (value is List) {
            return value
                .map((item) => '$item'.trim())
                .where((item) => item.isNotEmpty)
                .toList();
          }

          final rawValue = '$value'.trim();
          return rawValue.isEmpty ? <String>[] : <String>[rawValue];
        }

        final rawValue = '$value'.trim();
        return rawValue.isEmpty ? null : rawValue;
      case 'number':
        if (value is num) {
          return value;
        }
        return double.tryParse('$value'.replaceAll(',', '.')) ?? value;
      case 'bool':
        if (value is bool) {
          return value;
        }
        return parseCsvBool('$value', defaultValue: false);
      default:
        return value;
    }
  }

  String _matchSelectValue({
    required String collection,
    required PocketBaseFieldSchema field,
    required String rawValue,
  }) {
    final normalizedRawValue = _normalizeComparable(rawValue);

    for (final option in field.values) {
      if (_normalizeComparable(option) == normalizedRawValue) {
        return option;
      }
    }

    throw Exception(
      'Champ $collection.${field.name}: valeur "$rawValue" invalide. '
      'Valeurs autorisées: ${field.values.join(', ')}',
    );
  }

  String _normalizeComparable(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  }
}
