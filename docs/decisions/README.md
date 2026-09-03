# Architecture Decision Records (ADRs)

Short records of significant, hard-to-reverse decisions, so agents and new
contributors don't re-litigate settled choices. See [ARCHITECTURE.md](../../ARCHITECTURE.md)
for the layout and [CLAUDE.md](../../CLAUDE.md) for conventions.

| ADR | Decision | Status |
|---|---|---|
| [001](adr-001-riverpod.md) | Riverpod for state management & DI | Accepted |
| [002](adr-002-pocketbase.md) | PocketBase as the backend (BaaS) | Accepted |
| [003](adr-003-cms-section-model.md) | CMS-driven, data-first storefront | Accepted |

> Note on provenance: these ADRs were reconstructed from the codebase, not from a
> recorded decision log. The **Decision** and **Consequences** are verifiable in
> the code; where the original **rationale/alternatives** were not documented
> anywhere in the repo, that is stated explicitly rather than guessed. If you have
> the real context, fill it in.
