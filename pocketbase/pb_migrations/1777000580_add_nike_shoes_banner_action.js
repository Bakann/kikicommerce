/// <reference path="../pb_data/types.d.ts" />

// Adds the generic categoryListOverlay action to the Nike "Chaussures"
// banner. Non-destructive by design: if any non-empty action already exists
// on the target banner, the migration logs and leaves it untouched.

function log(message) {
  console.log(`[1777000580] ${message}`);
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
      `page = "${pageId}" && sectionId = "nike-category-banners"`,
    );
  } catch (_) {
    return null;
  }
}

function shoesAction() {
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

function isNonEmptyAction(value) {
  if (value == null) return false;
  if (Array.isArray(value)) return value.length > 0;
  if (typeof value === 'object') return Object.keys(value).length > 0;
  if (typeof value === 'string') return value.trim().length > 0;
  return true;
}

function findTargetBannerIndex(banners) {
  const byCode = banners.findIndex((banner) => {
    return banner && String(banner.code || '').trim() === 'nike_shoes';
  });
  if (byCode >= 0) {
    return { index: byCode, reason: 'code' };
  }

  const titleMatches = [];
  for (let i = 0; i < banners.length; i += 1) {
    const title = String((banners[i] && banners[i].title) || '').trim();
    if (title === 'Chaussures') {
      titleMatches.push(i);
    }
  }

  if (titleMatches.length === 1) {
    return { index: titleMatches[0], reason: 'title' };
  }
  if (titleMatches.length > 1) {
    return { index: -1, reason: 'ambiguous-title' };
  }
  return { index: -1, reason: 'missing' };
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
      log('nike-category-banners section not found; no-op.');
      return;
    }

    const config = section.get('config') || {};
    const banners = Array.isArray(config.banners) ? config.banners : [];
    if (banners.length === 0) {
      log('section has no banners; no-op.');
      return;
    }

    const target = findTargetBannerIndex(banners);
    if (target.index < 0) {
      log(`target banner not patched (${target.reason}); no-op.`);
      return;
    }

    const banner = { ...banners[target.index] };
    log(`target banner found by ${target.reason}.`);

    const hadCode = String(banner.code || '').trim().length > 0;
    if (!hadCode) {
      banner.code = 'nike_shoes';
    }

    if (isNonEmptyAction(banner.action)) {
      log('target banner already has a non-empty action; no-op for action.');
      if (!hadCode) {
        banners[target.index] = banner;
        section.set('config', { ...config, banners });
        app.save(section);
        log('added missing code only.');
      }
      return;
    }

    banner.action = shoesAction();
    banners[target.index] = banner;
    section.set('config', { ...config, banners });
    app.save(section);
    log('patched target banner with code/action.');
  },
  () => {},
);
