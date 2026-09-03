# Inventaire du schéma PocketBase — kiki commerce

> **Phase 0 du plan de migration.** Document généré le 2026-06-10 à partir de :
> 1. les migrations du repo (`pocketbase/pb_migrations/`, 32 fichiers) — **autoritatif** pour 8 collections ;
> 2. le code Flutter (modèles `lib/data/models/`, import/export CSV `lib/admin/`, définitions backoffice `lib/admin/admin_collection_schema.dart`) — pour les 9 collections importées par CSV dont le schéma n'est pas dans le repo ;
> 3. un **échantillonnage anonyme de l'API live** (`https://kiki-commerce.pockethost.io`) le 2026-06-10 — toutes les collections catalogue et CMS ont répondu en lecture publique, confirmant champs et règles.

**Légende des sources** : ✅ migration dans le repo · 🔎 reconstruit depuis le code Flutter · 🌐 confirmé par l'API live.

**Volumes constatés (live, 2026-06-10)** : products 25 · categories 90 · categoryProducts 25 · priceRows 24 · currencies 1 · units 1 · medias 73 · mediaContainers 21 · narrativeChapters 3 · pages 8 · page_sections 44 · navigation_menus 1 · navigation_items 4 · storefront_settings 3. Dataset très petit : la migration des données sera rapide et rejouable sans contrainte de fenêtre.

Tous les enregistrements portent les champs système PocketBase : `id` (15 caractères alphanumériques), `collectionId`, `collectionName`, et pour la plupart `created`/`updated` (autodate, format `YYYY-MM-DD HH:MM:SS.sssZ`).

---

## Module cible : catalog

### `products` 🔎🌐
Importée via CSV admin ; schéma reconstruit depuis `lib/data/models/product.dart`, `admin_collection_schema.dart`, `admin_import_service.dart` et confirmé sur l'échantillon live.

| Champ | Type | Requis | Notes |
|---|---|---|---|
| code | text | oui | identifiant métier (`PROD-ROBE-001`), clé d'upsert à l'import CSV |
| name | text | oui | |
| slug | text | non | utilisé pour le routage produit |
| summary | text (HTML) | non | |
| description | text (HTML) | non | |
| ean | text | non | |
| gender | text | non | valeurs constatées : `girl`, … |
| productType | text | non | |
| brand | text | non | |
| isActive | bool | — | filtre systématique côté storefront |
| isStorefrontVisible | bool | — | **⚠ présent en base (live) mais introuvable dans tout le code du repo** — ni modèle, ni import, ni filtre. À trancher : champ mort à abandonner ? |
| onlineDate | date | non | non filtré par l'app (affichage/donnée seulement) |
| offlineDate | date | non | idem |
| picture | relation → medias (1) | non | image principale |
| thumbnail | relation → medias (1) | non | miniature listing |
| galleryImages | relation → mediaContainers (N) | non | en pratique 0..1 conteneur par produit à l'import |
| searchIndex | text | — | **champ calculé à l'import** (`buildProductSearchIndex` : concat normalisée name/summary/description/brand/type/ean/code, cf. `lib/core/utils/search_index_utils.dart`) ; cible du `~` full-text de la recherche |

Règles : lecture publique (list/view confirmés anonymement) ; écriture authentifiée (backoffice).

### `categories` 🔎🌐 (+ ✅ partiel)
Importée via CSV ; les champs `position` et `isHidden` + l'index `idx_categories_drawer_order (isActive, isHidden, parent, position)` ont été ajoutés par la migration `1777000240_add_category_drawer_controls.js`.

| Champ | Type | Requis | Notes |
|---|---|---|---|
| code | text | oui | clé d'upsert CSV (`CAT-ROBES`) |
| name | text | oui | |
| description | text | non | |
| slug | text | non | routage PLP |
| parent | relation → categories (1) | non | hiérarchie (drawer en mode `categories`) |
| position | number (int) | non | ordre drawer/affichage |
| isActive | bool | — | |
| isHidden | bool | — | masque du drawer sans désactiver |

Règles : lecture publique ; écriture authentifiée.

### `categoryProducts` 🔎🌐
Table de liaison N-N catégorie↔produit, avec ordre et canonicité.

