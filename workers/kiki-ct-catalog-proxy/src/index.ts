interface Env {
  CT_PROJECT_KEY: string;
  CT_API_URL: string;
  CT_AUTH_URL: string;
  CT_SCOPE: string;
  CT_LOCALE_PROJECTION: string;
  CT_PRICE_CURRENCY: string;
  CT_PRICE_COUNTRY: string;
  ALLOWED_ORIGINS: string;
  CT_CLIENT_ID: string;
  CT_CLIENT_SECRET: string;
  // Optional image-resize settings (lab-only, see resizeImageUrl). Defaults are
  // applied in code, so these are not part of assertConfigured's required set.
  CT_IMAGE_RESIZE_MODE?: string;
  CT_IMAGE_WIDTH?: string;
  CT_IMAGE_QUALITY?: string;
  CT_IMAGE_FORMAT?: string;
  CT_DETAIL_IMAGE_WIDTH?: string;
}

interface TokenCache {
  accessToken: string;
  expiresAt: number;
}

interface CommercetoolsLocalizedString {
  [locale: string]: string | undefined;
}

interface CommercetoolsMoney {
  centAmount: number;
  currencyCode: string;
}

interface CommercetoolsPrice {
  value?: CommercetoolsMoney;
}

interface CommercetoolsImage {
  url?: string;
}

interface CommercetoolsVariant {
  images?: CommercetoolsImage[];
  price?: CommercetoolsPrice;
  prices?: CommercetoolsPrice[];
}

interface CommercetoolsProductProjection {
  id: string;
  key?: string;
  slug?: CommercetoolsLocalizedString;
  name?: CommercetoolsLocalizedString;
  description?: CommercetoolsLocalizedString;
  masterVariant?: CommercetoolsVariant;
  variants?: CommercetoolsVariant[];
}

interface CommercetoolsProductProjectionPagedQueryResponse {
  results?: CommercetoolsProductProjection[];
}

interface CatalogPrice {
  centAmount: number;
  currencyCode: string;
}

interface CatalogProduct {
  id: string;
  key: string | null;
  slug: string | null;
  name: string | null;
  description: string | null;
  imageUrl: string | null;
  price: CatalogPrice | null;
}

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;
const MAX_OFFSET = 10000;
const REQUEST_TIMEOUT_MS = 10000;
const TOKEN_EXPIRY_SKEW_MS = 60000;
const UPSTREAM_ERROR_LOG_LIMIT = 1000;

let tokenCache: TokenCache | undefined;
let pendingTokenRequest: Promise<TokenCache> | undefined;

function resetTokenCache(): void {
  tokenCache = undefined;
  pendingTokenRequest = undefined;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return handleRequest(request, env);
  },
};

export const testExports = {
  parseBoundedInteger,
  resetTokenCache,
  toCatalogProduct,
  resizeImageUrl,
  listingImageWidth,
  detailImageWidth,
};

async function handleRequest(request: Request, env: Env): Promise<Response> {
  const cors = corsHeaders(request, env);

  if (request.method === 'OPTIONS') {
    if (!isAllowedCorsRequest(request, env)) {
      return json({ error: 'Forbidden origin' }, 403, cors);
    }
    return new Response(null, { status: 204, headers: cors });
  }

  if (request.method !== 'GET') {
    return json({ error: 'Method not allowed' }, 405, cors);
  }

  if (!isAllowedCorsRequest(request, env)) {
    return json({ error: 'Forbidden origin' }, 403, cors);
  }

  try {
    const url = new URL(request.url);
    const pathname = normalizePathname(url.pathname);

    if (pathname === '/health') {
      return json({ ok: true }, 200, cors);
    }

    if (pathname === '/products') {
      assertConfigured(env);
      assertImageConfig(env); // fail fast on bad image config, before upstream
      const limit = parseBoundedInteger(url.searchParams.get('limit'), DEFAULT_LIMIT, 1, MAX_LIMIT, 'limit');
      const offset = parseBoundedInteger(url.searchParams.get('offset'), 0, 0, MAX_OFFSET, 'offset');
      const listingWidth = listingImageWidth(env);
      const products = await listProducts(env, limit, offset);
      const items = products.map((product) =>
        applyResizedImage(product, env, listingWidth),
      );
      return json({ items }, 200, cors);
    }

    const productSlugMatch = pathname.match(/^\/products\/([^/]+)$/);
    if (productSlugMatch) {
      assertConfigured(env);
      assertImageConfig(env); // fail fast on bad image config, before upstream
      const slugOrKey = decodeURIComponent(productSlugMatch[1]);
      const detailWidth = detailImageWidth(env);
      const product = await findProductBySlugOrKey(env, slugOrKey);

      if (!product) {
        return json({ error: 'Product not found' }, 404, cors);
      }

      return json(applyResizedImage(product, env, detailWidth), 200, cors);
    }

    return json({ error: 'Not found' }, 404, cors);
  } catch (error) {
    if (error instanceof HttpError) {
      return json({ error: error.message }, error.status, cors);
    }

    console.error('Unhandled Worker error', error);
    return json({ error: 'Internal server error' }, 500, cors);
  }
}

