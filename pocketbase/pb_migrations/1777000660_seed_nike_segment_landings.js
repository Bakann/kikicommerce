/// <reference path="../pb_data/types.d.ts" />

// Adds CMS-backed Sport segment landings for Femme and Enfant, and aligns the
// canonical Homme page so the Homme/Femme/Enfant tabs are landing variants
// instead of category links.
//
// Media slots intentionally fall back to the existing Nike placeholder. When
// segment-specific PocketBase media records are available, fill
// SEGMENT_MEDIA_IDS below; no renderer or CMS schema change is needed.

const PLACEHOLDER_MEDIA_ID = 'q9v4i6qj5iax0wh';

const SEGMENT_MEDIA_IDS = {
  homme: {},
  femme: {},
  enfant: {},
};

const TAB_ITEMS = [
  { label: 'Homme', href: '/sport/homme', segment: 'homme' },
  { label: 'Femme', href: '/sport/femme', segment: 'femme' },
  { label: 'Enfant', href: '/sport/enfant', segment: 'enfant' },
];

const SEGMENTS = [
  {
    key: 'femme',
    code: 'homepage_nike_femme',
    title: 'Boutique Sport Femme',
    pageTitle: 'Boutique Femme',
    activeIndex: 1,
    momentItems: [
      'Sélection NikeSKIMS Studio pour l’été',
      "Articles d'été",
      'Look de festival',
      'Running léger',
    ],
    banners: ['Chaussures', 'Vêtements', 'Accessoires'],
    adventureTitle: 'Pensé pour elle',
    adventureItems: ['Training', 'Running', 'Tennis', 'Yoga'],
    editorial: {
      eyebrow: 'FEMME',
      title: 'Bouger librement tout l’été',
      body:
        'Des silhouettes respirantes, des matières légères et des essentiels Sport pensés pour accompagner chaque rythme.',
    },
    featuredTitle: 'Dernières sorties Femme',
    featuredProducts: [
      'Nike Vomero 18 Femme',
      'NikeSKIMS Airy Short',
      'Nike Zenvy Legging',
      'Nike Motiva Femme',
    ],
  },
  {
    key: 'enfant',
    code: 'homepage_nike_enfant',
    title: 'Boutique Sport Enfant',
    pageTitle: 'Boutique Enfant',
    activeIndex: 2,
    momentItems: [
      "Articles d'été",
      'Nos basiques préférés',
      'Nike Football Academy',
      'Rentrée sportive',
    ],
    banners: ['Chaussures', 'Vêtements', 'Sport'],
    adventureTitle: 'Pour toutes leurs aventures',
    adventureItems: ['École', 'Football', 'Running', 'Lifestyle'],
    editorial: {
      eyebrow: 'ENFANT',
      title: 'Prêt pour jouer plus longtemps',
      body:
        'Des chaussures souples, des tenues résistantes et des essentiels faciles à porter du terrain à la cour.',
    },
    featuredTitle: 'Dernières sorties Enfant',
    featuredProducts: [
      'Nike Air Max Enfant',
      'Nike Club Fleece Junior',
      'Nike Flex Runner',
      'Nike Brasilia Mini',
    ],
  },
];

function log(message) {
  console.log(`[1777000660] ${message}`);
}

function hasField(collection, fieldName) {
  try {
    return !!collection.fields.getByName(fieldName);
  } catch (_) {
    return false;
  }
}

function asConfigObject(value) {
  if (!value) return {};
  try {
    if (typeof value === 'string') {
      const parsed = JSON.parse(value);
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
        ? parsed
        : {};
    }
    const cloned = JSON.parse(JSON.stringify(value));
    return cloned && typeof cloned === 'object' && !Array.isArray(cloned)
      ? cloned
      : {};
  } catch (_) {
    return {};
  }
}

function requiredConfig(value, fallback) {
  const config = asConfigObject(value);
  if (Object.keys(config).length > 0) return config;
  const fallbackConfig = asConfigObject(fallback);
  return Object.keys(fallbackConfig).length > 0
    ? fallbackConfig
    : { schemaVersion: 1 };
}

function setRequiredConfig(record, config, fallback) {
  record.set('config', requiredConfig(config, fallback));
}

function saveRecord(app, record, context) {
  try {
    app.save(record);
  } catch (error) {
    log(`failed to save ${context}: ${error}`);
    throw error;
  }
}

