/// <reference path="../pb_data/types.d.ts" />

// Runtime bundle for the Foil studio's 2.5D/Depth Anything renderer. The
// classic `foil` and `mask` fields remain unchanged, so existing storefronts
// and existing records keep working while the new renderer is rolled out.
const COLLECTION = 'product_foils';
const ADDED_FIELDS = [
  'product_image',
  'subject_mask',
  'background_clean',
  'rim',
  'depth_map',
  'depth_mesh',
  'particles',
];

function addImageField(collection, name) {
  if (collection.fields.getByName(name)) return;
  collection.fields.add(
    new FileField({
      name,
      required: false,
      maxSelect: 1,
      maxSize: 5242880,
      mimeTypes: ['image/webp', 'image/png', 'image/jpeg'],
    }),
  );
}

migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId(COLLECTION);
    for (const name of [
      'product_image',
      'subject_mask',
      'background_clean',
      'rim',
      'depth_map',
    ]) {
      addImageField(collection, name);
    }
    if (!collection.fields.getByName('depth_mesh')) {
      collection.fields.add(
        new JSONField({ name: 'depth_mesh', required: false, maxSize: 200000 }),
      );
    }
    if (!collection.fields.getByName('particles')) {
      collection.fields.add(
        new JSONField({ name: 'particles', required: false, maxSize: 200000 }),
      );
    }
    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId(COLLECTION);
    for (const name of ADDED_FIELDS) {
      const field = collection.fields.getByName(name);
      if (field) collection.fields.remove(field);
    }
    app.save(collection);
  },
);
