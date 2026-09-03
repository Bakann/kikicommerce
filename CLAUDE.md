# Project conventions for AI assistants

## Start here — project docs map

These are **not** auto-loaded; read them before non-trivial work:

- [ARCHITECTURE.md](ARCHITECTURE.md) — layers, dependency direction, bootstrap,
  and the CMS-driven landing flow (where to look / where to write).
- [docs/decisions/](docs/decisions/) — ADRs: why Riverpod, PocketBase, the CMS
  section model. Don't re-litigate settled choices.
- [README.md](README.md) — how to run, configure (`--dart-define`) and deploy.
- Deep dives: [docs/pocketbase-schema.md](docs/pocketbase-schema.md) (backend
  schema), [docs/audit_jank.md](docs/audit_jank.md) +
  [docs/dev/storefront_performance_profiling.md](docs/dev/storefront_performance_profiling.md)
  (perf).
- Web rendering: [docs/dev/skwasm_gpu_resource_disposal.md](docs/dev/skwasm_gpu_resource_disposal.md)
  — renderer-safety guide (CanvasKit deploy policy, skwasm
  `memory access out of bounds` traps, live-tree capture, GPU-object lifecycle);
  read it before touching the APIs in the "Flutter web rendering lifecycle
  safety" section below or before reintroducing `--wasm`.
  [docs/dev/shader_animation_performance.md](docs/dev/shader_animation_performance.md)
  — designing shader animations / warm-ups so first-use compilation doesn't jank.

The rest of this file is the coding rules.

## Structure & refactoring

When a file, class or function gets large, the strategy is **move each part to the
layer it belongs to** (UI → `presentation`, logic → `application`, data access →
`data`) — see [ARCHITECTURE.md](ARCHITECTURE.md). Size alone is a weak signal:
`cms_models.dart` is large but cohesive (many small parse classes), whereas a
2k-line *screen* is the real smell. Split by responsibility, not by line count.

House style, already followed across the codebase:

- **Section-local sub-widgets stay private in the same file** (e.g.
  `_FeatureCarousel`, `_FeatureCard` in `horizontal_tile_carousel_section.dart`).
  Promote a widget to a shared file under `presentation/widgets/` **only when it
  is reused** (e.g. `VerticalParallax` / `HorizontalParallax`). Don't pre-split a
  single section into many files.
- **Extract chunks of `build()` into private `Widget` classes, not
  `Widget _buildX()` helper methods.** A real widget class gets its own build
  scope, `const`-ability and rebuild isolation (perf — see the jank section).
- **Composition over inheritance** — never subclass a widget to extend it; compose.

## Riverpod: prefer `select` in heavy widget trees

When a widget watches a provider but only consumes a slice of its value,
use `provider.select(...)` so the build only re-runs when that slice
changes. This is especially important for large widgets (PDP, checkout)
where every cart or PLP transition would otherwise rebuild the whole
tree.

```dart
// ❌ Rebuilds on every brand-settings transition (loading, refresh, etc.)
final brandSettings = ref.watch(storefrontBrandSettingsProvider).value;
final brandName = brandSettings?.title ?? defaultStorefrontBrandTitle;

// ✅ Rebuilds only when the resolved title string changes.
final brandName = ref.watch(
  storefrontBrandSettingsProvider.select(
    (async) => async.value?.title ?? defaultStorefrontBrandTitle,
  ),
);
```

Skip `select` when the widget genuinely needs the full `AsyncValue`
(both the loading flag and the resolved data) or when the slice would
require defining a separate equality (e.g. a freshly-allocated record
each frame).

## Dart formatting: keep CI green

The quality gate runs `dart format --set-exit-if-changed`. A single unformatted
Dart file fails the build.

**Mandatory: run `dart format` on every `.dart` file you created or edited as the
step immediately before `git commit` — every commit, no exceptions.** Do not defer
it to a final cleanup pass or rely on remembering; format, then `git add`, then
commit, in one go.

```bash
dart format path/to/file.dart path/to/test.dart   # then git add … && git commit
```

For broad changes, format the main Dart trees: `dart format lib test`.

Before pushing, verify exactly the way CI does:

```bash
dart format --output=none --set-exit-if-changed lib test
```

Gotcha that bites repeatedly: the formatter uses Dart's newer "tall" style. Do
**not** hand-align multi-line constructor initializer lists, method/`.clamp(...)`
chains, or long argument lists — write them with a trailing comma and let
`dart format` decide the wrapping. Hand-written indentation such as `})  :` (two
spaces before the `:`) is rewritten to `}) :`, and that diff alone fails CI even
when the code is otherwise correct.

If CI reports "Changed <file>", run `dart format` on exactly those files, commit
the formatter-only diff, and rerun the check above locally before pushing.

## Rendering perf: avoid introducing jank

Landing / PLP / PDP / CMS / scroll / animation surfaces are jank-sensitive.
When touching them, default to these and call out any deviation:

- No per-frame work on the scroll/animation hot path. In particular, avoid
  `findRenderObject()` / `localToGlobal()` / `GlobalKey` geometry reads per
  scroll tick — derive from the scroll offset, coalesce to one read per frame,
  or limit to the ±1 neighbours (cf. `NarrativePdpSection`).
- Prefer composition over layout for moving elements: `Transform.translate`
  (+ `RepaintBoundary` / `ValueListenableBuilder`) instead of animating
  `Positioned(top:)` or anything that forces a relayout.
