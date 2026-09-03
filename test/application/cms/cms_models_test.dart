import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/cms/cms_models.dart';

void main() {
  group('CmsMediaRef.maybeFromJson', () {
    test('returns null for non-map input', () {
      expect(CmsMediaRef.maybeFromJson(null), isNull);
      expect(CmsMediaRef.maybeFromJson('string'), isNull);
      expect(CmsMediaRef.maybeFromJson(42), isNull);
    });

    test('returns null when any required field is missing', () {
      expect(
        CmsMediaRef.maybeFromJson({'recordId': 'r', 'collectionId': 'c'}),
        isNull,
      );
      expect(
        CmsMediaRef.maybeFromJson({'recordId': 'r', 'filename': 'f.jpg'}),
        isNull,
      );
      expect(
        CmsMediaRef.maybeFromJson({'collectionId': 'c', 'filename': 'f.jpg'}),
        isNull,
      );
    });

    test('returns null when fields are present but blank', () {
      expect(
        CmsMediaRef.maybeFromJson({
          'recordId': '',
          'collectionId': 'c',
          'filename': 'f.jpg',
        }),
        isNull,
      );
    });

    test('parses a complete payload', () {
      final ref = CmsMediaRef.maybeFromJson({
        'recordId': ' r1 ',
        'collectionId': ' medias ',
        'filename': ' hero.jpg ',
        'alt': ' alt text ',
      });
      expect(ref, isNotNull);
      expect(ref!.recordId, 'r1');
      expect(ref.collectionId, 'medias');
      expect(ref.filename, 'hero.jpg');
      expect(ref.alt, ' alt text ');
      expect(ref.isUsable, isTrue);
    });

    test('builds file and thumb URLs from fields', () {
      final ref = CmsMediaRef(
        recordId: 'r1',
        collectionId: 'medias',
        filename: 'hero.jpg',
      );
      expect(
        ref.fileUrl(baseUrl: 'https://example.test/'),
        'https://example.test/api/files/medias/r1/hero.jpg',
      );
      expect(
        ref.thumbUrl(baseUrl: 'https://example.test', size: '100x100'),
        'https://example.test/api/files/medias/r1/hero.jpg?thumb=100x100',
      );
    });

    test('encodes URI components for dangerous characters', () {
      final ref = CmsMediaRef(
        recordId: 'r1?&#',
        collectionId: 'medias/1',
        filename: 'hero 1.jpg',
      );
      expect(
        ref.fileUrl(baseUrl: 'https://example.test/'),
        'https://example.test/api/files/medias%2F1/r1%3F%26%23/hero%201.jpg',
      );
      expect(
        ref.thumbUrl(baseUrl: 'https://example.test', size: '100x100?'),
        'https://example.test/api/files/medias%2F1/r1%3F%26%23/hero%201.jpg?thumb=100x100%3F',
      );
    });
  });

  group('CmsCta.maybeFromJson', () {
    test('returns null when label or href is missing/blank', () {
      expect(CmsCta.maybeFromJson(null), isNull);
      expect(CmsCta.maybeFromJson({'label': 'Go'}), isNull);
      expect(CmsCta.maybeFromJson({'href': '/x'}), isNull);
      expect(CmsCta.maybeFromJson({'label': '', 'href': '/x'}), isNull);
    });

    test('parses internal CTA', () {
      final cta = CmsCta.maybeFromJson({
        'label': 'Découvrir',
        'href': '/catalog',
      });
      expect(cta, isNotNull);
      expect(cta!.isExternal, isFalse);
      expect(cta.isUsable, isTrue);
    });

    test('detects external CTA', () {
      final cta = CmsCta.maybeFromJson({
        'label': 'Site',
        'href': 'https://example.com',
      });
      expect(cta!.isExternal, isTrue);
    });
  });

  group('CategoryBannerItem.fromJson', () {
    test('parses a banner item with media and href', () {
      final item = CategoryBannerItem.fromJson({
        'title': 'Chaussures',
        'href': '/catalog',
        'media': {
          'recordId': 'r1',
          'collectionId': 'medias',
          'filename': 'shoe.jpg',
        },
        'backgroundTone': 'dark',
      });

      expect(item.title, 'Chaussures');
      expect(item.href, '/catalog');
      expect(item.media, isNotNull);
      expect(item.backgroundTone, 'dark');
    });

    test('falls back to default backgroundTone when missing', () {
      final item = CategoryBannerItem.fromJson({
        'title': 'Sport',
        'href': '/catalog',
      });
      expect(item.backgroundTone, 'dark');
    });

    test('parses custom gradient colors', () {
      final item = CategoryBannerItem.fromJson({
        'title': 'Sport',
        'href': '/catalog',
        'gradientStart': '#2A3038',
        'gradientEnd': '#5A6470',
      });
      expect(item.gradientStartHex, '#2A3038');
      expect(item.gradientEndHex, '#5A6470');
    });

    test('withAppearance overlays media and gradient, keeps identity', () {
      final item = CategoryBannerItem.fromJson({
        'title': 'Sport',
        'href': '/catalog',
        'categoryId': 'cat-1',
      });
      const appearance = CategoryBannerAppearance(
        media: CmsMediaRef(
          recordId: 'r1',
          collectionId: 'medias',
          filename: 'shoe.jpg',
        ),
        gradientStartHex: '#101418',
      );

      final styled = item.withAppearance(appearance);

      expect(styled.title, 'Sport');
      expect(styled.categoryId, 'cat-1');
      expect(styled.media?.filename, 'shoe.jpg');
      expect(styled.gradientStartHex, '#101418');
      expect(styled.gradientEndHex, isNull);
      expect(identical(item.withAppearance(null), item), isTrue);
    });
  });

  group('CategoryBannerStripConfig.fromJson', () {
    test('infers skeleton count from legacy banners payload', () {
      final config = CategoryBannerStripConfig.fromJson({
        'schemaVersion': 1,
        'banners': [
          {'title': 'Chaussures'},
          {'title': 'Vêtements'},
          {'title': 'Sport'},
        ],
      });

      expect(config.skeletonItemCount, 3);
    });

    test('uses explicit skeleton count over legacy banners', () {
      final config = CategoryBannerStripConfig.fromJson({
        'schemaVersion': 1,
        'skeletonItemCount': 2,
        'banners': [
          {'title': 'Chaussures'},
          {'title': 'Vêtements'},
          {'title': 'Sport'},
        ],
      });

      expect(config.skeletonItemCount, 2);
    });

    test('parses configured banner source without changing default source', () {
      final defaultConfig = CategoryBannerStripConfig.fromJson({
        'schemaVersion': 1,
        'banners': [
          {'title': 'Chaussures'},
        ],
      });
      expect(
        defaultConfig.sourceMode,
        CategoryBannerStripSourceMode.drawerRoots,
      );
      expect(defaultConfig.configuredBanners.single.title, 'Chaussures');

      final configured = CategoryBannerStripConfig.fromJson({
        'schemaVersion': 2,
        'sourceMode': 'configuredBanners',
        'banners': [
          {'title': 'Chaussures', 'href': '/catalog/shoes'},
          {'title': 'Vêtements', 'href': '/catalog/clothing'},
        ],
      });

      expect(
        configured.sourceMode,
        CategoryBannerStripSourceMode.configuredBanners,
      );
      expect(configured.skeletonItemCount, 2);
      expect(configured.configuredBanners.map((item) => item.title), [
        'Chaussures',
        'Vêtements',
      ]);
    });

    test('parses bannerAppearance overrides keyed by entry id', () {
      final config = CategoryBannerStripConfig.fromJson({
        'schemaVersion': 1,
        'bannerAppearance': {
          'nav-1': {
            'media': {
              'recordId': 'r1',
              'collectionId': 'medias',
              'filename': 'shoe.jpg',
            },
            'gradientStart': '#2A3038',
            'gradientEnd': '#5A6470',
          },
          'nav-2': {'gradientStart': '#EDEAE3'},
          'nav-empty': <String, dynamic>{},
          '': {'gradientStart': '#000000'},
        },
      });

      expect(config.bannerAppearance.keys, ['nav-1', 'nav-2']);
      expect(config.bannerAppearance['nav-1']?.media?.filename, 'shoe.jpg');
      expect(config.bannerAppearance['nav-1']?.gradientEndHex, '#5A6470');
      expect(config.bannerAppearance['nav-2']?.gradientStartHex, '#EDEAE3');
      expect(config.bannerAppearance['nav-2']?.media, isNull);
    });

    test('parses the shared background media for the visible banner stack', () {
      final config = CategoryBannerStripConfig.fromJson({
        'schemaVersion': 1,
        'sharedBackgroundMedia': {
          'recordId': 'group-1',
          'collectionId': 'medias',
          'filename': 'nike-team.jpg',
          'alt': 'Groupe Nike',
        },
      });

      expect(config.sharedBackgroundMedia?.recordId, 'group-1');
      expect(config.sharedBackgroundMedia?.filename, 'nike-team.jpg');
      expect(config.sharedBackgroundMedia?.alt, 'Groupe Nike');
    });
  });

  group('HeroCampaignConfig.fromJson', () {
    test('applies defaults on minimal payload', () {
      final c = HeroCampaignConfig.fromJson({'title': 'Hello'});
      expect(c.title, 'Hello');
      expect(c.eyebrow, isNull);
      expect(c.subtitle, isNull);
      expect(c.body, isNull);
      expect(c.primaryCta, isNull);
      expect(c.mediaDesktop, isNull);
      expect(c.mediaMobile, isNull);
      expect(c.mediaType, 'image');
      expect(c.textAlign, 'center');
      expect(c.heightMode, 'xl');
    });

    test(
      'treats blank or missing title as empty (renderer fallback responsibility)',
      () {
        final c = HeroCampaignConfig.fromJson({});
        expect(c.title, '');
      },
    );

    test('parses a complete payload', () {
      final c = HeroCampaignConfig.fromJson({
        'eyebrow': 'FEMME',
        'title': 'PE 2026',
        'subtitle': 'Spring',
        'body': 'Body copy',
        'primaryCta': {'label': 'CTA', 'href': '/x'},
        'mediaDesktop': {
          'recordId': 'r1',
          'collectionId': 'medias',
          'filename': 'd.jpg',
        },
        'mediaMobile': {
          'recordId': 'r2',
          'collectionId': 'medias',
          'filename': 'm.jpg',
        },
        'mediaType': 'video',
        'textAlign': 'left',
        'heightMode': 'lg',
      });
      expect(c.eyebrow, 'FEMME');
      expect(c.subtitle, 'Spring');
      expect(c.body, 'Body copy');
      expect(c.primaryCta?.label, 'CTA');
      expect(c.mediaDesktop?.recordId, 'r1');
      expect(c.mediaMobile?.recordId, 'r2');
      expect(c.mediaType, 'video');
      expect(c.textAlign, 'left');
      expect(c.heightMode, 'lg');
    });
  });

  group('CategoryTilesConfig.fromJson', () {
    test('clamps columns into [1, 6]', () {
      final c = CategoryTilesConfig.fromJson({
        'columnsMobile': 0,
        'columnsDesktop': 99,
        'tiles': [],
      });
      expect(c.columnsMobile, 1);
      expect(c.columnsDesktop, 6);
    });

    test('drops tiles missing label or href', () {
      final c = CategoryTilesConfig.fromJson({
        'tiles': [
          {'label': 'Sacs', 'href': '/bags'},
          {'label': '', 'href': '/x'},
          {'label': 'Other', 'href': ''},
          'not a map',
          42,
        ],
      });
      expect(c.tiles, hasLength(1));
      expect(c.tiles.single.label, 'Sacs');
    });
  });

  group('FeaturedProductsConfig.fromJson', () {
    test('drops blank and non-string product ids', () {
      final c = FeaturedProductsConfig.fromJson({
        'productIds': ['p1', '', null, 'p2', 42],
      });
      expect(c.productIds, ['p1', 'p2', '42']);
    });

    test('defaults layout and showPrices', () {
      final c = FeaturedProductsConfig.fromJson({});
      expect(c.layout, 'grid4');
      expect(c.showPrices, isTrue);
      expect(c.productIds, isEmpty);
    });
  });

  group('ServiceCardsConfig.fromJson', () {
    test('drops cards without title or href', () {
      final c = ServiceCardsConfig.fromJson({
        'cards': [
          {'title': 'OK', 'href': '/a'},
          {'title': '', 'href': '/b'},
          {'title': 'Bad', 'href': ''},
          'noise',
        ],
      });
      expect(c.cards, hasLength(1));
      expect(c.cards.single.title, 'OK');
    });
  });

  group('MixedProductGridConfig.fromJson', () {
    test('parses schema version and V1 merchandising fields', () {
      final c = MixedProductGridConfig.fromJson({
        'schemaVersion': 1,
        'source': {'type': 'routeCategory', 'limit': 48, 'sort': 'manual'},
        'columnsMobile': 2,
        'columnsTablet': 3,
        'columnsDesktop': 4,
        'toolbar': {'defaultSort': 'newest'},
        'productCard': {'showWishlist': false},
        'pinnedProducts': [
          {'productId': 'p1', 'slotPosition': 0},
        ],
        'excludedProductIds': ['p9'],
        'inserts': [
          {
            'type': 'category_tile',
            'slotPosition': 2,
            'displaySize': 'small',
            'title': 'Accessoires',
            'href': '/catalog/accessoires',
          },
          {'type': 'unknown_tile', 'slotPosition': 3},
        ],
      });

      expect(c.schemaVersion, 1);
      expect(c.source.type, 'routeCategory');
      expect(c.source.limit, 48);
      expect(c.toolbar.defaultSort, 'newest');
      expect(c.productCard.showWishlist, isFalse);
      expect(c.pinnedProducts.single.productId, 'p1');
      expect(c.excludedProductIds, ['p9']);
      expect(c.inserts.first, isA<CategoryTileInsert>());
      expect(c.inserts.last, isA<UnknownGridInsert>());
    });

    test('applies safe defaults on partial payload', () {
      final c = MixedProductGridConfig.fromJson({});
      expect(c.schemaVersion, 1);
      expect(c.source.type, 'routeCategory');
      expect(c.columnsMobile, 2);
      expect(c.columnsTablet, 3);
      expect(c.columnsDesktop, 4);
      expect(c.toolbar.showFilter, isFalse);
      expect(c.inserts, isEmpty);
    });
  });

  group('parseCmsSection', () {
    CmsSectionRecord makeRecord(
      String type, {
      Map<String, dynamic> config = const {},
      String id = 's1',
    }) {
      return CmsSectionRecord(
        id: id,
        pageId: 'p1',
        sectionId: id,
        sectionType: CmsSectionType.fromWireName(type),
        rawSectionType: type,
        position: 0,
        isActive: true,
        config: config,
      );
    }

    test('returns the matching typed section for each known type', () {
      expect(
        parseCmsSection(makeRecord('hero_campaign', config: {'title': 't'})),
        isA<CmsHeroSection>(),
      );
      expect(
        parseCmsSection(makeRecord('editorial_story', config: {'title': 't'})),
        isA<CmsEditorialSection>(),
      );
      expect(
        parseCmsSection(makeRecord('category_tiles')),
        isA<CmsCategoryTilesSection>(),
      );
      expect(
        parseCmsSection(makeRecord('featured_products')),
        isA<CmsFeaturedProductsSection>(),
      );
      expect(
        parseCmsSection(makeRecord('service_cards')),
        isA<CmsServiceCardsSection>(),
      );
    });

    test('returns CmsUnknownSection for unsupported types', () {
      final out = parseCmsSection(makeRecord('not_a_real_type'));
      expect(out, isA<CmsUnknownSection>());
    });

    test('every CmsSectionType has a renderer-eligible parse path', () {
      for (final type in CmsSectionType.values) {
        final out = parseCmsSection(makeRecord(type.wireName));
        expect(
          out,
          isNot(isA<CmsUnknownSection>()),
          reason: 'Section type ${type.wireName} must parse to a typed config',
        );
      }
    });
  });

  group('CmsSectionRecord.fromJson', () {
    test('reads page relation as string id', () {
      final r = CmsSectionRecord.fromJson({
        'id': 'sec1',
        'page': 'p1',
        'sectionId': 'hero',
        'sectionType': 'hero_campaign',
        'position': 0,
        'isActive': true,
        'config': {'title': 'X'},
      });
      expect(r.pageId, 'p1');
      expect(r.sectionType, CmsSectionType.heroCampaign);
    });

    test('reads page relation as a list of ids (PocketBase quirk)', () {
      final r = CmsSectionRecord.fromJson({
        'id': 'sec1',
        'page': ['p1'],
        'sectionId': 'hero',
        'sectionType': 'hero_campaign',
        'position': 0,
        'isActive': true,
        'config': {},
      });
      expect(r.pageId, 'p1');
    });

    test('falls back to empty config map when payload is malformed', () {
      final r = CmsSectionRecord.fromJson({
        'id': 'sec1',
        'page': 'p1',
        'sectionId': 'hero',
        'sectionType': 'hero_campaign',
        'config': 'not a map',
      });
      expect(r.config, isEmpty);
    });
  });

  group('HorizontalTileCarouselConfig.fromJson', () {
    test('defaults to the tiles layout, schema 1, no title, no items', () {
      final config = HorizontalTileCarouselConfig.fromJson({});
      expect(config.layout, 'tiles');
      expect(config.schemaVersion, 1);
      expect(config.title, isNull);
      expect(config.items, isEmpty);
    });

    test('parses the feature layout (case-insensitive, trimmed)', () {
      for (final raw in ['feature', 'FEATURE', '  Feature  ']) {
        expect(
          HorizontalTileCarouselConfig.fromJson({'layout': raw}).layout,
          'feature',
          reason: 'layout=$raw',
        );
      }
    });

    test('falls back to tiles for any non-feature layout', () {
      // The gotcha behind ADR-003: only an explicit 'feature' renders the big
      // cards; everything else (unknown values, blanks) resolves to 'tiles'.
      for (final raw in ['tiles', 'grid', '', 'features', 'feaure']) {
        expect(
          HorizontalTileCarouselConfig.fromJson({'layout': raw}).layout,
          'tiles',
          reason: 'layout=$raw',
        );
      }
    });

    test('drops items whose label is missing or blank', () {
      final config = HorizontalTileCarouselConfig.fromJson({
        'items': [
          {'label': 'Summer', 'href': '/summer'},
          {'label': '   ', 'href': '/blank'},
          {'href': '/no-label'},
        ],
      });
      expect(config.items, hasLength(1));
      expect(config.items.single.label, 'Summer');
      expect(config.items.single.href, '/summer');
    });

    test('ignores non-map entries in items', () {
      final config = HorizontalTileCarouselConfig.fromJson({
        'items': [
          'not a map',
          42,
          {'label': 'Real', 'href': '/real'},
        ],
      });
      expect(config.items.map((i) => i.label).toList(), ['Real']);
    });

    test('trims item label and href', () {
      final config = HorizontalTileCarouselConfig.fromJson({
        'items': [
          {'label': '  Spaced  ', 'href': '  /x  '},
        ],
      });
      final item = config.items.single;
      expect(item.label, 'Spaced');
      expect(item.href, '/x');
    });
  });
}
