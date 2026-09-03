# Shader and Animation Performance Guide

Use this guide before adding or changing shader-heavy animations on landing,
PLP, PDP, CMS grids, cart surfaces, or route transitions. The goal is to avoid
debugging first-tap jank after the fact by designing the animation around stable
GPU work from the start.

## Core rule

Animations must not discover new expensive rendering programs on the user's
first gesture. If an effect uses gradients, blurs, images, complex clips, path
ops, or save layers, either keep the per-frame rendering variants stable or
warm them up on the real target surface before the interaction.

## Design checklist

Before implementing, write down:

- Target surface: native mobile, Flutter web CanvasKit, desktop, or all of them.
- Hot path: scroll, first tap, route transition, drawer, sheet, or idle reveal.
- Rendering primitives: image draw, gradient, blur, backdrop filter, clip,
  opacity layer, path combine, shadow, particle trail.
- Motion contract: duration, max active elements, max painted area, and reduced
  motion fallback.
- Validation target: at least one physical mid-tier device for the riskiest
  platform. For web mobile, include Chrome Android CanvasKit.

If the effect is only decorative, prefer a simpler implementation on web mobile
over a complex fallback that needs multiple profiling passes.

## Painter structure

Prefer a `CustomPainter` driven by a `Listenable` for animation hot paths:

```dart
class EffectPainter extends CustomPainter {
  EffectPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;
  final Paint _paint = Paint();
  late final RRect _staticBounds = RRect.fromRectAndRadius(
    _rect,
    const Radius.circular(8),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    // Paint only; do not rebuild widgets or resolve layout geometry here.
  }
}
```

Rules for the hot path:

- Resolve layout geometry once at launch. Do not call `findRenderObject()`,
  `localToGlobal()`, or use `GlobalKey` lookups per frame.
- Wrap independent animated overlays in `RepaintBoundary`.
- Drive repaint through the painter's `repaint` listenable instead of rebuilding
  widgets every tick.
- Cache `Paint`, static `Path`, `RRect`, `Rect`, `Shader`, and image resources
  for the lifetime of the effect.
- Pre-sample particles and random values before the animation starts.
- Add early returns when an element is fully transparent, offscreen, or no longer
  contributes to the visual.

## Stable shader variants

Avoid creating a new shader variant every frame. This is the main rule for
CanvasKit/WebGL first-use jank.

Do not animate gradient stops, colors, or endpoints by recreating
`ui.Gradient.*` in `paint()`:

```dart
// Avoid on a per-frame path.
paint.shader = ui.Gradient.linear(
  rect.topLeft,
  rect.bottomRight,
  colorsFor(t),
  stopsFor(t),
);
```

Create a fixed shader once, then move the coordinate system:

```dart
late final ui.Gradient _shine = ui.Gradient.linear(
  rect.topLeft,
  rect.bottomRight,
  const [
    Color(0x00FFFFFF),
    Color(0x24CFE4FF),
    Color(0x38FFFFFF),
    Color(0x1FF3D9FF),
    Color(0x00FFFFFF),
  ],
  const [0.25, 0.40, 0.50, 0.60, 0.75],
);

void drawShine(Canvas canvas, Rect rect, double t) {
  final offset = (rect.bottomRight - rect.topLeft) * (t - 0.5);
  canvas.save();
  canvas.clipRect(rect);
  canvas.translate(offset.dx, offset.dy);
  paint.shader = _shine;
  canvas.drawRect(rect.shift(-offset), paint);
  paint.shader = null;
  canvas.restore();
}
```

Guidelines:

- Keep shader color count, stops, blend mode, and tile mode constant across
  frames.
- Move, rotate, or scale the canvas instead of changing shader endpoints.
- If opacity must change, bound any `saveLayer` to the smallest possible rect and
  profile it. Never add full-screen opacity layers casually.
- If a finite set of variants is unavoidable, quantize and prewarm that exact
  set. Do not allow unbounded per-frame shader combinations.

## Blurs and shadows

Treat blur as one of the most expensive primitives:

- `MaskFilter.blur`, `ImageFilter.blur`, and `BackdropFilter` can create extra
  GPU passes and shader compilation work.
