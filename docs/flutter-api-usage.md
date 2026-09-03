# Inventaire des appels API de l'app Flutter — périmètre exact de l'API v1

> **Phase 0 du plan de migration.** Ce document fixe le périmètre de la nouvelle API : **ne pas implémenter d'endpoint qui n'y figure pas.** Inventaire établi le 2026-06-10 en lisant chaque implémentation de `lib/data/repositories/`, `lib/admin/` et les interfaces de `lib/application/`.

**Architecture côté app** : tous les accès passent par deux clients HTTP maison (pas de SDK PocketBase) :
- `lib/data/api/pocketbase_client.dart` — storefront (GET avec retry réseau ×3, POST/PATCH/DELETE), headers `Authorization` et `X-Cart-Guest-Id` optionnels ;
- `lib/admin/admin_client.dart` — backoffice (auth, CRUD, **multipart**, introspection schéma).

Chaque repository implémente une interface de `lib/application/` ; la DI est centralisée dans `lib/app/app_providers.dart`. **Swap de backend = réimplémenter ces interfaces + remplacer les deux clients.** Aucun appel API dans les widgets.

**Non utilisé (hors périmètre v1)** : realtime/subscriptions, OAuth, batch API, refresh de token (le token JWT PocketBase est gardé tel quel en mémoire).

---

## 1. Storefront (lecture publique, anonyme)

### 1.1 Détail produit — `ProductCatalogRepository` → `product_repository.dart`
| Opération PocketBase | Besoin API v1 |
|---|---|
| `GET …/products/records/{id}?expand=picture,thumbnail,galleryImages,galleryImages.medias` | `GET /products/{id}` retournant le produit **avec** ses médias résolus (picture, thumbnail, galerie ordonnée avec les médias imbriqués) — une seule réponse composée, plus d'expand à la carte |
| `GET …/priceRows/records?filter=product="{id}" && isActive=true&expand=currency&perPage=50` | inclure les prix (avec devise : isocode, symbol) dans la réponse produit, ou sous-ressource `GET /products/{id}/prices` |
| `GET …/narrativeChapters/records?filter=product="{id}" && isActive=true&sort=position` | inclure les chapitres narratifs ordonnés dans la réponse produit |

Particularité : prix et chapitres sont *best-effort* côté app (timeout 3 s, liste vide en cas d'échec) ; le produit lui-même a un timeout de 8 s.

### 1.2 Catégories & PLP — `CategoryCatalogRepository` → `category_repository.dart`
| Opération | Besoin API v1 |
|---|---|
| Liste catégories actives : `filter=isActive=true [&& isHidden=false]`, `sort=position,name`, perPage 200 | `GET /categories?includeHidden=` — arbre ou liste plate avec `parent`, `position`, `isHidden` |
| Catégorie par slug : `filter=isActive=true && slug="…"` | `GET /categories/{slug}` |
| Produits d'une catégorie : `categoryProducts` `filter=category="{id}" && isActive=true && product.isActive=true`, `sort=position`, `expand=category,product,product.picture,product.thumbnail`, paginé | `GET /categories/{id}/products?page=&perPage=` — items ordonnés avec produit + médias listing + **prix** (l'app fait aujourd'hui un 2ᵉ appel priceRows en `||` d'ids + un 3ᵉ pour les galeries fallback : à composer côté serveur) |
| Résolution route produit : relations du produit `filter=product="{id}" && isActive=true…`, choix canonique (isPrimary desc, position asc, nom catégorie, id) | `GET /products/resolve-route?categorySlug=&productSlug=` ou équivalent — la logique de canonicité (slug produit calculé client via `canonicalProductSlug`) **doit être tranchée en conception** : la déplacer côté serveur simplifierait 3 allers-retours |

### 1.3 Recherche — `ProductSearchRepository` → `search_repository.dart`
`GET …/products/records?filter=isActive=true && (searchIndex ~ "mot1" && searchIndex ~ "mot2")&sort={…}&expand=picture,thumbnail&page=&perPage=` puis priceRows en `||` d'ids + galeries fallback.
→ **`GET /products?search=&sort=&page=&perPage=`** avec prix et média listing inclus. Le `searchIndex` est un champ précalculé à l'import ; en Postgres, un `tsvector`/ILIKE sur les mêmes champs suffit au volume actuel (25 produits). Tris supportés par `SearchQuery.sort` : pertinence/défaut, et variantes PocketBase (`-created`, etc. — à figer en conception).

### 1.4 Produits mis en avant (CMS) — `FeaturedProductsRepository`
`GET …/products/records?filter=(id="a" || id="b" …) && isActive=true&expand=picture,thumbnail,galleryImages,galleryImages.medias` + priceRows best-effort.
→ **`GET /products?ids=a,b,c`** (ordre de la requête préservé côté client), prix inclus.

