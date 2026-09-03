/// <reference path="../pb_data/types.d.ts" />

// Seeds the FR homepage CMS record with the existing landing hero asset.
// Idempotent: skips creation if a homepage/fr page already exists, and only
// creates the hero section when no section is attached yet.

const LANDING_HERO_MEDIA_ID = 'q9v4i6qj5iax0wh';

migrate(
  (app) => {
    const pagesCollection = app.findCollectionByNameOrId('pages');
    const sectionsCollection = app.findCollectionByNameOrId('page_sections');

    let page;
    try {
      page = app.findFirstRecordByFilter(
        pagesCollection.id,
        'code = "homepage" && locale = "fr"',
      );
    } catch (_) {
      page = null;
    }

    if (!page) {
      page = new Record(pagesCollection);
      page.set('code', 'homepage');
      page.set('locale', 'fr');
      page.set('title', 'Accueil');
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

    const heroMedia =
      heroFilename && mediasCollectionId
        ? {
            recordId: LANDING_HERO_MEDIA_ID,
            collectionId: mediasCollectionId,
            filename: heroFilename,
            alt: 'Campagne Printemps-Été 2026',
          }
        : null;

    const config = {
      eyebrow: null,
      title: 'Heritage revisite',
      subtitle: 'Printemps-Ete 2026',
      body: null,
      primaryCta: {
        label: 'Découvrir la collection',
        href: '/catalog',
      },
      mediaDesktop: heroMedia,
      mediaMobile: heroMedia,
      mediaType: heroMedia ? 'image' : 'none',
      textAlign: 'center',
      heightMode: 'xl',
    };

    const section = new Record(sectionsCollection);
    section.set('page', page.id);
    section.set('sectionId', 'homepage-hero');
    section.set('sectionType', 'hero_campaign');
    section.set('position', 0);
    section.set('isActive', true);
    section.set('config', config);
    app.save(section);
  },
  (app) => {
    // Data seed rollback is intentionally a no-op: the up migration is
    // idempotent and may attach to a pre-existing homepage, so deleting here
    // could remove marketer-owned CMS content.
  },
);
