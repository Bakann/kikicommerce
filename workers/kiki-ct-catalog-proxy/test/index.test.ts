import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';

import worker, { testExports } from '../src/index.ts';

const baseEnv = {
  CT_PROJECT_KEY: 'kiki',
  CT_API_URL: 'https://api.europe-west1.gcp.commercetools.com',
  CT_AUTH_URL: 'https://auth.europe-west1.gcp.commercetools.com',
  CT_SCOPE: 'view_published_products:kiki view_categories:kiki',
  CT_LOCALE_PROJECTION: 'en-GB',
  CT_PRICE_CURRENCY: 'EUR',
  CT_PRICE_COUNTRY: 'FR',
  ALLOWED_ORIGINS: 'https://kikicommerce.com,https://www.kikicommerce.com,http://localhost:3000',
  CT_CLIENT_ID: 'client-id',
  CT_CLIENT_SECRET: 'client-secret',
  // The deployed lab opts into weserv explicitly (the code default is 'none').
  CT_IMAGE_RESIZE_MODE: 'weserv',
};

const originalFetch = globalThis.fetch;
const originalConsoleError = console.error;

afterEach(() => {
  globalThis.fetch = originalFetch;
  console.error = originalConsoleError;
  testExports.resetTokenCache();
});

test('allows configured CORS origins', async () => {
  const response = await worker.fetch(
    new Request('https://worker.test/health', {
      headers: { Origin: 'https://www.kikicommerce.com' },
    }),
    baseEnv,
  );

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), 'https://www.kikicommerce.com');
  assert.deepEqual(await response.json(), { ok: true });
});

test('refuses unconfigured CORS origins', async () => {
  const response = await worker.fetch(
    new Request('https://worker.test/health', {
      headers: { Origin: 'https://example.com' },
    }),
    baseEnv,
  );

  assert.equal(response.status, 403);
  assert.equal(response.headers.get('Access-Control-Allow-Origin'), null);
});

test('validates limit and offset instead of clamping invalid values', () => {
  assert.equal(testExports.parseBoundedInteger(null, 20, 1, 100, 'limit'), 20);
  assert.equal(testExports.parseBoundedInteger('50', 20, 1, 100, 'limit'), 50);
  assert.throws(() => testExports.parseBoundedInteger('', 20, 1, 100, 'limit'), /limit must be/);
  assert.throws(() => testExports.parseBoundedInteger('101', 20, 1, 100, 'limit'), /limit must be/);
  assert.throws(() => testExports.parseBoundedInteger('-1', 0, 0, 10000, 'offset'), /offset must be/);
  assert.throws(() => testExports.parseBoundedInteger('abc', 0, 0, 10000, 'offset'), /offset must be/);
});

test('maps projected prices and ignores unprojected fallback prices', () => {
  const product = testExports.toCatalogProduct({
    id: 'product-1',
    key: 'chair',
    slug: { 'en-GB': 'rattan-chair' },
    name: { 'en-GB': 'Rattan Chair' },
    description: { 'en-GB': 'A lounge chair.' },
    masterVariant: {
      images: [{ url: 'https://cdn.example.com/chair.jpg' }],
      price: { value: { centAmount: 12900, currencyCode: 'EUR' } },
      prices: [{ value: { centAmount: 9900, currencyCode: 'GBP' } }],
    },
  });

  assert.deepEqual(product, {
    id: 'product-1',
    key: 'chair',
    slug: 'rattan-chair',
    name: 'Rattan Chair',
    description: 'A lounge chair.',
    imageUrl: 'https://cdn.example.com/chair.jpg',
    price: { centAmount: 12900, currencyCode: 'EUR' },
  });
});

test('maps missing optional image and projected price as null', () => {
  const product = testExports.toCatalogProduct({
    id: 'product-2',
    key: 'table',
    slug: { 'fr-FR': 'table' },
    name: { 'fr-FR': 'Table' },
    masterVariant: {
      prices: [{ value: { centAmount: 15000, currencyCode: 'EUR' } }],
    },
  });

  assert.equal(product.imageUrl, null);
  assert.equal(product.price, null);
});

