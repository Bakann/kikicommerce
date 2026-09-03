/// <reference path="../pb_data/types.d.ts" />

const NAV_MENUS_ID = 'navmenusv1a000';

function setDisplayModeValues(app, values) {
  const collection = app.findCollectionByNameOrId(NAV_MENUS_ID);
  const field = collection.fields.getByName('displayMode');

  if (typeof field.values !== 'undefined') {
    field.maxSelect = 1;
    field.values = values;
  } else {
    field.options = field.options || {};
    field.options.maxSelect = 1;
    field.options.values = values;
  }

  return app.save(collection);
}

migrate(
  (app) => setDisplayModeValues(app, ['drawer', 'categories']),
  (app) => setDisplayModeValues(app, ['drawer']),
);
