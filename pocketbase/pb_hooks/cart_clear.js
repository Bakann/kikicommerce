'use strict';

function RouteError(statusCode, body) {
  this.name = 'RouteError';
  this.statusCode = statusCode;
  this.body = body;
  this.message = body && body.message ? body.message : 'Route error';
}

RouteError.prototype = Object.create(Error.prototype);
RouteError.prototype.constructor = RouteError;

function processClearCartRequest(deps, request) {
  const guestId = normalizeRequiredText(
    request && request.headers ? request.headers.cartGuestId : '',
  );
  if (!guestId) {
    throw routeError(400, {
      code: 'missing_guest_header',
      message: 'Missing X-Cart-Guest-Id header',
    });
  }

  const body = parseRequestBody(request ? request.body : null);

  return deps.runInTransaction(function(tx) {
    const cart = tx.getCart(body.cartId);
    if (!cart) {
      throw routeError(404, {
        code: 'cart_not_found',
        message: 'Cart not found',
      });
    }

    if (!ownsGuestCart(cart, guestId)) {
      throw routeError(403, {
        code: 'cart_guest_mismatch',
        message: 'Guest does not own the cart',
      });
    }

    const entries = tx.findEntries(cart.id);
    entries.forEach(function(entry) {
      tx.deleteEntry(entry.id);
    });

    const updatedCart = tx.updateCartTotals(cart.id, {
      subtotal: 0,
      discountTotal: 0,
      shippingTotal: 0,
      taxTotal: 0,
      grandTotal: 0,
    });

    return {
      statusCode: 200,
      body: {
        cart: cartToResponseJson(updatedCart),
        entries: [],
        deletedCount: entries.length,
      },
      deletedCount: entries.length,
    };
  });
}

function parseRequestBody(body) {
  const source = body || {};
  const cartId = normalizeRequiredText(source.cartId);
  if (!cartId) {
    throw routeError(400, {
      code: 'missing_cart_id',
      message: 'Missing cartId',
    });
  }

  return { cartId: cartId };
}

function ownsGuestCart(cart, guestId) {
  return (
    normalizeRequiredText(cart.guestId) === guestId &&
    !normalizeRequiredText(cart.userId)
  );
}

function cartToResponseJson(cart) {
  return {
    id: normalizeRequiredText(cart.id),
    user: normalizeOptionalText(cart.userId),
    guest_id: normalizeOptionalText(cart.guestId),
    status: normalizeRequiredText(cart.status) || 'active',
    currency_code: normalizeRequiredText(cart.currencyCode) || 'EUR',
    subtotal: normalizeNumber(cart.subtotal),
    discount_total: normalizeNumber(cart.discountTotal),
    shipping_total: normalizeNumber(cart.shippingTotal),
    tax_total: normalizeNumber(cart.taxTotal),
    grand_total: normalizeNumber(cart.grandTotal),
  };
}

function normalizeNumber(value) {
  const numeric = Number(value);
  return isFinite(numeric) ? numeric : 0;
}

function normalizeRequiredText(value) {
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim();
}

function normalizeOptionalText(value) {
  if (value === null || value === undefined) {
    return '';
  }
  return normalizeRequiredText(String(value));
}

function routeError(statusCode, body) {
  return new RouteError(statusCode, body);
}

function isRouteError(error) {
  return !!(error && error.name === 'RouteError' && error.body);
}

module.exports = {
  RouteError: RouteError,
  processClearCartRequest: processClearCartRequest,
  parseRequestBody: parseRequestBody,
  cartToResponseJson: cartToResponseJson,
  isRouteError: isRouteError,
  routeError: routeError,
};