test('requests projected locale and price selection for product lists', async () => {
  const requestedUrls: string[] = [];
  globalThis.fetch = async (input) => {
    const url = String(input);
    requestedUrls.push(url);

    if (url.endsWith('/oauth/token')) {
      return Response.json({ access_token: 'token', expires_in: 3600 });
    }

    return Response.json({
      results: [
        {
          id: 'product-1',
          key: 'chair',
          slug: { 'en-GB': 'chair' },
          name: { 'en-GB': 'Chair' },
          masterVariant: {
            price: { value: { centAmount: 12900, currencyCode: 'EUR' } },
          },
        },
      ],
    });
  };

  const response = await worker.fetch(new Request('https://worker.test/products?limit=1&offset=0'), baseEnv);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.items[0].price.centAmount, 12900);
  assert.match(requestedUrls[1], /localeProjection=en-GB/);
  assert.match(requestedUrls[1], /priceCurrency=EUR/);
  assert.match(requestedUrls[1], /priceCountry=FR/);
});

const GCS_IMG = 'https://storage.googleapis.com/merchant-center-europe/sample-data/b2c-lifestyle/Bruno_Chair-1.1.jpeg';

test('resizeImageUrl (weserv) wraps a GCS URL with bounded params', () => {
  const out = testExports.resizeImageUrl(GCS_IMG, baseEnv, 600);
  assert.ok(out);
  const url = new URL(out as string);
  assert.equal(url.hostname, 'images.weserv.nl');
  assert.equal(url.searchParams.get('w'), '600');
  assert.equal(url.searchParams.get('q'), '75');
  assert.equal(url.searchParams.get('output'), 'webp');
  // Source is embedded (encoded) in the `url` param, exactly once, and the
  // result is not the raw GCS URL.
  assert.equal(url.searchParams.get('url'), GCS_IMG);
  assert.notEqual(out, GCS_IMG);
  assert.equal((out as string).split('storage.googleapis.com').length - 1, 1);
});

test('resizeImageUrl returns null for a null source', () => {
  assert.equal(testExports.resizeImageUrl(null, baseEnv, 600), null);
});

test('resizeImageUrl mode=none passes the original URL through', () => {
  const env = { ...baseEnv, CT_IMAGE_RESIZE_MODE: 'none' };
  assert.equal(testExports.resizeImageUrl(GCS_IMG, env, 600), GCS_IMG);
});

test('resizeImageUrl defaults to none (passthrough) when mode is unset', () => {
  const env = { ...baseEnv };
  delete (env as { CT_IMAGE_RESIZE_MODE?: string }).CT_IMAGE_RESIZE_MODE;
  assert.equal(testExports.resizeImageUrl(GCS_IMG, env, 600), GCS_IMG);
});

test('resizeImageUrl only proxies http(s) URLs', () => {
  assert.equal(testExports.resizeImageUrl('not a url', baseEnv, 600), 'not a url');
  assert.equal(testExports.resizeImageUrl('ftp://h/x.jpg', baseEnv, 600), 'ftp://h/x.jpg');
  assert.equal(testExports.resizeImageUrl('data:image/png;base64,AAAA', baseEnv, 600), 'data:image/png;base64,AAAA');
});

test('resizeImageUrl throws on an unknown mode', () => {
  const env = { ...baseEnv, CT_IMAGE_RESIZE_MODE: 'weeserv' };
  assert.throws(() => testExports.resizeImageUrl(GCS_IMG, env, 600), /Unsupported CT_IMAGE_RESIZE_MODE/);
});

test('resizeImageUrl throws on an unsupported format', () => {
  const env = { ...baseEnv, CT_IMAGE_FORMAT: 'wepb' };
  assert.throws(() => testExports.resizeImageUrl(GCS_IMG, env, 600), /Unsupported CT_IMAGE_FORMAT/);
});

test('width/quality helpers default when unset and throw on garbage', () => {
  assert.equal(testExports.listingImageWidth(baseEnv), 600);
  assert.equal(testExports.detailImageWidth(baseEnv), 1280);
  assert.throws(
    () => testExports.listingImageWidth({ ...baseEnv, CT_IMAGE_WIDTH: 'banana' }),
    /CT_IMAGE_WIDTH must be/,
  );
  assert.throws(
    () => testExports.resizeImageUrl(GCS_IMG, { ...baseEnv, CT_IMAGE_QUALITY: '999' }, 600),
    /CT_IMAGE_QUALITY must be/,
  );
});