async function listProducts(env: Env, limit: number, offset: number): Promise<CatalogProduct[]> {
  const response = await commercetoolsFetch<CommercetoolsProductProjectionPagedQueryResponse>(
    env,
    `/product-projections?${projectionQuery(env, { limit, offset })}`,
  );

  return (response.results ?? []).map(toCatalogProduct);
}

async function findProductBySlugOrKey(env: Env, slugOrKey: string): Promise<CatalogProduct | null> {
  const productByKey = await getProductByKey(env, slugOrKey);
  if (productByKey) {
    return productByKey;
  }

  const quoted = JSON.stringify(slugOrKey);
  const where = `slug(${env.CT_LOCALE_PROJECTION}=${quoted})`;
  const response = await commercetoolsFetch<CommercetoolsProductProjectionPagedQueryResponse>(
    env,
    `/product-projections?${projectionQuery(env, { limit: 1, where })}`,
  );

  const product = response.results?.[0];
  return product ? toCatalogProduct(product) : null;
}

async function getProductByKey(env: Env, key: string): Promise<CatalogProduct | null> {
  try {
    const response = await commercetoolsFetchOptional<CommercetoolsProductProjection>(
      env,
      `/product-projections/key=${encodeURIComponent(key)}?${projectionQuery(env)}`,
      { notFoundAsNull: true },
    );

    return response ? toCatalogProduct(response) : null;
  } catch (error) {
    if (error instanceof HttpError && error.status === 404) {
      return null;
    }
    throw error;
  }
}

async function commercetoolsFetch<T>(env: Env, pathAndQuery: string): Promise<T> {
  const result = await commercetoolsFetchOptional<T>(env, pathAndQuery);
  if (result === null) {
    throw new HttpError(404, 'commercetools resource not found');
  }

  return result;
}

async function commercetoolsFetchOptional<T>(
  env: Env,
  pathAndQuery: string,
  options: { notFoundAsNull?: boolean } = {},
): Promise<T | null> {
  const token = await getAccessToken(env);
  const url = `${trimTrailingSlash(env.CT_API_URL)}/${encodeURIComponent(env.CT_PROJECT_KEY)}${pathAndQuery}`;
  const response = await fetchWithTimeout(url, {
    method: 'GET',
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
      'User-Agent': 'KikiCommerceCatalogProxy/1.0',
    },
  });

  if (!response.ok) {
    if (options.notFoundAsNull && response.status === 404) {
      return null;
    }

    await logUpstreamError('commercetools API error', response, pathAndQuery);
    throw new HttpError(502, 'commercetools API error');
  }

  return response.json<T>();
}

async function getAccessToken(env: Env): Promise<string> {
  const now = Date.now();
  if (tokenCache && tokenCache.expiresAt > now) {
    return tokenCache.accessToken;
  }

  if (!pendingTokenRequest) {
    pendingTokenRequest = requestAccessToken(env).finally(() => {
      pendingTokenRequest = undefined;
    });
  }

  tokenCache = await pendingTokenRequest;
  return tokenCache.accessToken;
}

async function requestAccessToken(env: Env): Promise<TokenCache> {
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    scope: env.CT_SCOPE,
  });
  const credentials = btoa(`${env.CT_CLIENT_ID}:${env.CT_CLIENT_SECRET}`);
  const response = await fetchWithTimeout(`${trimTrailingSlash(env.CT_AUTH_URL)}/oauth/token`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
    },
    body,
  });

  if (!response.ok) {
    await logUpstreamError('commercetools OAuth error', response, '/oauth/token');
    throw new HttpError(502, 'commercetools OAuth error');
  }

  const payload = await response.json<{ access_token?: string; expires_in?: number }>();
  if (!payload.access_token) {
    throw new HttpError(502, 'commercetools OAuth response did not include an access token');
  }

  const expiresInMs = Math.max((payload.expires_in ?? 0) * 1000 - TOKEN_EXPIRY_SKEW_MS, 0);
  return {
    accessToken: payload.access_token,
    expiresAt: Date.now() + expiresInMs,
  };
}

