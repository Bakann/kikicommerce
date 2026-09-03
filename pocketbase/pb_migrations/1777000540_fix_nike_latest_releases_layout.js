/// <reference path="../pb_data/types.d.ts" />

// Aligns the lower Nike homepage with the live Nike reference:
// - "Dernières sorties" is a 3-column product grid with prices + "Voir tout".
// - "Modèles iconiques" remains a horizontal carousel after the product grid.
// To protect CMS edits, existing sections are left untouched; only missing
// records are created.

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

function findSectionOrNull(app, sectionsCollectionId, pageId, sectionId) {
  try {
    return app.findFirstRecordByFilter(
      sectionsCollectionId,
      `page = "${pageId}" && sectionId = "${sectionId}"`,
    );
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

function latestProductsConfig(tileMedia) {
  return {
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
  };
}

function iconicModelsConfig(tileMedia) {
  return {
    schemaVersion: 1,
    title: 'Modèles iconiques',
    items: [
      tile('Air Force 1', '/catalog', tileMedia),
      tile('Air Max', '/catalog', tileMedia),
      tile('Shox', '/catalog', tileMedia),
      tile('Dunk', '/catalog', tileMedia),
    ],
  };
}

migrate(
  (app) => {
    const pagesCollection = app.findCollectionByNameOrId('pages');
    const sectionsCollection = app.findCollectionByNameOrId('page_sections');
    const page = findPageOrNull(app, pagesCollection.id);
    if (!page) return;

    const tileMedia = resolveTileMedia(app);

    let latest = findSectionOrNull(
      app,
      sectionsCollection.id,
      page.id,
      'nike-dernieres-sorties',
    );
    if (!latest) {
      latest = new Record(sectionsCollection);
      latest.set('page', page.id);
      latest.set('sectionId', 'nike-dernieres-sorties');
      latest.set('isActive', true);
      latest.set('position', 5);
      latest.set('sectionType', 'featured_products');
      latest.set('config', latestProductsConfig(tileMedia));
      app.save(latest);
    }

    let models = findSectionOrNull(
      app,
      sectionsCollection.id,
      page.id,
      'nike-modeles-iconiques',
    );
    if (!models) {
      models = new Record(sectionsCollection);
      models.set('page', page.id);
      models.set('sectionId', 'nike-modeles-iconiques');
      models.set('isActive', true);
      models.set('position', 6);
      models.set('sectionType', 'horizontal_tile_carousel');
      models.set('config', iconicModelsConfig(tileMedia));
      app.save(models);
    }
  },
  () => {},
);
