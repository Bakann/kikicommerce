/// <reference path="../pb_data/types.d.ts" />

// V1 guest carts use X-Cart-Guest-Id as a bearer token. Client-written totals
// are display-only and must be recomputed server-side before checkout.

const CARTS_ID = 'cartsv1a000000';

migrate(
  (app) => {
    const usersId = app.findCollectionByNameOrId('users').id;

    const collection = new Collection({
      id: CARTS_ID,
      name: 'carts',
      type: 'base',
      system: false,
      listRule:
        '(@request.auth.id != "" && user = @request.auth.id) || (user = "" && guest_id != "" && @request.headers.x_cart_guest_id = guest_id)',
      viewRule:
        '(@request.auth.id != "" && user = @request.auth.id) || (user = "" && guest_id != "" && @request.headers.x_cart_guest_id = guest_id)',
      createRule:
        '(@request.auth.id != "" && @request.body.user = @request.auth.id) || ((@request.body.user:isset = false || @request.body.user = "") && @request.body.guest_id != "" && @request.body.guest_id = @request.headers.x_cart_guest_id)',
      updateRule:
        '((@request.auth.id != "" && user = @request.auth.id) || (user = "" && guest_id != "" && @request.headers.x_cart_guest_id = guest_id)) && (@request.auth.id != "" || (@request.body.user:isset = false && @request.body.guest_id:isset = false && @request.body.currency_code:isset = false && @request.body.status:isset = false))',
      deleteRule: '@request.auth.id != "" && user = @request.auth.id',
      indexes: [
        'CREATE INDEX idx_carts_guest_id ON carts (guest_id)',
        'CREATE INDEX idx_carts_user ON carts (user)',
        "CREATE UNIQUE INDEX idx_carts_guest_active ON carts (guest_id) WHERE status = 'active'",
      ],
      fields: [
        {
          name: 'user',
          type: 'relation',
          required: false,
          options: {
            collectionId: usersId,
            maxSelect: 1,
            cascadeDelete: false,
          },
        },
        {
          name: 'guest_id',
          type: 'text',
          required: false,
          options: { pattern: '^[0-9a-f-]{36}$', max: 36 },
        },
        {
          name: 'status',
          type: 'select',
          required: true,
          options: {
            maxSelect: 1,
            values: ['active', 'converted', 'abandoned'],
            default: 'active',
          },
        },
        {
          name: 'currency_code',
          type: 'text',
          required: true,
          options: { pattern: '^[A-Z]{3}$', min: 3, max: 3, default: 'EUR' },
        },
        {
          name: 'subtotal',
          type: 'number',
          required: true,
          options: { min: 0, default: 0 },
        },
        {
          name: 'discount_total',
          type: 'number',
          required: true,
          options: { min: 0, default: 0 },
        },
        {
          name: 'shipping_total',
          type: 'number',
          required: true,
          options: { min: 0, default: 0 },
        },
        {
          name: 'tax_total',
          type: 'number',
          required: true,
          options: { min: 0, default: 0 },
        },
        {
          name: 'grand_total',
          type: 'number',
          required: true,
          options: { min: 0, default: 0 },
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
    const collection = app.findCollectionByNameOrId(CARTS_ID);
    return app.delete(collection);
  },
);
