/// <reference path="../pb_data/types.d.ts" />

// Corrective migration. PocketBase runs each migration file only once (tracked
// by name), so the earlier rewrites of `1777000720` never re-applied: instances
// that ran its first version got a SINGLE shared Sport/Vêtements/Chaussures
// tree (roots), and `1777000740` then skipped the per-segment wiring because the
// Homme/Femme/Enfant categories did not exist. Result: subcategories shared
// across segments, and only the Homme banners (which defaulted to drawerRoots)
// opened the drawer while Femme/Enfant fell back to the PLP.
//
// This NEW file reconciles any instance to the correct state:
//   A) create the per-segment Homme/Femme/Enfant 3-level tree (idempotent),
//   B) remove the old shared SPORT/VETEMENTS/CHAUSSURES tree (delete; hide as a
//      fallback if a delete is blocked),
//   C) wire each segment page's category_banner_strip to categoryChildren with
//      the matching segment category id,
//   D) ensure main_drawer renders from categories (required for the drill).
//
// Idempotent and safe on a fresh instance too (creates skip if present, deletes
// skip if absent, wiring converges).

const ACCENTS = {
  à: 'a', â: 'a', ä: 'a', á: 'a', ã: 'a',
  ç: 'c',
  é: 'e', è: 'e', ê: 'e', ë: 'e',
  î: 'i', ï: 'i', í: 'i', ì: 'i',
  ô: 'o', ö: 'o', ó: 'o', ò: 'o', õ: 'o',
  û: 'u', ü: 'u', ù: 'u', ú: 'u',
  ÿ: 'y', ñ: 'n',
};

function slugify(value) {
  let out = '';
  const lower = String(value).toLowerCase();
  for (const ch of lower) {
    out += ACCENTS[ch] !== undefined ? ACCENTS[ch] : ch;
  }
  return out.replace(/[^a-z0-9]+/g, '-').replace(/(^-+)|(-+$)/g, '');
}

function codeSuffix(value) {
  return slugify(value).toUpperCase().replace(/-/g, '_');
}

function log(message) {
  console.log(`[1777000760] ${message}`);
}

