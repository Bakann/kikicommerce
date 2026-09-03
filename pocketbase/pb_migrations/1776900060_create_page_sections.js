/// <reference path="../pb_data/types.d.ts" />

const CMS_PAGES_ID = 'cmspagesv1a000';
const CMS_PAGE_SECTIONS_ID = 'cmspagesecv1a0';

migrate(
  (app) => {
    const collection = new Collection({
      id: CMS_PAGE_SECTIONS_ID,
      name: 'page_sections',
      type: 'base',
      system: false,
      listRule: '',
      viewRule: '',
      createRule: "@request.auth.id != ''",
      updateRule: "@request.auth.id != ''",
      deleteRule: "@request.auth.id != ''",
      indexes: [
        'CREATE INDEX idx_page_sections_page ON page_sections (page)',
        'CREATE INDEX idx_page_sections_page_position ON page_sections (page, position)',
        'CREATE INDEX idx_page_sections_page_active ON page_sections (page, isActive)',
      ],
      fields: [
        {
          name: 'page',
          type: 'relation',
          required: true,
          collectionId: CMS_PAGES_ID,
          maxSelect: 1,
          cascadeDelete: true,
        },
        {
          name: 'sectionId',
          type: 'text',
          required: true,
          min: 1,
          max: 64,
          pattern: '^[a-z0-9_-]+$',
        },
        {
          name: 'sectionType',
          type: 'select',
          required: true,
          maxSelect: 1,
          values: [
            'hero_campaign',
            'editorial_story',
            'category_tiles',
            'featured_products',
            'service_cards',
          ],
        },
        {
          name: 'position',
          type: 'number',
          required: false,
          min: 0,
          onlyInt: true,
        },
        {
          name: 'isActive',
          type: 'bool',
          required: false,
        },
        {
          name: 'config',
          type: 'json',
          required: true,
          maxSize: 200000,
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
    const collection = app.findCollectionByNameOrId(CMS_PAGE_SECTIONS_ID);
    return app.delete(collection);
  },
);
