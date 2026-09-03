import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';

void main() {
  group('CategorySplitTabsConfig.fromJson', () {
    test('parses items, defaultActiveIndex (clamped) and expansibleTitle', () {
      final config = CategorySplitTabsConfig.fromJson(const {
        'defaultActiveIndex': 5,
        'expansibleTitle': '  Parcourir  ',
        'items': [
          {'label': 'Homme', 'href': '/sport/homme', 'segment': 'homme'},
          {'label': 'Femme', 'href': '/sport/femme', 'segment': 'femme'},
        ],
      });

      expect(config.items, hasLength(2));
      expect(config.displayMode, isNull);
      expect(config.expansibleTitle, 'Parcourir');
      // Out-of-range index clamps back to 0.
      expect(config.defaultActiveIndex, 0);
    });

    test('defaults: empty items, index 0, no expansible title', () {
      final config = CategorySplitTabsConfig.fromJson(const {});
      expect(config.items, isEmpty);
      expect(config.defaultActiveIndex, 0);
      expect(config.displayMode, isNull);
      expect(config.expansibleTitle, isNull);
    });

    test('parses legacy displayMode only when valid', () {
      expect(
        CategorySplitTabsConfig.fromJson(const {
          'displayMode': ' EXPANSIBLE ',
        }).displayMode,
        'expansible',
      );
      expect(
        CategorySplitTabsConfig.fromJson(const {
          'displayMode': 'weird',
        }).displayMode,
        isNull,
      );
    });
  });
}
