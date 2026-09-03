# Flutter jank audit playbook

A reusable process for investigating real (not simulated) UI jank in a
Flutter app — on a physical device and, secondarily, on web. Distilled from
a real audit on this project (landing-page scroll jank on a Samsung S22
Ultra): two genuine bugs were found and fixed with hard numbers to back
them, and a residual jank was correctly identified as *not* worth a patch,
instead of forcing one. Both outcomes count as success. This is written to
be handed to another coding agent as a starting brief — it assumes no prior
context beyond "there's reported jank on route X."

Companion docs in this repo: `docs/dev/storefront_performance_profiling.md`
(the project's own checklist), `docs/audit_jank.md` (this project's live
findings — see the "Mise à jour 2026-07-01" section for a worked example of
everything below).

## Core principles

1. **Measure before touching code.** A jank hypothesis from reading source
   alone is a guess, not a finding. Every claim in the final report should
   trace back to a number from a real run.
2. **Compare against a clean reference, always.** A single absolute number
   ("worst frame: 40ms") means nothing alone. Profile the suspect route
   *and* at least one route known to be smooth, under identical conditions,
   in the same session. The delta is the signal.
3. **One variable at a time.** When isolating a cause, change exactly one
   thing, re-measure, then revert before touching the next hypothesis.
   Stacking changes destroys your ability to attribute the result.
4. **Verify empirically, even when the static-analysis story is convincing.**
   Reading a widget's code and concluding "this Opacity/BackdropFilter must
   be the cause" is a hypothesis. Instrument it, run it, watch it not
   correlate with the numbers, and be willing to throw the hypothesis away.
   This happened twice in the reference audit (a documented `KikiImage`
   theory and a `CmsSectionReveal`/`BackdropFilter` theory), and both were
   real dead ends that would have wasted an implementation cycle if acted on
   without measurement.
5. **Don't chase raw event counts.** A high count of some engine event
   (`saveLayer`, decode calls, whatever) is not itself evidence of a
   problem — the clean reference route may emit *more* of them. What
   matters is whether a specific event's *duration* or a *derived metric*
   (memory swing, missed-frame count) correlates with the bad frames.
6. **Never commit exploratory instrumentation or bypass patches.** Every
   temporary print statement, disabled widget, or bypassed effect used to
   test a hypothesis gets reverted (`git checkout -- <file>`) before the
   next experiment and before the final report. `git status` should be
   clean (module pre-existing unrelated diffs) at every checkpoint.
7. **Propose before implementing.** Once a cause is isolated with numbers,
   describe the minimal patch and its expected effect before writing it,
   especially if multiple viable fixes exist with different tradeoffs
   (visual quality, scope, risk). Let whoever's driving the audit choose.
8. **A live/mutable backend can invalidate your own findings mid-session.**
   If content is served from an editable CMS/database you don't control,
   re-verify the actual state (via its read API, not memory of an earlier
   observation) before trusting a trace against it — content can change
   between two profiling runs with zero code changes on your side. This is
   not a hypothetical: it happened in the reference audit and quietly
   invalidated an earlier "the video helps" conclusion.
9. **It is a legitimate outcome to conclude "no actionable Flutter-side
   cause found."** Don't force a patch to satisfy the shape of the request.
   Report the dead ends with their evidence, name the most likely remaining
   explanation (even if it's outside your control, e.g. a device/engine
   characteristic), and stop.

## 1. Build a real-touch profiling harness

Flutter's own `flutter_driver` synthetic gestures don't exercise the OS
input pipeline the same way a finger does, and won't reproduce every jank
mode. Drive the device with real touch events from the host while a
`flutter_driver` trace records:

```dart
// test_driver/scroll_perf_test.dart — driver script, not run by `flutter
// test`/CI. Target app entrypoint (test_driver/app.dart) must call
// enableFlutterDriverExtension() before app.main().
import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';

Future<void> main() async {
  final scenario = Platform.environment['PERF_SCENARIO'] ?? 'scroll_perf';
  final swipes = int.parse(Platform.environment['PERF_SWIPES'] ?? '8');
  final deviceSerial = Platform.environment['PERF_DEVICE_SERIAL'];
  final adbPath = Platform.environment['PERF_ADB_PATH'] ?? 'adb';
  final outputDir = Platform.environment['PERF_OUTPUT_DIR'] ?? 'build/perf';

  final driver = await FlutterDriver.connect();
  await Future<void>.delayed(const Duration(seconds: 3)); // let first paint/fetch settle

  Future<void> swipe(int y1, int y2, int durationMs) async {
    await Process.run(adbPath, [
      if (deviceSerial != null) ...['-s', deviceSerial],
      'shell', 'input', 'swipe', '540', '$y1', '540', '$y2', '$durationMs',
    ]);
  }

  final timeline = await driver.traceAction(() async {
    for (var i = 0; i < swipes; i++) { await swipe(1900, 400, 180); await Future<void>.delayed(const Duration(milliseconds: 500)); }
    for (var i = 0; i < swipes; i++) { await swipe(400, 1900, 180); await Future<void>.delayed(const Duration(milliseconds: 500)); }
  });

  final summary = TimelineSummary.summarize(timeline);
  await summary.writeTimelineToFile(scenario, destinationDirectory: outputDir, pretty: true);
  await driver.close();
}
```

Run it per route:

```bash
PERF_SCENARIO=<name> PERF_SWIPES=8 PERF_DEVICE_SERIAL=<adb-serial> \
  PERF_ADB_PATH="$(which adb)" PERF_OUTPUT_DIR=build/perf \
  flutter drive --target=test_driver/app.dart \
  --driver=test_driver/scroll_perf_test.dart \
  --profile -d <device-id> --route=<route>
