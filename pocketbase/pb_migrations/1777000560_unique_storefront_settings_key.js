/// <reference path="../pb_data/types.d.ts" />

// Adds a UNIQUE index on `storefront_settings.key` so subsequent runtime
// writes can't accidentally create parallel records (which is what caused
// the active_theme orphan loop earlier).
//
// The validation/dedup logic between BEGIN/END DEDUP CORE markers below
// is a VERBATIM copy of `pocketbase/pb_lib/storefront_settings_dedup.js`.
// The pb_lib version is what the node:test suite exercises; a CI guard
// (test/pocketbase/storefront_settings_dedup_sync_test.js) compares the
// two marked blocks byte-for-byte to catch drift. Keep them in sync.
//
// The migration itself uses the same planner shape (`decideDedup`) as
// the tests: collect records, call decideDedup, abort on `abortReason`,
// otherwise apply the planned `toDelete` via `app.delete`. This means
// the codepath the tests exercise IS the codepath the migration runs,
// minus the thin `findRecordsByFilter` + `app.delete` I/O wrapping.

const STOREFRONT_SETTINGS_NAME = 'storefront_settings';
const UNIQUE_KEY_INDEX =
  'CREATE UNIQUE INDEX idx_storefront_settings_key_unique ON storefront_settings (`key`)';
const PAGE_SIZE = 500;

function addIndexIfMissing(collection, indexSql) {
  collection.indexes = collection.indexes || [];
  if (!collection.indexes.includes(indexSql)) {
    collection.indexes.push(indexSql);
  }
}

function removeIndex(collection, indexSql) {
  collection.indexes = (collection.indexes || []).filter(
    (existing) => existing !== indexSql,
  );
}

// BEGIN DEDUP CORE
const VALID_NAVIGATION_STYLES = new Set(['drawer', 'fullscreenReveal']);
const VALID_ACTIVE_THEMES = new Set(['dior', 'nike']);
const KNOWN_KEYS = new Set(['brand', 'navigation', 'active_theme']);

// Normalisation must match the Dart parsers exactly:
//   - StorefrontTheme.fromWireName     -> trim().toLowerCase()
//   - MobileMenuStyle.fromValue        -> trim()
//   - StorefrontBrandSettings.fromJson -> trim()
function normalizeTheme(raw) {
  return (raw || '').trim().toLowerCase();
}

function normalizeStyle(raw) {
  return (raw || '').trim();
}

function normalizeText(raw) {
  return (raw || '').trim();
}

// `record` is anything that exposes a `.getString(field)` method — both
// PB records and plain test stubs satisfy this.
function isValid(record, key) {
  switch (key) {
    case 'brand': {
      const title = normalizeText(record.getString('brandTitle'));
      const href = normalizeText(record.getString('brandHref'));
      return title.length > 0 && href.length > 0;
    }
    case 'navigation': {
      const style = normalizeStyle(record.getString('mobileMenuStyle'));
      return VALID_NAVIGATION_STYLES.has(style);
    }
    case 'active_theme': {
      const theme = normalizeTheme(record.getString('theme'));
      return VALID_ACTIVE_THEMES.has(theme);
    }
    default:
      return false;
  }
}

// JSON.stringify (not `${title}|${href}`) so titles or hrefs that
// contain the separator don't collide.
function resolvedValueFor(record, key) {
  switch (key) {
    case 'brand':
      return JSON.stringify({
        title: normalizeText(record.getString('brandTitle')),
        href: normalizeText(record.getString('brandHref')),
      });
    case 'navigation':
      return normalizeStyle(record.getString('mobileMenuStyle'));
    case 'active_theme':
      return normalizeTheme(record.getString('theme'));
    default:
      return '';
  }
}

// Pure planning step. Returns the IDs to delete + keep, plus an abort
// reason if the migration should refuse to apply. This is what the
// node:test suite exercises end-to-end. The migration calls a verbatim
// copy of this function and then applies `toDelete` via `app.delete`.
function decideDedup(records, pageSize) {
  if (typeof pageSize === 'number' && records.length === pageSize) {
    return {
      toDelete: [],
      toKeep: [],
      abortReason:
        'storefront_settings: ' +
        pageSize +
        ' records returned (page cap). Possible pagination truncation — ' +
        'increase pageSize or paginate before deduping.',
    };
  }

  const toDelete = [];
  const toKeep = [];
  const byKey = new Map();

  for (const record of records) {
    const key = record.getString('key');
    if (!key || key.length === 0) {
      toDelete.push({ id: record.id, reason: 'empty_key' });
      continue;
    }
    if (!byKey.has(key)) byKey.set(key, []);
    byKey.get(key).push(record);
  }

  for (const [key, group] of byKey.entries()) {
    if (group.length === 1) {
      toKeep.push({ id: group[0].id, key: key });
      continue;
    }
    if (!KNOWN_KEYS.has(key)) {
      return {
        toDelete: [],
        toKeep: [],
        abortReason:
          'storefront_settings: unknown key "' +
          key +
          '" has ' +
          group.length +
          ' duplicate records. Migration refuses to silently delete ' +
          'unknown keys — clean them up via the admin first.',
      };
    }

    const valid = group.filter((r) => isValid(r, key));
    if (valid.length === 0) {
      return {
        toDelete: [],
        toKeep: [],
        abortReason:
          'storefront_settings: cannot dedup key "' +
          key +
          '" — all ' +
          group.length +
          ' records failed content validation. ' +
          'Inspect manually before retrying.',
      };
    }

    const distinct = new Set(valid.map((r) => resolvedValueFor(r, key)));
    if (distinct.size > 1) {
      const summary = Array.from(distinct).join(', ');
      return {
        toDelete: [],
        toKeep: [],
        abortReason:
          'storefront_settings: key "' +
          key +
          '" has ' +
          valid.length +
          ' valid records with conflicting values (' +
          summary +
          '). Migration refuses to pick one — resolve via the admin first.',
      };
    }

    const kept = valid[0];
    toKeep.push({ id: kept.id, key: key });
    for (const record of group) {
      if (record.id !== kept.id) {
        toDelete.push({ id: record.id, reason: 'duplicate', key: key });
      }
    }
  }

  return { toDelete: toDelete, toKeep: toKeep, abortReason: null };
}
// END DEDUP CORE

function applyDedup(app, collection) {
  // +id is the only universally-available sort target on this collection
  // (no auto-timestamp fields). It gives a stable, deterministic order so
  // re-runs of the migration always plan the same way.
  const records = app.findRecordsByFilter(
    collection.id,
    '',
    '+id',
    PAGE_SIZE,
    0,
  );

  const plan = decideDedup(records, PAGE_SIZE);
  if (plan.abortReason) {
    throw new Error(plan.abortReason);
  }

  // Map lookup is O(1) per delete vs O(n) for records.find(); the
  // dataset is tiny but the cleaner shape avoids quadratic blowup if
  // a future schema lets storefront_settings grow.
  const recordsById = new Map(records.map((r) => [r.id, r]));
  for (const target of plan.toDelete) {
    const found = recordsById.get(target.id);
    if (found) app.delete(found);
  }
}

migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId(STOREFRONT_SETTINGS_NAME);
    applyDedup(app, collection);

    // Re-fetch so the collection reference is fresh after the deletes.
    const fresh = app.findCollectionByNameOrId(STOREFRONT_SETTINGS_NAME);
    addIndexIfMissing(fresh, UNIQUE_KEY_INDEX);
    app.save(fresh);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId(STOREFRONT_SETTINGS_NAME);
    removeIndex(collection, UNIQUE_KEY_INDEX);
    app.save(collection);
  },
);
