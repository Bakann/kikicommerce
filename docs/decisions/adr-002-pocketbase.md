# ADR-002 — PocketBase as the backend (BaaS)

**Status:** Accepted (deeply integrated)

## Context

The storefront needs a backend for catalog, CMS content, navigation, cart and
auth. The repo is committed to PocketBase across many surfaces, not just data
reads.

## Decision

Use **PocketBase** as the single backend, accessed over `http` (no Dart SDK).

- Default instance is **hosted** (`API_BASE_URL`, see [README.md](../../README.md)) —
  there is no local backend to run.
- Repository implementations are `lib/data/repositories/pocketbase_*`.
- Server-side logic lives in `pocketbase/pb_hooks/` (JS), schema changes in
  `pocketbase/pb_migrations/`.

## Consequences

- **Backend changes are migrations.** Schema/collection changes go through
  `pocketbase/pb_migrations/`; the current schema is documented in
  [`docs/pocketbase-schema.md`](../pocketbase-schema.md).
- **Public-read collections.** `cms_pages`, `page_sections`, `navigation_*`,
  `storefront_settings` are anonymously readable — never put secrets in their
  `config` JSON (see [CLAUDE.md](../../CLAUDE.md)).
- **Custom endpoints are hooks**, e.g. the guest add-to-cart route
  (`pocketbase/pb_hooks/`); see README.
- **Media** is served through a CDN proxy worker (`cloudflare/media-proxy-worker`),
  not straight from PocketBase, in production.
- Switching backends would touch all of the above — treat PocketBase as fixed.

## Rationale

In MVP context, three reasons:

- **Fixed, small cost.** A one-time lifetime hosting plan (PocketHost "Flounder",
  paid once, no recurring fees) keeps the infra budget capped — deliberate for an
  MVP that should not bleed money before it has proven itself.
- **Familiarity.** PocketBase is SQLite under the hood — a SQL database the
  maintainer already knows, so no new datastore to learn.
- **A planned exit, via the layering.** Data access is isolated behind repository
  interfaces (`application/`) with PocketBase implementations (`data/`), so if the
  MVP grows into a real product the *data store* can be swapped without touching
  domain or UI. See [ARCHITECTURE.md](../../ARCHITECTURE.md) and
  [ADR-003](adr-003-cms-section-model.md).

**Caveat on that exit.** The repository seam insulates **data reads/writes**, not
the PocketBase-specific server pieces: JS hooks (`pocketbase/pb_hooks/`),
migrations, the custom cart-add route, auth, and the admin backoffice are all
tied to PocketBase. Replacing it wholesale is a larger migration than swapping a
repository implementation — the clean architecture lowers the data-layer cost,
not the full switching cost. Worth keeping that distinction honest if the "we can
always move off it" assumption is ever leaned on.
