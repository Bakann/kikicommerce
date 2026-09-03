import '../../../application/cms/cms_models.dart';

/// Sensible default config payloads for a freshly added section. Used by the
/// add-section flow as a starting point before the admin tweaks the JSON.
Map<String, dynamic> defaultConfigFor(CmsSectionType type) {
  switch (type) {
    case CmsSectionType.heroCampaign:
      return {
        'eyebrow': null,
        'title': 'Nouveau hero',
        'subtitle': null,
        'body': null,
        'primaryCta': {'label': 'Découvrir', 'href': '/catalog'},
        'mediaDesktop': null,
        'mediaMobile': null,
        'mediaType': 'image',
        'textAlign': 'center',
        'heightMode': 'xl',
      };
    case CmsSectionType.editorialStory:
      return {
        'eyebrow': null,
        'title': 'Nouvelle histoire',
        'body': null,
        'primaryCta': null,
        'mediaDesktop': null,
        'mediaMobile': null,
        'mediaType': 'image',
        'layoutVariant': 'mediaLeft',
        'backgroundTone': 'light',
      };
    case CmsSectionType.categoryTiles:
      return {
        'title': null,
        'subtitle': null,
        'columnsMobile': 2,
        'columnsDesktop': 4,
        'tiles': <Map<String, dynamic>>[],
      };
    case CmsSectionType.featuredProducts:
      return {
        'eyebrow': null,
        'title': null,
        'subtitle': null,
        'primaryCta': null,
        'productIds': <String>[],
        'layout': 'grid4',
        'showPrices': true,
      };
    case CmsSectionType.serviceCards:
      return {'title': null, 'cards': <Map<String, dynamic>>[]};
    case CmsSectionType.collectionHero:
      return {
        'schemaVersion': 1,
        'title': 'Nouvelle collection',
        'intro': 'Présentez la sélection et son intention.',
        'imageMobile': null,
        'imageDesktop': null,
        'mobileLayout': 'imageTop',
        'desktopLayout': 'split',
        'aspectRatio': '4/5',
      };
    case CmsSectionType.editorialIntro:
      return {
        'schemaVersion': 1,
        'eyebrow': 'Sélection',
        'title': 'Une sélection à découvrir',
        'body': 'Ajoutez un court texte éditorial.',
        'mobileLayout': 'textOnly',
        'desktopLayout': 'centered',
      };
    case CmsSectionType.mixedProductGrid:
      return {
        'schemaVersion': 1,
        'source': {'type': 'routeCategory', 'limit': 48, 'sort': 'manual'},
        'columnsMobile': 2,
        'columnsTablet': 3,
        'columnsDesktop': 4,
        'aspectRatio': '0.64',
        'toolbar': {
          'enabled': true,
          'stickyToolbar': true,
          'showSort': true,
          'showFilter': false,
          'defaultSort': 'manual',
          'sortOptions': ['manual', 'newest', 'price_asc', 'price_desc'],
        },
        'productCard': {
          'showWishlist': true,
          'showSummary': true,
          'showBadges': true,
          'showQuickAdd': true,
          'showPrices': true,
        },
        'pinnedProducts': <Map<String, dynamic>>[],
        'excludedProductIds': <String>[],
        'inserts': <Map<String, dynamic>>[],
      };
    case CmsSectionType.seoText:
      return {
        'schemaVersion': 1,
        'title': 'Texte éditorial',
        'body': 'Ajoutez un texte visible en bas de page.',
        'mobileLayout': 'collapsed',
        'desktopLayout': 'expanded',
      };
    case CmsSectionType.discoverLinks:
      return {
        'schemaVersion': 1,
        'title': 'Découvrir aussi',
        'columnsMobile': 1,
        'columnsDesktop': 4,
        'links': <Map<String, dynamic>>[],
      };
    case CmsSectionType.horizontalTileCarousel:
      return {
        'schemaVersion': 1,
        'title': 'En ce moment',
        'layout': 'tiles',
        'items': <Map<String, dynamic>>[],
      };
    case CmsSectionType.brandSegment:
      return {
        'schemaVersion': 1,
        'mode': 'themeSwitcher',
        'activeIndex': 0,
        'items': <Map<String, dynamic>>[
          {'label': 'Sport', 'theme': 'nike'},
          {'label': 'Luxe', 'theme': 'dior'},
        ],
      };
    case CmsSectionType.categorySplitTabs:
      return {
        'schemaVersion': 1,
        'defaultActiveIndex': 0,
        'items': <Map<String, dynamic>>[],
      };
    case CmsSectionType.categoryBannerStrip:
      return {
        'schemaVersion': 1,
        // The Nike banner strip was designed as a 3-row stack
        // (Chaussures / Vêtements / Sport). The live drawer may later resolve
        // fewer items, but this keeps the first-load skeleton aligned with the
        // intended section footprint unless admins override it.
        'skeletonItemCount': defaultCategoryBannerStripSkeletonItemCount,
      };
  }
}

/// Human-readable label for the section type, used in pickers/dialogs.
String sectionTypeLabel(CmsSectionType type) {
  switch (type) {
    case CmsSectionType.heroCampaign:
      return 'Hero campagne';
    case CmsSectionType.editorialStory:
      return 'Histoire éditoriale';
    case CmsSectionType.categoryTiles:
      return 'Grille de catégories';
    case CmsSectionType.featuredProducts:
      return 'Produits mis en avant';
    case CmsSectionType.serviceCards:
      return 'Cartes services';
    case CmsSectionType.collectionHero:
      return 'Hero collection';
    case CmsSectionType.editorialIntro:
      return 'Intro éditoriale';
    case CmsSectionType.mixedProductGrid:
      return 'Grille produits enrichie';
    case CmsSectionType.seoText:
      return 'Texte SEO';
    case CmsSectionType.discoverLinks:
      return 'Liens découverte';
    case CmsSectionType.horizontalTileCarousel:
      return 'Carrousel tuiles (Nike)';
    case CmsSectionType.brandSegment:
      return 'Segment de marque (Nike)';
    case CmsSectionType.categorySplitTabs:
      return 'Tabs catégories (Nike)';
    case CmsSectionType.categoryBannerStrip:
      return 'Bandeaux catégories (Nike)';
  }
}