```

- **Always `--profile`, never debug**, for any timing claim — debug frame
  times are inflated 5-20× and will send you chasing non-problems (this is
  also true for `flutter run -d chrome` on web).
- `--route=<path>` works out of the box with go_router-based apps as long as
  the app's root widget doesn't force an `initialLocation`, letting the
  platform's default route name (which `--route` sets) flow through.
- Keep this harness in the repo (`test_driver/`) — it's cheap infrastructure
  and will be needed again.
- **Known flake**: occasionally the run produces "TimelineSummary had no
  events to summarize" with zero app-level logs. This is an intermittent
  driver/device connection issue, not a real signal — wake the device
  (`adb shell input keyevent KEYCODE_WAKEUP`), restart the adb server if
  needed (`adb kill-server && adb start-server`), and retry.

## 2. Establish the baseline table

For every route under investigation *and* at least one clean reference
route, from the produced `<scenario>.timeline_summary.json`:

| Metric | Where |
|---|---|
| `worst_frame_build_time_millis` | UI/build-thread cost — rule out a rebuild storm |
| `worst_frame_rasterizer_time_millis` | GPU/raster-thread cost — most jank lives here |
| `missed_frame_build_budget_count` / `missed_frame_rasterizer_budget_count` | frames over the device's vsync budget (16.67ms @ 60Hz) |
| `frame_count` | sanity-check the run actually captured the intended scroll |
| `new_gen_gc_count` / `old_gen_gc_count` | allocation pressure, cheap secondary signal |

Compute your own `frames > 16.7ms` / `frames > 32ms` from
`frame_rasterizer_times` (microseconds) if you want the raw distribution,
not just percentiles.

## 3. If raster time dominates, read the raw timeline

`writeTimelineToFile` also drops `<scenario>.timeline.json` — a Chrome
trace-format dump with raw `B`/`E` (begin/end) events per thread. Pair them
up (a small Python script is faster than any GUI for this):

```python
from collections import defaultdict
stacks, intervals = defaultdict(list), []
for e in sorted(events, key=lambda x: x.get('ts', 0)):
    if e['ph'] == 'B':
        stacks[(e['tid'], e['name'])].append(e['ts'])
    elif e['ph'] == 'E' and stacks[(e['tid'], e['name'])]:
        start = stacks[(e['tid'], e['name'])].pop()
        intervals.append((e['tid'], e['name'], start, e['ts'] - start))
