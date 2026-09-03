/// <reference path="../pb_data/types.d.ts" />

// Seeds the FR `homepage_nike` CMS page used by the Nike storefront theme.
// Idempotent: skips creation when the page exists, and only adds sections if
// none are attached yet. For phase 1 we ship a single
// `horizontal_tile_carousel` section ("En ce moment") to validate the theme
// switch end-to-end; richer Nike layouts come in phase 2.
//
// Tile media reuses the landing hero asset already seeded by
// `1776900120_seed_homepage_fr.js` so the page has something visible without
// requiring dedicated Nike assets. Swap from the admin once real media is in.

const LANDING_HERO_MEDIA_ID = 'q9v4i6qj5iax0wh';

migrate(
  (app) => {
    const pagesCollection = app.findCollectionByNameOrId('pages');
    const sectionsCollection = app.findCollectionByNameOrId('page_sections');

    let page;
    try {
      page = app.findFirstRecordByFilter(
        pagesCollection.id,
        'code = "homepage_nike" && locale = "fr"',
      );
    } catch (_) {
      page = null;
    }

    if (!page) {
      page = new Record(pagesCollection);
      page.set('code', 'homepage_nike');
      page.set('locale', 'fr');
      page.set('title', 'Boutique (Nike)');
      page.set('isActive', true);
      app.save(page);
    }

    let existingSections = [];
    try {
      existingSections = app.findRecordsByFilter(
        sectionsCollection.id,
        `page = "${page.id}"`,
        '+position',
        50,
        0,
      );
    } catch (_) {
      existingSections = [];
    }
    if (existingSections && existingSections.length > 0) {
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

    const tile = (label, href) => ({
      label,
      href,
      media: tileMedia,
    });

    const carouselConfig = {
      schemaVersion: 1,
      title: 'En ce moment',
      items: [
        tile("Articles d'été", '/catalog'),
        tile('Pack Air Max Mad 90', '/catalog'),
        tile('Tennis', '/catalog'),
        tile('Running', '/catalog'),
      ],
    };

    const section = new Record(sectionsCollection);
    section.set('page', page.id);
    section.set('sectionId', 'nike-en-ce-moment');
    section.set('sectionType', 'horizontal_tile_carousel');
    section.set('position', 0);
    section.set('isActive', true);
    section.set('config', carouselConfig);
    app.save(section);
  },
  (app) => {
    // Data seed rollback is intentionally a no-op: the up migration is
    // idempotent and may attach to a pre-existing page, so deleting here
    // could remove marketer-owned CMS content.
  },
);
