/// <reference path="../pb_data/types.d.ts" />

// Phase 2: completes the homepage_nike layout to approximate the Nike
// reference. Adds three new section types (brand_segment,
// category_split_tabs, category_banner_strip) on top of the four phase-1
// carousels.
//
// Additive-only: existing sections (matched by sectionId) are left
// untouched. Position from `buildLayoutSpecs` is the *initial* position
// used when a section is created for the first time — subsequent admin
// reorders are preserved. This matches `1777000540` and the documented
// promise in storefront_theme_switch.md.
//
// Idempotent: re-runs are no-ops if all canonical sections already exist.

const LANDING_HERO_MEDIA_ID = 'q9v4i6qj5iax0wh';

function findPageOrNull(app, pagesCollectionId) {
  try {
    return app.findFirstRecordByFilter(
      pagesCollectionId,
      'code = "homepage_nike" && locale = "fr"',
    );
  } catch (_) {
    return null;
  }
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

function resolveTileMedia(app) {
  try {
    const mediasCollection = app.findCollectionByNameOrId('medias');
    const heroRecord = app.findRecordById(
      mediasCollection.id,
      LANDING_HERO_MEDIA_ID,
    );
    const filename = heroRecord.getString('file');
    if (!filename) return null;
    return {
      recordId: LANDING_HERO_MEDIA_ID,
      collectionId: mediasCollection.id,
      filename: filename,
      alt: 'Placeholder Nike',
    };
  } catch (_) {
    return null;
  }
}

function tile(label, href, media) {
  return { label, href, media };
}

function product(title, price, media) {
  return { title, price, href: '/catalog', media };
}

function shoesCategoryListAction() {
  return {
    type: 'categoryListOverlay',
    title: 'Chaussures',
    items: [
      { label: 'Toutes les chaussures', href: '/catalog' },
      { label: 'Lifestyle', href: '/catalog' },
      { label: 'Jordan', href: '/catalog' },
      { label: 'Running', href: '/catalog' },
      { label: 'Football', href: '/catalog' },
      { label: 'Basketball', href: '/catalog' },
      { label: 'Training et fitness', href: '/catalog' },
      { label: 'Skateboard', href: '/catalog' },
      { label: 'Chaussures personnalisées', href: '/catalog' },
    ],
  };
}

// Canonical phase-2 layout. Position is the *initial* index used only
// when the section is created for the first time. Existing sections
// (matched by sectionId) are not touched — their position and config
// are preserved so admin reorders survive re-runs.
function buildLayoutSpecs(tileMedia) {
  return [
    {
      sectionId: 'nike-brand-segment',
      position: 0,
      sectionType: 'brand_segment',
      config: {
        schemaVersion: 1,
        mode: 'themeSwitcher',
        activeIndex: 0,
        items: [
          { label: 'Sport', theme: 'nike', media: tileMedia },
          { label: 'Luxe', theme: 'dior', media: null },
        ],
      },
    },
    {
      sectionId: 'nike-category-tabs',
      position: 1,
      sectionType: 'category_split_tabs',
      config: {
        schemaVersion: 1,
        defaultActiveIndex: 0,
        items: [
          { label: 'Homme', href: '/sport/homme', segment: 'homme' },
          { label: 'Femme', href: '/sport/femme', segment: 'femme' },
          { label: 'Enfant', href: '/sport/enfant', segment: 'enfant' },
        ],
      },
    },
    {
      sectionId: 'nike-en-ce-moment',
      position: 2,
      sectionType: 'horizontal_tile_carousel',
      // Config provided only if the section is missing; existing config is
      // preserved so admin edits survive.
      config: {
        schemaVersion: 1,
        title: 'En ce moment',
        items: [
          tile("Articles d'été", '/catalog', tileMedia),
          tile('Pack Air Max Mad 90', '/catalog', tileMedia),
          tile('Tennis', '/catalog', tileMedia),
          tile('Running', '/catalog', tileMedia),
        ],
      },
    },
    {
      sectionId: 'nike-category-banners',
      position: 3,
      sectionType: 'category_banner_strip',
      config: {
        schemaVersion: 1,
        banners: [
          {
            code: 'nike_shoes',
            title: 'Chaussures',
            href: '/catalog',
            media: tileMedia,
            backgroundTone: 'dark',
            action: shoesCategoryListAction(),
          },
          {
            title: 'Vêtements',
            href: '/catalog',
            media: tileMedia,
            backgroundTone: 'dark',
          },
          {
            title: 'Sport',
            href: '/catalog',
            media: tileMedia,
            backgroundTone: 'dark',
          },
        ],
      },
    },
    {
      sectionId: 'nike-choisis-ton-aventure',
      position: 4,
      sectionType: 'horizontal_tile_carousel',
      config: {
        schemaVersion: 1,
        title: 'Choisis ton aventure',
        items: [
          tile('ACG Trail Run', '/catalog', tileMedia),
          tile('ACG Hike', '/catalog', tileMedia),
          tile('ACG Expedition', '/catalog', tileMedia),
          tile('Running route', '/catalog', tileMedia),
        ],
      },
    },
    {
      sectionId: 'nike-dernieres-sorties',
      position: 5,
      sectionType: 'featured_products',
      config: {
        schemaVersion: 1,
        title: 'Dernières sorties',
        primaryCta: { label: 'Voir tout', href: '/catalog' },
        productIds: [],
        placeholderProducts: [
          product('Nike Pegasus Premium', '209,99 €', tileMedia),
          product('Nike Pegasus Premium', '209,99 €', tileMedia),
          product('Nike Pegasus Premium', '209,99 €', tileMedia),
          product('Nike Pegasus Premium', '209,99 €', tileMedia),
          product('Nike Pegasus Premium', '209,99 €', tileMedia),
          product('Nike Vomero Premium', '229,99 €', tileMedia),
        ],
        layout: 'nikeGrid3',
        showPrices: true,
      },
    },
    {
      sectionId: 'nike-modeles-iconiques',
      position: 6,
      sectionType: 'horizontal_tile_carousel',
      config: {
        schemaVersion: 1,
        title: 'Modèles iconiques',
        items: [
          tile('Air Force 1', '/catalog', tileMedia),
          tile('Air Max', '/catalog', tileMedia),
          tile('Shox', '/catalog', tileMedia),
          tile('Dunk', '/catalog', tileMedia),
        ],
      },
    },
    {
      sectionId: 'nike-nos-marques',
      position: 7,
      sectionType: 'horizontal_tile_carousel',
      config: {
        schemaVersion: 1,
        title: 'Nos marques',
        items: [
          tile('NikeSKIMS', '/catalog', tileMedia),
          tile('All Conditions Gear', '/catalog', tileMedia),
          tile('Nike Sportswear', '/catalog', tileMedia),
          tile('Jordan', '/catalog', tileMedia),
        ],
      },
    },
  ];
}

migrate(
  (app) => {
    const pagesCollection = app.findCollectionByNameOrId('pages');
    const sectionsCollection = app.findCollectionByNameOrId('page_sections');

    const page = findPageOrNull(app, pagesCollection.id);
    if (!page) {
      // 1777000360 (base seed) must run first. If it failed or was skipped,
      // bail silently — nothing to align.
      return;
    }

    const tileMedia = resolveTileMedia(app);
    const existing = findExistingSectionsBySectionId(
      app,
      sectionsCollection.id,
      page.id,
    );

    for (const spec of buildLayoutSpecs(tileMedia)) {
      if (existing.has(spec.sectionId)) {
        // Existing section: preserve admin-edited position and config.
        continue;
      }
      const record = new Record(sectionsCollection);
      record.set('page', page.id);
      record.set('sectionId', spec.sectionId);
      record.set('sectionType', spec.sectionType);
      record.set('position', spec.position);
      record.set('isActive', true);
      record.set('config', spec.config);
      app.save(record);
    }
  },
  (app) => {
    // Data seed rollback is intentionally a no-op: admins may have edited
    // the seeded sections after the up migration ran.
  },
);
