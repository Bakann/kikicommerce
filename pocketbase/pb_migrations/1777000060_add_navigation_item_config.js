/// <reference path="../pb_data/types.d.ts" />

const NAV_ITEMS_ID = 'navitemsv1a000';

function fieldExists(collection, name) {
  return !!collection.fields.getByName(name);
}

migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId(NAV_ITEMS_ID);
    if (!fieldExists(collection, 'config')) {
      collection.fields.add(new JSONField({
        name: 'config',
        required: false,
        maxSize: 200000,
      }));
    }
    return app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId(NAV_ITEMS_ID);
    const field = collection.fields.getByName('config');
    if (field) {
      collection.fields.remove(field);
    }
    return app.save(collection);
  },
);
