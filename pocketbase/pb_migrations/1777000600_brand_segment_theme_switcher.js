/// <reference path="../pb_data/types.d.ts" />

// Converts the original Nike/Jordan brand segment seed into the visitor
// Sport/Luxe theme switcher. It intentionally leaves admin-customized configs
// untouched.

function log(message) {
  console.log(`[1777000600] ${message}`);
}

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

function findSectionOrNull(app, sectionsCollectionId, pageId) {
  try {
    return app.findFirstRecordByFilter(
      sectionsCollectionId,
      `page = "${pageId}" && sectionId = "nike-brand-segment"`,
    );
  } catch (_) {
    return null;
  }
}

function isOriginalSeedConfig(config) {
  if (!config || typeof config !== 'object') return false;
  if (String(config.mode || '').trim() !== '') return false;
  if (Number(config.schemaVersion || 1) !== 1) return false;
  if (Number(config.activeIndex || 0) !== 0) return false;

  const items = Array.isArray(config.items) ? config.items : [];
  if (items.length !== 2) return false;

  const first = items[0] || {};
  const second = items[1] || {};
  return (
    String(first.label || '').trim() === 'Nike' &&
    String(first.href || '').trim() === '/' &&
    String(first.theme || '').trim() === '' &&
    String(second.label || '').trim() === 'Jordan' &&
    String(second.href || '').trim() === '/catalog' &&
    String(second.theme || '').trim() === ''
  );
}

function themeSwitcherConfigFrom(config) {
  const items = Array.isArray(config.items) ? config.items : [];
  return {
    ...config,
    mode: 'themeSwitcher',
    activeIndex: 0,
    items: [
      { label: 'Sport', theme: 'nike', media: items[0] ? items[0].media || null : null },
      { label: 'Luxe', theme: 'dior', media: items[1] ? items[1].media || null : null },
    ],
  };
}

migrate(
  (app) => {
    const pagesCollection = app.findCollectionByNameOrId('pages');
    const sectionsCollection = app.findCollectionByNameOrId('page_sections');
    const page = findPageOrNull(app, pagesCollection.id);
    if (!page) {
      log('homepage_nike page not found; no-op.');
      return;
    }

    const section = findSectionOrNull(app, sectionsCollection.id, page.id);
    if (!section) {
      log('nike-brand-segment section not found; no-op.');
      return;
    }

    const sectionType = String(section.get('sectionType') || '').trim();
    if (sectionType !== 'brand_segment') {
      log(`section type is "${sectionType}"; no-op.`);
      return;
    }

    const config = section.get('config') || {};
    if (!isOriginalSeedConfig(config)) {
      log('config is not the original Nike/Jordan seed; no-op.');
      return;
    }

    section.set('config', themeSwitcherConfigFrom(config));
    app.save(section);
    log('converted Nike/Jordan segment to Sport/Luxe theme switcher.');
  },
  () => {},
);