- Keep sigma small and the painted bounds tight.
- Avoid stacking multiple moving blurs with a particle trail on the same first
  interaction unless the combination is explicitly profiled.
- Prefer static or pre-rasterized shadows when the shape is stable.
- If a blur only adds polish, gate it off for reduced motion and be ready to
  disable it on web mobile if traces show `GetShaderiv`, `GPUTask`, or long
  `FireAnimationFrame` stalls.

## Clips and path ops

Complex clipping is easy to hide in painter code and hard to see in a trace.

- Prefer `clipRect` or `clipRRect` over arbitrary `clipPath`.
- Compute dynamic half-planes or clipping paths once per frame, then reuse them.
- Run `Path.combine` at most once per needed shape per frame.
- Group clips under a single `save()`/`restore()` when possible.
- Precompute static paths such as sticker bounds, rounded rects, and strokes.
- Avoid clipping large blurred or opacity-layered regions unless the visual
  requires it.

## Images

Image work must be paid before the animation:

- Use the exact same `ImageProvider` cache key as the visible widget, including
  resize bounds and disk/cache dimensions.
- Precache the exact displayed size, not the original asset size.
- Do not call `toImage`, decode images, or create large `ui.Image` objects on a
  tap path.
- Dispose local `ui.Image` and `Picture` resources owned by warm-up or synthetic
  painters.

> **Synthetic capture vs live-tree capture.** A `PictureRecorder`/`toImage` that
> draws its *own* content (a warm-up texture, a seed image) is self-contained.
> Capturing a **mounted widget's** `RenderRepaintBoundary`
> (`renderObject.toImage`/`toImageSync`) composites the live layer tree and has
> stricter timing requirements, especially if skwasm is ever reintroduced. See
> `docs/dev/skwasm_gpu_resource_disposal.md` before capturing a live tree.

## First interaction render profile

For first-tap or first-route-transition effects on web mobile, do not rely on
warm-up alone. Add an explicit low-cost render profile for the first interaction
and keep a safer permanent web-mobile profile for later interactions. This is
the pattern that fixed the perceptible first-tap jank in the add-to-cart comet
(`de6cf38`).

Recommended profile split:

```dart
enum EffectRenderProfile {
  rich,
  webMobileSafe,
  webMobileFirstInteractionCheap,
}
```

Selection rules:

- Use `rich` on native mobile, desktop, and non-risky surfaces.
- Use `webMobileSafe` permanently on Chrome Android / CanvasKit for decorative
  effects that use particles, blur, image transforms, or multiple clips.
- Use `webMobileFirstInteractionCheap` until the warm-up has completed or until
  one interaction has already finished.
- Track warm-up `started` and `completed` separately. A warm-up that merely
  started must not unlock the richer profile.

The cheap profile should remove whole classes of GPU work, not just tweak
constants:

- Reduce particle count and visible trail window.
- Increase particle stride if the trail remains visually dense enough.
- Remove per-particle `MaskFilter.blur`; draw a simpler core or unblurred glow.
- Skip optional shine/sweep overlays on the first interaction.
- Replace moving blurred shadows with simple alpha shapes or no shadow.
- Use lower image filtering while the element is fast-moving.
- Keep behavior identical: cart mutation, navigation, cleanup, and reduced
  motion must not depend on the render profile.

The safe web-mobile profile should stay cheaper than rich mode even after
warm-up. Otherwise a second tap can rediscover the same expensive shader work
that was avoided on the first tap.

Anti-pattern:

```dart
if (firstTap) {
  disableExpensiveEffect();
} else {
  enableFullEffectWithoutWarmUp();
}
```

This only moves the jank from the first tap to a later tap. Either warm up the
full variant before enabling it, or keep the safer profile for that platform.

The add-to-cart comet used this approach by making web mobile:

- first tap: fewer particles, shorter/strided trail, no trail blur, no glow,
  low-alpha unblurred glow, no peel shadow blur, no shine sweep, low image
  filter;
- later taps: still no per-particle blur, bounded particle count, stronger
  unblurred glow/core, simple shadows, low image filter;
- non-web-mobile: unchanged rich renderer.

## Web CanvasKit warm-up

For web mobile effects that introduce new gradients, blurs, image draws, or
trail programs, add a best-effort warm-up instead of relying on the first tap.

