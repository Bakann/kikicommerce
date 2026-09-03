import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/catalog/media_asset.dart';

void main() {
  group('MediaAsset URLs encoding', () {
    test('encodes URI components for dangerous characters in media URLs', () {
      final media = MediaAsset.fromJson({
        'id': 'm1?&#',
        'collectionId': 'medias/1',
        'file': 'hero 1.jpg',
        'originalFile': 'hero 1_original.jpg',
      }, baseUrl: 'https://example.test');

      expect(
        media.fileUrl,
        'https://example.test/api/files/medias%2F1/m1%3F%26%23/hero%201.jpg',
      );
      expect(
        media.originalFileUrl,
        'https://example.test/api/files/medias%2F1/m1%3F%26%23/hero%201_original.jpg',
      );
      expect(
        media.thumbUrl(size: '100x100?'),
        'https://example.test/api/files/medias%2F1/m1%3F%26%23/hero%201.jpg?thumb=100x100%3F',
      );
    });

    test('adds an updated timestamp as cache-busting version', () {
      final media = MediaAsset.fromJson({
        'id': 'm1',
        'collectionId': 'medias',
        'file': 'hero.jpg',
        'updated': '2026-05-07T12:00:00.000Z',
      }, baseUrl: 'https://kikicommerce.com/img');

      expect(media.version, '1778155200000');
      expect(
        media.fileUrl,
        'https://kikicommerce.com/img/api/files/medias/m1/hero.jpg?v=1778155200000',
      );
      expect(
        media.thumbUrl(size: '600x800f'),
        'https://kikicommerce.com/img/api/files/medias/m1/hero.jpg?thumb=600x800f&v=1778155200000',
      );
    });

    test('omits cache-busting version when updated is absent', () {
      final media = MediaAsset.fromJson({
        'id': 'm1',
        'collectionId': 'medias',
        'file': 'hero.jpg',
      }, baseUrl: 'https://kikicommerce.com/img');

      expect(media.version, isNull);
      expect(
        media.fileUrl,
        'https://kikicommerce.com/img/api/files/medias/m1/hero.jpg',
      );
      expect(media.thumbUrl(size: '600x800f'), isNot(contains('v=')));
    });

    test('keeps the default PocketBase media origin without dart-defines', () {
      final media = MediaAsset.fromJson({
        'id': 'm1',
        'collectionId': 'medias',
        'file': 'hero.jpg',
      });

      expect(
        media.fileUrl,
        'https://kiki-commerce.pockethost.io/api/files/medias/m1/hero.jpg',
      );
    });
  });
}
