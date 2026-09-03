/// <reference path="../pb_data/types.d.ts" />

// Adds the `theme` field on `storefront_settings` and extends the public
// read rule so anonymous clients can resolve the active storefront theme.
// Also cleans up orphan `active_theme` records created before the schema
// was complete (the storefront UI POSTed Appliquer clicks that PocketBase
// silently saved without the unknown `theme` field).

const STOREFRONT_SETTINGS_ID = 'storefrontset00';
const STOREFRONT_SETTINGS_NAME = 'storefront_settings';
const PUBLIC_READ_RULE =
  'key = "brand" || key = "navigation" || key = "active_theme"';
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

function ensureThemeField(collection) {
  if (fieldExists(collection, 'theme')) return;
  collection.fields.add(
    new TextField({
      name: 'theme',
      required: false,
      max: 32,
    }),
  );
}

function cleanupOrphanActiveThemeRecords(app, collection) {
  let records = [];
  try {
    records = app.findRecordsByFilter(
      collection.id,
      'key = "active_theme"',
      '',
      200,
      0,
    );
  } catch (_) {
    return;
  }
  for (const record of records) {
    const theme = record.getString('theme');
    if (!theme || theme.length === 0) {
      app.delete(record);
    }
  }
}

migrate(
  (app) => {
    const collection = findCollectionOrNull(app);
    if (!collection) {
      throw new Error('storefront_settings collection is required');
    }

    ensureThemeField(collection);
    collection.listRule = PUBLIC_READ_RULE;
    collection.viewRule = PUBLIC_READ_RULE;
    collection.createRule = AUTH_RULE;
    collection.updateRule = AUTH_RULE;
    collection.deleteRule = AUTH_RULE;
    app.save(collection);

    const saved = app.findCollectionByNameOrId(collection.id);
    cleanupOrphanActiveThemeRecords(app, saved);
  },
  (app) => {
    const collection = findCollectionOrNull(app);
    if (!collection) return;
    collection.listRule = 'key = "brand" || key = "navigation"';
    collection.viewRule = 'key = "brand" || key = "navigation"';
    app.save(collection);
  },
);