### 1.5 Pages CMS — `CmsPageRepository`
| Opération | Besoin API v1 |
|---|---|
| Page par code+locale : `pages` `filter=code="…" && locale="…" && isActive=true`, fields partiels | `GET /cms/pages/{code}?locale=` |
| PLP CMS par catégorie : `filter=pageType="plp" && sourceCategory="{id}" && locale="…" && isActive=true` | `GET /cms/pages?pageType=plp&sourceCategory=&locale=` |
| Sections d'une page : `page_sections` `filter=page="{id}"`, `sort=position,created`, perPage 200 | inclure les sections (ordonnées, avec `config` JSON brut) dans la réponse page : **un seul endpoint « page bundle »** |

Le parsing/validation des `config` reste côté Flutter (`parseCmsSection`) — l'API livre le JSON tel quel.

### 1.6 Navigation drawer — `DrawerNavigationRepository`
1. `navigation_menus` `filter=code="main_drawer"` (fields partiels) ; 2. `navigation_items` `filter=menu="{id}" && isActive=true [&& isHidden=false]`, `sort=position,created`, `expand=category,product,promoMedia` avec une sélection `fields` très fine (voir `_navigationItemFields`).
→ **`GET /navigation/menus/{code}`** retournant menu + items actifs ordonnés avec cibles résolues (catégorie/produit allégés, média promo). NB : le menu live est en `displayMode=categories` → le drawer est alors construit depuis `GET /categories` (1.2), pas depuis les items.

