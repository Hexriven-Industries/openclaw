# OpenClaw Fork Roadmap (Working Doc)

Last updated: 2026-02-27
Owner: Hexriven + Codex
Purpose: durable in-repo tracker for in-flight work, sequencing, and checkpoints.

## Current Direction

- Pause net-new Smartdust integration changes in OpenClaw until upstream catch-up lands.
- Catch up fork to latest upstream stable and re-baseline policies for utility + safety.
- Keep Prod stable; make risky changes in Dev first with explicit canary checks.

## In Flight

### A) Upstream Catch-Up

Status: planned (next major workstream)

- Target version: latest upstream stable tag at execution time (currently seen as `v2026.2.26`; verify before starting).
- Baseline objective: merge/rebase `development` onto upstream stable and resolve fork deltas cleanly.
- Exit criteria:
  - Dev deploy succeeds.
  - Core chat + `/new` + exec approvals + `/vc` pass canary.
  - No critical security regressions in `status --deep` / `security audit --deep`.

### B) Policy Rebalance (Clawdy usability)

Status: active concern; implementation pending catch-up

- Problem: current restrictions reduce utility too far (high friction for normal workflows).
- Intent:
  - keep strong guardrails for dangerous exec paths,
  - reduce approval friction for low-risk/reasonable workflows,
  - preserve auditability and approval visibility.
- Candidate shape:
  - maintain exec approvals for high-risk commands,
  - reduce blanket blocking where safe,
  - keep worker pattern available for heavy tools and long-running jobs.

### C) Prod Reliability

Status: partially mitigated, needs hardening follow-up

- Backup incident: missed nightly run occurred; manual recovery run completed on 2026-02-27.
- Cron behavior and approval interactions need simplification so routine jobs do not stall.
- Keep rollout discipline:
  - Dev validation first,
  - then Prod apply,
  - then immediate post-deploy verification.

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
3. Build integration branch from `development`.
4. Resolve merge/rebase conflicts with tests per subsystem touched.
5. Deploy to Dev and run canary checklist (chat/new/exec/vc/cron/backup smoke).
6. Rebalance policy knobs in Dev for usability while preserving high-risk gating.
7. Record final Dev settings as desired-state config.
8. Run Prod preflight checklist (including backups and rollback paths).
9. Apply Prod changes in one controlled window.
10. Document post-migration status and reopen Smartdust phase.

## Open Questions

- Exact minimum viable policy that restores Clawdy productivity without reintroducing prior abuse paths.
- Whether upstream secure credential refinements can reduce 1Password dependency in this setup.
- Best structure for worker/tool agent pattern in native OpenClaw before deeper Smartdust coupling.
