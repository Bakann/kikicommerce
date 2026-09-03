/// <reference path="../pb_data/types.d.ts" />

// Per-locale label for a managed navigation item. The base navigation_items
// record keeps everything else (target, placement, media, flags); only the
// visitor-facing label is translated, one row per (item, locale), with the same
// active -> base (default-locale) fallback as the other translation
// collections. navigation_items is public-read, so this must be too.
const NAVIGATION_ITEM_TRANSLATIONS_ID = 'navitemtransl1';

migrate(
  (app) => {
    const items = app.findCollectionByNameOrId('navigation_items');

    const collection = new Collection({
      id: NAVIGATION_ITEM_TRANSLATIONS_ID,
      name: 'navigation_item_translations',
      type: 'base',
      system: false,
      listRule: '',
      viewRule: '',
      createRule: "@request.auth.id != ''",
      updateRule: "@request.auth.id != ''",
      deleteRule: "@request.auth.id != ''",
      indexes: [
        'CREATE UNIQUE INDEX idx_nav_item_tr_item_locale ON navigation_item_translations (item, locale)',
        'CREATE INDEX idx_nav_item_tr_locale ON navigation_item_translations (locale)',
      ],
      fields: [
        {
          name: 'item',
          type: 'relation',
          required: true,
          collectionId: items.id,
          maxSelect: 1,
          cascadeDelete: true,
        },
        {
          name: 'locale',
          type: 'text',
          required: true,
          min: 2,
          max: 5,
          pattern: '^[a-z]{2}(-[a-z]{2})?$',
        },
        {
          name: 'label',
          type: 'text',
          required: true,
          min: 1,
          max: 200,
        },
        {
          name: 'created',
          type: 'autodate',
          system: false,
          onCreate: true,
          onUpdate: false,
        },
        {
          name: 'updated',
          type: 'autodate',
          system: false,
          onCreate: true,
          onUpdate: true,
        },
      ],
    });

    return app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId(
      NAVIGATION_ITEM_TRANSLATIONS_ID,
    );
    return app.delete(collection);
  },
);
