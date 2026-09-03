/**
 * Local, non-intrusive diagnostic probe for commercetools price projection.
 *
 * Why this exists: the Worker maps `variant.price.value` (the price projected
 * by commercetools for the configured `priceCurrency`/`priceCountry`). The
 * `/products` endpoint currently returns `price: null`, and we want to know
 * *why* before changing the strict mapping — does the catalog have prices at
 * all, in which currencies, and with or without a country?
 *
 * This script does NOT touch the Worker contract, the Flutter app, or any
 * production behaviour. It only reads. Run it locally:
 *
 *   cd workers/kiki-ct-catalog-proxy
 *   npx tsx scripts/probe-prices.ts          # sample 5 products per combo
 *   npx tsx scripts/probe-prices.ts --limit=3
 *
 * Credentials come from `.dev.vars` (git-ignored) or process.env. Secrets are
 * never logged.
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKER_ROOT = join(__dirname, '..');

// Defaults mirror wrangler.jsonc `vars`. Only the two secrets must come from
// .dev.vars / env.
const DEFAULTS = {
  CT_PROJECT_KEY: 'kiki',
  CT_API_URL: 'https://api.europe-west1.gcp.commercetools.com',
  CT_AUTH_URL: 'https://auth.europe-west1.gcp.commercetools.com',
  CT_SCOPE: 'view_published_products:kiki view_categories:kiki',
  CT_LOCALE_PROJECTION: 'en-GB',
};

interface Money {
  centAmount: number;
  currencyCode: string;
  fractionDigits?: number;
}

interface Price {
  value?: Money;
  country?: string;
  channel?: { id?: string };
  customerGroup?: { id?: string };
  validFrom?: string;
  validUntil?: string;
}

interface Variant {
  id?: number;
  price?: Price;
  prices?: Price[];
}

interface ProductProjection {
  id: string;
  key?: string;
  slug?: Record<string, string | undefined>;
  name?: Record<string, string | undefined>;
  masterVariant?: Variant;
}

interface PagedResponse {
  total?: number;
  results?: ProductProjection[];
}

interface PriceCombo {
  label: string;
  priceCurrency?: string;
  priceCountry?: string;
}

const COMBOS: PriceCombo[] = [
  { label: 'EUR (no country)', priceCurrency: 'EUR' },
  { label: 'EUR / FR', priceCurrency: 'EUR', priceCountry: 'FR' },
  { label: 'EUR / DE', priceCurrency: 'EUR', priceCountry: 'DE' },
  { label: 'EUR / GB', priceCurrency: 'EUR', priceCountry: 'GB' },
  { label: 'GBP / GB', priceCurrency: 'GBP', priceCountry: 'GB' },
  { label: 'USD / US', priceCurrency: 'USD', priceCountry: 'US' },
  { label: 'no price projection (inspect embedded prices[])' },
];

function loadDevVars(): Record<string, string> {
  const out: Record<string, string> = {};
  try {
    const raw = readFileSync(join(WORKER_ROOT, '.dev.vars'), 'utf8');
    for (const line of raw.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eq = trimmed.indexOf('=');
      if (eq === -1) continue;
      out[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim();
    }
  } catch {
    // No .dev.vars — fall back entirely to process.env.
  }
  return out;
}

function resolveConfig() {
  const devVars = loadDevVars();
  const get = (key: string, fallback?: string): string | undefined =>
    process.env[key] ?? devVars[key] ?? fallback;

  const clientId = get('CT_CLIENT_ID');
  const clientSecret = get('CT_CLIENT_SECRET');
  if (!clientId || !clientSecret) {
    throw new Error(
      'Missing CT_CLIENT_ID / CT_CLIENT_SECRET. Set them in .dev.vars or env.',
    );
  }

  return {
    clientId,
    clientSecret,
    projectKey: get('CT_PROJECT_KEY', DEFAULTS.CT_PROJECT_KEY)!,
    apiUrl: trimSlash(get('CT_API_URL', DEFAULTS.CT_API_URL)!),
    authUrl: trimSlash(get('CT_AUTH_URL', DEFAULTS.CT_AUTH_URL)!),
    scope: get('CT_SCOPE', DEFAULTS.CT_SCOPE)!,
    locale: get('CT_LOCALE_PROJECTION', DEFAULTS.CT_LOCALE_PROJECTION)!,
  };
}

function trimSlash(value: string): string {
  return value.replace(/\/+$/, '');
}

function parseLimit(): number {
  const arg = process.argv.find((a) => a.startsWith('--limit='));
  if (!arg) return 5;
  const n = Number(arg.split('=')[1]);
  return Number.isInteger(n) && n > 0 && n <= 50 ? n : 5;
}

async function getToken(config: ReturnType<typeof resolveConfig>): Promise<string> {
  const credentials = Buffer.from(
    `${config.clientId}:${config.clientSecret}`,
  ).toString('base64');
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    scope: config.scope,
  });

  const res = await fetch(`${config.authUrl}/oauth/token`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      Accept: 'application/json',
    },
    body,
  });

  if (!res.ok) {
    // Never echo the request body / credentials, only the status.
    throw new Error(`OAuth token request failed: HTTP ${res.status}`);
  }

  const payload = (await res.json()) as { access_token?: string };
  if (!payload.access_token) {
    throw new Error('OAuth response did not include an access token.');
  }
  return payload.access_token;
}

async function fetchProjections(
  config: ReturnType<typeof resolveConfig>,
  token: string,
  combo: PriceCombo,
  limit: number,
): Promise<PagedResponse> {
  const params = new URLSearchParams({
    staged: 'false',
    localeProjection: config.locale,
    limit: String(limit),
  });
  if (combo.priceCurrency) params.set('priceCurrency', combo.priceCurrency);
  if (combo.priceCountry) params.set('priceCountry', combo.priceCountry);

  const url = `${config.apiUrl}/${encodeURIComponent(config.projectKey)}/product-projections?${params}`;
  const res = await fetch(url, {
    headers: { Accept: 'application/json', Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`product-projections failed (${combo.label}): HTTP ${res.status}`);
  }
  return (await res.json()) as PagedResponse;
}

function localized(value: Record<string, string | undefined> | undefined): string {
  if (!value) return '-';
  return value['en-GB'] ?? value['fr-FR'] ?? Object.values(value).find(Boolean) ?? '-';
}

function moneyLabel(money: Money | undefined): string {
  if (!money) return 'null';
  return `${money.centAmount} ${money.currencyCode}`;
}

function describeEmbeddedPrices(prices: Price[] | undefined): string {
  if (!prices || prices.length === 0) return 'none';
  return prices
    .map((p) => {
      const parts = [p.value?.currencyCode ?? '?'];
      if (p.country) parts.push(`country=${p.country}`);
      if (p.channel?.id) parts.push('channel');
      if (p.customerGroup?.id) parts.push('customerGroup');
      return parts.join('/');
    })
    .join(', ');
}

async function main(): Promise<void> {
  const config = resolveConfig();
  const limit = parseLimit();

  console.log('commercetools price projection probe');
  console.log(`project=${config.projectKey} locale=${config.locale} sample=${limit}`);
  console.log('(secrets are never printed)\n');

  const token = await getToken(config);

  for (const combo of COMBOS) {
    const page = await fetchProjections(config, token, combo, limit);
    const results = page.results ?? [];
    const withPrice = results.filter((p) => p.masterVariant?.price?.value).length;

    console.log('='.repeat(72));
    console.log(`COMBO: ${combo.label}`);
    console.log(`  total in project: ${page.total ?? '?'}`);
    console.log(`  sampled: ${results.length}  with projected masterVariant.price: ${withPrice}`);

    for (const product of results) {
      const mv = product.masterVariant;
      console.log(
        `  - ${localized(product.name)} | key=${product.key ?? '-'} ` +
          `slug=${localized(product.slug)}`,
      );
      console.log(`      projected price : ${moneyLabel(mv?.price?.value)}`);
      console.log(`      embedded prices : ${describeEmbeddedPrices(mv?.prices)}`);
    }
    console.log('');
  }

  console.log('Done. See docs/price-projection-investigation.md for analysis.');
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
