'use strict';

// Pure dedup/validation logic for `1777000560_unique_storefront_settings_key.js`.
//
// This file lives in pb_lib/ (NOT pb_hooks/) on purpose: it's not a
// PocketBase runtime hook, it's a testable shared module. PB only
// auto-loads files in pb_hooks/ as JS hooks; pb_lib/ is a project-local
// convention for testable JS helpers that the migration also references.
//
// The block between BEGIN/END DEDUP CORE markers below is copied verbatim
// into the migration file. A CI guard
// (test/pocketbase/storefront_settings_dedup_sync_test.js) compares the
// two blocks byte-for-byte to catch drift. If you change anything inside
// the markers, update BOTH files in the same commit.

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

module.exports = {
  VALID_NAVIGATION_STYLES: VALID_NAVIGATION_STYLES,
  VALID_ACTIVE_THEMES: VALID_ACTIVE_THEMES,
  KNOWN_KEYS: KNOWN_KEYS,
  normalizeTheme: normalizeTheme,
  normalizeStyle: normalizeStyle,
  normalizeText: normalizeText,
  isValid: isValid,
  resolvedValueFor: resolvedValueFor,
  decideDedup: decideDedup,
};
