/// <reference path="../pb_data/types.d.ts" />

// All pure cart-add logic lives in `cart_add_item.js`, which is exercised
// directly by `test/pocketbase/cart_add_item_hook_test.js` under Node. This
// hook only wires the route to PocketBase: it provides the data-access
// `deps` object backed by `app` and `txApp`, and translates the result of
// `processAddItemRequest` into an HTTP response. Keep the two files in
// sync — the only differences should be PocketBase-specific I/O.
routerAdd('POST', '/api/cart/add-item', (e) => {
  const cartHook = require(`${__hooks}/cart_add_item.js`);

  function toErrorString(error) {
    if (!error) {
      return 'unknown';
    }
    if (typeof error.message === 'string' && error.message.length > 0) {
      return error.message;
    }
    return String(error);
  }

  function findRecordById(app, collection, id) {
    try {
      return app.findRecordById(collection, id);
    } catch (_) {
      return null;
    }
  }

  function findIdempotencyRecord(app, guestId, idempotencyKey) {
    const records = app.findRecordsByFilter(
      'cart_add_idempotency',
      'guest_id = {:guestId} && idempotency_key = {:idempotencyKey}',
      '',
      1,
      0,
      { guestId: guestId, idempotencyKey: idempotencyKey },
    );
    if (!records || records.length === 0) {
      return null;
    }

    const record = records[0];
    return {
      id: record.id,
      requestHash: record.getString('request_hash'),
      responseBody: record.getString('response_body'),
      statusCode: record.getInt('status_code'),
    };
  }

  function isUniqueConstraintError(error) {
    const message = toErrorString(error).toLowerCase();
    return (
      message.indexOf('unique') >= 0 ||
      message.indexOf('constraint failed') >= 0
    );
  }

  function readJsonBody(e) {
    const raw = toString(e.request.body || '');
    if (!raw.trim()) {
      return {};
    }
    return JSON.parse(raw);
  }

  function createTxDeps(txApp) {
    return {
      findIdempotency: function(guestId, idempotencyKey) {
        return findIdempotencyRecord(txApp, guestId, idempotencyKey);
      },
      saveIdempotency: function(input) {
        const collection = txApp.findCollectionByNameOrId('cart_add_idempotency');
        const record = new Record(collection);
        record.set('guest_id', input.guestId);
        record.set('idempotency_key', input.idempotencyKey);
        record.set('request_hash', input.requestHash);
        record.set('response_body', JSON.stringify(input.responseBody));
        record.set('status_code', input.statusCode);
        try {
          txApp.save(record);
        } catch (error) {
          if (isUniqueConstraintError(error)) {
            throw cartHook.createConflictError('idempotency', error);
          }
          throw error;
        }
      },
      getProduct: function(productId) {
        const record = findRecordById(txApp, 'products', productId);
        return record ? {
          id: record.id,
          code: record.getString('code'),
          name: record.getString('name'),
          isActive: record.getBool('isActive'),
        } : null;
      },
      getPriceRow: function(priceId) {
        const record = findRecordById(txApp, 'priceRows', priceId);
        return record ? {
          id: record.id,
          productId: record.getString('product'),
          currencyId: record.getString('currency'),
          price: record.getFloat('price'),
          isActive: record.getBool('isActive'),
        } : null;
      },
      getCurrencyCode: function(currencyId) {
        const record = findRecordById(txApp, 'currencies', currencyId);
        return record ? record.getString('isocode') : '';
      },
      findActiveCart: function(guestId) {
        const records = txApp.findRecordsByFilter(
          'carts',
          'guest_id = {:guestId} && status = "active"',
          '',
          1,
          0,
          { guestId: guestId },
        );
        if (!records || records.length === 0) {
          return null;
        }

        const record = records[0];
        return {
          id: record.id,
          guestId: record.getString('guest_id'),
          userId: record.getString('user'),
          currencyCode: record.getString('currency_code'),
        };
      },
      createGuestCart: function(guestId, currencyCode) {
        const collection = txApp.findCollectionByNameOrId('carts');
        const record = new Record(collection);
        record.set('guest_id', guestId);
        record.set('status', 'active');
        record.set('currency_code', currencyCode);
        record.set('subtotal', 0);
        record.set('discount_total', 0);
        record.set('shipping_total', 0);
        record.set('tax_total', 0);
        record.set('grand_total', 0);
        try {
          txApp.save(record);
        } catch (error) {
          if (isUniqueConstraintError(error)) {
            throw cartHook.createConflictError('cart', error);
          }
          throw error;
        }
        return {
          id: record.id,
          guestId: record.getString('guest_id'),
          userId: record.getString('user'),
          currencyCode: record.getString('currency_code'),
        };
      },
      findEntry: function(cartId, productId) {
        const records = txApp.findRecordsByFilter(
          'cart_entries',
          'cart = {:cartId} && product = {:productId}',
          '',
          1,
          0,
          { cartId: cartId, productId: productId },
        );
        if (!records || records.length === 0) {
          return null;
        }

        const record = records[0];
        return {
          id: record.id,
          cartId: record.getString('cart'),
          productId: record.getString('product'),
          quantity: record.getInt('quantity'),
          unitPrice: record.getFloat('unit_price'),
        };
      },
      createEntry: function(input) {
        const collection = txApp.findCollectionByNameOrId('cart_entries');
        const record = new Record(collection);
        record.set('cart', input.cartId);
        record.set('product', input.productId);
        record.set('sku_snapshot', input.skuSnapshot);
        record.set('product_name_snapshot', input.productNameSnapshot);
        record.set('quantity', input.quantity);
        record.set('unit_price', input.unitPrice);
        record.set('line_total', input.unitPrice * input.quantity);
        try {
          txApp.save(record);
        } catch (error) {
          if (isUniqueConstraintError(error)) {
            throw cartHook.createConflictError('entry', error);
          }
          throw error;
        }
        return {
          id: record.id,
          cartId: record.getString('cart'),
          productId: record.getString('product'),
          quantity: record.getInt('quantity'),
          unitPrice: record.getFloat('unit_price'),
        };
      },
      updateEntryQuantity: function(entry, quantity, unitPrice) {
        const record = txApp.findRecordById('cart_entries', entry.id);
        record.set('quantity', quantity);
        record.set('unit_price', unitPrice);
        record.set('line_total', unitPrice * quantity);
        txApp.save(record);
        return {
          id: record.id,
          cartId: record.getString('cart'),
          productId: record.getString('product'),
          quantity: record.getInt('quantity'),
          unitPrice: record.getFloat('unit_price'),
        };
      },
    };
  }

  function createDeps(app) {
    return {
      sha256: function(text) {
        return $security.sha256(text);
      },
      runInTransaction: function(fn) {
        let result = null;
        app.runInTransaction((txApp) => {
          result = fn(createTxDeps(txApp));
        });
        return result;
      },
      findIdempotency: function(guestId, idempotencyKey) {
        return findIdempotencyRecord(app, guestId, idempotencyKey);
      },
    };
  }

  function respond(
    e,
    startedAt,
    statusCode,
    body,
    cartCreated,
    idempotencyHit,
    pathMode,
  ) {
    const durationMs = Date.now() - startedAt;
    e.response.header().set('Server-Timing', `cart_add_item;dur=${durationMs}`);
    console.log(
      JSON.stringify({
        event: 'cart.add_item',
        status_code: statusCode,
        duration_ms: durationMs,
        cart_created: cartCreated,
        idempotency_hit: idempotencyHit,
        path_mode: pathMode,
      }),
    );
    return e.json(statusCode, body);
  }

  const startedAt = Date.now();
  let statusCode = 500;
  let cartCreated = false;
  let idempotencyHit = false;
  let pathMode = 'warm';

  try {
    const result = cartHook.processAddItemRequest(
      createDeps(e.app),
      {
        headers: {
          cartGuestId: e.request.header.get('X-Cart-Guest-Id'),
          idempotencyKey: e.request.header.get('Idempotency-Key'),
        },
        body: readJsonBody(e),
      },
    );

    statusCode = result.statusCode;
    cartCreated = result.cartCreated;
    idempotencyHit = result.idempotencyHit;
    pathMode = result.pathMode;
    return respond(
      e,
      startedAt,
      statusCode,
      result.body,
      cartCreated,
      idempotencyHit,
      pathMode,
    );
  } catch (error) {
    if (cartHook.isRouteError(error)) {
      statusCode = error.statusCode;
      return respond(
        e,
        startedAt,
        statusCode,
        error.body,
        cartCreated,
        idempotencyHit,
        pathMode,
      );
    }

    console.log(
      JSON.stringify({
        event: 'cart.add_item',
        status_code: 500,
        duration_ms: Date.now() - startedAt,
        cart_created: cartCreated,
        idempotency_hit: idempotencyHit,
        path_mode: pathMode,
        error: toErrorString(error),
      }),
    );

    e.response.header().set(
      'Server-Timing',
      `cart_add_item;dur=${Date.now() - startedAt}`,
    );
    return e.json(500, {
      code: 'cart_add_internal_error',
      message: 'Unable to add item to cart',
    });
  }
});

