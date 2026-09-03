/// <reference path="../pb_data/types.d.ts" />

const STOREFRONT_SETTINGS_ID = 'storefrontset00';
const STOREFRONT_SETTINGS_NAME = 'storefront_settings';
const FIELD_NAME = 'categorySplitDisplayMode';

function findCollectionOrNull(app) {
  try {
    return app.findCollectionByNameOrId(STOREFRONT_SETTINGS_ID);
  } catch (_) {
    try {
      return app.findCollectionByNameOrId(STOREFRONT_SETTINGS_NAME);
    } catch (_) {
      return null;
    }
  }
}

function fieldExists(collection, name) {
  return !!collection.fields.getByName(name);
}

migrate(
  (app) => {
    const collection = findCollectionOrNull(app);
    if (!collection) {
      throw new Error('storefront_settings collection is required');
    }
    if (!fieldExists(collection, FIELD_NAME)) {
      collection.fields.add(
        new TextField({
          name: FIELD_NAME,
          required: false,
          max: 32,
        }),
      );
    }
    app.save(collection);
  },
  (app) => {
    const collection = findCollectionOrNull(app);
    if (!collection) return;
    const field = collection.fields.getByName(FIELD_NAME);
    if (!field) return;
    collection.fields.remove(field);
    app.save(collection);
  },
);
