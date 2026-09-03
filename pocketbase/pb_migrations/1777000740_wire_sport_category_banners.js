/// <reference path="../pb_data/types.d.ts" />

// Wires the Sport segment landings to the category tree seeded by
// `1777000720_seed_sport_categories.js`, so the `category_banner_strip`
// sections are category-driven and tapping a banner opens the drawer drilled
// into that category's children.
//
// Two parts:
//  1) Per segment: switch each page's `category_banner_strip` section to
//     `sourceMode: categoryChildren` with `sourceCategoryId` = the segment
//     category id (Homme/Femme/Enfant). The strip then renders the segment's
//     mid-level children (Chaussures/Vêtements/Sport) as banners, each
//     carrying its categoryId so the tap can drill.
//        homepage_nike        → HOMME
//        homepage_nike_femme  → FEMME
//        homepage_nike_enfant → ENFANT
//  2) Global: switch the `main_drawer` menu to `displayMode: categories` so the
//     drawer renders from the `categories` collection. This is REQUIRED for the
//     drill: the banner's drill check and the drawer's drill both resolve the
//     target through the live categories, not the managed navigation tree.
//     NOTE: the drawer is shared across themes, so this also makes the Luxe/
//     Dior drawer category-driven. Revert from the admin (drawer edit mode →
//     scope selector) or set displayMode back to `drawer` if undesired.
//
// Idempotent: re-runs converge to the same config. Rollback is a no-op
// (matches the other CMS seeds; admins may have edited sections/menu after).

const SEGMENT_PAGES = [
  { pageCode: 'homepage_nike', categoryCode: 'HOMME' },
  { pageCode: 'homepage_nike_femme', categoryCode: 'FEMME' },
  { pageCode: 'homepage_nike_enfant', categoryCode: 'ENFANT' },
];

function log(message) {
  console.log(`[1777000740] ${message}`);
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

function findFirstOrNull(app, collectionId, filter) {
  try {
    return app.findFirstRecordByFilter(collectionId, filter);
  } catch (_) {
    return null;
  }
}

migrate(
  (app) => {
    const categoriesCollection = app.findCollectionByNameOrId('categories');
    const pagesCollection = app.findCollectionByNameOrId('pages');
    const sectionsCollection = app.findCollectionByNameOrId('page_sections');

    // --- Part 1: per-segment banner sections → categoryChildren ---
    for (const spec of SEGMENT_PAGES) {
      const category = findFirstOrNull(
        app,
        categoriesCollection.id,
        `code = "${spec.categoryCode}"`,
      );
      if (!category) {
        log(`category ${spec.categoryCode} not found; ${spec.pageCode} skipped.`);
        continue;
      }

      const page = findFirstOrNull(
        app,
        pagesCollection.id,
        `code = "${spec.pageCode}" && locale = "fr"`,
      );
      if (!page) {
        log(`page ${spec.pageCode} not found; skipped.`);
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
      if (!sections || sections.length === 0) {
        log(`no category_banner_strip on ${spec.pageCode}; skipped.`);
        continue;
      }

      for (const section of sections) {
        const config = asConfigObject(section.get('config'));
        section.set('config', {
          ...config,
          schemaVersion: Math.max(Number(config.schemaVersion || 1), 2),
          sourceMode: 'categoryChildren',
          sourceCategoryId: category.id,
          skeletonItemCount: Number(config.skeletonItemCount) || 3,
        });
        app.save(section);
        log(`${spec.pageCode}: ${section.getString('sectionId')} → categoryChildren(${spec.categoryCode}).`);
      }
    }

    // --- Part 2: drawer renders from categories (required for the drill) ---
    const navMenusCollection = app.findCollectionByNameOrId('navigation_menus');
    const menu = findFirstOrNull(
      app,
      navMenusCollection.id,
      'code = "main_drawer"',
    );
    if (!menu) {
      // No managed menu → the drawer already falls back to the categories
      // collection, so the drill resolves. Nothing to switch.
      log('main_drawer menu not found; drawer already category-driven.');
    } else if (menu.getString('displayMode') !== 'categories') {
      menu.set('displayMode', 'categories');
      app.save(menu);
      log('main_drawer.displayMode → categories.');
    } else {
      log('main_drawer already in categories mode.');
    }
  },
  (app) => {
    // No-op rollback: matches the other CMS/data seeds. To revert manually, set
    // main_drawer.displayMode back to `drawer` and the segment banner sections
    // back to their previous sourceMode from the admin.
  },
);
