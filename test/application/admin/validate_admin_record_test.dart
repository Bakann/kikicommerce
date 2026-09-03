import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/validate_admin_record.dart';

void main() {
  group('validateNarrativeChapterDraft', () {
    test('returns null when product or media are missing', () {
      expect(
        validateNarrativeChapterDraft(data: const {}, relationData: const {}),
        isNull,
      );
      expect(
        validateNarrativeChapterDraft(
          data: const {'product': 'p1'},
          relationData: const {},
        ),
        isNull,
      );
      expect(
        validateNarrativeChapterDraft(
          data: const {'product': 'p1', 'media': ''},
          relationData: const {},
        ),
        isNull,
      );
    });

    test('returns null when product is not in the catalog', () {
      expect(
        validateNarrativeChapterDraft(
          data: const {'product': 'p1', 'media': 'm1'},
          relationData: const {'products': []},
        ),
        isNull,
      );
    });

    test('accepts media matching product.picture', () {
      final result = validateNarrativeChapterDraft(
        data: const {'product': 'p1', 'media': 'm1'},
        relationData: const {
          'products': [
            {'id': 'p1', 'picture': 'm1', 'galleryImages': <String>[]},
          ],
          'mediaContainers': [],
        },
      );
      expect(result, isNull);
    });

    test('accepts media reachable through a gallery container', () {
      final result = validateNarrativeChapterDraft(
        data: const {'product': 'p1', 'media': 'm2'},
        relationData: const {
          'products': [
            {
              'id': 'p1',
              'galleryImages': ['container-1'],
            },
          ],
          'mediaContainers': [
            {
              'id': 'container-1',
              'medias': ['m1', 'm2'],
            },
          ],
        },
      );
      expect(result, isNull);
    });

    test('falls back to product.thumbnail when no other media is allowed', () {
      final result = validateNarrativeChapterDraft(
        data: const {'product': 'p1', 'media': 'thumb'},
        relationData: const {
          'products': [
            {'id': 'p1', 'thumbnail': 'thumb', 'galleryImages': <String>[]},
          ],
          'mediaContainers': [],
        },
      );
      expect(result, isNull);
    });

    test('rejects media that is not visible to the product', () {
      final result = validateNarrativeChapterDraft(
        data: const {'product': 'p1', 'media': 'other'},
        relationData: const {
          'products': [
            {
              'id': 'p1',
              'picture': 'm1',
              'galleryImages': ['container-1'],
            },
          ],
          'mediaContainers': [
            {
              'id': 'container-1',
              'medias': ['m2'],
            },
          ],
        },
      );
      expect(result, isNotNull);
      expect(result, contains('galerie visible'));
    });
  });
}
