# commercetools projected prices — why `price` is `null`

**Status:** diagnosed and resolved for the lab. `CT_PRICE_COUNTRY` was changed
from `FR` to `DE` (option 1 below) so the lab page shows the existing EUR sample
prices. This is a **temporary lab setting tied to the sample data**, not a
business decision for a French storefront — see the recommendation. The Worker
JSON contract and the strict `variant.price` mapping are unchanged.

## Question

`GET /products` returns `"price": null` for every product, even though the
products are published and otherwise map correctly. Why?

## How it was investigated

A read-only local probe, `scripts/probe-prices.ts`, authenticates with the
commercetools client credentials from `.dev.vars` (never logged) and calls
`/product-projections` with several price-projection combinations, printing for
a sample of products:

- the **projected** price commercetools selects (`masterVariant.price.value`),
- the **embedded** price list (`masterVariant.prices[]`) with each price's
  currency and country.

```bash
cd workers/kiki-ct-catalog-proxy
npx tsx scripts/probe-prices.ts            # sample 5 products per combo
npx tsx scripts/probe-prices.ts --limit=3
```

## Result (117 published products)

Every sampled product (`Bruno Chair`, `Ben Pillow Cover`, `Charlie Armchair`, …)
has the **same three embedded prices**, each scoped to a country:

```
EUR / country=DE
GBP / country=GB
USD / country=US
```

Projection outcome per combination:

| `priceCurrency` | `priceCountry` | `masterVariant.price` |
|-----------------|----------------|-----------------------|
| EUR             | _(none)_       | **null**              |
| EUR             | **FR**  ← current config | **null**     |
| EUR             | DE             | ✅ e.g. `7999 EUR`    |
| EUR             | GB             | **null**              |
| GBP             | GB             | ✅ `7999 GBP`         |
| USD             | US             | ✅ `7999 USD`         |
| _(no projection)_ | _(none)_     | null (only `prices[]` populated) |

## Root cause

The Worker projects with `CT_PRICE_CURRENCY=EUR` + `CT_PRICE_COUNTRY=FR`
(`wrangler.jsonc`, used in `projectionQuery`, `src/index.ts`). The sample
catalog has **no EUR/FR price** — its only EUR price is scoped to **DE**.
commercetools price selection requires the projection to match an existing
price's currency *and* country, so:

- `EUR` + `FR` → no match → `null` (current behaviour).
- `EUR` with **no** country → still `null`, because the EUR price *is*
  country-scoped (to DE); a country-less projection only matches a price with
  no country.

So the strict mapping `variant.price.value` in `toCatalogProduct` is **correct**
— the catalog genuinely returns no projected price for the configured combo.
This is a **data/configuration mismatch**, not a Worker bug. The
`view_published_products` scope is sufficient: prices are present in
`prices[]`; they simply aren't selected by the FR projection.

## Recommendation (next commit, not applied here)

Pick based on intent; do **not** reintroduce `prices[0]` — that would defeat
the deliberate strict, projection-correct mapping.

1. **[APPLIED] Quick win to see EUR prices on the current sample data** — set
   `CT_PRICE_COUNTRY=DE` (keep `CT_PRICE_CURRENCY=EUR`) in `wrangler.jsonc` and
   redeploy. Matches the EUR/DE price the catalog actually has. Done — this is
   a temporary lab setting tied to the sample data.
2. **Proper fix for a French storefront (long-term target)** — add EUR/**FR**
   prices to the products in commercetools, then switch `priceCountry` back to
   `FR`. Preferred long-term; requires catalog data changes, not code.
3. Alternatively switch the lab to a currency/country pair the data supports
   (`GBP`/`GB` or `USD`/`US`) if EUR is not required for the demo.

## Constraints honoured

- No secrets committed or logged (`.dev.vars` is git-ignored; the probe prints
  only statuses and price metadata).
- No change to the Worker JSON contract, the Flutter app, or the lab page.
- The strict `variant.price` mapping is left intact.
