/// <reference path="../pb_data/types.d.ts" />

// Phase 2: adds `brand_segment`, `category_split_tabs`, and
// `category_banner_strip` to the allowed values of
// `page_sections.sectionType`. Required before the phase 2 seed migration
// can insert these section types. Idempotent — skips values already present.

const CMS_PAGE_SECTIONS_ID = 'cmspagesecv1a0';
const NEW_VALUES = [
  'brand_segment',
  'category_split_tabs',
  'category_banner_strip',
];

function readSelectValues(field) {
  if (typeof field.values !== 'undefined') return field.values || [];
  return (field.options && field.options.values) || [];
}

function writeSelectValues(field, values) {
  if (typeof field.values !== 'undefined') {
    field.values = values;
  } else {
    field.options = field.options || {};
    field.options.values = values;
  }
}

migrate(
  (app) => {
    const sections = app.findCollectionByNameOrId(CMS_PAGE_SECTIONS_ID);
    const field = sections.fields.getByName('sectionType');
    const current = readSelectValues(field);
    const missing = NEW_VALUES.filter((v) => !current.includes(v));
    if (missing.length === 0) return;
    writeSelectValues(field, [...current, ...missing]);
    app.save(sections);
  },
  (app) => {
    const sections = app.findCollectionByNameOrId(CMS_PAGE_SECTIONS_ID);
    const field = sections.fields.getByName('sectionType');
    const current = readSelectValues(field);
    const next = current.filter((value) => !NEW_VALUES.includes(value));
    writeSelectValues(field, next);
    app.save(sections);
  },
);
