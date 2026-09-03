/// <reference path="../pb_data/types.d.ts" />

// Applies the Kiki naming to catalog records that may already exist in a
// deployed PocketBase instance. Fresh databases already receive the updated
// wording from the earlier seed migrations.
const RECORD_UPDATES = [
  {
    collection: 'products',
    id: 'ra6tjkbv46mhqyr',
    fields: {
      brand: 'Kiki Atelier',
      searchIndex:
        'robe kiki atelier robe kiki atelier <p>robe rouge legere inspiree de kiki < p> <p>coton doux coupe ample finitions contrastees et poche discrete < p> kiki atelier robe 3760350100011 prod robe 001',
    },
  },
  {
    collection: 'products',
    id: 'aokhsveaq4ov77j',
    fields: {
      brand: 'Kiki Atelier',
      searchIndex:
        'robe chihiro voyage <p>robe fluide pensee pour les journees de voyage < p> <p>viscose souple imprime discret et ceinture ton sur ton < p> kiki atelier robe 3760350100028 prod robe 002',
    },
  },
  {
    collection: 'categories',
    id: '6s2lgwg23oh5npw',
    fields: {
      description: 'Collection capsule de robes inspirees des heroines Kiki.',
      name: 'Robes Studio Kiki',
      slug: 'robes-studio-kiki',
    },
  },
  {
    collection: 'category_translations',
    id: 'lzvc2k1hk8iiobx',
    fields: {
      description: 'A capsule collection of dresses inspired by Kiki heroines.',
      name: 'Studio Kiki Dresses',
    },
  },
];

migrate(
  (app) => {
    for (const update of RECORD_UPDATES) {
      try {
        const collection = app.findCollectionByNameOrId(update.collection);
        const record = app.findRecordById(collection.id, update.id);
        for (const field of Object.keys(update.fields)) {
          record.set(field, update.fields[field]);
        }
        app.save(record);
      } catch (_) {
        // Optional seed data may not exist in every environment.
      }
    }
  },
  () => {
    // Brand migrations are intentionally irreversible: rolling back must not
    // restore retired wording in user-visible catalog data.
  },
);
