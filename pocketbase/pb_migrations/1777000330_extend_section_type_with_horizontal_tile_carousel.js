/// <reference path="../pb_data/types.d.ts" />

// Adds `horizontal_tile_carousel` to the allowed values of
// `page_sections.sectionType`. Required before
// `1777000360_seed_homepage_nike_fr.js` can insert Nike-themed sections.
// Idempotent: skips if the value is already present.

const CMS_PAGE_SECTIONS_ID = 'cmspagesecv1a0';
const NEW_VALUE = 'horizontal_tile_carousel';

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
    if (current.includes(NEW_VALUE)) return;
    writeSelectValues(field, [...current, NEW_VALUE]);
    app.save(sections);
  },
  (app) => {
    const sections = app.findCollectionByNameOrId(CMS_PAGE_SECTIONS_ID);
    const field = sections.fields.getByName('sectionType');
    const current = readSelectValues(field);
    const next = current.filter((value) => value !== NEW_VALUE);
    writeSelectValues(field, next);
    app.save(sections);
  },
);
