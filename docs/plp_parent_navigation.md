# PLP parent navigation (back action)

Dev reference + lightweight ADR for the PLP "back" action when there is no
Navigator history to pop (deep links, refreshes, direct PLP entry).

Resolver: `PlpParentRouting.resolveParentLocation`
(`lib/application/catalog/plp_parent_routing.dart`). Wired from the Sport PLP
header (`_SportHeader` in `lib/presentation/screens/product_list_page.dart`),
the only PLP chrome that exposes an in-page back button. The editorial header
has none and relies on browser/Navigator back.

## Resolution order (most reliable first)

1. **Business parent** — the current category's `CatalogCategory.parentId`,
   resolved to the parent's slug among `activeCategoriesProvider`, builds
   `/<catalogBase>/<parentSlug>`. The current category comes from the PLP feed
   when present, or from a `currentCategoryId` lookup so **empty PLPs**
   (e.g. just-created categories) still resolve a real parent.
2. **URL-only fallback** — `PlpFallbackRouting.urlOnlyFallbackParentLocation`,
   which only strips the last path segment. A last resort.
3. **Catalog base** — `CatalogRoutes.catalogBase` when nothing else applies.

Only portable query params (`sort`, `view`) survive to the parent; category
filters (`size`, `surface`, …) are dropped.

## Decisions to revisit

- **Sport routes stay URL-driven.** `/sport/<segment>/…` segments
  (`homme`/`femme`/`enfant`) are *not* categories, so mapping a `parentId` to a
  flat `/catalog/<slug>` page would be wrong. Business-parent resolution is
  therefore scoped to the `/catalog` namespace; Sport walks up the URL segment
  tree. If Sport gains a real category hierarchy, add a Sport-aware builder
  (`/sport/<segment>/<parentSlug>`) instead of the blind URL fallback.
- **Loading degradation.** Mapping a `parentId` to a slug needs the category
  list loaded. While `activeCategoriesProvider` is still loading, the back
  action degrades to the URL-only fallback rather than blocking the button.
  Acceptable for the internal MVP; covered by a widget test. A per-category
  resolver or a disabled-until-ready arrow would remove the degradation.
