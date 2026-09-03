# Plan: act on the genuine findings from the full-repo senior review

## Context

A second, exhaustive senior-review prompt was run over the whole repo (not just
the last commit), covering architecture, Riverpod, GoRouter, CMS/catalog,
l10n, tests, and runtime jank. I fact-checked every load-bearing claim against
the code with three parallel Explore passes plus direct reads.

**Headline: the codebase is in good shape.** The generic alarmist framing of the
original pasted audit does not survive contact with the code:
- Images already go through `KikiImage` with DPR-aware `memCacheWidth`, CDN
  `thumbUrl(size:)` for thumbs, `listingUrl` for cards — no full-size decode in
  lists (`lib/presentation/widgets/kiki_image.dart`).
- PLP/search/PDP are all `CustomScrollView` + `SliverGrid`/builder — no eager
  `Column.map`, no `shrinkWrap` on large lists (only bounded modals).
- Catalog cache (`CachedRemoteReader` + `KikiCachePolicies`) uses per-key SWR
  with targeted + prefix invalidation. Cart is optimistic with stale-write
  guards. `.select` is used in the right hot spots (nav, shell, cross-sells).
- FR/EN ARB parity is exact (184 keys), generated l10n is committed and
  CI-guarded (`flutter gen-l10n` + `git diff --exit-code`), public strings are
  guarded by `scripts/check_public_l10n_strings.dart`.

Only a handful of findings are real and worth acting on. Everything else is
either already solved or acceptable MVP debt. This plan covers **only the real,
low-risk, high-leverage items.**

## Phase 1 — Quick wins (low risk)

### 1.1 Close the CMS invalidation consistency gap
**Problem:** `lib/application/catalog/catalog_invalidations.dart` maps collection
names → invalidation targets for every catalog collection **except** `cms_pages`
and `page_sections`. The CMS editor flow is safe (it invalidates directly in
`cms_page_editor_controller.dart:214-217`), but a mutation arriving through the
generic admin path produces no CMS invalidation — and CLAUDE.md explicitly says
every catalog read must be wired into the invalidator.

**Change:** Add `case 'cms_pages':` and `case 'page_sections':` to the dispatch
switch(es) (~lines 200-320), mapping them to the existing CMS sink hooks. Reuse
the already-defined `invalidateCmsMixedGridProducts()` and add a thin
`invalidateCmsPages()` sink method that invalidates the
`homepageCmsProvider` / `homepageCmsForSegmentProvider` / `cmsPageProvider` /
`cmsPlpProvider` family (the same set the editor controller already targets — so
no new invalidation semantics, just routed through the generic path too).

**Files:** `lib/application/catalog/catalog_invalidations.dart`,
`lib/presentation/providers/catalog_invalidator_provider.dart` (add the sink
method to the interface + its 2-3 impls).

**Tests:** Extend the existing catalog-invalidator test (find it under
`test/presentation/providers/` or `test/application/catalog/`) with a case
asserting a `cms_pages` collection change yields the CMS invalidation targets.

### 1.2 Add a FR-locale overflow guard test
**Problem:** FR strings run 25-88% longer than EN (61 keys), but no test forces
FR to catch `RenderFlex overflowed` on tight CTAs. `test/app/localization_test.dart`
and `localeOverrides()` in `test/support/l10n_harness.dart` exist but don't
assert layout. This is the user's explicitly stated worry (checkout/cart/PDP
buttons in FR).

**Change:** Add a widget test that pumps the highest-risk surfaces (checkout
access CTA, mobile cart action row, PDP add-to-bag) under
`localeOverrides(const Locale('fr'))` at a narrow width (e.g. 360px) and asserts
no overflow via `tester.takeException()` being null. Reuse the existing harness.

**Files:** new `test/presentation/screens/fr_overflow_test.dart` (or extend
`localization_test.dart`); reuses `test/support/l10n_harness.dart`.

## Phase 2 — Clarification (medium risk, optional)

### 2.1 De-duplicate the sport-segment fallback
**Problem:** The "Femme/Enfant fall back to Homme" rule lives in two places —
`cms_page_provider.dart:135-160` (hardcoded `segment == femme || segment ==
enfant`) and the code mapping in
`lib/application/storefront/storefront_sport_segment.dart`. Adding a segment
means editing both.

**Change:** Add a single `StorefrontSportSegment? get fallbackSegment` (or
`homepageFallbackChain`) on the enum and have the provider consume it. Pure Dart,
already-tested type — extend `test/app/catalog_routes_test.dart`.

**Risk:** Low-medium (touches homepage resolution); covered by existing
storefront landing/home tests.

## Phase 3 — Structural (defer unless measured)

