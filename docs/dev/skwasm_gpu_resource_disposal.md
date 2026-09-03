# Flutter web renderer safety: skwasm traps and CanvasKit deploy policy

Read this before changing the Flutter web build renderer or touching code that
uses low-level rendering APIs:

- `RenderRepaintBoundary.toImage` / `toImageSync`;
- `PictureRecorder`, `SceneBuilder`, `ui.Image`, `ui.Picture`;
- `ui.FragmentShader`, `ui.ImageFilter.shader(...)`;
- retained `RenderObject`s used from `Timer`, `Future`, post-frame, or scroll-end
  callbacks;
- text/layout workarounds intended specifically for web/skwasm.

## Production policy

Production web builds use **skwasm** (`--wasm`), for runtime performance:
switching to CanvasKit (dart2js) to dodge the freeze below janked the app
across all pages, which was a worse regression than the intermittent freeze.

**This means the July 2026 freeze is still live in production, as an accepted
open risk.** The incident is documented in
[docs/incidents/2026-07-09-skwasm-paragraph-relayout-freeze.md](../incidents/2026-07-09-skwasm-paragraph-relayout-freeze.md).
The useful crash evidence pointed at `SkwasmParagraph.maxIntrinsicWidth` under
`TextPainter.layout` / `RenderParagraph` during cold relayout — a skwasm-side
fault (CanvasKit's `CkParagraph` was unaffected). A real fix must stay on skwasm:
the leading candidate is a **Flutter upgrade** (re-test the freeze on a newer
skwasm), then a targeted workaround if the widget is ever identified. Do not
switch production back to CanvasKit without weighing the app-wide jank.

## What a skwasm trap looks like

On skwasm, renderer bugs and unsafe low-level rendering calls can trap the
WebAssembly heap:

```text
RuntimeError: memory access out of bounds
  at skwasm.wasm ...
```

This is not a normal Dart exception. It may freeze the tab before control
returns to Dart, so `try/catch` is not a safety mechanism. Prevent unsafe timing
and renderer exposure; do not rely on catching the failure.

After the first trap, later errors are usually collateral because the wasm
allocator or renderer state is already corrupted. Diagnose the **first** error in
the console. If you are trying to capture a useful stack, arm
`Error.stackTraceLimit = Infinity` before the reproduction attempt.

## July 2026 retained cause

The retained cause of the empty-PLP freeze is a skwasm text/layout crash:

```text
RenderParagraph.paint / RenderParagraph.performLayout
TextPainter.layout
SkwasmParagraph.maxIntrinsicWidth
defaultPaint / ChildLayoutHelper.layoutChild
```

The available stacks did not include an application widget above those framework
frames, and repeated cold-load/resize/throttled attempts did not reliably
retrigger the crash with a deeper stack. That means a widget-specific workaround
would be speculative. The build-level mitigation, CanvasKit, removes the whole
`SkwasmParagraph` path and is therefore the appropriate production fix.

## Low-level rendering rules

These rules still matter if skwasm is reintroduced for testing, if a low-level
rendering change is made, or if another web renderer trap appears. They are
precautions, not the retained cause of the July 2026 paragraph incident.

### Live render-tree capture

Capturing a mounted widget tree with `RenderRepaintBoundary.toImage()` /
`toImageSync()` composites live layers. Do not start such a capture from a stale
or delayed callback without checking the world at the exact moment of capture:

- `mounted`;
- `renderObject is RenderRepaintBoundary`;
- `renderObject.attached`;
- `!WidgetsBinding.instance.hasScheduledFrame`.

If the pipeline has a scheduled frame, a route transition, resize, animation, or
relayout is pending. Defer and retry instead of capturing. Prefer
`toImageSync()` when the point is to avoid an async window where navigation or
teardown can slip in between capture start and completion. `toByteData()` then
reads the already captured image.

`AdaptiveBottomNav._sample()` follows this guarded shape. Keep that hardening,
but do not cite it as the production fix for the `SkwasmParagraph` freeze.

### GPU-object lifetime

Synchronously disposing a shader/image/picture that might still be referenced by
the last submitted scene is a plausible renderer hazard on skwasm. When safety is
unclear during teardown:

- stop tickers/controllers/listeners first;
- stop producing new paint work;
- drop references instead of forcing immediate disposal;
- let `dart:ui` finalizers reclaim the object later.

Per-frame disposal in a hot loop is different: it is acceptable only when the
object being freed was already replaced and is no longer part of the live scene.

### Synthetic work vs mounted-tree capture

A `PictureRecorder`/`toImage` that draws its own synthetic content, such as a
warm-up texture or seed image, is self-contained. It is not the same risk as
capturing a mounted `RenderRepaintBoundary` during relayout or teardown.

The `AddToCartCometWarmUpLayer` is a first-interaction shader/WebGL warm-up. It
does not mitigate the skwasm paragraph crash, and it stays relevant on skwasm
(the current production renderer), which also compiles shader programs on first
use.

## Validation protocol

Widget tests cannot validate skwasm traps. They run on a different surface and
do not prove production renderer safety. For web renderer work:

1. Build release/profile web, not debug.
2. Match the production renderer: build with `--wasm` (skwasm), since that is
   what production ships.
3. Test a real browser/mobile viewport with the console open.
4. Repeat cold-load and navigation/resize scenarios because these races are
   intermittent.
5. Do not claim a renderer crash is fixed from a green widget test alone.

For the July 2026 class specifically, validate:

- `https://kikicommerce.com/fr` -> menu -> Homme -> Chaussures -> Lifestyle;
- direct `/fr/catalog/homme-chaussures-lifestyle`;
- bottom nav, PLP back, and browser back from the empty PLP;
- no `memory access out of bounds` and no unclickable controls.

## Related

- [docs/incidents/2026-07-09-skwasm-paragraph-relayout-freeze.md](../incidents/2026-07-09-skwasm-paragraph-relayout-freeze.md)
  — incident postmortem and retained build mitigation.
- [shader_animation_performance.md](shader_animation_performance.md) — CanvasKit
  shader animation and warm-up guidance.
- [../audit_jank.md](../audit_jank.md) — hotspot inventory.