function findFirstOrNull(app, collectionId, filter) {
  try {
    return app.findFirstRecordByFilter(collectionId, filter);
  } catch (_) {
    return null;
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

// Per-segment tree (segment-specific leaves, from the provided screenshots).
const SEGMENTS = [
  {
    code: 'HOMME',
    name: 'Homme',
    slug: 'homme',
    pageCode: 'homepage_nike',
    mids: [
      {
        name: 'Chaussures',
        children: [
          'Toutes les chaussures', 'Lifestyle', 'Jordan', 'Running',
          'Football', 'Basketball', 'Training et fitness', 'Skateboard',
          'Chaussures personnalisées',
        ],
      },
      {
        name: 'Vêtements',
        children: [
          'Tous les vêtements', 'Sweats à capuche et sweats',
          'Hauts et t-shirts', 'Survêtements', 'Vestes',
          'Pantalons et leggings', 'Shorts', 'Accessoires',
        ],
      },
      {
        name: 'Sport',
        children: [
          'Tous les sports', 'Running', 'Football', 'Basketball',
          'Training et fitness', 'Tennis', 'Golf',
        ],
      },
    ],
  },
  {
    code: 'FEMME',
    name: 'Femme',
    slug: 'femme',
    pageCode: 'homepage_nike_femme',
    mids: [
      {
        name: 'Chaussures',
        children: [
          'Toutes les chaussures', 'Lifestyle', 'Jordan', 'Running',
          'Training et fitness', 'Football', 'Basketball',
          'Chaussures personnalisées',
        ],
      },
      {
        name: 'Vêtements',
        children: [
          'Tous les vêtements', 'Sweats à capuche et sweats',
          'Hauts et t-shirts', 'Pantalons', 'Leggings', 'Ensembles', 'Vestes',
          'Shorts', 'Brassières de sport', 'Accessoires',
        ],
      },
      {
        name: 'Sport',
        children: [
          'Tous les sports', 'Running', 'Football', 'Basketball',
          'Training et fitness', 'Tennis', 'Golf',
        ],
      },
    ],
  },
  {
    code: 'ENFANT',
    name: 'Enfant',
    slug: 'enfant',
    pageCode: 'homepage_nike_enfant',
    mids: [
      {
        name: 'Chaussures',
        children: [
          'Toutes les chaussures', 'Lifestyle', 'Jordan', 'Football',
          'Running', 'Basketball', 'Éducation physique',
        ],
      },
      {
        name: 'Vêtements',
        children: [
          'Tous les vêtements', 'Sweats à capuche et sweats',
          'Hauts et t-shirts', 'Pantalons et leggings', 'Vestes',
          'Survêtements', 'Shorts', 'Brassières de sport', 'Ensembles',
        ],
      },
      {
        name: 'Sport',
        children: ['Running', 'Football', 'Basketball', 'Éducation physique'],
      },
    ],
  },
];

// Old shared roots from the first seed; their children carry these prefixes.
const OLD_ROOT_CODES = ['SPORT', 'VETEMENTS', 'CHAUSSURES'];

migrate(
  (app) => {
    const categories = app.findCollectionByNameOrId('categories');
    const pagesCollection = app.findCollectionByNameOrId('pages');
    const sectionsCollection = app.findCollectionByNameOrId('page_sections');

    const findByCode = (code) =>
      findFirstOrNull(app, categories.id, `code = "${code}"`);

    const upsert = ({ code, name, slug, parentId, position }) => {
      const existing = findByCode(code);
      if (existing) return existing;
      const record = new Record(categories);
      record.set('code', code);
      record.set('name', name);
      record.set('slug', slug);
      record.set('isActive', true);
      record.set('isHidden', false);
      record.set('position', position);
      if (parentId) record.set('parent', parentId);
      app.save(record);
      return record;
    };

    // --- A) create the per-segment tree, and remember each segment id ---
    const segmentIdByCode = {};
    SEGMENTS.forEach((segment, segmentIndex) => {
      const root = upsert({
        code: segment.code,
        name: segment.name,
        slug: segment.slug,
        parentId: null,
        position: (segmentIndex + 1) * 10,
      });
      segmentIdByCode[segment.code] = root.id;

      segment.mids.forEach((mid, midIndex) => {
        const midCode = `${segment.code}_${codeSuffix(mid.name)}`;
        const midSlug = `${segment.slug}-${slugify(mid.name)}`;
        const midRecord = upsert({
          code: midCode,
          name: mid.name,
          slug: midSlug,
          parentId: root.id,
          position: (midIndex + 1) * 10,
        });
        mid.children.forEach((childName, childIndex) => {
          upsert({
            code: `${midCode}_${codeSuffix(childName)}`,
            name: childName,
            slug: `${midSlug}-${slugify(childName)}`,
            parentId: midRecord.id,
            position: (childIndex + 1) * 10,
          });
        });
      });
    });
    log('per-segment tree ensured.');

    // --- B) remove the old shared Sport/Vêtements/Chaussures tree ---
    let allCategories = [];
    try {
      allCategories = app.findRecordsByFilter(
        categories.id,
        "id != ''",
        '',
        1000,
        0,
      );
    } catch (_) {
      allCategories = [];
    }
    const isOld = (code) =>
      OLD_ROOT_CODES.indexOf(code) !== -1 ||
      OLD_ROOT_CODES.some((root) => code.indexOf(`${root}_`) === 0);
    const oldRecords = allCategories.filter((r) => isOld(r.getString('code')));
    // Children (code contains "_") before roots, so parent relations are free.
    oldRecords.sort(
      (a, b) =>
        (b.getString('code').indexOf('_') >= 0 ? 1 : 0) -
        (a.getString('code').indexOf('_') >= 0 ? 1 : 0),
    );
    let removed = 0;
    let hidden = 0;
    for (const record of oldRecords) {
      try {
        app.delete(record);
        removed += 1;
      } catch (_) {
        try {
          record.set('isActive', false);
          record.set('isHidden', true);
          app.save(record);
          hidden += 1;
        } catch (__) {
          /* leave as-is */
        }
      }
    }
    log(`old shared tree: ${removed} deleted, ${hidden} hidden.`);

    // --- C) wire each segment page's banner strip to categoryChildren ---
    for (const segment of SEGMENTS) {
      const categoryId = segmentIdByCode[segment.code];
      const page = findFirstOrNull(
        app,
        pagesCollection.id,
        `code = "${segment.pageCode}" && locale = "fr"`,
      );
      if (!page) {
        log(`page ${segment.pageCode} not found; wiring skipped.`);
        continue;
      }
      let sections = [];
      try {
        sections = app.findRecordsByFilter(
          sectionsCollection.id,
          `page = "${page.id}" && sectionType = "category_banner_strip"`,
          '+position',
          50,
          0,
        );
      } catch (_) {
        sections = [];
      }
      for (const section of sections) {
        const config = asConfigObject(section.get('config'));
        section.set('config', {
          ...config,
          schemaVersion: Math.max(Number(config.schemaVersion || 1), 2),
          sourceMode: 'categoryChildren',
          sourceCategoryId: categoryId,
          skeletonItemCount: Number(config.skeletonItemCount) || 3,
        });
        app.save(section);
        log(`${segment.pageCode}: ${section.getString('sectionId')} → categoryChildren(${segment.code}).`);
      }
    }

    // --- D) drawer renders from categories (required for the drill) ---
    const navMenusCollection = app.findCollectionByNameOrId('navigation_menus');
    const menu = findFirstOrNull(
      app,
      navMenusCollection.id,
      'code = "main_drawer"',
    );
    if (menu && menu.getString('displayMode') !== 'categories') {
      menu.set('displayMode', 'categories');
      app.save(menu);
      log('main_drawer.displayMode → categories.');
    }
  },
  (app) => {
    // No-op rollback: matches the other CMS/data seeds. The up migration is
    // idempotent and deletes admin-visible data; reversing it automatically
    // could remove or recreate records an admin has since edited.
  },
);
