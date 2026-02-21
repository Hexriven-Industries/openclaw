# OpenClaw Config Repo Template

This folder is a starter template for a separate git repo such as:

- `~/Deployments/openclaw-config`

Use that repo as the source of truth for environment config, and keep runtime
state in per-environment state dirs (`~/.openclaw`, `~/.openclaw-dev`) untracked.

## Layout

- `base.json5`: shared defaults for all environments
- `dev.json5`: dev entrypoint config (`$include` + dev overrides)
- `prod.json5`: prod entrypoint config (`$include` + prod overrides)
- `overrides/*.local.example.json5`: local-only override examples
- `release-config-review-template.md`: release drift decision checklist

## Recommended runtime wiring

- Prod:
  - `OPENCLAW_CONFIG_PATH=~/Deployments/openclaw-config/prod.json5`
  - `OPENCLAW_STATE_DIR=~/.openclaw`
- Dev:
  - `OPENCLAW_CONFIG_PATH=~/Deployments/openclaw-config/dev.json5`
  - `OPENCLAW_STATE_DIR=~/.openclaw-dev`

## Guardrails

- Keep secrets in environment variables or untracked local override files.
- Do not commit runtime state (`sessions`, `credentials`, `memory`, caches).
- Prefer PR-style edits to config files over ad-hoc runtime changes.

## Optional drift check on release merges

From the OpenClaw source repo:

```bash
./scripts/config-surface-diff.sh v2026.2.18 v2026.2.19
```

Use output to update `release-config-review-template.md` in your config repo.
