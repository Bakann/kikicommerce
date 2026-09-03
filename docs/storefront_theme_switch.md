# Storefront theme switch (Dior / Nike)

This is the operator + dev reference for the storefront theme switch shipped
with the Nike storefront. It covers the switch infrastructure (theme enum,
providers, persistence, sidebar block), Nike chrome, and the Nike CMS sections
used by the current homepage seed.

## Concepts

- **Active theme** — the published storefront theme everybody sees. Stored in
  `storefront_settings.active_theme` (PocketBase). Anonymous-readable.
- **Editing override** — admin-only preview. Held in
  `editingStorefrontThemeProvider`. Cleared when admins click *Annuler* or
  *Appliquer*.
- **Effective theme** — what the running app actually renders. Equal to the
  editing override if set, otherwise the active theme.

The Dior theme keeps the historical CMS page code `homepage`. The Nike theme
loads a new page code `homepage_nike`. The resolver is
`homepageCodeFor(theme)` in `lib/application/storefront/storefront_theme.dart`.

## Admin workflow

1. Triple-tap the brand title in the navbar to reveal edit controls (existing).
2. Tap the edit FAB and sign in (existing).
3. The CMS sidebar now opens with an **Apparence** block at the top.
4. Tap *Nike* — the storefront immediately reloads from `homepage_nike` for
   you only. The hint reads *“Aperçu local — non publié”*.
5. Tap *Annuler* to revert, or *Appliquer* to publish for everybody.

The bottom floating navbar only appears when the effective theme is Nike. It
has five destinations: Accueil, Acheter, Rechercher, Panier, Profil. *Panier*
opens the cart route (`/cart`); checkout remains a later step from the cart.
*Profil* opens the existing customer account modal.

## One-time setup

### 1. Inter font assets

The Inter variable TTF is committed at
`assets/google_fonts/Inter-VariableFont_opsz,wght.ttf` and registered in
`pubspec.yaml`. Runtime Google Fonts fetching remains disabled.

### 2. Seed the Nike homepage

A PocketBase JS migration ships in
`pocketbase/pb_migrations/1777000360_seed_homepage_nike_fr.js`. It creates
the `homepage_nike` / `fr` page in the `pages` collection and attaches one
`horizontal_tile_carousel` section ("En ce moment") with four placeholder
tiles. The migration is idempotent: it skips if the page already exists with
sections attached.

Run it the same way as other PB migrations (start the PocketBase server with
the `pocketbase/` directory mounted, or run `./pocketbase migrate up` from
inside it). It reuses the landing hero media for all tiles so the page
renders something without dedicated Nike assets — swap from the admin once
you have real media.

Follow-up migrations add the brand segment, category tabs, banner strip,
product grid layout, lower carousels, and brand carousel. Seed migrations are
written to create missing records only. Existing CMS section config, type, and
position are not rewritten by layout repair migrations.

## Files added / changed

Added:

- `lib/application/storefront/storefront_theme.dart` — enum, tokens, page resolver.
- `lib/presentation/providers/storefront_theme_providers.dart` — active / editing / effective.
- `lib/presentation/widgets/cms/cms_appearance_block.dart` — sidebar block.
- `lib/presentation/widgets/navigation/floating_bottom_nav.dart` — bottom nav.
- `lib/presentation/widgets/cms/sections/horizontal_tile_carousel_section.dart`.
- `lib/presentation/widgets/cms/sections/brand_segment_section.dart`.
- `lib/presentation/widgets/cms/sections/category_split_tabs_section.dart`.
- `lib/presentation/widgets/cms/sections/category_banner_strip_section.dart`.

Changed:

- `lib/application/storefront/storefront_brand_settings.dart` — new repo methods.
- `lib/data/repositories/pocketbase_storefront_settings_repository.dart` — read + save active_theme.
- `lib/application/cms/cms_models.dart` — new section type + config + parser.
- `lib/presentation/widgets/cms/cms_section_renderer.dart` — dispatch case.
- `lib/presentation/widgets/cms/cms_section_defaults.dart` — default config + label.
- `lib/presentation/widgets/cms/cms_sections_sidebar.dart` — mount Apparence block.
- `lib/presentation/providers/cms_page_provider.dart` — `homepageCmsProvider` keyed on theme.
- `lib/presentation/screens/storefront_landing_page.dart` — mount FloatingBottomNav + bottom inset.
- `pubspec.yaml` — Inter font family.