async function fetchWithTimeout(input: RequestInfo | URL, init: RequestInit): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    return await fetch(input, {
      ...init,
      signal: controller.signal,
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new HttpError(504, 'Upstream request timed out');
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

function toCatalogProduct(product: CommercetoolsProductProjection): CatalogProduct {
  const variant = product.masterVariant ?? product.variants?.[0];
  const price = variant?.price?.value ?? null;

  return {
    id: product.id,
    key: product.key ?? null,
    slug: firstLocalizedValue(product.slug),
    name: firstLocalizedValue(product.name),
    description: firstLocalizedValue(product.description),
    imageUrl: variant?.images?.[0]?.url ?? null,
    price: price
      ? {
          centAmount: price.centAmount,
          currencyCode: price.currencyCode,
        }
      : null,
  };
}

function firstLocalizedValue(value: CommercetoolsLocalizedString | undefined): string | null {
  if (!value) return null;

  return value['en-GB'] ?? value['fr-FR'] ?? value.fr ?? value.en ?? Object.values(value).find((entry) => Boolean(entry)) ?? null;
}

const RESIZE_FORMATS = new Set(['webp', 'jpg', 'png']);

// Code default is the SAFE one: do nothing unless the lab explicitly opts into
// weserv via env (wrangler.jsonc sets it for the deployed lab). This way a copy
// of the Worker that forgets the var never silently ships image URLs to a third
// party.
function resolveResizeMode(env: Env): string {
  return (env.CT_IMAGE_RESIZE_MODE ?? 'none').trim().toLowerCase();
}

// Like parseBoundedInteger, but a bad value here is a SERVER misconfiguration
// (500), not a client error (400) — these come from env, not the request.
function parseEnvBoundedInteger(
  value: string | null,
  fallback: number,
  minimum: number,
  maximum: number,
  fieldName: string,
): number {
  try {
    return parseBoundedInteger(value, fallback, minimum, maximum, fieldName);
  } catch (error) {
    if (error instanceof HttpError) {
      throw new HttpError(500, error.message);
    }
    throw error;
  }
}

// LAB-ONLY image optimisation. The commercetools sample images are ~4 MB GCS
// originals; serving 20 of them on the PLP causes scroll jank. When enabled,
// this routes each image URL through the free images.weserv.nl resize proxy so
// the browser fetches small variants instead. It is NOT a production image
// pipeline (it sends product image URLs to a third party) — replace with
// Cloudflare Image Resizing or an owned pipeline before any non-lab use.
function resizeImageUrl(originalUrl: string | null, env: Env, width: number): string | null {
  if (!originalUrl) return null;

  const mode = resolveResizeMode(env);
  if (mode === 'none') return originalUrl;
  if (mode !== 'weserv') {
    throw new HttpError(500, `Unsupported CT_IMAGE_RESIZE_MODE: ${mode}`);
  }

  // Only proxy real http(s) URLs; never re-wrap an already-weserv URL.
  let parsed: URL | null = null;
  try {
    parsed = new URL(originalUrl);
  } catch {
    parsed = null;
  }
  if (!parsed || (parsed.protocol !== 'https:' && parsed.protocol !== 'http:')) {
    return originalUrl;
  }
  if (parsed.hostname === 'images.weserv.nl') return originalUrl;

  const quality = parseEnvBoundedInteger(env.CT_IMAGE_QUALITY ?? null, 75, 40, 90, 'CT_IMAGE_QUALITY');
  const output = (env.CT_IMAGE_FORMAT ?? 'webp').trim().toLowerCase();
  if (!RESIZE_FORMATS.has(output)) {
    throw new HttpError(500, `Unsupported CT_IMAGE_FORMAT: ${output}`);
  }

  const params = new URLSearchParams({
    url: originalUrl,
    w: String(width),
    q: String(quality),
    output,
  });
  return `https://images.weserv.nl/?${params.toString()}`;
}

function listingImageWidth(env: Env): number {
  return parseEnvBoundedInteger(env.CT_IMAGE_WIDTH ?? null, 600, 100, 1200, 'CT_IMAGE_WIDTH');
}

function detailImageWidth(env: Env): number {
  return parseEnvBoundedInteger(env.CT_DETAIL_IMAGE_WIDTH ?? null, 1280, 100, 2000, 'CT_DETAIL_IMAGE_WIDTH');
}

// Validate image config up front so a misconfig fails fast (clean 500) BEFORE
// any OAuth/commercetools upstream call.
function assertImageConfig(env: Env): void {
  const mode = resolveResizeMode(env);
  if (mode === 'none') return;
  if (mode !== 'weserv') {
    throw new HttpError(500, `Unsupported CT_IMAGE_RESIZE_MODE: ${mode}`);
  }
  parseEnvBoundedInteger(env.CT_IMAGE_QUALITY ?? null, 75, 40, 90, 'CT_IMAGE_QUALITY');
  const output = (env.CT_IMAGE_FORMAT ?? 'webp').trim().toLowerCase();
  if (!RESIZE_FORMATS.has(output)) {
    throw new HttpError(500, `Unsupported CT_IMAGE_FORMAT: ${output}`);
  }
  listingImageWidth(env);
  detailImageWidth(env);
}

function applyResizedImage(product: CatalogProduct, env: Env, width: number): CatalogProduct {
  return { ...product, imageUrl: resizeImageUrl(product.imageUrl, env, width) };
}

function corsHeaders(request: Request, env: Env): Headers {
  const headers = new Headers({
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Accept, Content-Type',
    'Access-Control-Max-Age': '86400',
    'Content-Type': 'application/json; charset=utf-8',
    Vary: 'Origin',
  });

  const origin = request.headers.get('Origin');
  if (!origin) {
    headers.set('Access-Control-Allow-Origin', firstAllowedOrigin(env));
    return headers;
  }

  if (allowedOrigins(env).has(origin)) {
    headers.set('Access-Control-Allow-Origin', origin);
  }

  return headers;
}

function isAllowedCorsRequest(request: Request, env: Env): boolean {
  const origin = request.headers.get('Origin');
  return !origin || allowedOrigins(env).has(origin);
}

function json(payload: unknown, status: number, headers: Headers): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers,
  });
}