function findPageOrNull(app, pagesCollectionId, code) {
  try {
    return app.findFirstRecordByFilter(
      pagesCollectionId,
      `code = "${code}" && locale = "fr"`,
    );
  } catch (_) {
    return null;
  }
}

function ensurePage(app, pagesCollection, spec) {
  let page = findPageOrNull(app, pagesCollection.id, spec.code);
  if (page) return page;

  page = new Record(pagesCollection);
  page.set('code', spec.code);
  page.set('locale', 'fr');
  page.set('title', spec.title);
  page.set('isActive', true);
  if (hasField(pagesCollection, 'pageType')) {
    page.set('pageType', 'home');
  }
  if (hasField(pagesCollection, 'config')) {
    page.set('config', { schemaVersion: 1 });
  }
  saveRecord(app, page, `page ${spec.code}`);
  return page;
}

function findExistingSectionsBySectionId(app, sectionsCollectionId, pageId) {
  let records = [];
  try {
    records = app.findRecordsByFilter(
      sectionsCollectionId,
      `page = "${pageId}"`,
      '+position',
      200,
      0,
    );
  } catch (_) {
    return new Map();
  }
  const bySectionId = new Map();
  for (const record of records) {
    bySectionId.set(record.getString('sectionId'), record);
  }
  return bySectionId;
}

function resolveMedia(app, mediasCollection, recordId, alt) {
  if (!recordId) return null;
  try {
    const record = app.findRecordById(mediasCollection.id, recordId);
    const filename = record.getString('file');
    if (!filename) return null;
    return {
      recordId: recordId,
      collectionId: mediasCollection.id,
      filename: filename,
      alt: alt,
    };
  } catch (_) {
    return null;
  }
}

function createMediaResolver(app) {
  let mediasCollection = null;
  try {
    mediasCollection = app.findCollectionByNameOrId('medias');
  } catch (_) {
    mediasCollection = null;
  }

  const cache = new Map();
  return (segment, slot, fallbackAlt) => {
    if (!mediasCollection) return null;
    const slotIds = SEGMENT_MEDIA_IDS[segment] || {};
    const id = slotIds[slot] || slotIds.default || PLACEHOLDER_MEDIA_ID;
    const cacheKey = `${id}:${fallbackAlt}`;
    if (cache.has(cacheKey)) return cache.get(cacheKey);
    const media = resolveMedia(app, mediasCollection, id, fallbackAlt);
    cache.set(cacheKey, media);
    return media;
  };
}

function tabConfig(activeIndex) {
  return {
    schemaVersion: 1,
    defaultActiveIndex: activeIndex,
    items: TAB_ITEMS,
  };
}

function tile(label, href, media) {
  return { label, href, media };
}

function product(title, media) {
  return { title, price: '', href: '/catalog', media };
}

function banner(title, href, media, code) {
  return {
    code,
    title,
    href,
    media,
    backgroundTone: 'dark',
  };
}

function segmentSectionSpecs(spec, mediaFor) {
  const segment = spec.key;
  const media = (slot) => mediaFor(segment, slot, `${spec.pageTitle} ${slot}`);
  return [
    {
      sectionId: `nike-${segment}-category-tabs`,
      position: 1,
      sectionType: 'category_split_tabs',
      config: tabConfig(spec.activeIndex),
    },
    {
      sectionId: `nike-${segment}-en-ce-moment`,
      position: 2,
      sectionType: 'horizontal_tile_carousel',
      config: {
        schemaVersion: 1,
        title: 'En ce moment',
        items: spec.momentItems.map((label, index) =>
          tile(label, '/catalog', media(`moment${index + 1}`)),
        ),
      },
    },
    {
      sectionId: `nike-${segment}-category-banners`,
      position: 3,
      sectionType: 'category_banner_strip',
      config: {
        schemaVersion: 2,
        sourceMode: 'configuredBanners',
        skeletonItemCount: spec.banners.length,
        banners: spec.banners.map((title, index) =>
          banner(
            title,
            '/catalog',
            media(`banner${index + 1}`),
            `${segment}_banner_${index + 1}`,
          ),
        ),
      },
    },
    {
      sectionId: `nike-${segment}-editorial`,
      position: 4,
      sectionType: 'editorial_story',
      config: {
        schemaVersion: 1,
        eyebrow: spec.editorial.eyebrow,
        title: spec.editorial.title,
        body: spec.editorial.body,
        primaryCta: { label: 'Découvrir', href: '/catalog' },
        mediaDesktop: media('editorial'),
        mediaMobile: media('editorialMobile'),
        mediaType: 'image',
        layoutVariant: 'mediaRight',
        backgroundTone: 'light',
      },
    },
    {
      sectionId: `nike-${segment}-adventure`,
      position: 5,
      sectionType: 'horizontal_tile_carousel',
      config: {
        schemaVersion: 1,
        title: spec.adventureTitle,
        items: spec.adventureItems.map((label, index) =>
          tile(label, '/catalog', media(`adventure${index + 1}`)),
        ),
      },
    },
    {
      sectionId: `nike-${segment}-latest`,
      position: 6,
      sectionType: 'featured_products',
      config: {
        schemaVersion: 1,
        title: spec.featuredTitle,
        primaryCta: { label: 'Voir tout', href: '/catalog' },
        productIds: [],
        placeholderProducts: spec.featuredProducts.map((title, index) =>
          product(title, media(`product${index + 1}`)),
        ),
        layout: 'nikeGrid3',
        showPrices: false,
      },
    },
  ];
}

