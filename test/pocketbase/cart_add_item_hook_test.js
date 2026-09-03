const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

const cartAddItem = require('../../pocketbase/pb_hooks/cart_add_item.js');

test('processAddItemRequest creates a cart, writes an entry, and stores idempotency on cold path', () => {
  const state = createState();

  const result = cartAddItem.processAddItemRequest(
    createDeps(state),
    request(),
  );

  assert.equal(result.statusCode, 200);
  assert.equal(result.cartCreated, true);
  assert.equal(result.idempotencyHit, false);
  assert.equal(result.pathMode, 'cold');
  assert.deepEqual(result.body, {
    cartId: 'cart-1',
    entryProductId: 'prod-1',
    quantityDelta: 2,
    cartCreated: true,
  });
  assert.equal(state.carts.length, 1);
  assert.equal(state.entries.length, 1);
  assert.equal(state.entries[0].quantity, 2);
  assert.equal(state.idempotency.length, 1);
});

test('processAddItemRequest replays a stored idempotent response without opening a transaction', () => {
  const state = createState();
  state.idempotency.push({
    guestId: 'guest-1',
    idempotencyKey: 'idem-1',
    requestHash: sha256(JSON.stringify(['prod-1', 'price-1', 2])),
    responseBody: JSON.stringify({
      cartId: 'cart-1',
      entryProductId: 'prod-1',
      quantityDelta: 2,
      cartCreated: false,
    }),
    statusCode: 200,
  });

  let transactionCalls = 0;
  const deps = createDeps(state, {
    runInTransaction(fn) {
      transactionCalls += 1;
      return fn(createTxDeps(state));
    },
  });

  const result = cartAddItem.processAddItemRequest(deps, request());

  assert.equal(result.statusCode, 200);
  assert.equal(result.idempotencyHit, true);
  assert.equal(result.pathMode, 'warm');
  assert.equal(transactionCalls, 0);
});

test('processAddItemRequest returns a route error for cart currency mismatches', () => {
  const state = createState();
  state.carts.push({
    id: 'cart-1',
    guestId: 'guest-1',
    userId: '',
    currencyCode: 'USD',
  });

  assert.throws(
    () => cartAddItem.processAddItemRequest(createDeps(state), request()),
    (error) => {
      assert.equal(error.statusCode, 409);
      assert.equal(error.body.code, 'cart_currency_mismatch');
      assert.equal(error.body.cartCurrencyCode, 'USD');
      return true;
    },
  );
});

test('processAddItemRequest rejects reusing an idempotency key with a different payload', () => {
  const state = createState();
  state.idempotency.push({
    guestId: 'guest-1',
    idempotencyKey: 'idem-1',
    requestHash: sha256(JSON.stringify(['prod-1', 'price-1', 1])),
    responseBody: JSON.stringify({
      cartId: 'cart-1',
      entryProductId: 'prod-1',
      quantityDelta: 1,
      cartCreated: false,
    }),
    statusCode: 200,
  });

  assert.throws(
    () => cartAddItem.processAddItemRequest(createDeps(state), request()),
    (error) => {
      assert.equal(error.statusCode, 409);
      assert.equal(error.body.code, 'idempotency_key_reused');
      return true;
    },
  );
});

test('processAddItemRequest handles a concurrent entry create conflict by re-reading and incrementing', () => {
  const state = createState();
  state.carts.push({
    id: 'cart-1',
    guestId: 'guest-1',
    userId: '',
    currencyCode: 'EUR',
  });
  let firstCreate = true;

  const deps = createDeps(state, {
    runInTransaction(fn) {
      return fn(
        createTxDeps(state, {
          createEntry(input) {
            if (firstCreate) {
              firstCreate = false;
              state.entries.push({
                id: 'entry-1',
                cartId: input.cartId,
                productId: input.productId,
                quantity: 1,
                unitPrice: input.unitPrice,
              });
              throw cartAddItem.createConflictError('entry', new Error('dup'));
            }
            return createTxDeps(state).createEntry(input);
          },
        }),
      );
    },
  });

  const result = cartAddItem.processAddItemRequest(deps, request());

  assert.equal(result.statusCode, 200);
  assert.equal(state.entries.length, 1);
  assert.equal(state.entries[0].quantity, 3);
});

