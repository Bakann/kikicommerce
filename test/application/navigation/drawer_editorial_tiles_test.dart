import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/navigation/drawer_editorial_tiles.dart';

void main() {
  group('DrawerEditorialTilesConfig', () {
    test('treats missing and malformed config as empty', () {
      expect(DrawerEditorialTilesConfig.fromJson(null).activeTiles, isEmpty);
      expect(
        DrawerEditorialTilesConfig.fromJson('invalid').activeTiles,
        isEmpty,
      );
    });

    test('filters inactive and invalid tiles while keeping valid ones', () {
      final config = DrawerEditorialTilesConfig.fromJson({
        'items': [
          {
            'title': 'Sacs femme',
            'link': '/sacs-femme',
            'media': {
              'recordId': 'media-1',
              'collectionId': 'medias',
              'filename': 'sacs.webp',
            },
          },
          {'title': 'Sans media', 'link': '/missing-media', 'media': null},
          {
            'title': 'Inactive',
            'link': '/inactive',
            'isActive': false,
            'media': {
              'recordId': 'media-2',
              'collectionId': 'medias',
              'filename': 'inactive.webp',
            },
          },
        ],
      });

      expect(config.activeTiles, hasLength(1));
      expect(config.activeTiles.first.title, 'Sacs femme');
      expect(config.activeTiles.first.media.alt, isNull);
    });

    test('detects external links from URL scheme', () {
      final config = DrawerEditorialTilesConfig.fromJson({
        'items': [
          {
            'title': 'External',
            'link': 'https://example.com',
            'media': {
              'recordId': 'media-1',
              'collectionId': 'medias',
              'filename': 'external.webp',
            },
          },
        ],
      });

      expect(config.activeTiles.single.isExternalLink, isTrue);
    });
  });

  group('resolveDrawerEditorialTilesLayout', () {
    test('maps auto counts to expected layouts', () {
      const layout = DrawerEditorialTilesLayout();

      expect(
        resolveDrawerEditorialTilesLayout(1, layout),
        DrawerEditorialTilesResolvedLayout.single,
      );
      expect(
        resolveDrawerEditorialTilesLayout(2, layout),
        DrawerEditorialTilesResolvedLayout.stacked,
      );
      expect(
        resolveDrawerEditorialTilesLayout(4, layout),
        DrawerEditorialTilesResolvedLayout.grid2x2,
      );
      expect(
        resolveDrawerEditorialTilesLayout(3, layout),
        DrawerEditorialTilesResolvedLayout.adaptive,
      );
    });

    test('forced layout wins over item count', () {
      const layout = DrawerEditorialTilesLayout(
        forced: DrawerEditorialTilesResolvedLayout.grid2x2,
      );

      expect(
        resolveDrawerEditorialTilesLayout(1, layout),
        DrawerEditorialTilesResolvedLayout.grid2x2,
      );
    });
  });

  test('drawerEditorialMediaMap defaults empty alt from title', () {
    final config = DrawerEditorialTilesConfig.fromJson({
      'items': [
        {
          'title': 'Sacs femme',
          'link': '/sacs-femme',
          'media': {
            'recordId': 'media-1',
            'collectionId': 'medias',
            'filename': 'sacs.webp',
            'alt': '',
          },
        },
      ],
    });

    final map = drawerEditorialMediaMap(
      config.activeTiles.single.media,
      fallbackAlt: config.activeTiles.single.title,
    );

    expect(map?['alt'], 'Sacs femme');
  });
}
