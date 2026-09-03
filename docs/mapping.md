# Mapping PocketBase → PostgreSQL — kiki commerce

> **Phase 0 du plan de migration.** Mapping cible pour `scripts/migrate-pocketbase.ts`, organisé par module du monolithe Hono. Conventions globales d'abord, puis table par table. Les points marqués **⚠ à valider** doivent être tranchés à la validation de la Phase 0.

## Décision de périmètre actée
Un **5ᵉ module `cms`** (pages, sections, navigation, réglages storefront) s'ajoute aux 4 modules du plan — l'app Flutter en dépend massivement (validé le 2026-06-10).

## Transformations globales

| Sujet | Règle |
|---|---|
| **IDs** | PocketBase : 15 chars alphanumériques → **UUID v7 générés à la migration**. Le script maintient une table de correspondance `id_map(pb_id, collection, uuid)` (en mémoire ou table temporaire) pour réécrire toutes les FK **et** les références embarquées dans les JSON (`config` CMS). Idempotence du script : l'UUID est dérivé de façon déterministe (ou la table `id_map` est persistée entre exécutions). |
| **Montants** | `priceRows.price`, `cart_entries.unit_price/line_total`, `carts.*_total` sont des **floats** en base (ex. `69.9`) → `*_cents integer` : `Math.round(value * 100)`. Devise = EUR partout (1 seule currency). Type `Money { amountCents, currency }` dans `shared/kernel`. |
| **Dates** | autodate PocketBase `"2026-03-18 16:40:07.691Z"` → `timestamptz`. Chaînes vides (`""` pour onlineDate/offlineDate/endTime) → `NULL`. |
| **Relations** | id PocketBase (string, `""` si absent) → FK UUID `NULL`-able. Relations multiples (tableaux ordonnés : `mediaContainers.medias`, `products.galleryImages`) → table de liaison avec colonne `position`. |
| **Booléens** | PocketBase omet parfois le champ (défaut applicatif) → colonnes `boolean NOT NULL DEFAULT …` reprenant les défauts du code Dart. |
| **Fichiers** | `medias.file`/`originalFile` : copie depuis `https://kiki-commerce.pockethost.io/api/files/{collection}/{recordId}/{filename}` → R2 sous clé `media/{uuid}/{filename}` (+ `media/{uuid}/original/{filename}`). La colonne stocke la **clé R2**. 73 médias au total. |
| **Champs système PB** | `collectionId`/`collectionName` : abandonnés. `created`/`updated` → `created_at`/`updated_at`. |
| **`isActive`** | conservé tel quel (`is_active boolean`) — c'est le soft-toggle métier de toutes les collections, pas un soft-delete générique. |

---

## Module `catalog`

### `products` → `products`
| PocketBase | Postgres | Transformation |
|---|---|---|
| id | id uuid pk | id_map |
| code | code text NOT NULL UNIQUE | clé d'upsert import CSV — garder l'unicité |
| name | name text NOT NULL | |
| slug | slug text | ⚠ à valider : `UNIQUE` souhaitable (routage), à vérifier sur les données réelles avant de poser l'index |
| summary | summary text | HTML conservé tel quel |
| description | description text | HTML conservé tel quel |
| ean | ean text | |
| gender | gender text | |
| productType | product_type text | |
| brand | brand text | |
| isActive | is_active boolean NOT NULL DEFAULT true | |
| isStorefrontVisible | — | **⚠ à valider : champ présent en base mais inutilisé par tout le code → proposition : ne pas migrer** |
| onlineDate / offlineDate | online_date / offline_date timestamptz | `""` → NULL |
| picture | picture_media_id uuid FK → medias | |
| thumbnail | thumbnail_media_id uuid FK → medias | |
| galleryImages | table `product_gallery_containers(product_id, container_id, position)` | tableau ordonné (0..1 en pratique) |
| searchIndex | — (colonne générée ou tsvector) | **ne pas migrer la valeur** : recalculer côté Postgres (`to_tsvector` sur name/summary/description/brand/product_type/ean/code, ou colonne `search_text` recalculée par le service à chaque écriture) |
| created/updated | created_at/updated_at timestamptz | |