```

Then sort by duration and look for these specific event names (their
presence/duration is diagnostic, not just their count):

- **`DecompressTexture`** (on `FlutterConcurrentMessageLoopWorker` threads)
  — image decode. Long (multi-hundred-ms) events here mean an image is
  being decoded at a far larger resolution than needed. Cross-reference
  with `ImageCache.putIfAbsent` events nearby (their `args.key` sometimes
  shows the URL/provider type, e.g. `CachedNetworkImageProvider(...)` vs. a
  bare `FileImage`/`ResizeImageKey` — the latter two mean no size hint
  reached the decoder).
- **`Canvas::saveLayer`** — compositing cost (opacity, blur, complex clips,
  shader masks all force this). A *populated* saveLayer (child paint events
  nested inside its Begin→End span) means expensive content is being
  composited — legitimate rendering cost. A saveLayer whose Begin→End span
  is *empty* (nothing nested inside, yet it still takes tens of ms) means
  the raster thread stalled on something else entirely (see next point) —
  don't blame the widget that triggered the layer.
- **`AllocatorVK`** (`args.MemoryBudgetUsageMB`, Impeller/Vulkan backend) —
  sample this across the whole trace. A route with a large swing (tens to
  hundreds of MB) correlates with GPU memory pressure; a clean route
  typically stays flat. This is a strong, cheap-to-check signal for "is the
  jank GPU-memory-bound" before auditing any widget.
- **`ReclaimResources`** / **`DestroyImage`** — GPU resource eviction.
  Expensive, synchronous instances landing inside a slow frame's window are
  a strong corroborating signal alongside an `AllocatorVK` swing.

## 4. Rule out image sizing precisely (cheap, decisive, often skipped)

Don't assume "images are probably oversized" — check exactly, before
proposing any thumbnail/decode-size change:

1. Temporarily add one `print()` in the shared image widget's build path,
   logging url, requested render size, devicePixelRatio, and the resulting
   decode (`cacheWidth`/`cacheHeight` or equivalent) size.
2. Run the harness with a *low* swipe count (see the buffer caveat below)
   so the log stays readable, capture the driver's stdout to a file, and
   dedupe.
3. Compute `decodeSize / (renderSize × devicePixelRatio)`. A ratio at or
   near 1.0 means the widget is already sizing correctly — there is no
   patch to write. A ratio significantly above 1.0 is your target.
4. If useful, `curl -sI <url>` (or download + inspect headers/dimensions)
   to check the actual network payload size and whether a CDN thumbnail
   transform is even being honored — this is a separate axis from decode
   sizing and can be wrong independently.

**Buffer eviction gotcha**: the Timeline JSON trace only retains a fixed
recent window of engine events — a long scroll session (many swipes) can
silently evict the early portion (e.g. first-load images) by the time you
fetch it. `print()`-based logging via the driver script's stdout is *not*
subject to this — prefer it over the JSON trace when you need to see
everything that loaded, not just what happened in the last few seconds.

## 5. The empirical isolation loop

For each hypothesis (an effect, a widget, a video, a config value):

1. Make the smallest possible temporary edit that isolates the variable —
   an early return, a `if (false && ...)` guard, a hardcoded flag. Prefer
   edits that keep the diff obviously reversible and don't ripple into
   unrelated files.
2. `flutter analyze <touched-file>` — confirm it still compiles before
   spending device time on it.
3. Re-run the harness with the same scenario name pattern (e.g.
   `exp_a_<hypothesis>`) and swipe count as the baseline, on the *same*
   route.
4. Compare worst-raster, missed-frame count, and whichever raw-timeline
   metric (saveLayer count/duration, memory swing) motivated the
   hypothesis, against baseline.
5. `git checkout -- <file>` immediately — before writing up the result,
   before starting the next hypothesis.
6. Record the result in a table (hypothesis / test / result) regardless of
   outcome — a disproven hypothesis is still a finding worth documenting so
   nobody re-investigates it from scratch later.

Expect noise: re-running the *unmodified* baseline twice can itself show a
several-ms and a few-missed-frame swing. Don't read too much into a small
delta; look for an order-of-magnitude change or a metric that goes to zero
before crediting a variant with a real effect.

## 6. Web cross-check (if the app also targets web)

1. Build **release**, not debug — `flutter build web --release` (+ whatever
   `--dart-define`s production requires). Debug web frame times are as
   misleading as debug-mode profiling.
2. Serve the static output with a **SPA-fallback** static server — a plain
   `http.server` 404s on any deep route (`/some/nested/path`) because
   there's no matching file. Override `send_head` (not just `do_GET` — HEAD
   requests bypass a `do_GET`-only override) to fall back to `index.html`
   for any path without a real file, so `page.goto('/deep/route')` works.
3. Drive scroll with synthetic `WheelEvent`s dispatched on
   `document.elementFromPoint(x, y)` (resolves to the Flutter view element)
   via a browser-automation tool (Playwright or similar) — no need to
   enable accessibility, keeps the render path pristine.
4. Probe with a `requestAnimationFrame` delta recorder plus a
   `PerformanceObserver({entryTypes: ['longtask']})`; report
   median/p95/p99/max frame ms and longtask count.
5. To compare a before/after code change on web, build twice from the two
   commits/working-tree-states, serve both on different ports, run the
   identical probe against both. `git checkout <sha> -- <files>` +
   rebuild + `git checkout HEAD -- <files>` + rebuild is fine for this as
   long as you restore the working tree immediately after each build and
   verify with `git status` before moving on.
6. A finding validated on a physical device does not automatically transfer
   to web perf tooling run on a desktop machine — desktop CPU/GPU headroom
   can hide a cost that's very real on a phone-class device. Report this
   caveat explicitly rather than implying the web result generalizes.

## 7. Closing the audit

- Update the project's own jank/perf doc (if one exists) rather than
  leaving findings only in chat history — link commits, include the
  before/after numbers, and clearly separate **fixed bugs** (with commit
  hashes and measured effect) from **ruled-out hypotheses** (with what was
  tested and the result) from **accepted residual issues** (with the most
  likely explanation, even if it's "device/engine characteristic, not
  app-code-fixable").
- Record the reusable methodology itself (this playbook, or a link to it)
  somewhere discoverable, so the next investigation starts from "run the
  harness" instead of re-deriving the whole process.
- Final `git status` should show only the intended commit(s) — no stray
  experimental diffs, no accidental unrelated file changes bundled in.
