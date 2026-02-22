#!/usr/bin/env bash
# remote-check-dev.sh — Run dev runtime health checks on the remote host.
#
# Usage:
#   OPENCLAW_REMOTE_HOST=hexmini.local ./scripts/remote-check-dev.sh
#
# Required env:
#   OPENCLAW_REMOTE_HOST         SSH host (or host alias) for the runtime machine.
#
# Optional env:
#   OPENCLAW_REMOTE_USER         SSH user (defaults to current $USER)
#   OPENCLAW_REMOTE_ROOT         Remote home root (default: /Users/<user>)
#   OPENCLAW_REMOTE_SSH_OPTS     Extra ssh options

set -euo pipefail

REMOTE_HOST="${OPENCLAW_REMOTE_HOST:-}"
if [[ -z "$REMOTE_HOST" ]]; then
  echo "OPENCLAW_REMOTE_HOST is required (example: OPENCLAW_REMOTE_HOST=hexmini.local)." >&2
  exit 64
fi

REMOTE_USER="${OPENCLAW_REMOTE_USER:-$USER}"
REMOTE_ROOT="${OPENCLAW_REMOTE_ROOT:-/Users/${REMOTE_USER}}"
REMOTE_SSH_OPTS="${OPENCLAW_REMOTE_SSH_OPTS:-}"
REMOTE_TARGET="${REMOTE_USER}@${REMOTE_HOST}"
REMOTE_OPENCLAW_DIR="${OPENCLAW_REMOTE_OPENCLAW_DIR:-${REMOTE_ROOT}/Development/openclaw}"
REMOTE_GATEWAY_CTL="${OPENCLAW_REMOTE_GATEWAY_CTL:-${REMOTE_OPENCLAW_DIR}/scripts/gateway-ctl.sh}"

REMOTE_DEV_CONFIG="${REMOTE_ROOT}/Deployments/openclaw-config/dev.json5"
REMOTE_DEV_STATE="${REMOTE_ROOT}/.openclaw-dev"
REMOTE_DEV_BIN="${REMOTE_ROOT}/Deployments/openclaw-dev/dist/index.js"
REMOTE_DEV_PLIST="${REMOTE_ROOT}/Library/LaunchAgents/ai.openclaw.dev.plist"

run_ssh() {
  if [[ -n "$REMOTE_SSH_OPTS" ]]; then
    # shellcheck disable=SC2086
    ssh $REMOTE_SSH_OPTS "$REMOTE_TARGET" "$@"
  else
    ssh "$REMOTE_TARGET" "$@"
  fi
}

echo "  -> Remote dev gateway status"
run_ssh "OPENCLAW_PROFILE=dev '${REMOTE_GATEWAY_CTL}' dev status"

echo "  -> Remote dev deep status"
run_ssh "DEV_TOKEN=\"\$(/usr/bin/plutil -extract EnvironmentVariables.OPENCLAW_GATEWAY_TOKEN raw -o - '${REMOTE_DEV_PLIST}')\"; OPENCLAW_CONFIG_PATH='${REMOTE_DEV_CONFIG}' OPENCLAW_STATE_DIR='${REMOTE_DEV_STATE}' OPENCLAW_GATEWAY_TOKEN=\"\$DEV_TOKEN\" node '${REMOTE_DEV_BIN}' status --deep"

echo "  -> Remote dev channel probe"
run_ssh "DEV_TOKEN=\"\$(/usr/bin/plutil -extract EnvironmentVariables.OPENCLAW_GATEWAY_TOKEN raw -o - '${REMOTE_DEV_PLIST}')\"; OPENCLAW_CONFIG_PATH='${REMOTE_DEV_CONFIG}' OPENCLAW_STATE_DIR='${REMOTE_DEV_STATE}' OPENCLAW_GATEWAY_TOKEN=\"\$DEV_TOKEN\" node '${REMOTE_DEV_BIN}' channels status --probe"
