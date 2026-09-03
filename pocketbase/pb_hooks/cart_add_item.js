'use strict';

function RouteError(statusCode, body) {
  this.name = 'RouteError';
  this.statusCode = statusCode;
  this.body = body;
  this.message = body && body.message ? body.message : 'Route error';
}

RouteError.prototype = Object.create(Error.prototype);
RouteError.prototype.constructor = RouteError;

function ConflictError(kind, cause) {
  this.name = 'ConflictError';
  this.kind = kind;
  this.cause = cause;
  this.message = kind + ' conflict';
}

ConflictError.prototype = Object.create(Error.prototype);
ConflictError.prototype.constructor = ConflictError;

function processAddItemRequest(deps, request) {
  const guestId = normalizeRequiredText(
    request && request.headers ? request.headers.cartGuestId : '',
  );
  if (!guestId) {
    throw routeError(400, {
      code: 'missing_guest_header',
      message: 'Missing X-Cart-Guest-Id header',
    });
  }

  const idempotencyKey = normalizeRequiredText(
    request && request.headers ? request.headers.idempotencyKey : '',
  );
  if (!idempotencyKey) {
    throw routeError(400, {
      code: 'missing_idempotency_key',
      message: 'Missing Idempotency-Key header',
    });
  }

  const body = parseRequestBody(request ? request.body : null);
  const requestHash = buildRequestHash(deps.sha256, body);

  const existing = deps.findIdempotency(guestId, idempotencyKey);
  if (existing) {
    ensureMatchingIdempotency(existing, requestHash);
    return buildStoredResponse(existing, true);
  }

  try {
    return deps.runInTransaction(function(tx) {
      const storedInTx = tx.findIdempotency(guestId, idempotencyKey);
      if (storedInTx) {
        ensureMatchingIdempotency(storedInTx, requestHash);
        return buildStoredResponse(storedInTx, true);
      }

      const product = tx.getProduct(body.productId);
      ensureActiveRecord(product, 'product_not_found', 'Product not found');

      const priceRow = tx.getPriceRow(body.priceId);
      ensureActiveRecord(priceRow, 'price_not_found', 'Price row not found');

      if (toText(priceRow.productId) !== body.productId) {
        throw routeError(400, {
          code: 'price_product_mismatch',
          message: 'Price row does not belong to the product',
        });
      }

      const currencyCode = normalizeRequiredText(
        tx.getCurrencyCode(priceRow.currencyId),
      );
      if (!currencyCode) {
        // Server-side configuration error (price row references a currency
        // that no longer exists), not a client mistake — return 500.
        throw routeError(500, {
          code: 'currency_not_found',
          message: 'Currency not found for price row',
        });
      }

      let cart = tx.findActiveCart(guestId);
      let cartCreated = false;
      if (!cart) {
        try {
          cart = tx.createGuestCart(guestId, currencyCode);
          cartCreated = true;
        } catch (error) {
          if (!isConflictError(error, 'cart')) {
            throw error;
          }
          cart = tx.findActiveCart(guestId);
          cartCreated = false;
        }
      }

      if (!cart) {
        throw routeError(500, {
          code: 'cart_creation_failed',
          message: 'Unable to resolve active cart',
        });
      }

      if (!ownsGuestCart(cart, guestId)) {
        throw routeError(403, {
          code: 'cart_guest_mismatch',
          message: 'Guest does not own the active cart',
        });
      }

      if (normalizeRequiredText(cart.currencyCode) !== currencyCode) {
        throw routeError(409, {
          code: 'cart_currency_mismatch',
          message: 'Cart currency does not match price currency',
          cartCurrencyCode: normalizeRequiredText(cart.currencyCode) || 'unknown',
          priceCurrencyCode: currencyCode,
        });
      }

      let entry = tx.findEntry(cart.id, body.productId);
      if (entry) {
        entry = tx.updateEntryQuantity(
          entry,
          entry.quantity + body.quantity,
          priceRow.price,
        );
      } else {
        try {
          entry = tx.createEntry({
            cartId: cart.id,
            productId: body.productId,
            quantity: body.quantity,
            unitPrice: priceRow.price,
            skuSnapshot: normalizeOptionalText(product.code),
            productNameSnapshot: normalizeRequiredText(product.name) || body.productId,
          });
        } catch (error) {
          if (!isConflictError(error, 'entry')) {
            throw error;
          }

          entry = tx.findEntry(cart.id, body.productId);
          if (!entry) {
            throw error;
          }
          entry = tx.updateEntryQuantity(
            entry,
            entry.quantity + body.quantity,
            priceRow.price,
          );
        }
      }

      if (!entry) {
        throw routeError(500, {
          code: 'entry_write_failed',
          message: 'Unable to persist cart entry',
        });
      }

      const responseBody = {
        cartId: cart.id,
        entryProductId: body.productId,
        quantityDelta: body.quantity,
        cartCreated: cartCreated,
      };

      tx.saveIdempotency({
        guestId: guestId,
        idempotencyKey: idempotencyKey,
        requestHash: requestHash,
        responseBody: responseBody,
        statusCode: 200,
      });

      return {
        statusCode: 200,
        body: responseBody,
        cartCreated: cartCreated,
        idempotencyHit: false,
        pathMode: cartCreated ? 'cold' : 'warm',
      };
    });
  } catch (error) {
    if (!isConflictError(error, 'idempotency')) {
      throw error;
    }

    const concurrent = deps.findIdempotency(guestId, idempotencyKey);
    if (!concurrent) {
      throw error;
    }
    ensureMatchingIdempotency(concurrent, requestHash);
    return buildStoredResponse(concurrent, true);
  }
}

