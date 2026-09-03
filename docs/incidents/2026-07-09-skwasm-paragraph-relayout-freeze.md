# Postmortem - skwasm paragraph relayout freeze (2026-07-08/09)

This is the frozen history of one production incident. The durable rules live in
[docs/dev/skwasm_gpu_resource_disposal.md](../dev/skwasm_gpu_resource_disposal.md).

## Summary

The production Flutter web build was deployed with `flutter build web --wasm`,
therefore using the skwasm renderer. On mobile Chrome, navigating from the
landing menu to an empty PLP such as
`/fr/catalog/homme-chaussures-lifestyle`, or leaving that empty PLP quickly,
could freeze the tab with `RuntimeError: memory access out of bounds`.

The useful crash evidence points into skwasm's text pipeline:

```text
RenderParagraph.paint / RenderParagraph.performLayout
TextPainter.layout
SkwasmParagraph.maxIntrinsicWidth
defaultPaint / ChildLayoutHelper.layoutChild
```

The stack did not include an application widget above the framework frames. The
working conclusion is a skwasm paragraph/layout bug during cold relayout, not an
actionable `Text` widget bug in the app.

## User impact

The tab froze hard: bottom navigation, PLP back, and browser back stopped
responding until reload. The common path was:

1. Open `https://kikicommerce.com/fr` on an iPhone-class viewport.
2. Use the landing menu: Homme -> Chaussures -> Lifestyle.
3. Land on the empty PLP.
4. Leave quickly or hit the race during the cold mobile relayout.

The issue was web-only. Native apps were unaffected.

## Evidence

- The crash signature was `RuntimeError: memory access out of bounds` from
  `skwasm.wasm`.
- The captured Dart/framework frames ended in `SkwasmParagraph.maxIntrinsicWidth`
  through `TextPainter.layout` / `RenderParagraph`.
- The surrounding framework frames were generic Row/Column layout/paint helpers,
  so they did not identify a specific app widget.
- The first hit happened on a very slow first cold frame (`requestAnimationFrame`
  around 99 ms), which likely widened the race window.

## Reproduction attempts after the first hit

The crash became hard to reproduce after the renderer warmed up:

- Tight resize loops, 40-60 toggles at 50-60 ms: no repro; Flutter coalesced the
  relayouts.
- Cold-load plus one mobile resize, repeated 16 times: no repro.
- CPU throttling at 4x and 6x to recreate slow frames: no reliable repro.
- Cross-shell navigation loops under throttle: no reliable repro.
- `Error.stackTraceLimit = Infinity` was armed for later attempts, but no second
  useful full stack was captured.

Because the retained fix removes skwasm from production, the missing app widget
name is not blocking: CanvasKit avoids the whole `SkwasmParagraph` code path.

## skwasm vs CanvasKit comparison

Two local `--profile` builds were driven through the same stress (Playwright):

- **skwasm** (`--wasm`): crashed on the first cold-load + desktop→mobile resize —
  93 `memory access out of bounds`, symbolicated to `SkwasmParagraph.maxIntrinsicWidth`
  (this is the capture that identified the text pipeline as the crash site).
- **CanvasKit** (no `--wasm`): the same battery — ~7 desktop↔mobile resize toggles,
  2 cold-load+resize cycles, and 1 cross-shell Home navigation — produced **zero
  errors**.

Caveat: the skwasm crash is itself intermittent (one hit, then hard to
retrigger), so "CanvasKit clean across ~10 events" is *suggestive*, not a rigorous
A/B. It corroborates the decisive argument, which is structural: `SkwasmParagraph`
exists only in skwasm, so the faulting code path is absent in CanvasKit
(`CkParagraph`). Final confirmation on the real production browser is still owed
once the CanvasKit build is deployed (see [Validation rule](#validation-rule)).

## Rejected or non-final hypotheses

- **AddToCartComet warm-up.** It caused a visible artifact on empty PLPs before
  `d5eef45`, but that was a CanvasKit warm-up layer leaking visually. It was not
  the tab-freeze root cause.
- **Navigation shader/GPU disposal.** Deferring disposal by one frame and then
  dropping references for GC did not eliminate the freeze. Keep the lifecycle
  precautions, but do not cite them as the proven cause.
- **Adaptive nav live-tree capture.** `e1116f7` hardened
  `AdaptiveBottomNav._sample()` against unsafe `toImage` timing. That remains a
  useful skwasm safety guard, but the later crash evidence pointed at
  `SkwasmParagraph`, so it is not the retained production fix.
- **COOP/COEP / raster-worker deadlock.** Production was not cross-origin
  isolated; do not explain the freeze as a worker `Atomics.wait` deadlock.

## Attempted fix, then reverted

The first mitigation switched production to CanvasKit (drop `--wasm`), since
`CkParagraph` avoids the skwasm `SkwasmParagraph` path (commit `814bac7`,
deployed). It **removed the freeze but janked the app across all pages**:
CanvasKit runs on dart2js, which is markedly slower than dart2wasm for this
shader/particle/animation-heavy app. That regression was worse than the
intermittent freeze, so production was reverted to skwasm (`--wasm`).

## Current status: unresolved on skwasm

Production is back on skwasm for performance, so **this freeze is live again as
an accepted open risk**. It is not fixed — it is deferred.

The proper fix must stay on skwasm. Leading candidate: a **Flutter upgrade**
(the crash is a skwasm-engine `SkwasmParagraph` fault, plausibly fixed upstream
since 3.44.4) — re-run the [validation](#validation-rule) on the newer skwasm.
If it persists, identify the triggering `Text` widget (needs a reliable repro,
which was not achieved here) and apply a targeted workaround. Do **not** switch
production back to CanvasKit without weighing the app-wide jank it caused.

CanvasKit uses `CkParagraph` instead of `SkwasmParagraph`, so this mitigates the
entire crash class observed here regardless of which `Text` widget happened to
trigger the layout path.

## Validation rule

Widget tests cannot prove this fixed: they do not exercise the production web
renderer. Validate with a release/profile web build in Chrome mobile mode:

- `/fr` -> landing menu -> Homme -> Chaussures -> Lifestyle;
- direct load of `/fr/catalog/homme-chaussures-lifestyle`;
- leave the empty PLP with bottom nav, PLP back, and browser back;
- repeat after a cold browser context when possible.

No `memory access out of bounds` should appear in the console, and controls must
remain clickable.

## Warm-up note

The `AddToCartCometWarmUpLayer` is still a CanvasKit/WebGL first-interaction
performance optimization. It does not mitigate this skwasm crash, and the skwasm
crash does not make the warm-up obsolete. Keep it unless profiling on real
Chrome Android shows the first add-to-cart flight no longer needs it.
