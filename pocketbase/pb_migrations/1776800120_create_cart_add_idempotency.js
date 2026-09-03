/// <reference path="../pb_data/types.d.ts" />

const CART_ADD_IDEMPOTENCY_ID = 'cartaddidem0001';

migrate(
  (app) => {
    const collection = new Collection({
      id: CART_ADD_IDEMPOTENCY_ID,
      name: 'cart_add_idempotency',
      type: 'base',
      system: false,
      listRule: null,
      viewRule: null,
      createRule: null,
      updateRule: null,
      deleteRule: null,
      indexes: [
        'CREATE UNIQUE INDEX idx_cart_add_idempotency_guest_key ON cart_add_idempotency (guest_id, idempotency_key)',
      ],
      fields: [
        {
          name: 'guest_id',
          type: 'text',
          required: true,
          options: { pattern: '^[0-9a-f-]{36}$', max: 36 },
        },
        {
          name: 'idempotency_key',
          type: 'text',
          required: true,
          options: { max: 128 },
        },
        {
          name: 'request_hash',
          type: 'text',
          required: true,
          options: { max: 128 },
        },
        {
          name: 'response_body',
          type: 'text',
          required: true,
          options: { max: 4096 },
        },
        {
          name: 'status_code',
          type: 'number',
          required: true,
          options: { min: 200, max: 599, noDecimal: true, default: 200 },
        },
        {
          name: 'created',
          type: 'autodate',
          system: false,
          onCreate: true,
          onUpdate: false,
        },
      ],
    });

    return app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId(CART_ADD_IDEMPOTENCY_ID);
    return app.delete(collection);
  },
);
