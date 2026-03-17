# Post-Promotion Status — 2026-03-07

Purpose: short handoff snapshot after promoting the upstream integration branch into `development`.

## Baseline

- `development` is now the active baseline branch.
- Promotion source was `codex/upstream-v2026.2.26-integration`.
- Prod / `main` were not touched.

## Dev State

- Dev is deployed from `development`.
- Core smoke is green enough for baseline promotion:
  - basic Discord chat works
  - `/new` works
  - `nano-banana-pro` works
  - structured recall no longer defaults to exec approval hell for the tested repro

## Key Completed Fixes

- durable Dev `nano-banana-pro` credential wiring
- async MEDIA result promotion
- single-image duplicate-attachment fix
- multi-image narrated-gallery duplicate-attachment fix
- memory tool registration in the main tool factory
- structured recall routing guidance
- post-promotion `nano-banana-pro` guidance tweak to discourage shell-debugging

## Notably Unchanged

- Prod policy/runtime were not changed here.
- `main` was not changed here.
- M4 Ultra migration has not started yet.

## Remaining Work Type

The remaining work is follow-on quality work, not integration blocking work:

- Dev burn-in
- M4 migration planning
- reliability hardening on the future host
- deeper worker/tool-agent design
- optional recall-quality refinement

## Operator Note

If a new Codex session picks up here, start from:

1. verify Dev is still healthy on `development`
2. use the roadmap in `/Users/ehrenweerheim/Development/openclaw/notes/fork-roadmap.md`
3. prioritize the M4 Ultra migration plan before reopening broader experimentation
