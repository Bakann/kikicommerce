# Kiki commercetools catalog proxy

Cloudflare Worker for the read-only Kiki catalog integration. It keeps the
commercetools OAuth client credentials server-side, calls the Product Projection
API, and returns a small JSON model for Flutter Web.

## Endpoints

```text
GET /health
GET /products?limit=20&offset=0
GET /products/:slug
```

`/products/:slug` first tries `GET /product-projections/key={key}` with the
path segment. If no product key matches, it falls back to a slug predicate using
`CT_LOCALE_PROJECTION`. For the most reliable V1 integration, keep
commercetools product keys aligned with storefront slugs.

`/products` returns:

```json
{
  "items": [
    {
      "id": "123",
      "key": "rattan-lounge-chair",
      "slug": "rattan-lounge-chair",
      "name": "Rattan Lounge Chair",
      "description": "...",
      "imageUrl": "https://...",
      "price": {
        "centAmount": 12900,
        "currencyCode": "EUR"
      }
    }
  ]
}
```

## Install

```bash
cd workers/kiki-ct-catalog-proxy
npm install
```

## Local development

Copy the example local env file and fill in the commercetools API client values:

```bash
cp .dev.vars.example .dev.vars
```

Run the Worker locally:

```bash
npm run dev
```

The default non-secret bindings are declared in `wrangler.jsonc`:

```text
CT_PROJECT_KEY=kiki
CT_API_URL=https://api.europe-west1.gcp.commercetools.com
CT_AUTH_URL=https://auth.europe-west1.gcp.commercetools.com
CT_SCOPE=view_published_products:kiki view_categories:kiki
CT_LOCALE_PROJECTION=en-GB
CT_PRICE_CURRENCY=EUR
CT_PRICE_COUNTRY=DE
ALLOWED_ORIGINS=https://kikicommerce.com,https://www.kikicommerce.com,http://localhost:3000
CT_IMAGE_RESIZE_MODE=weserv
CT_IMAGE_WIDTH=600
CT_IMAGE_QUALITY=75
CT_IMAGE_FORMAT=webp
CT_DETAIL_IMAGE_WIDTH=1280
```

`CT_PRICE_COUNTRY=DE` is a **temporary lab setting**: the commercetools sample
data only has EUR prices scoped to DE, so EUR/FR projects no price. For a real
French storefront, add EUR/FR prices in commercetools and switch this back to
`FR`. See [`docs/price-projection-investigation.md`](docs/price-projection-investigation.md).

### Image resizing (lab-only)

The commercetools sample images are heavy GCS originals (~4 MB each), which made
the lab PLP janky (20 × ~4 MB). The Worker rewrites each product `imageUrl`
through the free [images.weserv.nl](https://images.weserv.nl) resize proxy so the
browser fetches small variants — listing at `CT_IMAGE_WIDTH` (600), detail at
`CT_DETAIL_IMAGE_WIDTH` (1280), `CT_IMAGE_QUALITY` (75), `CT_IMAGE_FORMAT`
(webp). Set `CT_IMAGE_RESIZE_MODE=none` to pass originals through. Invalid
mode/format/width values fail fast with a 500.

> **Lab-only.** This sends product image URLs to a third party and is **not** a
> production image pipeline. Replace it with Cloudflare Image Resizing (on a
> custom domain) or an owned pipeline before any non-lab use.

For local browser testing, include the exact Flutter Web origin in
`ALLOWED_ORIGINS`. The list is comma-separated.

`limit` must be an integer from `1` to `100`. `offset` must be an integer from
`0` to `10000`. Invalid values return `400 Bad Request` instead of being
silently changed.

## Secrets

Set the production secrets with Wrangler:

```bash
npx wrangler secret put CT_CLIENT_ID
npx wrangler secret put CT_CLIENT_SECRET
```

Do not commit `.dev.vars`. Do not put the client secret in Flutter Web.

## Deploy

```bash
npm run deploy
```

## Verification

Local examples:

```bash
curl http://localhost:8787/health
curl 'http://localhost:8787/products?limit=20'
curl 'http://localhost:8787/products/rattan-lounge-chair'
```

Deployed examples:

```bash
curl https://kiki-ct-catalog-proxy.<your-subdomain>.workers.dev/health
curl 'https://kiki-ct-catalog-proxy.<your-subdomain>.workers.dev/products?limit=20'
```

## Checks

```bash
npm test
npm run typecheck
npx wrangler deploy --dry-run
```
