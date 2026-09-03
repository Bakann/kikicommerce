# commercetools catalog lab page

An **experimental, isolated** page that lists commercetools products fetched
from the public Cloudflare Worker `kiki-ct-catalog-proxy`. It exists to
validate the path end-to-end:

```
Flutter Web → Cloudflare Worker → commercetools
```

It does **not** replace the PocketBase storefront. The cart, checkout, orders,
PLP, PDP, and all existing providers are untouched.

## Access

Two ways in:

```
/lab/commercetools-products        (direct URL)
Drawer → "Démo commercetools"      (last link)
```

The page is mounted inside `MainShell`, so it uses the storefront chrome, and
it is surfaced as the **last link in the drawer**, labelled
**"Démo commercetools"**, to demonstrate the integration.

It renders with the real **Luxe `ProductCard` grid**: commercetools products
are mapped to the app's catalog UI models by `CommercetoolsCatalogAdapter`
(`lib/data/models/commercetools_catalog_adapter.dart`) and laid out with the
same columns/spacing/aspect ratio as the storefront PLP, forced to the Luxe
(editorial) presentation. There is no internal `AppBar` — `MainShell` carries
the chrome.

It is a **technical demo**, not the official catalog: it does not replace the
PocketBase PLP/PDP and is not wired to the cart/checkout. The goal is to show
the `Flutter → Worker → commercetools` flow.

### Clickable cards → isolated lab PDP

Tapping a card opens a dedicated lab PDP at
`/lab/commercetools-products/:productSlug`
(`LabCommercetoolsProductDetailPage`), reusing the same PDP route transition
and image-Hero mechanism as the PocketBase PLP → PDP path. It is **isolated**
from PocketBase: it never reads `pdpProvider`, the cart, or admin/media
editing. `ProductCard` exposes an optional `onOpen` hook so the lab PLP can
push this route while reusing the card's Hero wiring; the PocketBase storefront
keeps its default `openProductDetail` behavior. The lab PDP reuses the real
Luxe hero components (`PdpHeroContext` + the hero bodies) with edit mode forced
off; "add to cart" shows a "not connected" notice. On deep-link/refresh (no
in-memory hint) the product is resolved from
`commercetoolsCatalogProductsProvider` by slug/key/id.

### How the drawer link works

The live drawer runs in `displayMode: categories`
(`DrawerLiveSource.categories`), so it renders the auto category tree rather
than managed `navigation_items`. The link is therefore added **in code** at the
bottom of the category drawer (`storefront_category_drawer.dart`), not seeded in
PocketBase — a `page`-type managed item would not show without switching the
whole menu to managed mode.

For a future managed drawer, `CatalogRoutes.pageKeyLocation` already maps the
`page` keys `lab_commercetools_products` / `commercetools_lab` to
`/lab/commercetools-products`, so a managed item would resolve correctly. This
commit adds **no PocketBase migration or data** for the link.

## Worker URL (dev)

```
https://kiki-ct-catalog-proxy.herocospo.workers.dev
```

The proxy responds to:

```
GET https://kiki-ct-catalog-proxy.herocospo.workers.dev/products?limit=20
```

## Running

The Worker URL is supplied at build time via `--dart-define`:

```bash
flutter run -d chrome \
  --dart-define=CT_CATALOG_PROXY_URL=https://kiki-ct-catalog-proxy.herocospo.workers.dev
```

Then open `/lab/commercetools-products`.

If `CT_CATALOG_PROXY_URL` is absent or invalid, the page shows:

```
CT_CATALOG_PROXY_URL is not configured.
```

## Building for web

```bash
flutter build web \
  --dart-define=CT_CATALOG_PROXY_URL=https://kiki-ct-catalog-proxy.herocospo.workers.dev
```

## Notes

- **No commercetools secret in Flutter.** The credentials live only in the
  Worker; Flutter calls the public Worker URL.
- **Lab page only** — commercetools is not (yet) the official catalog source.
- **Prices may be `null`.** The sample data currently returns no projected
  price for the configured currency/country, so the UI shows
  *"Prix non disponible"*. Fixing prices is a later step (Worker-side
  `priceCurrency` / `priceCountry` tuning).
- **Image resizing (lab-only).** The commercetools sample images are ~4 MB GCS
  originals; rendering 20 on the PLP caused scroll jank. The **Worker** rewrites
  each `imageUrl` through the [images.weserv.nl](https://images.weserv.nl) resize
  proxy (listing 600px, detail 1280px, q75, webp) so the browser fetches small
  variants — no Flutter change. Controlled by five env vars
  (`CT_IMAGE_RESIZE_MODE`, `CT_IMAGE_WIDTH`, `CT_IMAGE_QUALITY`,
  `CT_IMAGE_FORMAT`, `CT_DETAIL_IMAGE_WIDTH`); `CT_IMAGE_RESIZE_MODE=none`
  disables it. This is **not** a production image pipeline (it sends image URLs
  to a third party); replace it with Cloudflare Image Resizing or an owned
  pipeline before any non-lab use.
