/// <reference path="../pb_data/types.d.ts" />

const CMS_PAGES_ID = 'cmspagesv1a000';

migrate(
  (app) => {
    const collection = new Collection({
      id: CMS_PAGES_ID,
      name: 'pages',
      type: 'base',
      system: false,
      listRule: '',
      viewRule: '',
      createRule: "@request.auth.id != ''",
      updateRule: "@request.auth.id != ''",
      deleteRule: "@request.auth.id != ''",
      indexes: [
        'CREATE UNIQUE INDEX idx_pages_code_locale ON pages (code, locale)',
        'CREATE INDEX idx_pages_active ON pages (isActive)',
      ],
      fields: [
        {
          name: 'code',
          type: 'text',
          required: true,
          min: 1,
          max: 64,
          pattern: '^[a-z0-9_]+$',
        },
        {
          name: 'locale',
          type: 'text',
          required: true,
          min: 2,
          max: 5,
          pattern: '^[a-z]{2}(-[a-z]{2})?$',
        },
        {
          name: 'title',
          type: 'text',
          required: true,
          min: 1,
          max: 200,
        },
        {
          name: 'isActive',
          type: 'bool',
          required: false,
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
    const collection = app.findCollectionByNameOrId(CMS_PAGES_ID);
    return app.delete(collection);
  },
);