**⚠ Écart plan ↔ existant** : le plan Phase 2 prévoit `product_variants(sku, price_cents, position)` et `products.status[draft|published]`. L'existant n'a **pas de variantes** (panier agrégé par produit, commentaire explicite dans la migration carts) et utilise `isActive` (pas draft/published). Proposition : V1 sans table variants (l'ajouter le jour où le besoin tailles/coloris arrive), `is_active` au lieu du statut draft/published. **À trancher avant la Phase 2.**

### `categories` → `categories`
id→uuid · code UNIQUE NOT NULL · name NOT NULL · description · slug (⚠ même question d'unicité) · parent → parent_id uuid FK self (NULL) · position integer NOT NULL DEFAULT 0 · isActive→is_active · isHidden→is_hidden · created_at/updated_at.
Index : `(is_active, is_hidden, parent_id, position)` (équivalent de `idx_categories_drawer_order`).

### `categoryProducts` → `product_categories`
id→uuid · category→category_id FK · product→product_id FK · position integer · isPrimary→is_primary boolean NOT NULL DEFAULT false · isActive→is_active · created_at/updated_at.
Contrainte : **UNIQUE (category_id, product_id)** (aujourd'hui garantie seulement par la logique d'import — vérifier l'absence de doublons dans `verify-migration.ts`).
Nom aligné sur le plan (`product_categories`) ; sémantique inchangée (position = ordre PLP, is_primary = catégorie canonique).

### `priceRows` → `price_rows`
| PocketBase | Postgres | Transformation |
|---|---|---|
| product / currency / unit | product_id FK NOT NULL / currency_id FK NOT NULL / unit_id FK NULL | |
| price (float) | **amount_cents integer NOT NULL** | `round(price*100)` |
| minqtd | min_qty integer | |
| net | net boolean | |
| startTime / endTime | start_at / end_at timestamptz | `""` → NULL ; aucune logique de validité temporelle côté app aujourd'hui |
| channel | channel text | valeur constatée : `web` |
| isDefault / isActive | is_default / is_active boolean | |

⚠ à valider : le plan met le prix sur `product_variants.price_cents`. Sans variantes (cf. ci-dessus), `price_rows` rattachée au produit est la structure fidèle à l'existant (multi-lignes par produit : canal/période/quantité min). Recommandation : garder `price_rows` telle quelle.

### `currencies` → `currencies`
isocode UNIQUE NOT NULL · symbol NOT NULL · name · digits integer · is_active. (1 enregistrement : EUR. La table reste utile pour l'affichage symbol/digits même en mono-devise.)

### `units` → `units`
code UNIQUE NOT NULL · name NOT NULL · symbol · is_active. (1 enregistrement : PCS.)

### `medias` → `media_assets`
| PocketBase | Postgres | Transformation |
|---|---|---|
| code | code text UNIQUE NOT NULL | |
| title / altText / mimeType | title / alt_text / mime_type text | |
| file | **r2_key text NOT NULL** | copie fichier PB → R2 (`media/{uuid}/{filename}`) |
| originalFile | original_r2_key text NULL | copie si non vide |
| cropPreset / cropX/Y/Width/Height | crop_preset text, crop_x/y/width/height numeric | métadonnées du recadrage backoffice |
| isActive | is_active | |
| updated | updated_at | servait au cache-busting `?v=` — le nom de fichier R2 changeant à chaque upload, le cache-busting devient naturel (cf. mémoire projet) |

### `mediaContainers` → `media_containers` + `media_container_items`
`media_containers(id, code UNIQUE, name, is_active, created_at, updated_at)` ; le tableau ordonné `medias` → `media_container_items(container_id FK, media_id FK, position)` avec UNIQUE (container_id, media_id).

### `narrativeChapters` → `narrative_chapters`
product_id FK NOT NULL · media_id FK NOT NULL · position integer NOT NULL · headline text NOT NULL · story text · cta_label text · cta_action text (CHECK in zoom/sizeGuide/materialDetail/none, ⚠ ou enum Postgres — choix de style Phase 2) · is_active. UNIQUE (product_id, media_id) (garantie d'import actuelle).

---

## Module `cms`

### `pages` → `cms_pages`
code NOT NULL · locale NOT NULL · title NOT NULL · is_active · page_type text NULL (CHECK home/plp/content) · source_category_id uuid FK → categories NULL (**FK inter-modules cms→catalog : simple colonne UUID sans jointure SQL inter-module, résolue via le `public.ts` de catalog — invariant §3.1 du plan**) · seo_title · seo_description · created_at/updated_at.
Contraintes : UNIQUE (code, locale) ; index (page_type, source_category_id, locale, is_active).

### `page_sections` → `cms_page_sections`
page→page_id FK NOT NULL ON DELETE CASCADE · section_id text NOT NULL (slug stable) · section_type text NOT NULL (CHECK sur les 15 valeurs) · position integer · is_active · **config jsonb NOT NULL** · created_at/updated_at. Index (page_id, position).

**⚠ Transformation critique — réécriture des `config`** : les JSON embarquent des références médias `{collectionId, recordId, filename, alt}` (hero mediaDesktop/mediaMobile, tuiles, carrousels…) et des **ids produits** (sections `featured_products`) et **ids catégories**. Le script de migration doit parcourir chaque `config`, remplacer :
- `{collectionId, recordId, filename}` → la nouvelle référence média (uuid + clé R2 ou URL finale) ;
- les ids produits/catégories PocketBase → les UUID correspondants (via id_map).
Le format cible de la référence média dans `config` est un **choix de conception Phase 2** (proposition : `{mediaId: uuid, url, alt}`). `verify-migration.ts` doit valider qu'aucun id PocketBase 15-chars ne subsiste dans les jsonb migrés.

### `navigation_menus` → `navigation_menus`
name NOT NULL · code UNIQUE NOT NULL · display_mode text NOT NULL (CHECK drawer/categories) · is_active · created_at/updated_at.

### `navigation_items` → `navigation_items`
menu_id FK NOT NULL ON DELETE CASCADE · parent_id FK self NULL · position integer NOT NULL · label NOT NULL · item_type text NOT NULL (CHECK category/product/page/external) · category_id uuid NULL · product_id uuid NULL · page_key text · url text · promo_media_id uuid NULL · placement text NOT NULL (CHECK nav/promo) · desktop_drawer_template text NULL (CHECK 4 valeurs) · **config jsonb NULL** (⚠ même réécriture des références médias que `cms_page_sections.config`) · is_active · is_hidden · created_at/updated_at.
Index : (menu_id, position) ; (menu_id, is_active).

### `storefront_settings` → `storefront_settings`
**Restructuration** : la collection PocketBase est « à plat » (tous les champs sur chaque ligne, seuls ceux de la clé renseignés). Cible : `storefront_settings(key text pk, value jsonb NOT NULL, updated_at)` — un JSON typé par clé :
- `brand` → `{title, href}` (depuis brandTitle/brandHref) ;
- `navigation` → `{mobileMenuStyle, replaceMobileLogoWithThemeSwitcher, categorySplitDisplayMode}` ;
- `active_theme` → `{theme}` (dior|nike).
La validation par clé (faite aujourd'hui dans `pb_lib/storefront_settings_dedup.js` + parsers Dart) devient des schémas Zod par clé dans le module cms. L'unicité de `key` (pk) supprime tout le code de dédoublonnage client.
⚠ à valider : alternative = colonnes typées par clé (3 lignes restent 3 lignes). Le jsonb par clé est recommandé : il évite une migration de schéma à chaque nouveau réglage (4 champs ajoutés en 6 semaines d'historique).

---

## Module `sales`

### `carts` → `carts`
| PocketBase | Postgres | Transformation |
|---|---|---|
| user | user_id uuid FK NULL | aucune donnée en pratique |
| guest_id | guest_id uuid NULL | déjà des UUID v4 |
| status | status text NOT NULL (CHECK active/converted/abandoned) | |
| currency_code | currency_code char(3) NOT NULL DEFAULT 'EUR' | |
| subtotal, discount_total, shipping_total, tax_total, grand_total (floats) | `*_cents integer NOT NULL DEFAULT 0` | ×100 arrondi ; **recalculés par le serveur uniquement** (plus jamais écrits par le client) |
| created/updated | created_at/updated_at | |

Contrainte : index **UNIQUE partiel** `(guest_id) WHERE status = 'active'` — à reproduire tel quel, c'est lui qui rend la création de panier idempotente sous concurrence.
Les règles d'accès PocketBase (header `X-Cart-Guest-Id`) deviennent du code service : middleware qui résout le panier par guest_id et vérifie la propriété.
⚠ à valider : migrer les paniers existants ou repartir à zéro ? Production quasi vide (0 visible) et données volatiles → **proposition : ne pas migrer carts/cart_entries**.

### `cart_entries` → `cart_lines`
cart_id FK CASCADE · product_id FK · sku_snapshot text · product_name_snapshot text NOT NULL · quantity integer NOT NULL CHECK ≥1 · unit_price_cents integer NOT NULL · line_total_cents : **supprimé** (calculé `unit_price_cents × quantity` au besoin) ⚠ ou conservé par fidélité — proposition : supprimer. UNIQUE (cart_id, product_id) (agrégat par produit, V1 sans variantes).
Aligné sur le plan (`cart_lines` avec `name_snapshot`/`unit_price_cents`), enrichi de `sku_snapshot` qui existe déjà.

### `cart_add_idempotency` → **non migrée**
Remplacée par le mécanisme d'idempotence du nouveau backend (même sémantique : clé + hash de requête + réponse stockée, mais portée par le module sales ; le plan prévoit déjà `processed_stripe_events` pour le webhook — l'idempotence add-item suit le même pattern).

### `orders`, `order_lines`, `order_status_history` → **net-new (Phase 3)**
Aucune collection commande n'existe dans PocketBase. La clause du plan Phase 5 « commandes historiques (statut completed, source='pocketbase') » est **sans objet** — rien à migrer.

---

## Module `identity`

### `users` + `_superusers` → `users`
`users(id uuid pk, email citext UNIQUE NOT NULL, password_hash text NOT NULL, role text NOT NULL CHECK ('admin','editor','customer'), created_at, updated_at)`.
- `_superusers` PocketBase → `role='admin'` (accès backoffice complet : catalogue, import/export, médias).
- `users` PocketBase → `role='editor'` (les règles CMS actuelles n'exigent qu'un utilisateur authentifié) ; `customer` réservé pour plus tard.
- Hash : PocketBase utilise **bcrypt** → import direct dans `password_hash` (compatible, prévu par le plan). Si un hash s'avère non-bcrypt à l'inspection du dump : flag `must_reset_password`.
- ⚠ **Accès requis** : le nombre et la liste des comptes `users`/`_superusers` ne sont pas lisibles anonymement. Il faudra les identifiants superuser (ou un export `pb_data`) pour la Phase 5.

---

## Module `inventory`

**Aucune source PocketBase** — ni stock ni mouvement n'existent. `stock_items`/`stock_movements` sont net-new (Phase 3). ⚠ à valider : politique d'initialisation du stock à la bascule (tout à 0 et saisie admin ? valeur par défaut par produit ?).

---

## Hors migration (abandonné ou re-câblé)

| Élément PocketBase | Devenir |
|---|---|
| Endpoint `/api/cart/add-item` (hook) | réimplémenté dans le module sales (contrat documenté dans `pocketbase-schema.md`) |
| Thumbs dynamiques `?thumb=WxH` | ⚠ à trancher : R2 ne redimensionne pas — worker + Image Resizing, variantes à l'upload, ou originaux seuls (73 médias) — cf. `flutter-api-usage.md` §3 |
| Worker média Cloudflare | conservé devant R2 (ou remplacé par le domaine public R2) ; `MEDIA_BASE_URL` reste le pivot côté app |
| Introspection `GET /api/collections/{name}` | abandonnée (contrat OpenAPI typé) |
| `products.searchIndex` | recalculé en Postgres (tsvector/colonne générée) |
| `products.isStorefrontVisible` | ⚠ proposition : abandonné (inutilisé) |
| Worker commercetools (lab) | hors périmètre, inchangé |

---

## Ordre de migration (Phase 5, dépendances FK)
1. currencies, units → 2. categories (avec parent en 2ᵉ passe) → 3. medias (copie fichiers → R2) → 4. media_containers + items → 5. products (+ gallery containers) → 6. product_categories, price_rows, narrative_chapters → 7. cms_pages → 8. cms_page_sections + navigation_menus + navigation_items (**avec réécriture des config jsonb**) → 9. storefront_settings (restructuration clé→jsonb) → 10. users (depuis export/credentials) → 11. carts/cart_lines : proposition de ne pas migrer (⚠).

`verify-migration.ts` : comptages par table vs `totalItems` PocketBase ; échantillons champ à champ ; somme des `amount_cents` vs somme des floats ×100 ; zéro id 15-chars résiduel dans les jsonb ; tous les objets R2 répondent en HEAD.
