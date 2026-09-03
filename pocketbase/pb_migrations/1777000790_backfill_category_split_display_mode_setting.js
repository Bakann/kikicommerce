/// <reference path="../pb_data/types.d.ts" />

// Backfills the new global `categorySplitDisplayMode` setting from legacy CMS
// section configs. Some instances had `displayMode: "expansible"` only on the
// Homme category_split_tabs section; Femme/Enfant then fell back to tabs after
// navigation because their sections did not carry that per-section flag.

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

function ensureField(collection) {
  if (fieldExists(collection, FIELD_NAME)) return;
  collection.fields.add(
    new TextField({
      name: FIELD_NAME,
      required: false,
      max: 32,
    }),
  );
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

function findNavigationRecordOrNull(app, collection) {
  try {
    return app.findFirstRecordByFilter(collection.id, 'key = "navigation"');
  } catch (_) {
    return null;
  }
}

function ensureNavigationRecord(app, collection) {
  const existing = findNavigationRecordOrNull(app, collection);
  if (existing) return existing;
  const record = new Record(collection);
  record.set('key', 'navigation');
  record.set('mobileMenuStyle', 'drawer');
  app.save(record);
  return record;
}

function hasLegacyExpansibleSection(app) {
  let sections = [];
  try {
    const sectionsCollection = app.findCollectionByNameOrId('page_sections');
    sections = app.findRecordsByFilter(
      sectionsCollection.id,
      'sectionType = "category_split_tabs"',
      '',
      200,
      0,
    );
  } catch (_) {
    return false;
  }
  for (const section of sections) {
    const config = asConfigObject(section.get('config'));
    if (String(config.displayMode || '').trim().toLowerCase() === 'expansible') {
      return true;
    }
  }
  return false;
}

migrate(
  (app) => {
    const collection = findCollectionOrNull(app);
    if (!collection) {
      throw new Error('storefront_settings collection is required');
    }

    ensureField(collection);
    app.save(collection);

    const saved = app.findCollectionByNameOrId(collection.id);
    const navigation = ensureNavigationRecord(app, saved);
    const current = navigation.getString(FIELD_NAME).trim();
    if (current === 'tabs' || current === 'expansible') {
      return;
    }

    navigation.set(
      FIELD_NAME,
      hasLegacyExpansibleSection(app) ? 'expansible' : 'tabs',
    );
    app.save(navigation);
  },
  () => {
    // Data backfill rollback intentionally no-ops; admins may have changed the
    // setting after this migration ran.
  },
);