function parseRequestBody(body) {
  const source = body || {};
  const productId = normalizeRequiredText(source.productId);
  const priceId = normalizeRequiredText(source.priceId);
  const quantity = normalizeQuantity(source.quantity);

  if (!productId) {
    throw routeError(400, {
      code: 'missing_product_id',
      message: 'Missing productId',
    });
  }

  if (!priceId) {
    throw routeError(400, {
      code: 'missing_price_id',
      message: 'Missing priceId',
    });
  }

  if (quantity === null) {
    throw routeError(400, {
      code: 'invalid_quantity',
      message: 'Quantity must be a positive integer',
    });
  }

  return {
    productId: productId,
    priceId: priceId,
    quantity: quantity,
  };
}

function buildRequestHash(sha256, payload) {
  return sha256(
    JSON.stringify([
      payload.productId,
      payload.priceId,
      payload.quantity,
    ]),
  );
}

function buildStoredResponse(record, idempotencyHit) {
  const body = typeof record.responseBody === 'string'
      ? JSON.parse(record.responseBody)
      : record.responseBody;
  return {
    statusCode: record.statusCode || 200,
    body: body,
    cartCreated: !!(body && body.cartCreated),
    idempotencyHit: idempotencyHit,
    pathMode: body && body.cartCreated ? 'cold' : 'warm',
  };
}

function ensureMatchingIdempotency(record, requestHash) {
  if (normalizeRequiredText(record.requestHash) === requestHash) {
    return;
  }

  throw routeError(409, {
    code: 'idempotency_key_reused',
    message: 'Idempotency key already used for a different payload',
  });
}

function ensureActiveRecord(record, code, message) {
  if (!record || record.isActive === false) {
    throw routeError(404, {
      code: code,
      message: message,
    });
  }
}

function ownsGuestCart(cart, guestId) {
  return (
    normalizeRequiredText(cart.guestId) === guestId &&
    !normalizeRequiredText(cart.userId)
  );
}

function normalizeQuantity(value) {
  const numeric = Number(value);
  if (!isFinite(numeric) || numeric <= 0 || Math.floor(numeric) !== numeric) {
    return null;
  }
  return numeric;
}

function normalizeRequiredText(value) {
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
}

function normalizeOptionalText(value) {
  const text = toText(value);
  return text ? text.trim() : '';
}

function toText(value) {
  if (typeof value === 'string') {
    return value;
  }
  if (value === null || value === undefined) {
    return '';
  }
  return String(value);
}

function routeError(statusCode, body) {
  return new RouteError(statusCode, body);
}

function createConflictError(kind, cause) {
  return new ConflictError(kind, cause);
}

function isRouteError(error) {
  return !!(error && error.name === 'RouteError' && error.body);
}

function isConflictError(error, kind) {
  return !!(
    error &&
    error.name === 'ConflictError' &&
    (!kind || error.kind === kind)
  );
}

module.exports = {
  RouteError: RouteError,
  ConflictError: ConflictError,
  processAddItemRequest: processAddItemRequest,
  parseRequestBody: parseRequestBody,
  buildRequestHash: buildRequestHash,
  buildStoredResponse: buildStoredResponse,
  createConflictError: createConflictError,
  isRouteError: isRouteError,
  isConflictError: isConflictError,
  routeError: routeError,
};
