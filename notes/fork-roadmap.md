# OpenClaw Fork Roadmap (Working Doc)

Last updated: 2026-03-03
Owner: Hexriven + Codex
Purpose: durable in-repo tracker for in-flight work, sequencing, and checkpoints.

## Current Direction

- Pause net-new Smartdust integration changes in OpenClaw until upstream catch-up lands.
- Pivot to migration-first strategy: stand up new Mac mini M4 Ultra host on latest upstream stable, then restore Clawdy capability with safe defaults.
- Avoid further deep policy surgery on current Prod host; treat it as temporary service continuity only.

## In Flight

### A) Upstream Catch-Up

Status: planned (next major workstream)

- Target version: latest upstream stable tag at execution time (currently seen as `v2026.2.26`; verify before starting).
- Baseline objective: merge/rebase `development` onto upstream stable and resolve fork deltas cleanly.
- Exit criteria:
  - Dev deploy succeeds.
  - Core chat + `/new` + exec approvals + `/vc` pass canary.
  - No critical security regressions in `status --deep` / `security audit --deep`.

### B) Migration-First Rebaseline (M4 Ultra)

Status: approved direction (next major track)

- Goal: reinstall Clawdy on fresh host using latest tagged upstream release and restore "magical + useful" behavior with bounded safety.
- Migration policy:
  - move workspace/state data needed for memory continuity,
  - do not blindly import legacy config hardening/overrides from old host,
  - do not carry custom guard plugins by default (including token-size guard) until proven needed,
  - reintroduce guardrails intentionally from clean baseline.
- Desired outcome:
  - safe enough for production use,
  - low-friction enough to be fun and effective in daily use.

### C) Prod Reliability

Status: partially mitigated, needs hardening follow-up

- Backup incident: missed nightly run occurred; manual recovery run completed on 2026-02-27.
- Discord outage pattern observed on 2026-03-03:
  - repeated DNS failures (`ENOTFOUND gateway-us-east1-c.discord.gg`) causing websocket reconnect storms,
  - process-alive but functionally-degraded behavior.
- Control UI outage observed on 2026-03-03:
  - assets missing at runtime,
  - auto-repair build path failed until deps/lockfile were synced.
- Cron behavior and approval interactions need simplification so routine jobs do not stall.
- Keep rollout discipline:
  - Dev validation first,
  - then Prod apply,
  - then immediate post-deploy verification.
- Reliability actions to implement:
  - add watchdog healthcheck (WS reachable + dashboard HTML + channel probe),
  - auto-restart once on failure, then alert/escalate,
  - add DNS sanity probe classification so external outages are explicit,
  - add UI asset verification gate to deploy flow to prevent dashboard regressions.

## Smartdust Track

Status: paused for OpenClaw upstream catch-up

- Smartdust spec exists and early PRs are merged in `smartdust` repo.
- Resume only after OpenClaw baseline is upgraded and policy model is stable.
- Re-entry criteria:
  - OpenClaw catch-up complete,
  - policy rebalance implemented and tested in Dev,
  - callback/tool-agent boundaries locked.

## Operational Guardrails

- Never change Prod first for major policy/runtime changes.
- Keep all migration steps checklist-driven and reversible.
- Keep backup verification explicit (artifact existence + size + timestamp).
- Prefer small, auditable commits over large mixed change sets.

## Next 10 Actions (Ordered)

1. Snapshot/park current OpenClaw Smartdust WIP on a dedicated branch.
2. Fetch upstream and lock exact target tag for integration.
3. Build integration branch from `development` and complete upstream catch-up.
4. Stand up new Mac mini M4 Ultra host baseline (OS, runtime, OpenClaw latest stable).
5. Install fresh OpenClaw on new host from upstream tag (no fork-specific policy carryover).
6. Migrate Clawdy workspace/state needed for memory continuity; exclude legacy policy baggage/custom guard plugins initially.
7. Configure "safe but usable" defaults on new host and run canary checklist (chat/new/exec/vc/cron/backup smoke).
8. Add reliability watchdog + UI asset gate on new host.
9. Run controlled cutover from old Prod to new host with rollback plan.
10. Document cutover results and reopen Smartdust phase.

## Open Questions

- Exact minimum viable policy that restores Clawdy productivity without reintroducing prior abuse paths.
- Whether upstream secure credential refinements can reduce 1Password dependency in this setup.
- Best structure for worker/tool agent pattern in native OpenClaw before deeper Smartdust coupling.
- Exact state subset to migrate vs regenerate on the new host (sessions, memories, credentials, cron definitions).
