/// <reference path="../pb_data/types.d.ts" />

// Per-locale translatable fields for products. The base `products` record keeps
// all locale-invariant data (code, ean, slug, media, relations, dates); only
// the visitor-facing strings live here, one row per (product, locale). The
// storefront reads the active-locale row and falls back to the default locale,
// then to the base column, so a partially-translated catalog never renders
// empty. Public-read / authenticated-write, like the other storefront content.
const PRODUCT_TRANSLATIONS_ID = 'producttransl1';

migrate(
  (app) => {
    const products = app.findCollectionByNameOrId('products');

    const collection = new Collection({
      id: PRODUCT_TRANSLATIONS_ID,
      name: 'product_translations',
      type: 'base',
      system: false,
      listRule: '',
      viewRule: '',
      createRule: "@request.auth.id != ''",
      updateRule: "@request.auth.id != ''",
      deleteRule: "@request.auth.id != ''",
      indexes: [
        'CREATE UNIQUE INDEX idx_product_tr_product_locale ON product_translations (product, locale)',
        'CREATE INDEX idx_product_tr_locale ON product_translations (locale)',
      ],
      fields: [
        {
          name: 'product',
          type: 'relation',
          required: true,
          collectionId: products.id,
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
          name: 'summary',
          type: 'text',
          required: false,
          max: 5000,
        },
        {
          name: 'description',
          type: 'text',
          required: false,
          max: 100000,
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
    const collection = app.findCollectionByNameOrId(PRODUCT_TRANSLATIONS_ID);
    return app.delete(collection);
  },
);
