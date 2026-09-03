const test = require('node:test');
const assert = require('node:assert/strict');

const cartClear = require('../../pocketbase/pb_hooks/cart_clear.js');

test('processClearCartRequest deletes all owned entries and zeroes totals', () => {
  const state = createState();
  state.carts.push({
    id: 'cart-1',
    guestId: 'guest-1',
    userId: '',
    status: 'active',
    currencyCode: 'EUR',
    subtotal: 78,
    discountTotal: 4,
    shippingTotal: 6,
    taxTotal: 2,
    grandTotal: 82,
  });
  state.entries.push(
    { id: 'entry-1', cartId: 'cart-1' },
    { id: 'entry-2', cartId: 'cart-1' },
  );

  const result = cartClear.processClearCartRequest(
    createDeps(state),
    request(),
  );

  assert.equal(result.statusCode, 200);
  assert.equal(result.deletedCount, 2);
  assert.deepEqual(result.body.entries, []);
  assert.equal(result.body.deletedCount, 2);
  assert.equal(result.body.cart.id, 'cart-1');
  assert.equal(result.body.cart.subtotal, 0);
  assert.equal(result.body.cart.discount_total, 0);
  assert.equal(result.body.cart.shipping_total, 0);
  assert.equal(result.body.cart.tax_total, 0);
  assert.equal(result.body.cart.grand_total, 0);
  assert.deepEqual(state.entries, []);
  assert.equal(state.carts[0].grandTotal, 0);
});

test('processClearCartRequest rejects missing guest headers', () => {
  assert.throws(
    () =>
      cartClear.processClearCartRequest(createDeps(createState()), {
        headers: {},
        body: { cartId: 'cart-1' },
      }),
    (error) => {
      assert.equal(error.statusCode, 400);
      assert.equal(error.body.code, 'missing_guest_header');
      return true;
    },
  );
});

test('processClearCartRequest rejects carts from another guest', () => {
  const state = createState();
  state.carts.push({
    id: 'cart-1',
    guestId: 'guest-2',
    userId: '',
    status: 'active',
    currencyCode: 'EUR',
  });
  state.entries.push({ id: 'entry-1', cartId: 'cart-1' });

  assert.throws(
    () => cartClear.processClearCartRequest(createDeps(state), request()),
    (error) => {
      assert.equal(error.statusCode, 403);
      assert.equal(error.body.code, 'cart_guest_mismatch');
      return true;
    },
  );
  assert.equal(state.entries.length, 1);
});

function request() {
  return {
    headers: {
      cartGuestId: 'guest-1',
    },
    body: {
      cartId: 'cart-1',
    },
  };
}

function createState() {
  return {
    carts: [],
    entries: [],
  };
}

function createDeps(state, overrides = {}) {
  return {
    runInTransaction(fn) {
      return fn(createTxDeps(state));
    },
    ...overrides,
  };
}

function createTxDeps(state, overrides = {}) {
  return {
    getCart(cartId) {
      return state.carts.find((cart) => cart.id === cartId) || null;
    },
    findEntries(cartId) {
      return state.entries.filter((entry) => entry.cartId === cartId);
    },
    deleteEntry(entryId) {
      state.entries = state.entries.filter((entry) => entry.id !== entryId);
    },
    updateCartTotals(cartId, totals) {
      const cart = state.carts.find((cart) => cart.id === cartId);
      Object.assign(cart, totals);
      return cart;
    },
    ...overrides,
  };
}
