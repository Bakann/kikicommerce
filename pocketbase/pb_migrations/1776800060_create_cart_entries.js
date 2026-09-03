/// <reference path="../pb_data/types.d.ts" />

// V1 intentionally aggregates by product only. Size/variant-specific lines
// will require an additive migration for a variant field and unique index.

const CARTS_ID = 'cartsv1a000000';
const CART_ENTRIES_ID = 'cartentriesv1a0';

migrate(
  (app) => {
    const productsId = app.findCollectionByNameOrId('products').id;

    const collection = new Collection({
      id: CART_ENTRIES_ID,
      name: 'cart_entries',
      type: 'base',
      system: false,
      listRule:
        '(@request.auth.id != "" && cart.user = @request.auth.id) || (cart.user = "" && cart.guest_id != "" && @request.headers.x_cart_guest_id = cart.guest_id)',
      viewRule:
        '(@request.auth.id != "" && cart.user = @request.auth.id) || (cart.user = "" && cart.guest_id != "" && @request.headers.x_cart_guest_id = cart.guest_id)',
      createRule:
        '(@request.auth.id != "" && cart.user = @request.auth.id) || (cart.user = "" && cart.guest_id != "" && @request.headers.x_cart_guest_id = cart.guest_id)',
      updateRule:
        '(@request.auth.id != "" && cart.user = @request.auth.id) || (cart.user = "" && cart.guest_id != "" && @request.headers.x_cart_guest_id = cart.guest_id)',
      deleteRule:
        '(@request.auth.id != "" && cart.user = @request.auth.id) || (cart.user = "" && cart.guest_id != "" && @request.headers.x_cart_guest_id = cart.guest_id)',
      indexes: [
        'CREATE INDEX idx_cart_entries_cart ON cart_entries (cart)',
        'CREATE UNIQUE INDEX idx_cart_entries_cart_product ON cart_entries (cart, product)',
      ],
      fields: [
        {
          name: 'cart',
          type: 'relation',
          required: true,
          options: {
            collectionId: CARTS_ID,
            maxSelect: 1,
            cascadeDelete: true,
          },
        },
        {
          name: 'product',
          type: 'relation',
          required: true,
          options: {
            collectionId: productsId,
            maxSelect: 1,
            cascadeDelete: false,
          },
        },
        {
          name: 'sku_snapshot',
          type: 'text',
          required: false,
          options: { max: 64 },
        },
        {
          name: 'product_name_snapshot',
          type: 'text',
          required: true,
          options: { min: 1, max: 320 },
        },
        {
          name: 'quantity',
          type: 'number',
          required: true,
          options: { min: 1, noDecimal: true, default: 1 },
        },
        {
          name: 'unit_price',
          type: 'number',
          required: true,
          options: { min: 0 },
        },
        {
          name: 'line_total',
          type: 'number',
          required: true,
          options: { min: 0 },
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
    const collection = app.findCollectionByNameOrId(CART_ENTRIES_ID);
    return app.delete(collection);
  },
);
