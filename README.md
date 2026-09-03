# Kiki's Commerce

Storefront Flutter branché sur PocketBase, avec un backoffice admin pour :

- importer un CSV catalogue dénormalisé vers les collections `products`, `categories`, `categoryProducts`, `priceRows`, `currencies`, `units`, `medias`, `mediaContainers`
- éditer chaque collection depuis une interface unique
- naviguer rapidement entre les records liés

## Lancer le projet

```bash
flutter pub get
flutter run -d chrome
```

Routes utiles :

- `/` : storefront. La home charge automatiquement la première catégorie active.
- `/admin` : backoffice admin PocketBase.

## Variables d'environnement (`--dart-define`)

| Variable | Défaut | Description |
|---|---|---|
| `API_BASE_URL` | `https://kiki-commerce.pockethost.io` | Origine PocketBase pour toutes les lectures et mutations. |
| `MEDIA_BASE_URL` | _(non défini → fallback `API_BASE_URL`)_ | Origine CDN pour les URLs médias publiques. **Obligatoire en prod** : `ApiConfig.assertMediaConfigured` lève en `kReleaseMode` si la valeur n'est pas fournie au build. |
| `USE_CART_ADD_ENDPOINT` | `true` | Bascule entre la route panier custom (`POST /api/cart/add-item`) et le flow legacy. |
| `ENABLE_NAVBAR_SHADERS` | `false` | Active les runtime-shaders de la navbar Sport (anneau Home multipasse et loupe Search). Désactivé par défaut : Home et Search utilisent de simples icônes Material, sans anneau, loupe custom ni découpe optique. |
| `ENABLE_MOBILE_WEB_IRIDESCENT_FEEDBACK` | `false` | Réactive le feedback shader texturé du bouton Accueil sous 768 px pour un A/B contrôlé, uniquement si `ENABLE_NAVBAR_SHADERS=true`. Le défaut statique évite ce runtime-effect pendant l'isolation du crash skwasm mobile. |

Exemple de build prod :

```bash
flutter build web --release --wasm \
  --dart-define=API_BASE_URL=https://kiki-commerce.pockethost.io \
  --dart-define=MEDIA_BASE_URL=https://kikicommerce.com/img
```

Le build web de production utilise le renderer **skwasm** (`--wasm` = dart2wasm +
skwasm). Le build CanvasKit (dart2js) provoquait du jank généralisé sur cette app
lourde en shaders/animations, d'où le retour à skwasm pour la performance.
**Compromis connu :** skwasm réintroduit le freeze mobile empty-PLP → Home
(risque ouvert, à corriger côté skwasm — upgrade Flutter / workaround ciblé),
documenté dans
[`docs/incidents/2026-07-09-skwasm-paragraph-relayout-freeze.md`](docs/incidents/2026-07-09-skwasm-paragraph-relayout-freeze.md).

Sans `MEDIA_BASE_URL` au build prod, le binaire échouera au démarrage avec un `StateError` clair plutôt que de servir silencieusement les images depuis PocketBase.

## CI / déploiement

- **`Quality Gate`** (`.github/workflows/quality.yml`) — `flutter pub get`, `flutter analyze`, `flutter test`, `dart format --set-exit-if-changed`, `node --check` du worker. Tourne sur PR + push `main`.
- **`Deploy Flutter Web to Cloudflare Pages`** (`.github/workflows/deploy.yml`) — se déclenche **uniquement** sur succès du Quality Gate via `workflow_run`. Skippe si le seul changement concerne le worker.
- **`Deploy Media Worker to Cloudflare`** (`.github/workflows/deploy-media-worker.yml`) — déploie le Worker quand `cloudflare/media-proxy-worker/**` change.

Secrets attendus côté GitHub : `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.

## Backoffice admin

Le backoffice permet deux modes d'authentification :

- jeton admin PocketBase
- email + mot de passe `_superusers`

Une fois connecté :

- chargez le CSV exemple
- importez-le pour hydrater les 8 collections
- éditez les records collection par collection

Le CSV d'exemple se trouve ici :

- `assets/admin/sample_catalog.csv`

Il crée :

- 3 catégories
- 6 produits
- leurs médias et mediaContainers
- leurs liaisons `categoryProducts`
- 1 devise et 1 unité
- 6 lignes de prix

## Cart custom routes

Les flows panier guest utilisent des routes PocketBase custom pour éviter que
le client orchestre les écritures sensibles ligne par ligne :

- hook JS : `pocketbase/pb_hooks/main.pb.js` (route + duplication actuelle)
- module isolé : `pocketbase/pb_hooks/cart_add_item.js`
- module clear : `pocketbase/pb_hooks/cart_clear.js`
- persistance d'idempotence : `pocketbase/pb_migrations/1776800120_create_cart_add_idempotency.js`

Le client Flutter active le chemin add-item par défaut. Pour forcer
temporairement le legacy flow côté app :

```bash
flutter run -d chrome --dart-define=USE_CART_ADD_ENDPOINT=false
```

Le rollout attendu est :

1. déployer les migrations + `pb_hooks`
2. valider les routes `POST /api/cart/add-item` et `POST /api/cart/clear`
3. déployer le frontend avec le flag par défaut, ou forcer `USE_CART_ADD_ENDPOINT=true`

## Media CDN proxy

Par défaut, l'API et les médias pointent vers PocketBase :

```bash
flutter run -d chrome
```

En production, les URLs médias publiques passent par le proxy Cloudflare :

```bash
flutter build web --release --wasm \
  --dart-define=API_BASE_URL=https://kiki-commerce.pockethost.io \
  --dart-define=MEDIA_BASE_URL=https://kikicommerce.com/img
```

Le proxy média mappe :

```text
https://kikicommerce.com/img/api/files/{collectionId}/{recordId}/{filename}?thumb=600x800f&v=...
```

vers :

```text
https://kiki-commerce.pockethost.io/api/files/{collectionId}/{recordId}/{filename}?thumb=600x800f&v=...
```

L'origine PocketBase du worker est lue depuis le binding `[vars] ORIGIN` déclaré dans `cloudflare/media-proxy-worker/wrangler.toml` et `wrangler.ci.toml`. Override ponctuel :

```bash
npx wrangler deploy --var ORIGIN=https://staging-pb.example.com
```

Déploiement manuel standard :

```bash
cd cloudflare/media-proxy-worker
npx wrangler deploy
```

### Smoke test post-deploy

```bash
curl -I 'https://kikicommerce.com/img/api/files/<collection>/<record>/<file>.jpg?thumb=600x800f'
```

Attendu :

- `HTTP 200`, `cf-cache-status: HIT` (au second appel) ou `MISS` (premier appel)
- `x-kiki-media-proxy: cloudflare-cache`
- `cache-control: max-age=2592000, stale-while-revalidate=86400`

Un 404 doit revenir avec `cache-control: no-store` (sinon une URL périmée resterait coincée au CDN).

## Configurations CMS publiques

Les collections suivantes sont **publiques en lecture** (`listRule: ''`, `viewRule: ''`) — c'est intentionnel pour permettre au storefront de charger ses sections sans token :

- `cms_pages`, `page_sections`
- `navigation_menus`, `navigation_items`
- `drawer_navigation_*`
- `storefront_settings` (clé `brand`)

Conséquence : **ne jamais stocker de données sensibles dans la `config` JSON** d'une section CMS ou d'un item de navigation. Tout ce qui est saisi y est lisible publiquement par n'importe quel client.

Pour les données sensibles (clés API, configurations admin, etc.), utiliser une collection dédiée avec des règles d'accès restreintes.
