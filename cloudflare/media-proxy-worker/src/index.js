const CACHE_TTL_SECONDS = 60 * 60 * 24 * 30;
const STALE_WHILE_REVALIDATE_SECONDS = 60 * 60 * 24;
const CACHE_CONTROL =
  `public, max-age=${CACHE_TTL_SECONDS}, stale-while-revalidate=${STALE_WHILE_REVALIDATE_SECONDS}`;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Allow-Headers': 'Accept, Content-Type, Range',
  'Cross-Origin-Resource-Policy': 'cross-origin',
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method Not Allowed', {
        status: 405,
        headers: corsHeaders,
      });
    }

    if (!url.pathname.startsWith('/img/api/files/')) {
      return new Response('Not Found', { status: 404, headers: corsHeaders });
    }

    const origin = env && env.ORIGIN;
    if (!origin) {
      // Misconfiguration: the [vars] ORIGIN binding must be set in
      // wrangler.toml. Fail loudly rather than silently proxying garbage.
      return new Response('Origin not configured', {
        status: 500,
        headers: corsHeaders,
      });
    }

    const originPath = url.pathname.replace(/^\/img/, '');
    const originUrl = new URL(originPath + url.search, origin);
    const isRangeRequest = request.headers.has('Range');

    if (isRangeRequest) {
      const originResponse = await fetchOrigin(request, originUrl);
      return withCommonHeaders(originResponse);
    }

    if (request.method === 'GET') {
      const cache = caches.default;
      // Full public URL is the Worker Cache API key, including thumb= and v=.
      // Cloudflare's effective edge cache state is reported by cf-cache-status;
      // this proxy header only identifies that media responses are cacheable at
      // the Cloudflare layer.
      const cacheKey = new Request(url.toString(), { method: 'GET' });
      const cached = await cache.match(cacheKey);
      if (cached) {
        return withCommonHeaders(cached);
      }

      const originResponse = await fetchOrigin(request, originUrl);
      if (!isCacheable(originResponse)) {
        return withCommonHeaders(originResponse);
      }

      const response = withCommonHeaders(originResponse);
      response.headers.set('Cache-Control', CACHE_CONTROL);

      ctx.waitUntil(cache.put(cacheKey, response.clone()));
      return response;
    }

    const originResponse = await fetchOrigin(request, originUrl);
    return withCommonHeaders(originResponse);
  },
};

async function fetchOrigin(request, originUrl) {
  const headers = {
    Accept: request.headers.get('Accept') || '*/*',
    'User-Agent': 'KikiCommerceMediaProxy/1.0',
  };
  const range = request.headers.get('Range');
  if (range) {
    headers.Range = range;
  }

  return fetch(
    new Request(originUrl.toString(), {
      method: request.method,
      headers,
    }),
  );
}

function isCacheable(response) {
  if (response.status !== 200) return false;
  const cacheControl = response.headers.get('Cache-Control') || '';
  return !cacheControl.toLowerCase().includes('no-store');
}

function withCommonHeaders(response) {
  const next = new Response(response.body, response);
  for (const [name, value] of Object.entries(corsHeaders)) {
    next.headers.set(name, value);
  }
  if (!isCacheableStatus(response.status)) {
    next.headers.set('Cache-Control', 'no-store');
  }
  next.headers.set('X-Kiki-Media-Proxy', 'cloudflare-cache');
  return next;
}

function isCacheableStatus(status) {
  return status === 200 || status === 206 || status === 304;
}
