/// <reference path="../pb_data/types.d.ts" />

const NAV_MENUS_ID = 'navmenusv1a000';

migrate(
  (app) => {
    const collection = new Collection({
      id: NAV_MENUS_ID,
      name: 'navigation_menus',
      type: 'base',
      system: false,
      listRule: '',
      viewRule: '',
      createRule: "@request.auth.id != ''",
      updateRule: "@request.auth.id != ''",
      deleteRule: "@request.auth.id != ''",
      indexes: [
        'CREATE UNIQUE INDEX idx_navigation_menus_code ON navigation_menus (code)',
        'CREATE INDEX idx_navigation_menus_active ON navigation_menus (isActive)',
      ],
      fields: [
        {
          name: 'name',
          type: 'text',
          required: true,
          options: { min: 1, max: 160 },
        },
        {
          name: 'code',
          type: 'text',
          required: true,
          options: { pattern: '^[a-z0-9_]+$', min: 1, max: 64 },
        },
        {
          name: 'displayMode',
          type: 'select',
          required: true,
          options: { maxSelect: 1, values: ['drawer'] },
        },
        {
          name: 'isActive',
          type: 'bool',
          required: true,
          options: { default: true },
        },
        {
          name: 'created',
          type: 'autodate',
          system: false,
          onCreate: true,
          onUpdate: false,
        },
        {
          name: 'updated',
          type: 'autodate',
          system: false,
          onCreate: true,
          onUpdate: true,
        },
      ],
    });

    return app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId(NAV_MENUS_ID);
    return app.delete(collection);
  },
);