function normalizePathname(pathname: string): string {
  if (pathname.length > 1 && pathname.endsWith('/')) {
    return pathname.slice(0, -1);
  }
  return pathname;
}

function parseBoundedInteger(
  value: string | null,
  fallback: number,
  minimum: number,
  maximum: number,
  fieldName = 'value',
): number {
  if (value === null) return fallback;

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < minimum || parsed > maximum) {
    throw new HttpError(400, `${fieldName} must be an integer between ${minimum} and ${maximum}`);
  }

  return parsed;
}

function assertConfigured(env: Env): void {
  const requiredBindings: Array<keyof Env> = [
    'CT_PROJECT_KEY',
    'CT_API_URL',
    'CT_AUTH_URL',
    'CT_SCOPE',
    'CT_LOCALE_PROJECTION',
    'CT_PRICE_CURRENCY',
    'CT_PRICE_COUNTRY',
    'ALLOWED_ORIGINS',
    'CT_CLIENT_ID',
    'CT_CLIENT_SECRET',
  ];

  const missing = requiredBindings.filter((binding) => !env[binding]);
  if (missing.length > 0) {
    throw new HttpError(500, `Worker is missing required configuration: ${missing.join(', ')}`);
  }
}

function trimTrailingSlash(value: string): string {
  return value.replace(/\/+$/, '');
}

function projectionQuery(
  env: Env,
  options: { limit?: number; offset?: number; where?: string } = {},
): string {
  const params = new URLSearchParams({
    staged: 'false',
    localeProjection: env.CT_LOCALE_PROJECTION,
    priceCurrency: env.CT_PRICE_CURRENCY,
    priceCountry: env.CT_PRICE_COUNTRY,
  });

  if (options.limit !== undefined) {
    params.set('limit', String(options.limit));
  }

  if (options.offset !== undefined) {
    params.set('offset', String(options.offset));
  }

  if (options.where) {
    params.set('where', options.where);
  }

  return params.toString();
}

function allowedOrigins(env: Env): Set<string> {
  return new Set(
    (env.ALLOWED_ORIGINS ?? '')
      .split(',')
      .map((origin) => origin.trim())
      .filter(Boolean),
  );
}

function firstAllowedOrigin(env: Env): string {
  return allowedOrigins(env).values().next().value ?? 'https://kikicommerce.com';
}

async function logUpstreamError(label: string, response: Response, path: string): Promise<void> {
  let body = '';
  try {
    body = await response.text();
  } catch {
    body = '<unreadable body>';
  }

  console.error(label, {
    status: response.status,
    path,
    body: body.slice(0, UPSTREAM_ERROR_LOG_LIMIT),
  });
}

class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}