function addMissingSections(app, sectionsCollection, page, specs) {
  const existing = findExistingSectionsBySectionId(
    app,
    sectionsCollection.id,
    page.id,
  );

  for (const spec of specs) {
    if (existing.has(spec.sectionId)) continue;
    const record = new Record(sectionsCollection);
    record.set('page', page.id);
    record.set('sectionId', spec.sectionId);
    record.set('sectionType', spec.sectionType);
    record.set('position', spec.position);
    record.set('isActive', true);
    setRequiredConfig(record, spec.config, { schemaVersion: 1 });
    saveRecord(app, record, `section ${spec.sectionId}`);
  }
}

function patchCanonicalTabs(section, activeIndex) {
  if (!section) return;
  const config = asConfigObject(section.get('config'));
  const items = Array.isArray(config.items) ? config.items : [];
  const bySegment = new Map(TAB_ITEMS.map((item) => [item.segment, item]));
  const nextItems = items.length > 0 ? items.map((item) => {
    const label = String((item && item.label) || '').trim().toLowerCase();
    const segment = label === 'homme' || label === 'femme' || label === 'enfant'
      ? label
      : String((item && item.segment) || '').trim().toLowerCase();
    const canonical = bySegment.get(segment);
    return canonical ? { ...item, ...canonical } : item;
  }) : TAB_ITEMS;

  setRequiredConfig(section, {
    ...config,
    schemaVersion: config.schemaVersion || 1,
    defaultActiveIndex: activeIndex,
    items: nextItems,
  }, tabConfig(activeIndex));
}

function patchHommePage(app, sectionsCollection, page) {
  const sections = findExistingSectionsBySectionId(
    app,
    sectionsCollection.id,
    page.id,
  );

  const tabs = sections.get('nike-category-tabs');
  if (tabs) {
    patchCanonicalTabs(tabs, 0);
    saveRecord(app, tabs, 'section nike-category-tabs');
  }

  const banners = sections.get('nike-category-banners');
  if (banners) {
    const config = asConfigObject(banners.get('config'));
    const bannerItems = Array.isArray(config.banners) ? config.banners : [];
    if (bannerItems.length > 0) {
      setRequiredConfig(banners, {
        ...config,
        schemaVersion: Math.max(Number(config.schemaVersion || 1), 2),
        sourceMode: 'configuredBanners',
        skeletonItemCount: config.skeletonItemCount || bannerItems.length,
      }, config);
      saveRecord(app, banners, 'section nike-category-banners');
    }
  }
}

migrate(
  (app) => {
    const pagesCollection = app.findCollectionByNameOrId('pages');
    const sectionsCollection = app.findCollectionByNameOrId('page_sections');
    const mediaFor = createMediaResolver(app);

    const hommePage = findPageOrNull(app, pagesCollection.id, 'homepage_nike');
    if (hommePage) {
      patchHommePage(app, sectionsCollection, hommePage);
    } else {
      log('homepage_nike page not found; Homme alignment skipped.');
    }

    for (const spec of SEGMENTS) {
      const page = ensurePage(app, pagesCollection, spec);
      addMissingSections(
        app,
        sectionsCollection,
        page,
        segmentSectionSpecs(spec, mediaFor),
      );
    }
  },
  () => {
    // Data seed rollback intentionally no-ops: seeded CMS pages/sections may
    // have been edited by admins after creation.
  },
);