### 1.7 Réglages storefront — `StorefrontSettingsRepository`
Lectures anonymes : `storefront_settings` `filter=key="brand"|"navigation"|"active_theme"`, `sort=+id`, perPage 1.
→ **`GET /storefront/settings`** (les 3 clés d'un coup) ou `GET /storefront/settings/{key}`.
Écriture (authentifiée, depuis l'UI de switch de thème) : upsert de `active_theme` avec dédoublonnage client (create-or-update + delete des doublons) — devient un simple **`PUT /storefront/settings/active_theme`** côté serveur (l'unicité de `key` est garantie en base).

### 1.8 Panier (invité, header `X-Cart-Guest-Id`) — `CartRepository` → `cart_repository_impl.dart`
| Opération | Besoin API v1 |
|---|---|
| `POST /api/cart/add-item` (headers guest + `Idempotency-Key`, body `{productId, priceId, quantity}`) | **à reprendre tel quel** — contrat complet documenté dans `pocketbase-schema.md` §endpoint custom (reprix serveur, idempotence, codes d'erreur) |
| `POST /api/cart/clear` (header guest, body `{cartId}`) | `POST /carts/{id}/clear` — suppression serveur transactionnelle de toutes les lignes + totaux à 0 ; ne pas reproduire le clear ligne par ligne côté client |
| Panier actif : `carts` `filter=guest_id="…" && status="active"` | `GET /carts/active` (résolu par le header guest) |
| `POST …/carts/records` (création invité avec totaux à 0) | `POST /carts` |
| `GET …/carts/records/{id}` + toutes les `cart_entries` `filter=cart="{id}"`, `sort=created`, paginé | `GET /carts/{id}` retournant panier + lignes (une réponse composée) |
| Ligne par produit : `cart_entries` `filter=cart="…" && product="…"` | couvert par `GET /carts/{id}` |
| `POST/PATCH …/cart_entries` (quantité, reprix), `DELETE …/cart_entries/{id}` | `PATCH /carts/{id}/lines/{lineId}` (quantité), `DELETE /carts/{id}/lines/{lineId}` — **reprix systématique côté serveur** (le plan §Phase 3 l'exige ; aujourd'hui le client envoie `unit_price`/`line_total`, ce qui disparaît) |
| Recalcul des totaux : PATCH `carts/{id}` avec subtotal/grand_total calculés client | disparaît — totaux toujours calculés serveur et renvoyés dans chaque réponse panier |

Le **fallback legacy** (CRUD direct si la route custom manque) disparaît aussi : l'API v1 n'expose que le chemin endpoint.

---

## 2. Backoffice (authentifié)

### 2.1 Authentification — `AdminAuthRepository`, `AdminBackofficeRepository`
- `POST /api/collections/_superusers/auth-with-password` `{identity, password}` → `{token}` — login backoffice complet.
- `POST /api/collections/users/auth-with-password` → `{token}` — login « éditeur » (suffit pour les écritures CMS).
→ **`POST /auth/login`** → `{token, user:{role}}` ; les rôles (`admin` vs éditeur) remplacent la distinction _superusers/users. Pas de refresh token utilisé aujourd'hui.

### 2.2 CRUD générique backoffice — `AdminBackofficeRepository` + `admin_collection_schema.dart`
Le backoffice est un CRUD **générique piloté par les définitions Dart** (`adminCollectionDefinitions`) sur 11 collections : `categories`, `navigation_menus`, `navigation_items`, `products`, `categoryProducts`, `priceRows`, `narrativeChapters`, `currencies`, `units`, `medias`, `mediaContainers`.
Opérations : `listRecords` (sort par définition, perPage 200, filter optionnel), `createRecord`, `updateRecord`, `deleteRecord`.
→ Endpoints admin REST par ressource (`GET/POST/PATCH/DELETE /admin/{ressource}`) — les champs requis/types sont déjà décrits par les définitions Dart, qui resteront la source du formulaire.
**Introspection** : `getCollectionSchema(collection)` (`GET /api/collections/{name}`) sert à (a) valider les valeurs `select` à l'import CSV, (b) filtrer les champs inconnus. → **À abandonner** : avec une API typée OpenAPI, la validation est dans le contrat. À signaler comme simplification, pas comme endpoint à reproduire.

### 2.3 Import/export CSV catalogue — `admin_import_service.dart` / `admin_export_service.dart`
Implémentés **côté client** comme des suites de CRUD unitaires (lectures perPage 500 de toutes les collections, puis upserts collection par collection dans l'ordre currencies → units → categories → medias → mediaContainers → products → narrativeChapters → categoryProducts → priceRows, avec calcul du `searchIndex` produit).
→ Aucun endpoint dédié requis : le même service Flutter fonctionne sur les endpoints admin §2.2. (Option d'amélioration future, hors périmètre : un `POST /admin/catalog/import` serveur.)

### 2.4 Médias — `AdminMediaRepository` + `upsertMultipartRecord`
- Upload/remplacement : `POST|PATCH …/medias/records[/{id}]` **multipart** — champs `file` (recadré), `originalFile` (optionnel), `cropPreset/X/Y/Width/Height`, `mimeType` + métadonnées. Retente sans les champs optionnels si le schéma ne les connaît pas (robustesse à abandonner avec une API typée).
- `fetchBytes(url)` : GET binaire d'une image source (réimport).
→ Avec R2 et le plan §2 : **`POST /admin/uploads/presign`** (type/poids validés) + PUT direct R2 + `POST/PATCH /admin/medias` avec la clé R2 et les métadonnées (crop incluses). Deux requêtes au lieu d'un multipart — la couche `ApiRepository` Flutter absorbe le changement.

### 2.5 Éditeur CMS — `CmsPageEditorRepository` (token user)
- `POST …/pages/records` (création page PLP : code, locale, title, pageType=plp, sourceCategory, seo*) ;
- `POST/PATCH/DELETE …/page_sections/records[/{id}]` (config JSON complet ou patch partiel).
→ `POST /admin/cms/pages`, `POST/PATCH/DELETE /admin/cms/sections/{id}`.
- Sauvegarde du thème actif (cf. 1.7, écriture).

---

## 3. Construction des URLs médias (≈50 points d'usage)

`lib/core/utils/media_url_builder.dart` + `MediaAsset.fileUrl/thumbUrl` fabriquent **côté client** :
`{MEDIA_BASE_URL}/api/files/{collectionId}/{recordId}/{filename}?thumb=WxH&v={updated_ms}`

- `MEDIA_BASE_URL` (dart-define, **obligatoire en release**) pointe vers le worker Cloudflare de cache, qui proxifie PocketBase.
- Tailles de thumb utilisées : `300x300` (défaut MediaAsset), `400x0` (défaut client), autres tailles à inventorier finement en Phase 4.
- Les `config` JSON CMS référencent les médias par `{collectionId, recordId, filename}` et repassent par le même builder.

**⚠ Conséquence R2 (à trancher à la validation de la Phase 0)** : R2 ne fait pas de redimensionnement dynamique (`?thumb=`). Options : (a) servir les originaux via le worker + Cloudflare Image Resizing ; (b) générer des variantes à l'upload ; (c) ignorer les thumbs au volume actuel (73 médias). La nouvelle API doit de toute façon renvoyer pour chaque média une **URL (ou clé) directement exploitable**, pour que `MediaUrlBuilder` devienne trivial ou disparaisse.

---

## 4. Récapitulatif des endpoints v1 à concevoir

**Public** : `GET /products` (search, ids, pagination, tri) · `GET /products/{id}` (composé : médias+prix+chapitres) · résolution de route produit (à concevoir) · `GET /categories` · `GET /categories/{slug}` · `GET /categories/{id}/products` (composé) · `GET /cms/pages/{code}?locale=` (bundle sections) · `GET /cms/pages?pageType=plp&sourceCategory=` · `GET /navigation/menus/{code}` · `GET /storefront/settings` · `POST /carts` · `GET /carts/{id}` (composé) · `GET /carts/active` · `POST /cart/add-item` (idempotent, contrat existant) · `PATCH|DELETE /carts/{id}/lines/{lineId}`.

**Admin** : `POST /auth/login` · CRUD sur 11 ressources catalogue/navigation · `POST /admin/uploads/presign` + CRUD médias · `POST /admin/cms/pages` · `POST/PATCH/DELETE /admin/cms/sections/{id}` · `PUT /storefront/settings/{key}`.

**Net-new du plan (aucun usage Flutter aujourd'hui, Phase 3)** : checkout Stripe, commandes (`orders`), stock (`inventory`), emails. L'app n'a **aucun écran de commande/checkout** actuellement — le périmètre Flutter de ces features sera défini quand elles seront construites.
