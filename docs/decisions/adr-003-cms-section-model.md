# ADR-003 — CMS-driven, data-first storefront (section model)

**Status:** Accepted (core architecture; fully reflected in the code)

## Context

Storefront content — the landing page, navigation, promotional blocks — must be
editable from the admin backoffice without shipping a Flutter build.

## Decision

The storefront is **data-driven**. A CMS page is a record whose body is an
ordered list of typed **sections**; a section's appearance is configuration, not
code.

- Section config is fetched via `CmsPageRepository`
  (`data/repositories/pocketbase_cms_page_repository.dart`) and parsed into the
  models in `lib/application/cms/cms_models.dart`.
- `lib/presentation/screens/storefront_landing_page.dart` renders the sections in
  a vertical `ListView.builder`.
- Each section **type** maps to a widget in
  `lib/presentation/widgets/cms/sections/`; **layout/variant** (e.g. the tile
  carousel's `'tiles'` vs `'feature'`) is a field on the record.

## Consequences

- **Adding a section type touches a set of files, not one:** the model
  (`application/cms/cms_models.dart`), the renderer
  (`presentation/widgets/cms/sections/…`), the admin editor form
  (`presentation/widgets/cms/forms/…`), the defaults
  (`presentation/widgets/cms/cms_section_defaults.dart`), and a PocketBase
  migration that extends the section-type enum (`pocketbase/pb_migrations/…`).
  The `horizontal_tile_carousel` triplet is the worked example.
- **A variant only appears if a CMS record uses it.** Code paths are necessary
  but not sufficient — e.g. the `'feature'` carousel layout renders only for a
  section explicitly configured for it, not by default. Don't assume a variant
  is live just because the widget exists.
- **Never hard-code landing content** in widgets; it belongs in the CMS.
- Section config is **public-read** (see [ADR-002](adr-002-pocketbase.md)): no
  secrets in `config` JSON.

## Rationale / alternatives

The "editable without a deploy" goal is evident from the architecture (admin
backoffice + per-record config). Specific alternatives considered (e.g. a
headless CMS vs. PocketBase collections) are not documented in the repo.