Preferred pattern:

- Gate to `kIsWeb`, mobile layout, relevant theme/route, non-reduced motion, and
  a session-level latch.
- Wait until the page has rendered and the user has dwelled briefly.
- Paint the real production painters on the real surface, hidden under opaque
  content or otherwise invisible to the user.
- Split warm-up over several real frames; one representative timeline step per
  frame is safer than one long warm-up task.
- Cover the actual variants: peel, folded flight, unfolded flight, snap, max
  trail, image draw, shadow blur, and any clip/gradient combination.
- Keep the warm-up non-interactive: no visible overlay, no input hit target, no
  route side effect.

Do not assume an offscreen `ui.PictureRecorder.toImage()` warm-up compiles the
same programs as the visible CanvasKit/WebGL surface. It can be useful for smoke
testing painter code, but the real-surface warm-up is the relevant mechanism for
first-frame shader stalls. Such a warm-up draws its own synthetic content; this
is **not** the same as capturing a live `RenderRepaintBoundary` on a delay, which
has separate renderer-safety constraints (see
`docs/dev/skwasm_gpu_resource_disposal.md`).

This remains relevant after the production build switched away from skwasm:
CanvasKit still pays first-use WebGL program compilation costs. The warm-up does
not fix skwasm crashes, and the CanvasKit build fix does not make the warm-up
automatically obsolete.

## Reduced motion and fallback

Every decorative animation needs a simpler path:

- Respect `MediaQuery.disableAnimationsOf(context)`.
- Keep add-to-cart, navigation, cart mutation, and sheet behavior identical when
  motion is skipped.
- Prefer a short fade/scale or no animation over a complex fallback that still
  uses the same costly shaders.
- Make web mobile fallback decisions explicit and measured, not accidental.

## Testing

Unit and widget tests should verify contracts, not frame time:

- The animation completes and cleans up.
- Reduced motion skips visual work but preserves behavior.
- Warm-up hosts mount only on intended surfaces.
- Warm-up does not insert visible overlay entries or interactive widgets.
- Painters can render representative frames without throwing.

Do not claim a perf fix from tests alone. Visual and jank changes require
profile or release validation.

## Profiling protocol

For shader or animation changes:

1. Capture a baseline before rewriting when possible.
2. Use profile or release mode on a physical device.
3. For web mobile, test Chrome Android CanvasKit on the target route.
4. Compare at least two runs per variant; keep route, data, network, locale, and
   dwell time fixed.
5. For first-tap effects, wait at least one second after page render before the
   tap so load jank and tap jank are not mixed.
6. Isolate hypotheses with one temporary flag at a time, then remove those flags
   before shipping.
7. Inspect trace events, not just visual feel.

Useful trace symptoms:

- `FireAnimationFrame` long task near the tap: Dart/JS frame stalled.
- `GLES2Implementation::GetShaderiv`: shader/program compilation or query.
- `GPUTask`: GPU-side work blocking the frame.
- `Canvas::saveLayer`: opacity, blur, filter, or compositing cost.
- `DecompressTexture`: image decode/upload work.

## PR checklist

Before opening or merging a PR that touches shader-heavy animation:

- No per-frame `ui.Gradient.*` creation with animated stops/colors/endpoints.
- No unbounded `saveLayer`, blur, or backdrop filter on the hot path.
- No per-frame layout reads.
- Static geometry and reusable paints/shaders are cached.
- Dynamic paths and `Path.combine` calls are factored and reused per frame.
- Image providers match visible cache keys exactly.
- Reduced motion behavior is covered.
- Web mobile CanvasKit warm-up exists when new first-use shader work is expected.
- Relevant widget tests pass.
- Profile/release measurements are attached or the PR clearly states why they
  are not needed.

## Related

- `docs/dev/skwasm_gpu_resource_disposal.md` — the renderer-safety half of the
  lifecycle. Production runs on skwasm (`--wasm`); a CanvasKit build was tried to
  dodge the 2026-07 `SkwasmParagraph` freeze but janked app-wide, so skwasm was
  kept and that freeze is a known open risk. Read that guide before touching
  low-level rendering or the web build renderer.
