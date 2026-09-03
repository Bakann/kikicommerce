/// <reference path="../pb_data/types.d.ts" />

function fieldExists(collection, name) {
  return !!collection.fields.getByName(name);
}

function addFieldIfMissing(collection, name, fieldFactory) {
  if (fieldExists(collection, name)) return;
  collection.fields.add(fieldFactory());
}

function removeFieldIfPresent(collection, name) {
  const field = collection.fields.getByName(name);
  if (!field) return;
  collection.fields.remove(field);
}

function addIndexIfMissing(collection, indexSql) {
  collection.indexes = collection.indexes || [];
  if (!collection.indexes.includes(indexSql)) {
    collection.indexes.push(indexSql);
  }
}

migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId('categories');
    addFieldIfMissing(
      collection,
      'position',
      () =>
        new NumberField({
          name: 'position',
          required: false,
          min: 0,
          onlyInt: true,
        }),
    );
    addFieldIfMissing(
      collection,
      'isHidden',
      () =>
        new BoolField({
          name: 'isHidden',
          required: false,
          default: false,
        }),
    );
    addIndexIfMissing(
      collection,
      'CREATE INDEX idx_categories_drawer_order ON categories (isActive, isHidden, parent, position)',
    );
    return app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId('categories');
    collection.indexes = (collection.indexes || []).filter(
      (indexSql) =>
        indexSql !==
        'CREATE INDEX idx_categories_drawer_order ON categories (isActive, isHidden, parent, position)',
    );
    removeFieldIfPresent(collection, 'position');
    removeFieldIfPresent(collection, 'isHidden');
    return app.save(collection);
  },
);
