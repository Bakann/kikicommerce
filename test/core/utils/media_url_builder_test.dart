import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/core/utils/media_url_builder.dart';

void main() {
  group('MediaUrlBuilder', () {
    test('builds a file URL without version', () {
      expect(
        MediaUrlBuilder.fileUrl(
          collectionId: 'medias',
          recordId: 'abc',
          filename: 'hero.jpg',
          baseUrl: 'https://kiki-commerce.pockethost.io',
        ),
        'https://kiki-commerce.pockethost.io/api/files/medias/abc/hero.jpg',
      );
    });

    test('builds a file URL against a distinct media base URL', () {
      expect(
        MediaUrlBuilder.fileUrl(
          collectionId: 'medias',
          recordId: 'abc',
          filename: 'robe rouge.webp',
          version: '1778155200000',
          baseUrl: 'https://kikicommerce.com/img',
        ),
        'https://kikicommerce.com/img/api/files/medias/abc/robe%20rouge.webp?v=1778155200000',
      );
    });

    test('builds a thumb URL with thumb and version', () {
      expect(
        MediaUrlBuilder.thumbUrl(
          collectionId: 'medias',
          recordId: 'abc',
          filename: 'hero.jpg',
          size: '600x800f',
          version: '1778155200000',
          baseUrl: 'https://kikicommerce.com/img',
        ),
        'https://kikicommerce.com/img/api/files/medias/abc/hero.jpg?thumb=600x800f&v=1778155200000',
      );
    });

    test('normalizes trailing slashes in base URLs', () {
      expect(
        MediaUrlBuilder.fileUrl(
          collectionId: 'medias',
          recordId: 'abc',
          filename: 'hero.jpg',
          baseUrl: 'https://kikicommerce.com/img/',
        ),
        'https://kikicommerce.com/img/api/files/medias/abc/hero.jpg',
      );
    });

    test('omits v when the version is absent', () {
      expect(
        MediaUrlBuilder.thumbUrl(
          collectionId: 'medias',
          recordId: 'abc',
          filename: 'hero.jpg',
          size: '600x800f',
          baseUrl: 'https://kikicommerce.com/img',
        ),
        'https://kikicommerce.com/img/api/files/medias/abc/hero.jpg?thumb=600x800f',
      );
    });

    test('different thumb sizes produce different URLs', () {
      final first = MediaUrlBuilder.thumbUrl(
        collectionId: 'medias',
        recordId: 'abc',
        filename: 'hero.jpg',
        size: '600x800f',
        baseUrl: 'https://kikicommerce.com/img',
      );
      final second = MediaUrlBuilder.thumbUrl(
        collectionId: 'medias',
        recordId: 'abc',
        filename: 'hero.jpg',
        size: '1280x1720f',
        baseUrl: 'https://kikicommerce.com/img',
      );

      expect(first, isNot(second));
      expect(first, contains('thumb=600x800f'));
      expect(second, contains('thumb=1280x1720f'));
    });
  });
}
