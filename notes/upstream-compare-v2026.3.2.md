# Focused Upstream Compare Set (v2026.3.2)

Last updated: 2026-03-05
Working branch: `codex/upstream-v2026.2.26-integration`
Base branch: `development`
Upstream target: `v2026.3.2`

## Purpose

This note narrows the first integration pass to the subsystems most likely to affect
Clawdy behavior and fork collision risk:

- policy/config
- Discord/channel routing
- exec/security
- voice

## Snapshot

- `development` resolves to `v2026.2.21`
- `upstream/main` resolves to `v2026.3.2`
- divergence at check time:
  - behind: `3930`
  - ahead: `106`

## Fork-Only Collision Zones

These are the fork-specific changes most likely to collide with upstream when we start
rebasing or cherry-picking integration batches:

- Discord voice fixes and tests:
  - `src/discord/voice/command.ts`
  - `src/discord/voice/manager.ts`
  - `src/discord/voice/command.test.ts`
  - `src/discord/voice/manager.test.ts`
- Discord native command diagnostics:
  - `src/discord/monitor/native-command.ts`
  - `src/discord/monitor/native-command.test.ts`
- Discord messaging/tool glue:
  - `src/agents/tools/discord-actions-messaging.ts`
  - `src/agents/tools/message-tool.ts`
  - `src/channels/plugins/actions/discord/handle-action.ts`
- System prompt / sandbox guard edits:
  - `src/agents/system-prompt.ts`
  - `src/agents/pi-embedded-runner/system-prompt.ts`
  - `src/agents/pi-tools.sandbox-mounted-paths.workspace-only.test.ts`
- Local roadmap/docs:
  - `docs/channels/discord.md`
  - `notes/fork-roadmap.md`

## Upstream Areas That Matter Most

### 1. Policy / Config

High-signal upstream changes:

- `dfa0b5b4f` Channels: move single-account config into `accounts.default`
- `64de4b6d6` fix: enforce explicit group auth boundaries across channels
- `051fdcc42` fix(security): centralize dm/group allowlist auth composition
- `cfa44ea6b` fix(security): make `allowFrom` id-only by default with dangerous name opt-in
- `72cf9253f` Gateway: add `SecretRef` support for `gateway.auth.token`
- `806803b7e` feat(secrets): expand `SecretRef` coverage across user-supplied credentials
- large doc/config surface updates in:
  - `docs/gateway/configuration-reference.md`
  - `docs/gateway/secrets.md`
  - `docs/gateway/security/index.md`

Why this matters:

- This directly intersects the permission pain we created in Prod and Dev.
- It also intersects the 1Password/external-secrets path we introduced.
- It likely gives us a cleaner upstream-native way to express some of the hardening we
  previously layered on by hand.

Assessment:

- Highest-value batch to inspect first.
- Likely source of both simplification opportunity and merge conflicts.

### 2. Discord / Channel Routing

High-signal upstream changes:

- `063e493d3` fix: decouple Discord inbound worker timeout from listener timeout
- `b8b1eeb05` fix(discord): harden slash command routing
- `ca307c3fd` fix: harden Discord channel resolution
- `60330e011` fix(discord): log ignored messages from non-allowlisted channels
- `50e2674df` fix(discord): unify dm command auth gating
- `65816657c` feat(discord): add `allowBots` mention gating
- `0eef7a367` fix(discord): honor agent media roots in replies
- `16ebbd24b` fix(discord): reset thread sessions on archive
- `61f7cea48` fix: kill stuck ACP child processes on startup and harden sessions in discord threads

Why this matters:

- Clawdy lives in Discord. This is the highest behavioral risk area after policy.
- Upstream has touched routing, allowlist semantics, slash command behavior, thread
  lifecycle, and timeout behavior since our baseline.
- This area will collide with our forum-thread auth fixes and native command diagnostics.

Assessment:

- Second batch after config/policy primitives.
- Expect real conflict resolution in `src/discord/**`.

### 3. Exec / Security

High-signal upstream changes:

- `7b2b86c60` fix(exec): add approval race changelog and regressions
- `6f0dd6179` fix(exec): restore two-phase approval registration flow
- `4894d907f` refactor(exec-approvals): unify system.run binding and generate host env policy
- `9a4b2266c` fix(security): bind node system.run approvals to env
- `03e689fc8` fix(security): bind system.run approvals to argv identity
- `98b2b16ac` Security/Exec: persist inner commands for shell-wrapper approvals
- `47c3f742b` fix(exec): require explicit safe-bin profiles
- `64b273a71` fix(exec): harden safe-bin trust and add explicit trusted dirs
- `c76a47cce` Exec: fail closed when sandbox host is unavailable
- `1b327da6e` fix: harden exec sandbox fallback semantics
- `223d7dc23` feat(gateway)!: require explicit non-loopback control-ui origins

Why this matters:

- This is directly relevant to Clawdy being too shackled and to cron/approval weirdness.
- Upstream has continued to harden approvals, safe-bin handling, and sandbox fail-closed
  behavior after our current fork baseline.
- This is the likely place to recover sane behavior without reverting to chaos.

Assessment:

- Third batch, but inspect in parallel with config/policy because auth boundaries and
  exec approvals are coupled.

### 4. Voice

High-signal upstream changes:

- `3c6a15ce9` fix(discord): make opus optional and log fallback
- `b0bcea03d` fix: drop discord opus dependency
- `346d3590f` fix(discord): harden voice ffmpeg path and opus fast-path
- `924d9e34e` fix(discord): resample audio to 48kHz for voice messages
- `9cd50c51b` fix(discord): harden voice DAVE receive reliability
- `3b3738e41` fix(discord): use fetch for voice upload slots

Why this matters:

- We already carried local voice fixes to restore `/vc` behavior.
- Upstream has continued to change the underlying voice runtime and dependency story.
- This is a clear collision zone with our fork-only voice manager fixes.

Assessment:

- Fourth batch, after Discord core routing/auth is stable.
- Re-test `/vc join`, `/vc status`, `/vc leave`, and actual speaking after integration.

## Recommended Integration Order

1. Policy/config primitives
2. Discord auth/routing/session behavior
3. Exec approvals and sandbox/security semantics
4. Voice runtime
5. Docs/config examples cleanup after code behavior is settled

## Immediate Next Step

Build a narrower code-level compare for batch 1:

- `src/channels/**`
- `src/security/**`
- `src/agents/bash-tools*`
- config schema / config resolution paths
- `SecretRef` runtime handling

Goal: identify which fork-local permission constraints are now upstream-native, which can
be dropped, and which still require local policy choices.
