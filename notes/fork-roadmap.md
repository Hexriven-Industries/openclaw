# OpenClaw Fork Roadmap (Working Doc)

Last updated: 2026-03-07
Owner: Hexriven + Codex
Purpose: durable in-repo tracker for in-flight work, sequencing, and checkpoints.

## Current Direction

- Pause net-new Smartdust integration changes in OpenClaw until upstream catch-up lands.
- Pivot to migration-first strategy: stand up new Mac mini M4 Ultra host on latest upstream stable, then restore Clawdy capability with safe defaults.
- Avoid further deep policy surgery on current Prod host; treat it as temporary service continuity only.

## In Flight

### A) Upstream Catch-Up

Status: completed

- Target landed: upstream stable line promoted into `development`.
- New baseline branch: `development`
- Promotion result:
  - Dev deploy succeeds from `development`
  - core chat works
  - `/new` works
  - `nano-banana-pro` works in Dev
  - async MEDIA swallow bug fixed
  - duplicate-attachment seams fixed
  - structured recall lane is functional enough for follow-on work
- Remaining work here is quality tuning, not baseline integration.

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
- OpenClaw baseline upgrade is now complete.
- Resume only after:
  - Dev burn-in on the new `development` baseline,
  - M4 migration planning is concrete,
  - tool/worker policy direction is stable.
- Re-entry criteria:
  - OpenClaw catch-up complete,
  - policy rebalance implemented and tested in Dev,
  - callback/tool-agent boundaries locked.

## Operational Guardrails

- Never change Prod first for major policy/runtime changes.
- Keep all migration steps checklist-driven and reversible.
- Keep backup verification explicit (artifact existence + size + timestamp).
- Prefer small, auditable commits over large mixed change sets.

## Current Baseline

- `development` is now the active fork baseline.
- Dev is running from `development`.
- Prod remains untouched in this promotion cycle.
- The following Dev workstreams are complete enough:
  - durable `nano-banana-pro` exposure
  - async MEDIA promotion fix
  - duplicate-attachment fixes
  - structured recall routing improvement
  - post-promotion `nano-banana-pro` anti-shell-debug guidance

## Next Active Priorities (Ordered)

1. Let Dev burn in on `development` and only fix clear regressions.
2. Finalize the M4 Ultra migration checklist and cutover plan.
3. Stand up the new Mac mini M4 Ultra host baseline (OS, runtime, OpenClaw latest stable).
4. Install fresh OpenClaw on the new host from upstream (no legacy config sludge by default).
5. Migrate Clawdy workspace/state needed for continuity; do not blindly import old policy baggage or custom guard plugins.
6. Reconnect Obsidian/vault access and confirm memory continuity.
7. Re-establish "safe but useful" defaults and validate with the canary checklist.
8. Add reliability watchdog + UI asset verification on the new host.
9. Run controlled cutover from current Prod to the new host with rollback plan.
10. Resume Smartdust and deeper worker/tool-agent design only after the new baseline is stable.

## Open Questions

- Exact minimum viable policy that restores Clawdy productivity without reintroducing prior abuse paths.
- Whether upstream secure credential refinements can reduce 1Password dependency in this setup.
- Best structure for worker/tool agent pattern in native OpenClaw before deeper Smartdust coupling.
- Exact state subset to migrate vs regenerate on the new host (sessions, memories, credentials, cron definitions).
