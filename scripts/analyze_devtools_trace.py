#!/usr/bin/env python3
"""Extract the high-signal parts of a Chrome DevTools performance trace.

The goal is not to reproduce DevTools. It is to shrink a large trace JSON into
the questions that usually matter for web performance work:
main-thread long tasks, costly scripts, rendering/paint/raster work, network
requests, dropped frames, and Flutter web user-timing spans when present.
"""

from __future__ import annotations

import argparse
import bisect
import collections
import json
import math
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


NOISE_NAMES = {
    "RunTask",
    "v8::Debugger::AsyncTaskRun",
    "v8::Debugger::AsyncTaskScheduled",
    "v8::Debugger::AsyncTaskCanceled",
    "v8.callFunction",
    "ProfileChunk",
    "PipelineReporter",
    "UpdateCounters",
}

INTERESTING_CHILD_NAMES = {
    "EvaluateScript",
    "FunctionCall",
    "TimerFire",
    "FireAnimationFrame",
    "EventDispatch",
    "RunMicrotasks",
    "Layout",
    "UpdateLayoutTree",
    "PrePaint",
    "Paint",
    "CompositeLayers",
    "RasterTask",
    "GPUTask",
    "ResourceSendRequest",
    "ResourceReceiveResponse",
    "ResourceFinish",
    "v8.compile",
    "v8.run",
    "v8.parseOnBackground",
    "v8.parseOnBackgroundParsing",
    "V8.GC_MC_INCREMENTAL",
    "V8.GC_MC_BACKGROUND_SWEEPING",
    "MajorGC",
    "MinorGC",
}

FLUTTER_SPANS = {
    "Animate",
    "BUILD",
    "LAYOUT (root)",
    "PAINT",
    "Frame",
}

RESOURCE_EVENT_NAMES = {"ResourceSendRequest", "ResourceReceiveResponse", "ResourceFinish"}
PAINT_TIMING_NAMES = {"firstPaint", "firstContentfulPaint"}
LCP_NAMES = {"largestContentfulPaint::Candidate", "LargestImagePaint::Candidate"}


def ms(us: float | int | None) -> float:
    return (us or 0) / 1000.0


def fmt_ms(value: float) -> str:
    if value >= 100:
        return f"{value:.0f} ms"
    if value >= 10:
        return f"{value:.1f} ms"
    return f"{value:.2f} ms"


def fmt_score(value: float) -> str:
    return f"{value:.4f}".rstrip("0").rstrip(".") or "0"


def event_data(event: dict[str, Any]) -> dict[str, Any]:
    args = event.get("args") or {}
    data = args.get("data")
    return data if isinstance(data, dict) else args


def event_url(event: dict[str, Any]) -> str:
    data = event_data(event)
    url = data.get("url") or data.get("fileName") or event.get("fileName") or ""
    if not url and isinstance(data.get("initiator"), dict):
        url = data["initiator"].get("url", "")
    return str(url)


def short_url(url: str, max_len: int = 88) -> str:
    if not url:
        return ""
    parsed = urlparse(url)
    if parsed.scheme and parsed.netloc:
        path = parsed.path or "/"
        if parsed.query:
            path += "?" + parsed.query
        label = path
    else:
        label = url
    if len(label) > max_len:
        return "..." + label[-(max_len - 3) :]
    return label


def classify(event: dict[str, Any]) -> str:
    name = event.get("name", "")
    cat = event.get("cat", "")
    if "GC" in name or "gc" in cat or "marking" in name.lower() or "sweeping" in name.lower():
        return "GC"
    if name.startswith("Resource") or "loading" in cat or "URLLoader" in name:
        return "Loading"
    if name in {"EvaluateScript", "FunctionCall", "TimerFire", "FireAnimationFrame", "RunMicrotasks"}:
        return "Scripting"
    if name.startswith("v8.") or name.startswith("V8.") or name in {"ScriptCompiled", "ParseHTML"}:
        return "Scripting"
    if name in {"Layout", "UpdateLayoutTree", "RecalculateStyles", "PrePaint"} or "StyleAndLayout" in name:
        return "Rendering"
    if name in {"Paint", "CompositeLayers", "RasterTask", "GPUTask", "UpdateLayer", "Commit"}:
        return "Paint/Raster/GPU"
    if name == "EventDispatch" or "input" in cat.lower() or any(x in name for x in ("Mouse", "Pointer", "Touch", "Scroll", "Gesture")):
        return "Input"
    if name in FLUTTER_SPANS:
        return "Flutter spans"
    return "Other"


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = (len(ordered) - 1) * pct
    lower = math.floor(index)
    upper = math.ceil(index)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] * (upper - index) + ordered[upper] * (index - lower)


