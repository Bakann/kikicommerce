/// <reference path="../pb_data/types.d.ts" />

// Per-locale translatable fields for categories. The base `categories` record
// keeps all locale-invariant data (code, slug, position, parent, flags); only
// the visitor-facing strings live here, one row per (category, locale). Same
// active -> default-locale -> base-column fallback as product_translations.
// Public-read / authenticated-write.
const CATEGORY_TRANSLATIONS_ID = 'categorytrans1';

migrate(
  (app) => {
    const categories = app.findCollectionByNameOrId('categories');

    const collection = new Collection({
      id: CATEGORY_TRANSLATIONS_ID,
      name: 'category_translations',
      type: 'base',
      system: false,
      listRule: '',
      viewRule: '',
      createRule: "@request.auth.id != ''",
      updateRule: "@request.auth.id != ''",
      deleteRule: "@request.auth.id != ''",
      indexes: [
        'CREATE UNIQUE INDEX idx_category_tr_category_locale ON category_translations (category, locale)',
        'CREATE INDEX idx_category_tr_locale ON category_translations (locale)',
      ],
      fields: [
        {
          name: 'category',
          type: 'relation',
          required: true,
          collectionId: categories.id,
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
          name: 'name',
          type: 'text',
          required: true,
          min: 1,
          max: 255,
        },
        {
          name: 'description',
          type: 'text',
          required: false,
          max: 5000,
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
    const collection = app.findCollectionByNameOrId(CATEGORY_TRANSLATIONS_ID);
    return app.delete(collection);
  },
);
