/// <reference path="../pb_data/types.d.ts" />

const STOREFRONT_SETTINGS_ID = 'storefrontset00';
const STOREFRONT_SETTINGS_NAME = 'storefront_settings';
const PUBLIC_NAVIGATION_RULE = 'key = "brand" || key = "navigation"';
const AUTH_RULE = "@request.auth.id != ''";

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

function ensureMobileMenuStyleField(collection) {
  if (fieldExists(collection, 'mobileMenuStyle')) {
    return;
  }

  collection.fields.add(
    new TextField({
      name: 'mobileMenuStyle',
      required: false,
      max: 32,
    }),
  );
}

function ensureNavigationRecord(app, collection) {
  let record;
  try {
    record = app.findFirstRecordByFilter(collection.id, 'key = "navigation"');
  } catch (_) {
    record = null;
  }
  if (record) {
    return;
  }

  record = new Record(collection);
  record.set('key', 'navigation');
  record.set('mobileMenuStyle', 'drawer');
  app.save(record);
}

migrate(
  (app) => {
    const collection = findCollectionOrNull(app);
    if (!collection) {
      throw new Error('storefront_settings collection is required');
    }

    ensureMobileMenuStyleField(collection);
    collection.listRule = PUBLIC_NAVIGATION_RULE;
    collection.viewRule = PUBLIC_NAVIGATION_RULE;
    collection.createRule = AUTH_RULE;
    collection.updateRule = AUTH_RULE;
    collection.deleteRule = AUTH_RULE;
    // Do not add a unique index on key here. Existing MVP databases can
    // already contain duplicate storefront_settings keys, and a migration
    // must not delete merchant data to make an index fit. Runtime writes
    // search the existing navigation record before creating one.
    app.save(collection);

    const savedCollection = app.findCollectionByNameOrId(collection.id);
    ensureNavigationRecord(app, savedCollection);
  },
  (app) => {
    const collection = findCollectionOrNull(app);
    if (!collection) {
      return;
    }

    collection.listRule = 'key = "brand"';
    collection.viewRule = 'key = "brand"';
    app.save(collection);
  },
);