def load_events(path: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        return {}, data
    return data.get("metadata") or {}, data.get("traceEvents") or []


def build_thread_maps(events: list[dict[str, Any]]) -> tuple[dict[int, str], dict[tuple[int, int], str]]:
    processes: dict[int, str] = {}
    threads: dict[tuple[int, int], str] = {}
    for event in events:
        if event.get("ph") != "M":
            continue
        name = event.get("name")
        args = event.get("args") or {}
        if name == "process_name":
            processes[event.get("pid")] = args.get("name", "")
        elif name == "thread_name":
            threads[(event.get("pid"), event.get("tid"))] = args.get("name", "")
    return processes, threads


def find_main_thread(
    events: list[dict[str, Any]],
    processes: dict[int, str],
    threads: dict[tuple[int, int], str],
) -> tuple[int, int] | None:
    for key, name in threads.items():
        pid, _ = key
        if processes.get(pid) == "Renderer" and name == "CrRendererMain":
            return key
    durations = collections.Counter()
    for event in events:
        if event.get("ph") == "X" and event.get("dur"):
            durations[(event.get("pid"), event.get("tid"))] += event.get("dur", 0)
    return durations.most_common(1)[0][0] if durations else None


def update_resource(resources: dict[str, dict[str, Any]], event: dict[str, Any]) -> None:
    name = event.get("name")
    data = event_data(event)
    request_id = data.get("requestId")
    if not request_id:
        return
    item = resources[str(request_id)]
    item["requestId"] = str(request_id)
    if name == "ResourceSendRequest":
        item["start_ts"] = event.get("ts")
        item["url"] = data.get("url", item.get("url", ""))
        item["type"] = data.get("resourceType", item.get("type", ""))
        item["priority"] = data.get("priority", item.get("priority", ""))
    elif name == "ResourceReceiveResponse":
        item["response_ts"] = event.get("ts")
        item["status"] = data.get("statusCode", item.get("status"))
        item["mime"] = data.get("mimeType", item.get("mime", ""))
        item["fromCache"] = data.get("fromCache")
        item["encoded_headers"] = data.get("encodedDataLength", item.get("encoded_headers", 0))
    elif name == "ResourceFinish":
        item["finish_ts"] = event.get("ts")
        item["encoded"] = data.get("encodedDataLength", item.get("encoded", 0))
        item["decoded"] = data.get("decodedBodyLength", item.get("decoded", 0))
        item["failed"] = data.get("didFail", item.get("failed", False))


def finalize_resources(resources: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    summarized = []
    for item in resources.values():
        start = item.get("start_ts")
        finish = item.get("finish_ts") or item.get("response_ts")
        item["duration_ms"] = ms(finish - start) if start and finish else 0
        summarized.append(item)
    return summarized


def pair_async_spans(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    open_spans: dict[tuple[str, str, int, int], dict[str, Any]] = {}
    spans: list[dict[str, Any]] = []
    for event in sorted(events, key=lambda e: e.get("ts", 0)):
        name = event.get("name")
        ph = event.get("ph")
        span_id = event.get("id2", {}).get("local") or event.get("id") or event.get("args", {}).get("traceId")
        key = (str(name), str(span_id), event.get("pid"), event.get("tid"))
        if ph in {"b", "B"}:
            open_spans[key] = event
        elif ph in {"e", "E"} and key in open_spans:
            start = open_spans.pop(key)
            spans.append(
                {
                    "name": name,
                    "ts": start.get("ts", 0),
                    "dur_ms": ms(event.get("ts", 0) - start.get("ts", 0)),
                    "args": start.get("args", {}),
                }
            )
    return spans


def top_children_for_task(
    task: dict[str, Any],
    same_thread_events: list[dict[str, Any]],
    same_thread_timestamps: list[int],
    child_threshold_ms: float,
    limit: int,
) -> list[dict[str, Any]]:
    start = task.get("ts", 0)
    end = start + task.get("dur", 0)
    children = []
    start_index = bisect.bisect_left(same_thread_timestamps, start)
    end_index = bisect.bisect_left(same_thread_timestamps, end)
    for index in range(start_index, end_index):
        event = same_thread_events[index]
        if event is task or event.get("ph") != "X" or not event.get("dur"):
            continue
        dur = ms(event.get("dur"))
        if dur < child_threshold_ms:
            continue
        name = event.get("name", "")
        if name in NOISE_NAMES:
            continue
        if name not in INTERESTING_CHILD_NAMES and classify(event) == "Other":
            continue
        children.append(
            {
                "name": name,
                "dur_ms": dur,
                "category": classify(event),
                "url": short_url(event_url(event), 70),
                "detail": child_detail(event),
            }
        )
    return sorted(children, key=lambda item: item["dur_ms"], reverse=True)[:limit]


def layout_shift_score(event: dict[str, Any]) -> float:
    data = event_data(event)
    return float(data.get("weighted_score_delta", data.get("score", 0)) or 0)


def calculate_cls(shifts: list[tuple[int, float]]) -> float:
    if not shifts:
        return 0.0
    ordered = sorted(shifts)
    best = 0.0
    for start_index, (start_ts, _) in enumerate(ordered):
        score = 0.0
        previous_ts = start_ts
        for ts, value in ordered[start_index:]:
            if ts - start_ts > 5_000_000 or ts - previous_ts > 1_000_000:
                break
            score += value
            best = max(best, score)
            previous_ts = ts
    return best


def detect_flutter_debug(resources: list[dict[str, Any]]) -> str | None:
    script_urls = [str(item.get("url", "")) for item in resources if item.get("type") == "Script"]
    dart_lib_count = sum(".dart.lib.js" in url for url in script_urls)
    has_dart_sdk = any(url.endswith("/dart_sdk.js") or "dart_sdk.js" in url for url in script_urls)
    largest_script = max((int(item.get("decoded", 0) or 0) for item in resources if item.get("type") == "Script"), default=0)
    if has_dart_sdk and dart_lib_count >= 10 and largest_script > 5 * 1024 * 1024:
        return (
            "Trace likely captured Flutter web debug/DDC output: many `.dart.lib.js` modules, "
            "`dart_sdk.js`, and very large unminified scripts. Prefer a profile/release web trace "
            "before treating JS compile/evaluate cost as an application regression."
        )
    return None


def child_detail(event: dict[str, Any]) -> str:
    data = event_data(event)
    if event.get("name") == "EventDispatch":
        return data.get("type", "")
    if event.get("name") == "FunctionCall":
        fn = data.get("functionName", "")
        line = data.get("lineNumber")
        return f"{fn}:{line}" if fn and line is not None else fn
    if event.get("name") == "Layout":
        begin = event.get("args", {}).get("beginData", {})
        dirty = begin.get("dirtyObjects")
        total = begin.get("totalObjects")
        return f"dirty={dirty} total={total}" if dirty is not None else ""
    return ""


def make_report(args: argparse.Namespace) -> str:
    trace_path = Path(args.trace)
    metadata, events = load_events(trace_path)
    processes, threads = build_thread_maps(events)
    main_thread = find_main_thread(events, processes, threads)

    min_ts = None
    max_ts = None
    main_events: list[dict[str, Any]] = []
    long_tasks: list[dict[str, Any]] = []
    resource_map: dict[str, dict[str, Any]] = collections.defaultdict(dict)
    grouped = collections.defaultdict(float)
    by_name = collections.defaultdict(float)
    dropped_frame_count = 0
    flutter_span_events: list[dict[str, Any]] = []
    paint_timings: dict[str, int] = {}
    lcp_candidates: list[dict[str, Any]] = []
    layout_shift_count = 0
    layout_shift_recent_input_count = 0
    layout_shift_scores: list[tuple[int, float]] = []

    for event in events:
        name = event.get("name", "")
        ts = event.get("ts")
        if isinstance(ts, int) and ts > 0 and event.get("ph") != "M":
            min_ts = ts if min_ts is None else min(min_ts, ts)
            max_ts = ts if max_ts is None else max(max_ts, ts)

        if name in RESOURCE_EVENT_NAMES:
            update_resource(resource_map, event)
        elif name == "DroppedFrame":
            dropped_frame_count += 1
        elif name in FLUTTER_SPANS:
            flutter_span_events.append(event)
        elif name in PAINT_TIMING_NAMES and isinstance(ts, int):
            paint_timings.setdefault(name, ts)
        elif name in LCP_NAMES and isinstance(ts, int):
            data = event_data(event)
            lcp_candidates.append(
                {
                    "name": name,
                    "ts": ts,
                    "node": data.get("nodeName", ""),
                    "type": data.get("type", ""),
                    "size": data.get("size", 0),
                }
            )
        elif name == "LayoutShift":
            layout_shift_count += 1
            data = event_data(event)
            if data.get("had_recent_input"):
                layout_shift_recent_input_count += 1
            elif isinstance(ts, int):
                layout_shift_scores.append((ts, layout_shift_score(event)))

        if event.get("ph") != "X" or not event.get("dur"):
            continue
        if not main_thread or (event.get("pid"), event.get("tid")) != main_thread:
            continue
        main_events.append(event)
        if name == "RunTask" and ms(event.get("dur")) >= args.long_task_ms:
            long_tasks.append(event)
        if name in NOISE_NAMES:
            continue
        grouped[classify(event)] += ms(event.get("dur"))
        by_name[name] += ms(event.get("dur"))

    min_ts = min_ts or 0
    max_ts = max_ts or 0
    breadcrumb = (metadata.get("modifications") or {}).get("initialBreadcrumb", {}).get("window", {})
    window_min = breadcrumb.get("min", min_ts)
    window_max = breadcrumb.get("max", max_ts)

    long_tasks = sorted(long_tasks, key=lambda event: event.get("dur", 0), reverse=True)

    resources = finalize_resources(resource_map)
    slow_resources = sorted(resources, key=lambda item: item.get("duration_ms", 0), reverse=True)[: args.top]
    heavy_resources = sorted(resources, key=lambda item: item.get("decoded", 0), reverse=True)[: args.top]

    flutter_spans = pair_async_spans(flutter_span_events)
    flutter_by_name: dict[str, list[float]] = collections.defaultdict(list)
    for span in flutter_spans:
        flutter_by_name[span["name"]].append(span["dur_ms"])
    cls = calculate_cls(layout_shift_scores)
    lcp = max(lcp_candidates, key=lambda item: item.get("ts", 0), default=None)
    diagnosis_hint = detect_flutter_debug(resources)

    lines: list[str] = []
    lines.append(f"# DevTools Trace Summary: {trace_path.name}")
    lines.append("")
    lines.append(f"- Source: {metadata.get('source', 'unknown')}")
    lines.append(f"- Start time: {metadata.get('startTime', 'unknown')}")
    lines.append(f"- Emulated device: {metadata.get('emulatedDeviceTitle', 'unknown')}")
    lines.append(f"- Events: {len(events):,}")
    lines.append(f"- Trace duration: {fmt_ms(ms(max_ts - min_ts))}")
    lines.append(f"- Selected DevTools window: {fmt_ms(ms(window_max - window_min))}")
    if main_thread:
        pid, tid = main_thread
        lines.append(f"- Main thread: pid={pid} tid={tid} {processes.get(pid, '?')}/{threads.get(main_thread, '?')}")
    lines.append(f"- Dropped frames: {dropped_frame_count:,}")
    lines.append("")

    if diagnosis_hint:
        lines.append("## Diagnosis hints")
        lines.append(f"- {diagnosis_hint}")
        lines.append("")

    lines.append("## Main-thread cost, inclusive")
    if grouped:
        for name, total in sorted(grouped.items(), key=lambda item: item[1], reverse=True):
            lines.append(f"- {name}: {fmt_ms(total)}")
    else:
        lines.append("- No main-thread slices found.")
    lines.append("")

    lines.append("## Top main-thread event names")
    for name, total in sorted(by_name.items(), key=lambda item: item[1], reverse=True)[: args.top]:
        lines.append(f"- {name}: {fmt_ms(total)}")
    lines.append("")

    lines.append(f"## Long tasks >= {fmt_ms(args.long_task_ms)}")
    if not long_tasks:
        lines.append("- None.")
    same_thread_sorted = sorted(main_events, key=lambda event: event.get("ts", 0))
    same_thread_timestamps = [event.get("ts", 0) for event in same_thread_sorted]
    for index, task in enumerate(long_tasks[: args.top], 1):
        offset = ms(task.get("ts", 0) - window_min)
        lines.append(f"{index}. {fmt_ms(ms(task.get('dur')))} at +{fmt_ms(offset)}")
        for child in top_children_for_task(task, same_thread_sorted, same_thread_timestamps, args.child_ms, args.child_top):
            suffix = " ".join(x for x in [child["url"], child["detail"]] if x)
            lines.append(f"   - {child['category']}: {child['name']} {fmt_ms(child['dur_ms'])} {suffix}".rstrip())
    lines.append("")

    lines.append("## UX timings")
    if not paint_timings and not lcp and layout_shift_count == 0:
        lines.append("- No paint timing, LCP, or layout-shift events found.")
    for name in sorted(paint_timings):
        lines.append(f"- {name}: +{fmt_ms(ms(paint_timings[name] - window_min))}")
    if lcp:
        detail = " ".join(str(value) for value in [lcp.get("node"), lcp.get("type")] if value)
        size = int(lcp.get("size", 0) or 0)
        suffix = f" {detail} size={size}" if detail or size else ""
        lines.append(f"- LCP candidate: +{fmt_ms(ms(lcp['ts'] - window_min))}{suffix}")
    if layout_shift_count:
        included = layout_shift_count - layout_shift_recent_input_count
        lines.append(
            f"- CLS estimate: {fmt_score(cls)} "
            f"({included} shifts counted, {layout_shift_recent_input_count} ignored after recent input)"
        )
    lines.append("")

    lines.append("## Flutter web spans")
    if not flutter_by_name:
        lines.append("- No Flutter user-timing spans found.")
    for name, values in sorted(flutter_by_name.items()):
        lines.append(
            f"- {name}: count={len(values)}, total={fmt_ms(sum(values))}, "
            f"p50={fmt_ms(percentile(values, 0.50))}, p95={fmt_ms(percentile(values, 0.95))}, "
            f"max={fmt_ms(max(values))}"
        )
    lines.append("")

    lines.append("## Slowest resources")
    if not slow_resources:
        lines.append("- None.")
    for item in slow_resources:
        lines.append(
            f"- {fmt_ms(item.get('duration_ms', 0))} "
            f"{item.get('status', '?')} {item.get('type', '')} "
            f"{item.get('decoded', 0) / 1024:.1f} KiB {short_url(item.get('url', ''))}"
        )
    lines.append("")

    lines.append("## Largest resources")
    if not heavy_resources:
        lines.append("- None.")
    for item in heavy_resources:
        lines.append(
            f"- {item.get('decoded', 0) / 1024:.1f} KiB "
            f"{fmt_ms(item.get('duration_ms', 0))} "
            f"{item.get('status', '?')} {item.get('type', '')} {short_url(item.get('url', ''))}"
        )
    lines.append("")

    lines.append("## What to ignore")
    lines.append("- DevTools/debugger wrapper events such as `v8::Debugger::*`, `RunTask`, `ProfileChunk`.")
    lines.append("- Background parse/compile events unless they align with a user-visible long task.")
    lines.append("- Inclusive category totals as exact accounting; nested trace slices overlap by design.")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", help="Path to the DevTools performance trace JSON")
    parser.add_argument("--top", type=int, default=12, help="Number of rows per section")
    parser.add_argument("--long-task-ms", type=float, default=50, help="Long task threshold")
    parser.add_argument("--child-ms", type=float, default=5, help="Minimum child slice duration shown inside a long task")
    parser.add_argument("--child-top", type=int, default=5, help="Number of child slices shown per long task")
    parser.add_argument("--report", type=Path, help="Write markdown report to this path")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    report = make_report(args)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(report + "\n", encoding="utf-8")
    print(report)


if __name__ == "__main__":
    main()
