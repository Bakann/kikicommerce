# Kiki Commerce media proxy

Cloudflare Worker for public storefront media URLs under `/img/api/files/*`.

It maps:

```text
https://kikicommerce.com/img/api/files/{collectionId}/{recordId}/{filename}?thumb=600x800f&v=...
```

to:

```text
https://kiki-commerce.pockethost.io/api/files/{collectionId}/{recordId}/{filename}?thumb=600x800f&v=...
```

The PocketBase origin is read from the `ORIGIN` Worker var declared in
`wrangler.toml` / `wrangler.ci.toml`. Override per environment with
`wrangler deploy --var ORIGIN=https://...` when targeting a non-prod
PocketBase. If the binding is missing the Worker returns `500 Origin not
configured` rather than silently proxying to a wrong host.

Deploy manually after confirming the Cloudflare zone:

```bash
npx wrangler deploy
```

Deployments also run automatically from GitHub Actions after a merge to `main`
when files under `cloudflare/media-proxy-worker/**` change. The workflow uses
the repository secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
CI uses `wrangler.ci.toml` to update the existing Worker script without
rewriting the Cloudflare route, which remains declared in `wrangler.toml` for
manual route-aware deploys.

The worker only caches `GET 200` responses, uses the full public URL including
query string as cache key, and keeps `thumb` and `v` as distinct cache entries.
Non-cacheable responses such as `404` are returned with `Cache-Control:
no-store` so a restored or re-uploaded PocketBase file is visible immediately.
Range requests are forwarded to PocketBase and bypass the Worker cache so HTML5
video seek/playback can receive origin `206 Partial Content` responses.

`X-Kiki-Media-Proxy: cloudflare-cache` identifies responses served through this
proxy. The effective Cloudflare CDN result is reported by Cloudflare's own
`cf-cache-status` response header; use that header to verify `HIT`, `MISS`, or
other edge-cache states.

Manual verification after deployment:

```bash
curl -I 'https://kikicommerce.com/img/api/files/pbc_633459407/7g9revmp0t99m79/chat_gpt_image_may_3_2026_06_13_25_pm_h465btpk8h_1m20a6f1t7.jpg?v=1777824969075&thumb=600x800f'
```

Expected result after the URL has been cached by Cloudflare:

```text
HTTP 200
server: cloudflare
cf-cache-status: HIT
cache-control: max-age=2592000, stale-while-revalidate=86400
x-kiki-media-proxy: cloudflare-cache
```