routerAdd('POST', '/api/cart/clear', (e) => {
  const cartClearHook = require(`${__hooks}/cart_clear.js`);

  function toErrorString(error) {
    if (!error) {
      return 'unknown';
    }
    if (typeof error.message === 'string' && error.message.length > 0) {
      return error.message;
    }
    return String(error);
  }

  function findRecordById(app, collection, id) {
    try {
      return app.findRecordById(collection, id);
    } catch (_) {
      return null;
    }
  }

  function readJsonBody(e) {
    const raw = toString(e.request.body || '');
    if (!raw.trim()) {
      return {};
    }
    return JSON.parse(raw);
  }

  function cartFromRecord(record) {
    if (!record) {
      return null;
    }
    return {
      id: record.id,
      userId: record.getString('user'),
      guestId: record.getString('guest_id'),
      status: record.getString('status'),
      currencyCode: record.getString('currency_code'),
      subtotal: record.getFloat('subtotal'),
      discountTotal: record.getFloat('discount_total'),
      shippingTotal: record.getFloat('shipping_total'),
      taxTotal: record.getFloat('tax_total'),
      grandTotal: record.getFloat('grand_total'),
    };
  }

  function findEntryRecords(app, cartId) {
    const records = [];
    const batchSize = 200;
    let offset = 0;
    while (true) {
      const page = app.findRecordsByFilter(
        'cart_entries',
        'cart = {:cartId}',
        'created',
        batchSize,
        offset,
        { cartId: cartId },
      );
      if (!page || page.length === 0) {
        break;
      }
      records.push.apply(records, page);
      if (page.length < batchSize) {
        break;
      }
      offset += batchSize;
    }
    return records;
  }

  function createTxDeps(txApp) {
    return {
      getCart: function(cartId) {
        return cartFromRecord(findRecordById(txApp, 'carts', cartId));
      },
      findEntries: function(cartId) {
        return findEntryRecords(txApp, cartId).map(function(record) {
          return {
            id: record.id,
            cartId: record.getString('cart'),
          };
        });
      },
      deleteEntry: function(entryId) {
        const record = txApp.findRecordById('cart_entries', entryId);
        txApp.delete(record);
      },
      updateCartTotals: function(cartId, totals) {
        const record = txApp.findRecordById('carts', cartId);
        record.set('subtotal', totals.subtotal);
        record.set('discount_total', totals.discountTotal);
        record.set('shipping_total', totals.shippingTotal);
        record.set('tax_total', totals.taxTotal);
        record.set('grand_total', totals.grandTotal);
        txApp.save(record);
        return cartFromRecord(record);
      },
    };
  }

  function createDeps(app) {
    return {
      runInTransaction: function(fn) {
        let result = null;
        app.runInTransaction((txApp) => {
          result = fn(createTxDeps(txApp));
        });
        return result;
      },
    };
  }

  function respond(e, startedAt, statusCode, body, deletedCount) {
    const durationMs = Date.now() - startedAt;
    e.response.header().set('Server-Timing', `cart_clear;dur=${durationMs}`);
    console.log(
      JSON.stringify({
        event: 'cart.clear',
        status_code: statusCode,
        duration_ms: durationMs,
        deleted_count: deletedCount,
      }),
    );
    return e.json(statusCode, body);
  }

  const startedAt = Date.now();
  let statusCode = 500;
  let deletedCount = 0;

  try {
    const result = cartClearHook.processClearCartRequest(
      createDeps(e.app),
      {
        headers: {
          cartGuestId: e.request.header.get('X-Cart-Guest-Id'),
        },
        body: readJsonBody(e),
      },
    );

    statusCode = result.statusCode;
    deletedCount = result.deletedCount;
    return respond(e, startedAt, statusCode, result.body, deletedCount);
  } catch (error) {
    if (cartClearHook.isRouteError(error)) {
      statusCode = error.statusCode;
      return respond(e, startedAt, statusCode, error.body, deletedCount);
    }

    console.log(
      JSON.stringify({
        event: 'cart.clear',
        status_code: 500,
        duration_ms: Date.now() - startedAt,
        deleted_count: deletedCount,
        error: toErrorString(error),
      }),
    );

    e.response.header().set(
      'Server-Timing',
      `cart_clear;dur=${Date.now() - startedAt}`,
    );
    return e.json(500, {
      code: 'cart_clear_internal_error',
      message: 'Unable to clear cart',
    });
  }
});
