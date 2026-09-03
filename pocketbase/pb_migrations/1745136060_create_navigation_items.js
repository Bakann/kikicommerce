/// <reference path="../pb_data/types.d.ts" />

const NAV_MENUS_ID = 'navmenusv1a000';
const NAV_ITEMS_ID = 'navitemsv1a000';

migrate(
  (app) => {
    const categoriesId = app.findCollectionByNameOrId('categories').id;
    const productsId = app.findCollectionByNameOrId('products').id;
    const mediasId = app.findCollectionByNameOrId('medias').id;

    const collection = new Collection({
      id: NAV_ITEMS_ID,
      name: 'navigation_items',
      type: 'base',
      system: false,
      listRule: '',
      viewRule: '',
      createRule: "@request.auth.id != ''",
      updateRule: "@request.auth.id != ''",
      deleteRule: "@request.auth.id != ''",
      indexes: [
        'CREATE INDEX idx_navigation_items_menu ON navigation_items (menu)',
        'CREATE INDEX idx_navigation_items_parent ON navigation_items (parent)',
        'CREATE INDEX idx_navigation_items_menu_parent ON navigation_items (menu, parent)',
        'CREATE INDEX idx_navigation_items_menu_position ON navigation_items (menu, position)',
        'CREATE INDEX idx_navigation_items_menu_active ON navigation_items (menu, isActive)',
      ],
      fields: [
        {
          name: 'menu',
          type: 'relation',
          required: true,
          options: {
            collectionId: NAV_MENUS_ID,
            maxSelect: 1,
            cascadeDelete: true,
          },
        },
        {
          name: 'parent',
          type: 'relation',
          required: false,
          options: {
            collectionId: NAV_ITEMS_ID,
            maxSelect: 1,
            cascadeDelete: false,
          },
        },
        {
          name: 'position',
          type: 'number',
          required: true,
          options: { min: 0, noDecimal: true, default: 0 },
        },
        {
          name: 'label',
          type: 'text',
          required: true,
          options: { min: 1, max: 160 },
        },
        {
          name: 'itemType',
          type: 'select',
          required: true,
          options: {
            maxSelect: 1,
            values: ['category', 'product', 'page', 'external'],
          },
        },
        {
          name: 'category',
          type: 'relation',
          required: false,
          options: {
            collectionId: categoriesId,
            maxSelect: 1,
            cascadeDelete: false,
          },
        },
        {
          name: 'product',
          type: 'relation',
          required: false,
          options: {
            collectionId: productsId,
            maxSelect: 1,
            cascadeDelete: false,
          },
        },
        {
          name: 'pageKey',
          type: 'text',
          required: false,
          options: { pattern: '^[a-z0-9_]+$', max: 64 },
        },
        {
          name: 'url',
          type: 'url',
          required: false,
        },
        {
          name: 'promoMedia',
          type: 'relation',
          required: false,
          options: {
            collectionId: mediasId,
            maxSelect: 1,
            cascadeDelete: false,
          },
        },
        {
          name: 'placement',
          type: 'select',
          required: true,
          options: { maxSelect: 1, values: ['nav', 'promo'], default: 'nav' },
        },
        {
          name: 'desktopDrawerTemplate',
          type: 'select',
          required: false,
          options: {
            maxSelect: 1,
            values: [
              'list_only',
              'hero_single',
              'promo_grid_2x2',
              'promo_stack_2',
            ],
          },
        },
        {
          name: 'isActive',
          type: 'bool',
          required: true,
          options: { default: true },
        },
        {
          name: 'isHidden',
          type: 'bool',
          required: true,
          options: { default: false },
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
    const collection = app.findCollectionByNameOrId(NAV_ITEMS_ID);
    return app.delete(collection);
  },
);
