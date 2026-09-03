import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/catalog_import_indexes.dart';

void main() {
  group('CatalogImportIndexes.fromCollections', () {
    test('indexes categories/products/currencies/units/medias by their code', () {
      final indexes = CatalogImportIndexes.fromCollections({
        'categories': [
          {'id': 'cat1', 'code': 'shoes'},
          {'id': 'cat2', 'code': ''},
        ],
        'products': [
          {'id': 'p1', 'code': 'SKU-1'},
        ],
        'currencies': [
          {'id': 'cur1', 'isocode': 'EUR'},
        ],
        'units': [
          {'id': 'u1', 'code': 'pair'},
        ],
        'medias': [
          {'id': 'm1', 'code': 'hero'},
        ],
        'mediaContainers': [
          {'id': 'mc1', 'code': 'gallery-1'},
        ],
        'categoryProducts': [
          {'id': 'cp1', 'category': 'cat1', 'product': 'p1'},
        ],
        'priceRows': [
          {
            'id': 'pr1',
            'product': 'p1',
            'currency': 'cur1',
            'unit': 'u1',
            'channel': 'web',
            'minqtd': 1,
            'startTime': '',
          },
        ],
        'narrativeChapters': [
          {'id': 'nc1', 'product': 'p1', 'media': 'm1'},
        ],
      });

      expect(indexes.categoriesByCode.keys, ['shoes']);
      expect(indexes.productsByCode['SKU-1']?['id'], 'p1');
      expect(indexes.currenciesByIsoCode.containsKey('EUR'), isTrue);
      expect(indexes.unitsByCode.containsKey('pair'), isTrue);
      expect(indexes.mediasByCode.containsKey('hero'), isTrue);
      expect(indexes.mediaContainersByCode.containsKey('gallery-1'), isTrue);
      expect(indexes.mediaContainersById.containsKey('mc1'), isTrue);
      expect(
        indexes.categoryProductsByKey[CatalogImportIndexes.categoryProductKey(
          'cat1',
          'p1',
        )]?['id'],
        'cp1',
      );
      expect(
        indexes
            .narrativeChaptersByProductAndMedia[CatalogImportIndexes.narrativeChapterKey(
          'p1',
          'm1',
        )]?['id'],
        'nc1',
      );
      expect(
        indexes.priceRowsByKey[CatalogImportIndexes.priceRowKey(
          productId: 'p1',
          currencyId: 'cur1',
          unitId: 'u1',
          channel: 'web',
          minQuantity: 1,
          startTime: '',
        )]?['id'],
        'pr1',
      );
    });

    test('tolerates missing collections (defaults to empty)', () {
      final indexes = CatalogImportIndexes.fromCollections({});
      expect(indexes.categoriesByCode, isEmpty);
      expect(indexes.productsByCode, isEmpty);
      expect(indexes.priceRowsByKey, isEmpty);
    });

    test('skips records with empty code/isocode keys', () {
      final indexes = CatalogImportIndexes.fromCollections({
        'categories': [
          {'id': 'x', 'code': ''},
          {'id': 'y'},
        ],
        'currencies': [
          {'id': 'z'},
        ],
      });
      expect(indexes.categoriesByCode, isEmpty);
      expect(indexes.currenciesByIsoCode, isEmpty);
    });
  });

  group('key helpers', () {
    test('categoryProductKey joins with ::', () {
      expect(CatalogImportIndexes.categoryProductKey('a', 'b'), 'a::b');
    });

    test('narrativeChapterKey joins with ::', () {
      expect(CatalogImportIndexes.narrativeChapterKey('p', 'm'), 'p::m');
    });

    test('priceRowKey encodes optional fields as empty strings', () {
      expect(
        CatalogImportIndexes.priceRowKey(productId: 'p', currencyId: 'c'),
        'p::c::::::::',
      );
      expect(
        CatalogImportIndexes.priceRowKey(
          productId: 'p',
          currencyId: 'c',
          unitId: 'u',
          channel: 'web',
          minQuantity: 3,
          startTime: '2026-01-01',
        ),
        'p::c::u::web::3::2026-01-01',
      );
    });
  });
}