test('resizeImageUrl encodes a source URL that has its own querystring once', () => {
  const src = 'https://cdn.example.com/p.jpg?v=2&x=1';
  const out = testExports.resizeImageUrl(src, baseEnv, 600) as string;
  const url = new URL(out);
  assert.equal(url.searchParams.get('url'), src); // decoded back to exactly the source
  assert.equal(out.split('cdn.example.com').length - 1, 1); // embedded once
});

test('resizeImageUrl does not double-wrap an already-weserv URL', () => {
  const already = 'https://images.weserv.nl/?url=https%3A%2F%2Fcdn.example.com%2Fp.jpg&w=600';
  assert.equal(testExports.resizeImageUrl(already, baseEnv, 600), already);
});

test('detail width is applied (w=1280)', () => {
  const out = testExports.resizeImageUrl(GCS_IMG, baseEnv, testExports.detailImageWidth(baseEnv)) as string;
  assert.equal(new URL(out).searchParams.get('w'), '1280');
});

function _withImageFetch() {
  globalThis.fetch = async (input) => {
    const url = String(input);
    if (url.endsWith('/oauth/token')) {
      return Response.json({ access_token: 'token', expires_in: 3600 });
    }
    return Response.json({
      results: [
        {
          id: 'product-1',
          key: 'chair',
          slug: { 'en-GB': 'chair' },
          name: { 'en-GB': 'Chair' },
          masterVariant: {
            images: [{ url: GCS_IMG }],
            price: { value: { centAmount: 12900, currencyCode: 'EUR' } },
          },
        },
      ],
    });
  };
}

test('/products returns weserv-resized image URLs (not raw GCS)', async () => {
  _withImageFetch();
  const response = await worker.fetch(new Request('https://worker.test/products?limit=1'), baseEnv);
  const body = await response.json();

  assert.equal(response.status, 200);
  const imageUrl: string = body.items[0].imageUrl;
  assert.equal(new URL(imageUrl).hostname, 'images.weserv.nl');
  assert.notEqual(imageUrl, GCS_IMG);
});

test('/products returns a clean 500 on invalid image config', async () => {
  _withImageFetch();
  const env = { ...baseEnv, CT_IMAGE_RESIZE_MODE: 'weeserv' };
  const response = await worker.fetch(new Request('https://worker.test/products?limit=1'), env);
  const body = await response.json();

  assert.equal(response.status, 500);
  assert.equal(typeof body.error, 'string');
  assert.match(body.error, /Unsupported CT_IMAGE_RESIZE_MODE/);
  assert.ok(!JSON.stringify(body).includes('client-secret'));
});

test('/products returns 500 (server config), not 400, on bad width/quality', async () => {
  _withImageFetch();
  for (const bad of [{ CT_IMAGE_WIDTH: 'banana' }, { CT_IMAGE_QUALITY: '999' }]) {
    const response = await worker.fetch(
      new Request('https://worker.test/products?limit=1'),
      { ...baseEnv, ...bad },
    );
    assert.equal(response.status, 500);
  }
});

test('invalid image config fails before any upstream/OAuth fetch', async () => {
  let fetched = false;
  globalThis.fetch = async (input) => {
    fetched = true;
    return Response.json({ access_token: 'token', expires_in: 3600 });
  };
  const response = await worker.fetch(
    new Request('https://worker.test/products?limit=1'),
    { ...baseEnv, CT_IMAGE_RESIZE_MODE: 'weeserv' },
  );
  assert.equal(response.status, 500);
  assert.equal(fetched, false); // assertImageConfig ran before listProducts
});

test('logs sanitized upstream API errors and returns a stable client error', async () => {
  const logged: unknown[][] = [];
  console.error = (...args: unknown[]) => {
    logged.push(args);
  };

  globalThis.fetch = async (input) => {
    const url = String(input);

    if (url.endsWith('/oauth/token')) {
      return Response.json({ access_token: 'token', expires_in: 3600 });
    }

    return new Response('{"message":"missing scope"}', { status: 403 });
  };

  const response = await worker.fetch(new Request('https://worker.test/products?limit=1'), baseEnv);
  const body = await response.json();

  assert.equal(response.status, 502);
  assert.deepEqual(body, { error: 'commercetools API error' });
  assert.equal(logged.length, 1);
  assert.equal(logged[0][0], 'commercetools API error');
  assert.deepEqual(logged[0][1], {
    status: 403,
    path: '/product-projections?staged=false&localeProjection=en-GB&priceCurrency=EUR&priceCountry=FR&limit=1&offset=0',
    body: '{"message":"missing scope"}',
  });
});
