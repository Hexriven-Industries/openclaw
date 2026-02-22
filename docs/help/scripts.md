---
summary: "Repository scripts: purpose, scope, and safety notes"
read_when:
  - Running scripts from the repo
  - Adding or changing scripts under ./scripts
title: "Scripts"
---

# Scripts

The `scripts/` directory contains helper scripts for local workflows and ops tasks.
Use these when a task is clearly tied to a script; otherwise prefer the CLI.

## Conventions

- Scripts are **optional** unless referenced in docs or release checklists.
- Prefer CLI surfaces when they exist (example: auth monitoring uses `openclaw models status --check`).
- Assume scripts are host‑specific; read them before running on a new machine.

## Auth monitoring scripts

Auth monitoring scripts are documented here:
[/automation/auth-monitoring](/automation/auth-monitoring)

## Remote host workflows

For MacBook -> host workflows (for example, deploying to a Mac mini over SSH), use:

- `./scripts/remote-dev.sh` for Dev workflows.
- `./scripts/remote-prod.sh` for Prod workflows.

Recommended shortcuts:

```bash
alias rdev='./scripts/remote-dev.sh'
alias rprod='./scripts/remote-prod.sh'
```

One-time host setup:

```bash
rdev set-host <host> <user>
rprod set-host <host> <user>
```

Dev examples:

```bash
rdev check
rdev deploy --skip-build
rdev config
```

Prod examples:

```bash
rprod check
rprod deploy --confirm-prod --skip-build
rprod config --confirm-prod
```

`remote-prod.sh` requires `--confirm-prod` for mutating actions (`deploy`, `config`) as an explicit safety gate.

## When adding scripts

- Keep scripts focused and documented.
- Add a short entry in the relevant doc (or create one if missing).