Storefront `_StorefrontLandingPageState` is large (~1463 lines) but already
factored into 18 sub-widgets with timers correctly disposed. Extracting the
prewarm timers into a Riverpod notifier is the one clean structural move, but it
touches the hot path and fixes no observed bug. **Do not do this without a
DevTools baseline showing real cost** (per the "baseline first, smallest fix
first" rule). Listed here only so it's tracked.

## Phase 4 — Acceptable MVP debt (watch, don't touch)

- **Global cache-key placeholders** (`locale=global|currency=global` in
  `product_providers.dart` / `category_providers.dart`) — already documented as
  a TODO in code. Latent multi-market collision; address only when i18n/markets
  ship. Trigger: first multi-currency or multi-market story.
- **Public l10n guard is whitelist-based** (`check_public_l10n_strings.dart`
  blocks specific known strings, not an exhaustive scan). Fine for now; revisit
  if a hardcoded FR string ships to a public surface despite the guard.
- **Admin copy intentionally hardcoded French** — by design, documented in the
  CI guard comment. Not debt.

## Verification

1. `flutter analyze` — clean.
2. `flutter test test/presentation/providers/ test/application/catalog/` — CMS
   invalidation test passes.
3. `flutter test test/presentation/screens/fr_overflow_test.dart` — FR overflow
   guard passes (and would fail if a CTA overflowed in FR).
4. `flutter test` — full suite (138 files) stays green.
5. Manual: in the admin backoffice, edit a CMS page/section, return to the
   storefront, confirm the change appears without a manual reload (validates the
   invalidation path). Switch EN→FR on checkout/cart/PDP at phone width, confirm
   no clipped buttons.

---

## Outcome — what shipped (all pushed to `main`)

### Round A — first pasted audit (admin keys + router dedup)
- `fix(admin): key record list items by id` — `KeyedSubtree(ValueKey(record['id']))`
  on the backoffice `ListView.separated`.
- `refactor(router): dedupe sport-segment redirect into a helper` —
  `_sportSegmentRedirect`, shared by both `/sport/:segment` routes.

### Round B — full-repo senior review (this plan's Phase 1–2)
- `3dc4a87 fix(cache): invalidate cms_pages/page_sections via generic invalidator`
  — **Phase 1.1 done.** Added a `CmsPagesInvalidation` target + `cms_pages` /
  `page_sections` cases in both dispatch switches; new `invalidateCmsPages()`
  sink method (interface + 3 impls) invalidating the
  `homepageCms*`/`cmsPage*`/`cmsPlp` family. No cache-prefix sweep — confirmed
  CMS reads never touch `LocalReadCache` (the `cmsPage` key is defined but
  unused). Tests in `catalog_invalidations_test.dart` + `catalog_invalidator_test.dart`.
- `6261a19 test(l10n): guard FR add-to-cart CTA against overflow at narrow split`
  — **Phase 1.2 done, narrowed.** The standalone CTA pages need too many
  providers to mount cleanly, so instead of a new `fr_overflow_test.dart` the
  guard rides the existing `_NarrativeHarness` (real PDP purchase CTA) at 601px
  in FR. *Finding:* the label is already in `Expanded` — this is a regression
  guard, not a bug fix.
- `19cf174 refactor(storefront): single-source the sport segment homepage fallback`
  — **Phase 2.1 done.** Named the getter `homepageFallback` (not
  `fallbackSegment`); `cms_page_provider.dart` consumes it. Behavior identical.

### Round C — ChatGPT review of rounds A+B (follow-up fixes)
- `3fde7ce fix(cms): only report usedFallback when the fallback page resolves`
  — real semantic bug: `usedFallback: true` even when the fallback page was also
  missing, misleading the edit-mode hint (`storefront_landing_page.dart:1094`).
  Now `fallbackBundle != null`; corrected the test that had codified the bug.
  Added a **teeth-test** proving `CmsPagesInvalidation` forces a real repository
  re-read (guards the "CMS is Riverpod-only" contract flagged as fragile).
- `a5b6ad4 fix(router): preserve category slug when redirecting an invalid sport
  segment` — the deep route dropped the slug (`/sport/foo/shoes → /sport/homme`);
  added `_sportSegmentCategoryRedirect` to keep it (`→ /sport/homme/shoes`), with
  a router test. (This partially re-splits the Round-A dedup — the two routes
  genuinely have different correct behavior.)
- `7a8f5f0 fix(admin): harden record list key against null ids` — replaced
  `ValueKey(record['id'])` with a collection-namespaced key + index fallback so a
  null id can't collapse every row.

**ChatGPT claims rejected after verification:**
- *PLP cache key `categorySlug: categoryId` looks wrong* → **not a bug.** The
  fetch (`product_providers.dart:21-37`) passes `categoryId` on the same
  `categorySlug` axis, documented; fetch and invalidation agree.
- *Document CMS-is-Riverpod-only* → covered better by the teeth-test than a comment.
- *Segment fallback is rigid* → acknowledged acceptable for the MVP.

### Not done (deferred, by decision)
- **Phase 3** (storefront prewarm → notifier): still needs a DevTools baseline
  first; no observed cost.
- **Phase 4** watch-items unchanged (global cache-key placeholders; whitelist
  l10n guard).

### Final state
`flutter analyze` clean · full suite **1057/1057** green · 8 commits total across
rounds A–C, all on `origin/main` (`…42b3af1..7a8f5f0`).