| Champ | Type | Requis | Notes |
|---|---|---|---|
| category | relation → categories (1) | oui | |
| product | relation → products (1) | oui | |
| position | number (int) | non | ordre dans la PLP |
| isPrimary | bool | — | catégorie canonique du produit (résolution d'URL produit) |
| isActive | bool | — | |

Règles : lecture publique ; écriture authentifiée. Unicité (category, product) assurée par la logique d'import, **pas par un index** constaté.

### `priceRows` 🔎🌐
| Champ | Type | Requis | Notes |
|---|---|---|---|
| product | relation → products (1) | oui | |
| currency | relation → currencies (1) | oui | |
| unit | relation → units (1) | non | |
| price | **number (float)** | oui | ex. `69.9` — **⚠ float en base, à convertir en centimes entiers** |
| minqtd | number (int) | non | |
| net | bool | non | |
| startTime | date | non | non filtré par l'app (pas de logique de validité temporelle côté client) |
| endTime | date | non | idem |
| channel | text | non | ex. `web` |
| isDefault | bool | — | |
| isActive | bool | — | filtre systématique |

Règles : lecture publique ; écriture authentifiée.

### `currencies` 🔎🌐
`isocode` (text, requis, ex. `EUR`), `symbol` (text, requis), `name` (text), `digits` (number int), `isActive` (bool). Lecture publique. 1 seul enregistrement (EUR) — cohérent avec le mono-devise du plan.

### `units` 🔎🌐
`code` (text, requis, ex. `PCS`), `name` (text, requis), `symbol` (text), `isActive` (bool). Lecture publique. 1 seul enregistrement.

### `medias` 🔎🌐
Collection à **champs fichiers PocketBase** — c'est elle qui devient des clés R2.

| Champ | Type | Requis | Notes |
|---|---|---|---|
| code | text | oui | clé d'upsert CSV (`MED-ROBE-001-TH`) |
| title | text | non | |
| altText | text | non | |
| mimeType | text | non | `image/png`, vidéos `video/mp4` constatées dans les configs CMS |
| file | **file** | — | fichier servi (souvent recadré par le backoffice) |
| originalFile | **file** | non | original conservé lors d'un recadrage |
| cropPreset | text | non | preset de recadrage backoffice |
| cropX / cropY / cropWidth / cropHeight | number | non | coordonnées du recadrage |
| isActive | bool | — | |

Règles : lecture publique ; écriture authentifiée (multipart). URLs servies via `/api/files/{collectionIdOrName}/{recordId}/{filename}` avec paramètre optionnel `?thumb=WxH` (thumbs dynamiques PocketBase) et `?v=` (cache-busting basé sur `updated`).

### `mediaContainers` 🔎🌐
Galeries ordonnées. `code` (text, requis), `name` (text), `medias` (relation → medias, **multiple**, l'ordre du tableau est significatif), `isActive` (bool). Lecture publique.

### `narrativeChapters` 🔎🌐
Storytelling PDP. `product` (relation 1, requis), `media` (relation → medias 1, requis), `position` (int, requis), `headline` (text, requis), `story` (text), `ctaLabel` (text), `ctaAction` (select : `zoom`, `sizeGuide`, `materialDetail`, `none`), `isActive` (bool). Lecture publique. Contrainte logique d'import : le média doit appartenir à la galerie visible du produit ; unicité (product, media) par la logique d'import.

### `product_foils` ✅
Couche décorative publiée par le Foil studio, une ligne par produit. Lecture
publique pour le PDP, écriture authentifiée. L'URL `source_image` identifie le
média exact utilisé lors de la génération ; le storefront ignore le record si
ce média n'est pas celui affiché.

| Champ | Type | Notes |
|---|---|---|
| product_id | text, requis, unique | id PocketBase du produit |
| source_image | text | URL exacte de l'image source |
| preset | json | effet classique et flags `parallax`, `volume`, `particles` |
| foil / mask | file | relief holo et masque d'effet classiques |
| product_image | file | copie WebP redimensionnée exacte utilisée par le bundle 2,5D |
| subject_mask | file | alpha BiRefNet du sujet, distinct du masque d'effet |
| background_clean | file | fond reconstruit sans le sujet |
| rim | file | bande alpha du contour pour la rim light |
| depth_map | file | carte Depth Anything V2 conservée pour audit |
| depth_mesh | json | grille signée et épinglée au contour utilisée au runtime |
| particles | json | points d'émission normalisés et déterministes |

Les champs 2,5D sont optionnels : un ancien record reste un foil classique. Un
preset Volume sans bundle complet retombe sur la photo/foil classique.

---

## Module cible : cms

### `pages` ✅🌐 (`1776900000`, étendue par `1777000000`)
| Champ | Type | Requis | Contraintes |
|---|---|---|---|
| code | text | oui | `^[a-z0-9_]+$`, 1–64 |
| locale | text | oui | `^[a-z]{2}(-[a-z]{2})?$` |
| title | text | oui | 1–200 |
| isActive | bool | non | |
| pageType | select | non | `home` \| `plp` \| `content` |
| sourceCategory | relation → categories (1) | non | rattache une page PLP à sa catégorie |
| seoTitle | text | non | max 180 |
| seoDescription | text | non | max 320 |

Index : UNIQUE (code, locale) ; (isActive) ; (pageType, sourceCategory, locale, isActive).
Règles : list/view publics (`''`) ; create/update/delete : tout utilisateur authentifié (`@request.auth.id != ''`).
Codes constatés/documentés : `homepage`, `homepage_nike`, landings segments Nike, pages PLP par catégorie.

### `page_sections` ✅🌐 (`1776900060`, types étendus par `1777000000/330/500`)
| Champ | Type | Requis | Contraintes |
|---|---|---|---|
| page | relation → pages (1) | oui | cascadeDelete: true |
| sectionId | text | oui | `^[a-z0-9_-]+$`, 1–64 |
| sectionType | select | oui | 15 valeurs : `hero_campaign`, `editorial_story`, `category_tiles`, `featured_products`, `service_cards`, `collection_hero`, `editorial_intro`, `mixed_product_grid`, `seo_text`, `discover_links`, `horizontal_tile_carousel`, `brand_segment`, `category_split_tabs`, `category_banner_strip` |
| position | number (int) | non | |
| isActive | bool | non | |
| config | **json** | oui | max 200 Ko ; schéma libre par type de section, parsé côté Flutter (`parseCmsSection`) |

Index : (page) ; (page, position) ; (page, isActive). Règles : publiques en lecture, authentifié en écriture.
**⚠ Les `config` embarquent des références médias PocketBase** au format `{collectionId, recordId, filename, alt}` (ex. `mediaDesktop`/`mediaMobile` du hero, tuiles, items de `featured_products` par id produit). La migration devra réécrire ces références (→ clés R2) **dans le JSON**, pas seulement dans les tables.

### `navigation_menus` ✅🌐 (`1745136000`, `displayMode` étendu par `1776770699`)
`name` (text 1–160, requis), `code` (text `^[a-z0-9_]+$` 1–64, requis, UNIQUE), `displayMode` (select : `drawer` \| `categories`, requis), `isActive` (bool, requis). Lecture publique, écriture authentifiée. Le seul menu live est `main_drawer` en mode `categories` (le drawer est alors construit depuis l'arbre `categories`, pas depuis `navigation_items`).

### `navigation_items` ✅🌐 (`1745136060`, `config` ajouté par `1777000060`)
| Champ | Type | Requis | Notes |
|---|---|---|---|
| menu | relation → navigation_menus (1) | oui | cascadeDelete |
| parent | relation → navigation_items (1) | non | hiérarchie |
| position | number (int ≥0) | oui | |
| label | text 1–160 | oui | |
| itemType | select | oui | `category` \| `product` \| `page` \| `external` |
| category | relation → categories (1) | non | cible si itemType=category |
| product | relation → products (1) | non | |
| pageKey | text `^[a-z0-9_]+$` ≤64 | non | |
| url | url | non | cible externe |
| promoMedia | relation → medias (1) | non | visuel promo |
| placement | select | oui | `nav` \| `promo` |
| desktopDrawerTemplate | select | non | `list_only` \| `hero_single` \| `promo_grid_2x2` \| `promo_stack_2` |
| config | json ≤200 Ko | non | ex. `drawer_editorial_tiles` — **embarque aussi des références médias** (⚠ même réécriture que page_sections.config) |
| isActive / isHidden | bool | oui | |

Index : (menu) ; (parent) ; (menu,parent) ; (menu,position) ; (menu,isActive). Lecture publique, écriture authentifiée.

### `storefront_settings` ✅🌐 (`1777000120` puis 6 migrations d'extension)
Collection clé-valeur « à plat » : un enregistrement par `key`, tous les champs existent sur tous les enregistrements mais seuls ceux de la clé sont renseignés.

| Champ | Type | Notes |
|---|---|---|
| key | text `^[a-z0-9_]+$` 1–64, requis, **UNIQUE** (`1777000560`, avec dédup préalable) | clés connues : `brand`, `navigation`, `active_theme` |
| brandTitle | text ≤60 | clé `brand` |
| brandHref | text ≤200 | clé `brand` |
| mobileMenuStyle | text ≤32 | clé `navigation` ; valeurs valides : `drawer` \| `fullscreenReveal` |
| theme | text ≤32 | clé `active_theme` ; valeurs valides : `dior` \| `nike` |
| replaceMobileLogoWithThemeSwitcher | bool | clé `navigation` (`1777000640`) |
| categorySplitDisplayMode | text ≤32 | clé `navigation` (`1777000780`) ; `tabs` \| `expansible` |

Règles : list/view publics **filtrés par règle** `key = "brand" || key = "navigation" || key = "active_theme"` ; écriture authentifiée. La logique de normalisation/validation est dupliquée dans `pocketbase/pb_lib/storefront_settings_dedup.js` (testée sous Node).

---

## Module cible : sales

### `carts` ✅ (`1776800000`)
| Champ | Type | Requis | Notes |
|---|---|---|---|
| user | relation → users (1) | non | panier d'un client connecté (non utilisé en pratique : pas de login client dans l'app) |
| guest_id | text, pattern UUID v4 ≤36 | non | identifiant invité généré côté app |
| status | select | oui | `active` \| `converted` \| `abandoned` (défaut `active`) |
| currency_code | text `^[A-Z]{3}$` | oui | défaut `EUR` |
| subtotal, discount_total, shipping_total, tax_total, grand_total | number ≥0 | oui | **floats** ; le commentaire de migration précise : totaux écrits par le client = affichage uniquement, à recalculer côté serveur avant checkout |

Index : (guest_id) ; (user) ; **UNIQUE partiel** `(guest_id) WHERE status='active'` — un seul panier actif par invité.
Règles d'accès (le point le plus complexe du schéma) : list/view/create/update conditionnés soit à `user = @request.auth.id`, soit à l'égalité **header** `X-Cart-Guest-Id` ↔ `guest_id` ; l'update invité interdit de toucher `user`, `guest_id`, `currency_code`, `status` ; delete réservé au propriétaire authentifié.

### `cart_entries` ✅ (`1776800060`)
| Champ | Type | Requis | Notes |
|---|---|---|---|
| cart | relation → carts (1) | oui | cascadeDelete |
| product | relation → products (1) | oui | V1 agrège **par produit** (pas de variante) — UNIQUE (cart, product) |
| sku_snapshot | text ≤64 | non | copie de `products.code` |
| product_name_snapshot | text 1–320 | oui | |
| quantity | number int ≥1 | oui | |
| unit_price | number ≥0 | oui | **float**, copié de `priceRows.price` |
| line_total | number ≥0 | oui | calculé `unit_price × quantity` |

Règles : mêmes conditions que `carts` via la relation (`cart.user` / `cart.guest_id` + header).

### `cart_add_idempotency` ✅ (`1776800120`)
Cache d'idempotence du hook add-item : `guest_id` (UUID v4), `idempotency_key` (≤128), `request_hash` (sha256 du payload), `response_body` (text ≤4096, JSON sérialisé), `status_code` (200–599). UNIQUE (guest_id, idempotency_key). **Toutes règles `null`** : accessible uniquement par le hook serveur. → Non migrée ; remplacée par le mécanisme d'idempotence du nouveau backend.

---

## Module cible : identity

### `users` (collection auth système PocketBase)
Aucune migration dans le repo ; champs PocketBase standard (email, password, verified…). Usages constatés :
- `POST /api/collections/users/auth-with-password` (`AdminClient.authenticateUser`) — connexion « éditeur CMS » : les règles d'écriture des collections CMS exigent juste `@request.auth.id != ''`.
- Cible de la relation `carts.user` (inutilisée en pratique : pas de compte client dans le storefront).
- Liste anonyme : 0 enregistrement visible (règle restrictive ou collection vide — **non vérifiable sans accès superuser** ; à confirmer avant migration).

### `_superusers` (système PocketBase)
`POST /api/collections/_superusers/auth-with-password` (`authenticateSuperuser`) — connexion backoffice (import/export CSV, CRUD catalogue, médias). → cible : `users.role = 'admin'` dans le nouveau backend.

---

## Endpoint custom existant : `POST /api/cart/add-item` ✅
Défini dans `pocketbase/pb_hooks/main.pb.js` ; logique pure dans `pb_hooks/cart_add_item.js` (testée sous Node, `test/pocketbase/`). Activé côté app par `USE_CART_ADD_ENDPOINT` (défaut true) avec **fallback legacy** (CRUD direct carts/cart_entries) si la route renvoie 404/405/501.

**Contrat** :
- Headers requis : `X-Cart-Guest-Id` (UUID invité), `Idempotency-Key`.
- Body : `{ productId, priceId, quantity }` (quantity entier > 0).
- Comportement (transactionnel) : idempotence (rejoue la réponse stockée si clé connue et hash identique, 409 `idempotency_key_reused` sinon) → valide produit actif (404), priceRow actif (404) et appartenance prix↔produit (400) → résout la devise (`currencies.isocode`) → trouve ou crée le panier actif invité (gère la course via l'index unique) → 409 `cart_currency_mismatch` si devise différente → upsert de la ligne (incrémente la quantité, reprice au `priceRows.price` courant) → enregistre l'idempotence.
- Réponse 200 : `{ cartId, entryProductId, quantityDelta, cartCreated }`.
- Erreurs : `{ code, message }` — codes : `missing_guest_header`, `missing_idempotency_key`, `missing_product_id`, `missing_price_id`, `invalid_quantity`, `product_not_found`, `price_not_found`, `price_product_mismatch`, `currency_not_found`, `cart_guest_mismatch`, `cart_currency_mismatch`, `idempotency_key_reused`, `cart_add_internal_error`.
- Observabilité : header `Server-Timing: cart_add_item;dur=…`, log JSON `{event, status_code, duration_ms, cart_created, idempotency_hit, path_mode}`.

C'est le **modèle direct** du futur `POST /carts/:id/lines` (ou équivalent) côté Hono — le reprix serveur systématique exigé par le plan y est déjà implémenté.

## Endpoint custom existant : `POST /api/cart/clear` ✅
Défini dans `pocketbase/pb_hooks/main.pb.js` ; logique pure dans
`pb_hooks/cart_clear.js` (testée sous Node, `test/pocketbase/`). Ajouté pour
éviter que la cart page vide le panier par `DELETE cart_entries/{id}` répétés :
le batch natif PocketBase (`POST /api/batch`) est désactivé sur l'instance
PocketHost de production.

**Contrat** :
- Header requis : `X-Cart-Guest-Id` (UUID invité).
- Body : `{ cartId }`.
- Comportement (transactionnel) : charge le panier demandé → vérifie que
  `guest_id` correspond au header et que `user` est vide → liste toutes les
  lignes `cart_entries` du panier → supprime toutes les lignes → remet
  `subtotal`, `discount_total`, `shipping_total`, `tax_total`, `grand_total` à
  `0`.
- Réponse 200 : `{ cart, entries: [], deletedCount }`, où `cart` reprend les
  noms de champs PocketBase (`guest_id`, `currency_code`, `grand_total`, etc.).
- Erreurs : `{ code, message }` — codes : `missing_guest_header`,
  `missing_cart_id`, `cart_not_found`, `cart_guest_mismatch`,
  `cart_clear_internal_error`.
- Observabilité : header `Server-Timing: cart_clear;dur=…`, log JSON
  `{event, status_code, duration_ms, deleted_count}`.

Le client Flutter utilise ce chemin en priorité et ne retombe sur le legacy
CRUD direct que si la route custom manque encore (404 route manquante, 405 ou
501).

---

## Infrastructure périphérique (hors PocketBase, à conserver ou re-câbler)

- **Worker média CDN** (`cloudflare/media-proxy-worker/`) : proxy/cache devant `/api/files/...` de PocketBase ; le storefront construit ses URLs d'images sur `MEDIA_BASE_URL` (obligatoire en release). Avec R2, ce worker (ou un domaine public R2) reste le point d'entrée — voir mapping §médias.
- **Worker commercetools** (`workers/kiki-ct-catalog-proxy/`) : page lab expérimentale, hors périmètre migration.
- **Config app** (`lib/config/api_config.dart`) : `API_BASE_URL`, `MEDIA_BASE_URL`, `CT_CATALOG_PROXY_URL`, `USE_CART_ADD_ENDPOINT` (dart-define).
