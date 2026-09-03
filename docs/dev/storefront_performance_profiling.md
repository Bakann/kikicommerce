# Storefront Performance Profiling

Use this checklist before changing rendering strategy on landing, PLP, PDP, or
CMS grid surfaces. The goal is to capture repeatable evidence before adding
caps, lazy builders, route caches, or layout rewrites.

For shader-heavy animations, also apply
[`shader_animation_performance.md`](shader_animation_performance.md) before
coding the effect.

## Build

- Run in Flutter profile mode on a physical mid-tier mobile device first.
- Keep the same seed data, network, locale, and storefront theme across runs.
- Record both cold app start and warm in-app navigation.

## Scenarios

- Landing `/`: first paint, theme switch, drawer open/close.
- Sport landing `/sport/homme`: scroll through hero, mixed grid, and product
  tiles.
- Category PLP `/catalog/<slug>` and `/sport/<segment>/<slug>`: push from a CMS
  tile, scroll one viewport at a time, open PDP, then back.
- PDP `/catalog/<slug>/<product-slug>`: hero transition, image gallery scroll,
  add-to-cart top sheet.
- Search `/search?q=<term>`: initial query, sort change, pagination.

## Metrics

- Frame build/raster times from Flutter DevTools timeline.
- Longest jank span and count of frames over 16 ms and 32 ms.
- Image decode/upload spikes and repeated network image fetches.
- Provider recomputation count for PLP, PDP, drawer navigation, and CMS grid
  providers.
- Memory before/after a full scenario loop, especially image cache growth.

## Capture

- Save a DevTools timeline export per scenario.
- Note device, OS, Flutter version, build commit, data snapshot, and route.
- Include a screen recording when visual symptoms are visible.
- Compare three runs and use the median before/after value.

## Change Gate

- Do not add MixedGrid caps, route-level caches, or eager/lazy rewrites without
  a baseline and a before/after capture.
- Prefer fixes that remove duplicate work or expensive rebuilds shown in the
  trace over broad UI rewrites.
- Keep screenshots or timeline exports linked from the PR so regressions can be
  re-profiled.