test('processAddItemRequest lets idempotency conflicts roll back cart mutations before replay', () => {
  const state = createState();
  state.carts.push({
    id: 'cart-1',
    guestId: 'guest-1',
    userId: '',
    currencyCode: 'EUR',
  });
  state.entries.push({
    id: 'entry-1',
    cartId: 'cart-1',
    productId: 'prod-1',
    quantity: 2,
    unitPrice: 39,
  });
  const requestHash = sha256(JSON.stringify(['prod-1', 'price-1', 2]));
  let concurrentRecord = null;

  const deps = createDeps(state, {
    findIdempotency() {
      return concurrentRecord;
    },
    runInTransaction(fn) {
      const entrySnapshot = state.entries.map((entry) => ({ ...entry }));
      try {
        return fn(
          createTxDeps(state, {
            findIdempotency() {
              return null;
            },
            saveIdempotency() {
              concurrentRecord = {
                guestId: 'guest-1',
                idempotencyKey: 'idem-1',
                requestHash,
                responseBody: JSON.stringify({
                  cartId: 'cart-1',
                  entryProductId: 'prod-1',
                  quantityDelta: 2,
                  cartCreated: false,
                }),
                statusCode: 200,
              };
              throw cartAddItem.createConflictError(
                'idempotency',
                new Error('dup'),
              );
            },
          }),
        );
      } catch (error) {
        state.entries = entrySnapshot.map((entry) => ({ ...entry }));
        throw error;
      }
    },
  });

  const result = cartAddItem.processAddItemRequest(deps, request());

  assert.equal(result.statusCode, 200);
  assert.equal(result.idempotencyHit, true);
  assert.equal(state.entries.length, 1);
  assert.equal(state.entries[0].quantity, 2);
});

function request() {
  return {
    headers: {
      cartGuestId: 'guest-1',
      idempotencyKey: 'idem-1',
    },
    body: {
      productId: 'prod-1',
      priceId: 'price-1',
      quantity: 2,
    },
  };
}

function createState() {
  return {
    products: {
      'prod-1': {
        id: 'prod-1',
        code: 'SKU-1',
        name: 'Sac Totoro',
        isActive: true,
      },
    },
    prices: {
      'price-1': {
        id: 'price-1',
        productId: 'prod-1',
        currencyId: 'cur-eur',
        price: 39,
        isActive: true,
      },
    },
    currencies: {
      'cur-eur': 'EUR',
    },
    carts: [],
    entries: [],
    idempotency: [],
  };
}

function createDeps(state, overrides = {}) {
  return {
    sha256,
    findIdempotency(guestId, idempotencyKey) {
      return findIdempotency(state, guestId, idempotencyKey);
    },
    runInTransaction(fn) {
      return fn(createTxDeps(state));
    },
    ...overrides,
  };
}

function createTxDeps(state, overrides = {}) {
  return {
    findIdempotency(guestId, idempotencyKey) {
      return findIdempotency(state, guestId, idempotencyKey);
    },
    saveIdempotency(input) {
      state.idempotency.push({
        guestId: input.guestId,
        idempotencyKey: input.idempotencyKey,
        requestHash: input.requestHash,
        responseBody: JSON.stringify(input.responseBody),
        statusCode: input.statusCode,
      });
    },
    getProduct(productId) {
      return state.products[productId] || null;
    },
    getPriceRow(priceId) {
      return state.prices[priceId] || null;
    },
    getCurrencyCode(currencyId) {
      return state.currencies[currencyId] || '';
    },
    findActiveCart(guestId) {
      return (
        state.carts.find((cart) => cart.guestId === guestId) || null
      );
    },
    createGuestCart(guestId, currencyCode) {
      const cart = {
        id: `cart-${state.carts.length + 1}`,
        guestId,
        userId: '',
        currencyCode,
      };
      state.carts.push(cart);
      return cart;
    },
    findEntry(cartId, productId) {
      return (
        state.entries.find(
          (entry) => entry.cartId === cartId && entry.productId === productId,
        ) || null
      );
    },
    createEntry(input) {
      const entry = {
        id: `entry-${state.entries.length + 1}`,
        cartId: input.cartId,
        productId: input.productId,
        quantity: input.quantity,
        unitPrice: input.unitPrice,
      };
      state.entries.push(entry);
      return entry;
    },
    updateEntryQuantity(entry, quantity, unitPrice) {
      entry.quantity = quantity;
      entry.unitPrice = unitPrice;
      return entry;
    },
    ...overrides,
  };
}

function findIdempotency(state, guestId, idempotencyKey) {
  return (
    state.idempotency.find(
      (entry) =>
        entry.guestId === guestId &&
        entry.idempotencyKey === idempotencyKey,
    ) || null
  );
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}
