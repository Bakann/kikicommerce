/// <reference path="../pb_data/types.d.ts" />

const STOREFRONT_SETTINGS_ID = 'storefrontset00';
const STOREFRONT_SETTINGS_NAME = 'storefront_settings';
const PUBLIC_BRAND_RULE = 'key = "brand"';
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

function newCollection() {
  return new Collection({
    id: STOREFRONT_SETTINGS_ID,
    name: STOREFRONT_SETTINGS_NAME,
    type: 'base',
    system: false,
    listRule: null,
    viewRule: null,
    createRule: AUTH_RULE,
    updateRule: AUTH_RULE,
    deleteRule: AUTH_RULE,
    fields: [
      {
        name: 'key',
        type: 'text',
        required: true,
        min: 1,
        max: 64,
        pattern: '^[a-z0-9_]+$',
      },
      {
        name: 'brandTitle',
        type: 'text',
        required: false,
        max: 60,
      },
      {
        name: 'brandHref',
        type: 'text',
        required: false,
        max: 200,
      },
    ],
  });
}

function ensureFields(collection) {
  if (!fieldExists(collection, 'key')) {
    collection.fields.add(
      new TextField({
        name: 'key',
        required: true,
        min: 1,
        max: 64,
        pattern: '^[a-z0-9_]+$',
      }),
    );
  }
  if (!fieldExists(collection, 'brandTitle')) {
    collection.fields.add(
      new TextField({
        name: 'brandTitle',
        required: false,
        max: 60,
      }),
    );
  }
  if (!fieldExists(collection, 'brandHref')) {
    collection.fields.add(
      new TextField({
        name: 'brandHref',
        required: false,
        max: 200,
      }),
    );
  }
}

function ensureBrandRecord(app, collection) {
  let record;
  try {
    record = app.findFirstRecordByFilter(collection.id, 'key = "brand"');
  } catch (_) {
    record = null;
  }
  if (record) return;

  record = new Record(collection);
  record.set('key', 'brand');
  record.set('brandTitle', "Kiki's Commerce");
  record.set('brandHref', '/');
  app.save(record);
}

migrate(
  (app) => {
    let collection = findCollectionOrNull(app);
    if (!collection) {
      collection = newCollection();
      app.save(collection);
    } else {
      ensureFields(collection);
      collection.createRule = AUTH_RULE;
      collection.updateRule = AUTH_RULE;
      collection.deleteRule = AUTH_RULE;
      app.save(collection);
    }

    collection = app.findCollectionByNameOrId(STOREFRONT_SETTINGS_ID);
    ensureFields(collection);
    collection.listRule = PUBLIC_BRAND_RULE;
    collection.viewRule = PUBLIC_BRAND_RULE;
    collection.createRule = AUTH_RULE;
    collection.updateRule = AUTH_RULE;
    collection.deleteRule = AUTH_RULE;
    app.save(collection);

    ensureBrandRecord(app, collection);
  },
  (app) => {
    const collection = findCollectionOrNull(app);
    if (!collection) return;
    collection.listRule = null;
    collection.viewRule = null;
    return app.save(collection);
  },
);
