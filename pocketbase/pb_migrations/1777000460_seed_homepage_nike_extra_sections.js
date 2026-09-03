/// <reference path="../pb_data/types.d.ts" />

// Enriches the Nike homepage with three additional horizontal_tile_carousel
// sections so the storefront approximates the reference Nike landing using
// only the section types available in phase 1.
//
// Idempotent per sectionId: a section is created only if no row with the
// same sectionId is already attached to the page. Safe to re-run after
// admin edits.
//
// Tile media reuses the landing hero placeholder. Swap from the admin once
// you have dedicated Nike assets — the labels are aligned with the reference
// screenshots so the swap is straightforward.

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

function findExistingSectionIds(app, sectionsCollectionId, pageId) {
  let records = [];
  try {
    records = app.findRecordsByFilter(
      sectionsCollectionId,
      `page = "${pageId}"`,
      '+position',
      100,
      0,
    );
  } catch (_) {
    return new Set();
  }
  const ids = new Set();
  for (const record of records) {
    ids.add(record.getString('sectionId'));
  }
  return ids;
}

function tile(label, href, media) {
  return { label, href, media };
}

function product(title, price, media) {
  return { title, price, href: '/catalog', media };
}

function buildSectionSpecs(tileMedia) {
  return [
    {
      sectionId: 'nike-choisis-ton-aventure',
      position: 1,
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
      position: 2,
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
      position: 3,
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
      position: 4,
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
      // The base seed (1777000360) creates the page; if it ran successfully
      // this will succeed. Skip silently otherwise so this migration stays
      // independent.
      return;
    }

    let heroFilename = '';
    let mediasCollectionId = '';
    try {
      const mediasCollection = app.findCollectionByNameOrId('medias');
      mediasCollectionId = mediasCollection.id;
      const heroRecord = app.findRecordById(
        mediasCollectionId,
        LANDING_HERO_MEDIA_ID,
      );
      heroFilename = heroRecord.getString('file');
    } catch (_) {
      heroFilename = '';
    }

    const tileMedia =
      heroFilename && mediasCollectionId
        ? {
            recordId: LANDING_HERO_MEDIA_ID,
            collectionId: mediasCollectionId,
            filename: heroFilename,
            alt: 'Placeholder Nike',
          }
        : null;

    const existing = findExistingSectionIds(
      app,
      sectionsCollection.id,
      page.id,
    );

    for (const spec of buildSectionSpecs(tileMedia)) {
      if (existing.has(spec.sectionId)) continue;
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
