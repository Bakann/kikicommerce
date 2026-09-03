import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/navigation/drawer_navigation_models.dart';

void main() {
  group('DrawerNavigationItemData.fromJson', () {
    test('encodes URI components for dangerous characters in media URLs', () {
      final data = DrawerNavigationItemData.fromJson({
        'id': 'item-1',
        'menu': 'menu-1',
        'position': 10,
        'label': 'Test Item',
        'itemType': 'page',
        'placement': 'nav',
        'isActive': true,
        'isHidden': false,
        'expand': {
          'promoMedia': {
            'id': 'm1?&#',
            'collectionId': 'medias/1',
            'file': 'hero 1.jpg',
            'originalFile': 'hero 1_original.jpg',
          },
        },
      }, baseUrl: 'https://example.test');

      expect(data.promoMedia, isNotNull);
      expect(
        data.promoMedia!.url,
        'https://example.test/api/files/medias%2F1/m1%3F%26%23/hero%201.jpg',
      );
      expect(
        data.promoMedia!.originalUrl,
        'https://example.test/api/files/medias%2F1/m1%3F%26%23/hero%201_original.jpg',
      );
      expect(
        data.promoMedia!.previewUrl,
        'https://example.test/api/files/medias%2F1/m1%3F%26%23/hero%201.jpg?thumb=600x600',
      );
    });

    test('adds cache-busting version to public promo media URLs', () {
      final data = DrawerNavigationItemData.fromJson({
        'id': 'item-1',
        'menu': 'menu-1',
        'position': 10,
        'label': 'Test Item',
        'itemType': 'page',
        'placement': 'promo',
        'isActive': true,
        'isHidden': false,
        'expand': {
          'promoMedia': {
            'id': 'm1',
            'collectionId': 'medias',
            'file': 'hero.jpg',
            'updated': '2026-05-07T12:00:00.000Z',
          },
        },
      }, baseUrl: 'https://kikicommerce.com/img');

      expect(
        data.promoMedia!.url,
        'https://kikicommerce.com/img/api/files/medias/m1/hero.jpg?v=1778155200000',
      );
      expect(
        data.promoMedia!.previewUrl,
        'https://kikicommerce.com/img/api/files/medias/m1/hero.jpg?thumb=600x600&v=1778155200000',
      );
    });
  });
}
