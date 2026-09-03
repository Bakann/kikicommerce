# ADR-001 — Riverpod for state management & DI

**Status:** Accepted (observed throughout the codebase)

## Context

The app needs both state management and dependency injection, shared across the
storefront and the admin backoffice. `flutter_riverpod` (`^3.x`) is the **only**
state/DI library in `pubspec.yaml` — no `provider`, `bloc`, or `get_it`.

## Decision

Use Riverpod for all application state and dependency injection.

- UI-facing providers live in `lib/presentation/providers/`.
- Cross-app wiring (repositories exposed as providers) is in
  `lib/app/app_providers.dart`; the root is a single `ProviderScope` in
  `lib/main.dart` (with launch-time overrides for locale).

## Consequences

- **One state solution only.** Do not introduce Provider / Bloc / GetIt
  alongside it.
- **DI is provider-based.** Repository interfaces (in `application/`) are
  exposed as providers and bound to their `data/` implementations; tests and
  bootstrap override providers rather than passing dependencies by hand.
- **Performance convention:** prefer `provider.select(...)` in heavy trees
  (PDP, checkout, CMS) so a build only re-runs on the slice it consumes — see
  the Riverpod section of [CLAUDE.md](../../CLAUDE.md).

## Rationale

**Widget testability.** Riverpod was chosen primarily because it makes widgets
easy to test: `ProviderScope(overrides: [...])` lets a test swap any repository
or provider for a fake without constructor plumbing or global singletons, so a
widget can be pumped in isolation with controlled state. This keeps the
regression suite cheap to write and maintain (see the `ProviderScope`-based
widget tests under `test/`).

If a migration away from Riverpod is ever considered, weigh it against this
test-ergonomics benefit and raise a new ADR.
