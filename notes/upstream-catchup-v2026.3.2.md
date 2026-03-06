# Upstream Catch-Up Plan (v2026.3.2)

Last updated: 2026-03-05
Working branch: `codex/upstream-v2026.2.26-integration` (name retained; target updated in-place)
Base branch: `development`
Pinned upstream target: `v2026.3.2`

## Baseline Snapshot

- `upstream/main` currently resolves to tag: `v2026.3.2`
- `development` currently resolves to tag: `v2026.2.21`
- Divergence at snapshot time:
  - behind: `development..upstream/main` = `3930` commits
  - ahead: `upstream/main..development` = `106` commits

## Execution Sequence

1. Generate focused compare checkpoints by subsystem:
   - config/policy
   - discord/channel
   - exec approvals/security
   - voice
   - docs/tooling
2. Integrate upstream changes in small batches on this branch.
3. After each batch:
   - run targeted tests for touched areas
   - run typecheck/build gates
4. Deploy integrated build to Dev only.
5. Run Dev canary:
   - chat mention response
   - `/new`
   - exec approval flow
   - `/vc` join/status/leave
   - backup/cron smoke
6. Only after canary pass: prep Prod preflight and rollout plan.

## Guardrails

- No direct Prod changes during catch-up branch integration.
- Keep Smartdust integration paused during catch-up.
- Resolve conflicts with minimal behavior drift; preserve fork-specific intent where still needed.