- Keep long CMS/product lists lazy (`ListView`/`SliverGrid.builder`); never
  build a whole grid eagerly in a `Column`.
- Watch a provider with `select(...)` when a heavy tree only needs a slice
  (see the Riverpod section above); memoize O(n) getters read per frame.
- Precache the *exact* above-the-fold image URLs (matching thumb size) on
  transitions rather than letting them decode on the transition frame.
- Gate non-essential motion on `MediaQuery.disableAnimationsOf(context)` (and
  skip it when there is no enclosing `Scrollable`) — e.g. the scroll parallax
  widgets render statically under reduced motion.

Measure before rewriting, and measure in **profile/release** — debug web frame
times are inflated ~5–20× and will mislead you into "fixing" non-problems or
destabilising delicate code (e.g. the segment-transition slide). Follow the
Change Gate in `docs/dev/storefront_performance_profiling.md`; hotspot
inventory in `docs/audit_jank.md`.

## Flutter web rendering lifecycle safety

Production web deploys use **skwasm** (`--wasm` = dart2wasm + skwasm). CanvasKit
(dart2js) was tried to dodge the freeze below but janked app-wide on this
shader/animation-heavy app, so skwasm was kept for performance. **Known open
trade-off:** skwasm still has the empty-PLP → Home mobile freeze
(`memory access out of bounds` in `SkwasmParagraph` under relayout), documented
in
[docs/incidents/2026-07-09-skwasm-paragraph-relayout-freeze.md](docs/incidents/2026-07-09-skwasm-paragraph-relayout-freeze.md)
— an accepted risk pending a skwasm-side fix (Flutter upgrade / targeted
workaround), not resolved yet.

On skwasm, `memory access out of bounds` is a renderer-fatal wasm trap, not a
catchable Dart exception. Rules (details in
[docs/dev/skwasm_gpu_resource_disposal.md](docs/dev/skwasm_gpu_resource_disposal.md) —
**read it first**):

- Any change touching `RenderRepaintBoundary.toImage`/`toImageSync`,
  `PictureRecorder`, `SceneBuilder`, `ui.Image`, `ui.Picture`, `FragmentShader`,
  `ImageFilter.shader`, or a `RenderObject` retained in a deferred callback:
  read the web renderer guide before implementing.
- Never start a capture of the **live render tree** from a `Timer`, `Future`,
  post-frame callback, or scroll-end without re-checking widget + `RenderObject`
  state at the exact moment of capture.
- A live-tree capture should at least check `mounted`, `renderObject.attached`,
  and pipeline quiescence (`!WidgetsBinding.instance.hasScheduledFrame`), per
  the hardened `AdaptiveBottomNav._sample()` pattern. Prefer `toImageSync()` so
  no navigation/teardown can slip into an async window mid-capture.
- `try/catch` does **not** protect against `memory access out of bounds`: a wasm
  trap can kill the renderer before control returns to Dart.
- Never gate profile/release behaviour on a `debug*`/assert-only member (e.g.
  `debugNeedsPaint` throws `LateInitializationError` once asserts are stripped).
- Validate renderer changes on a real **profile/release web build**, not widget
  tests: navigation during animation, widget teardown, cross-shell route change,
  desktop↔mobile resize — repeated, because these races are intermittent.
- On a cascading wasm crash, diagnose the **first** `memory access out of
  bounds`, not the secondary `*_dispose`/`malloc` failures it triggers.

## Catalog cache (PLP/PDP)

`plpProvider` and `pdpProvider` go through `CachedRemoteReader` with the
SWR policies in `KikiCachePolicies`. Mutations must always be paired
with a `CatalogInvalidator` call — see
`lib/presentation/providers/catalog_invalidator_provider.dart`. Do not
add a new catalog read provider without wiring its key into the
invalidator.

## CMS / navigation collections are public-read

`cms_pages`, `page_sections`, `navigation_*`, and `storefront_settings`
have empty `listRule`/`viewRule`. Never store secrets in their `config`
JSON — the storefront fetches them anonymously.

## After pushing to GitHub

Do not monitor, poll, watch, or retrieve the result of the GitHub Quality Gate
or deployment workflows after a push. Stop after reporting the pushed commit
and the local verification performed. The user checks GitHub Actions manually;
only inspect a workflow when the user explicitly asks for it.

## Testing

Tests are the regression safety net here — Riverpod was chosen partly for
testability (see [ADR-001](docs/decisions/adr-001-riverpod.md)). Defaults:

- **Cover business/use-case logic and repository behaviour** with tests. Pump
  widgets in isolation via `ProviderScope(overrides: [...])`, injecting fakes
  rather than hitting PocketBase.
- **Test observable behaviour and contracts, not implementation details.** A
  test that asserts internals breaks on safe refactors and becomes a liability;
  assert what the widget/use-case *does*, not how.
- **Visual and performance changes are not verifiable by unit tests.** Parallax,
  animations, layout/margins, scroll/jank — a green unit test only proves its
  own assertion, never that the pixels or frame times are right. Validate those
  by running the app (golden tests for visuals; profile mode for perf, per the
  jank section above). Don't claim a visual/perf fix is verified by a unit test.
- **Run the relevant tests before committing**, alongside `dart format`, as the
  regression gate.
