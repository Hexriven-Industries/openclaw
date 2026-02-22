#!/usr/bin/env bash
# remote-deploy-config-dev.sh — Sync openclaw-config repo to remote and render/apply dev config there.
#
# Usage:
#   OPENCLAW_REMOTE_HOST=hexmini.local ./scripts/remote-deploy-config-dev.sh
#   OPENCLAW_REMOTE_HOST=hexmini.local ./scripts/remote-deploy-config-dev.sh --restart
#
# Required env:
#   OPENCLAW_REMOTE_HOST         SSH host (or host alias) for the runtime machine.
#
# Optional env:
#   OPENCLAW_REMOTE_USER         SSH user (defaults to current $USER)
#   OPENCLAW_REMOTE_ROOT         Remote home root (default: /Users/<user>)
#   OPENCLAW_REMOTE_CONFIG_DIR   Remote config repo path (default: <root>/Development/openclaw-config)
#   OPENCLAW_REMOTE_DEV_BIN      Remote dev runtime bin (default: <root>/Deployments/openclaw-dev/dist/index.js)
#   OPENCLAW_REMOTE_SSH_OPTS     Extra ssh options

set -euo pipefail

REMOTE_HOST="${OPENCLAW_REMOTE_HOST:-}"
if [[ -z "$REMOTE_HOST" ]]; then
  echo "OPENCLAW_REMOTE_HOST is required (example: OPENCLAW_REMOTE_HOST=hexmini.local)." >&2
  exit 64
fi

REMOTE_USER="${OPENCLAW_REMOTE_USER:-$USER}"
REMOTE_ROOT="${OPENCLAW_REMOTE_ROOT:-/Users/${REMOTE_USER}}"
REMOTE_CONFIG_DIR="${OPENCLAW_REMOTE_CONFIG_DIR:-${REMOTE_ROOT}/Development/openclaw-config}"
REMOTE_DEV_BIN="${OPENCLAW_REMOTE_DEV_BIN:-${REMOTE_ROOT}/Deployments/openclaw-dev/dist/index.js}"
REMOTE_SSH_OPTS="${OPENCLAW_REMOTE_SSH_OPTS:-}"
REMOTE_TARGET="${REMOTE_USER}@${REMOTE_HOST}"
LOCAL_CONFIG_DIR="${OPENCLAW_LOCAL_CONFIG_DIR:-${HOME}/Development/openclaw-config}"

if [[ ! -d "$LOCAL_CONFIG_DIR" ]]; then
  echo "Local config repo not found: $LOCAL_CONFIG_DIR" >&2
  exit 1
fi

PASS_ARGS=("$@")

run_ssh() {
  if [[ -n "$REMOTE_SSH_OPTS" ]]; then
    # shellcheck disable=SC2086
    ssh $REMOTE_SSH_OPTS "$REMOTE_TARGET" "$@"
  else
    ssh "$REMOTE_TARGET" "$@"
  fi
}

echo "  -> Syncing config repo to ${REMOTE_TARGET}:${REMOTE_CONFIG_DIR}"
RSYNC_RSH="ssh${REMOTE_SSH_OPTS:+ $REMOTE_SSH_OPTS}" \
  rsync -az --delete \
    --exclude '.git/' \
    --exclude '.DS_Store' \
    "${LOCAL_CONFIG_DIR}/" "${REMOTE_TARGET}:${REMOTE_CONFIG_DIR}/"

REMOTE_CMD="cd '${REMOTE_CONFIG_DIR}' && OPENCLAW_BIN='${REMOTE_DEV_BIN}' ./scripts/deploy-config.sh dev"
for arg in "${PASS_ARGS[@]}"; do
  REMOTE_CMD+=" '$(printf "%s" "$arg" | sed "s/'/'\\''/g")'"
done

echo "  -> Running remote dev config deploy"
run_ssh "$REMOTE_CMD"
