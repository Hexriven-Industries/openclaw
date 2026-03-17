#!/usr/bin/env bash
# remote-check-prod.sh — Run prod runtime health checks on the remote host.

set -euo pipefail

REMOTE_HOST="${OPENCLAW_REMOTE_HOST:-}"
if [[ -z "$REMOTE_HOST" ]]; then
  echo "OPENCLAW_REMOTE_HOST is required (example: OPENCLAW_REMOTE_HOST=hexmini.local)." >&2
  exit 64
fi

REMOTE_USER="${OPENCLAW_REMOTE_USER:-$USER}"
REMOTE_ROOT="${OPENCLAW_REMOTE_ROOT:-/Users/${REMOTE_USER}}"
REMOTE_SSH_OPTS="${OPENCLAW_REMOTE_SSH_OPTS:-}"
REMOTE_PATH="${OPENCLAW_REMOTE_PATH:-/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin}"
REMOTE_TARGET="${REMOTE_USER}@${REMOTE_HOST}"
REMOTE_OPENCLAW_DIR="${OPENCLAW_REMOTE_OPENCLAW_DIR:-${REMOTE_ROOT}/Development/openclaw}"
REMOTE_GATEWAY_CTL="${OPENCLAW_REMOTE_GATEWAY_CTL:-${REMOTE_OPENCLAW_DIR}/scripts/gateway-ctl.sh}"

REMOTE_PROD_CONFIG="${REMOTE_ROOT}/Deployments/openclaw-config/prod.json5"
REMOTE_PROD_STATE="${REMOTE_ROOT}/.openclaw"
REMOTE_PROD_BIN="${REMOTE_ROOT}/Deployments/openclaw-prod/dist/index.js"
REMOTE_PROD_PLIST="${REMOTE_ROOT}/Library/LaunchAgents/ai.openclaw.gateway.plist"
REMOTE_NODE_BIN="${OPENCLAW_REMOTE_NODE_BIN:-node}"

run_ssh() {
  local cmd="$1"
  if [[ -n "$REMOTE_SSH_OPTS" ]]; then
    # shellcheck disable=SC2086
    ssh $REMOTE_SSH_OPTS "$REMOTE_TARGET" "export PATH='${REMOTE_PATH}'; ${cmd}"
  else
    ssh "$REMOTE_TARGET" "export PATH='${REMOTE_PATH}'; ${cmd}"
  fi
}

echo "  -> Remote prod gateway status"
run_ssh "OPENCLAW_PROFILE=prod '${REMOTE_GATEWAY_CTL}' prod status"

echo "  -> Remote prod deep status"
run_ssh "PROD_TOKEN=\"\$(/usr/bin/plutil -extract EnvironmentVariables.OPENCLAW_GATEWAY_TOKEN raw -o - '${REMOTE_PROD_PLIST}')\"; OPENCLAW_CONFIG_PATH='${REMOTE_PROD_CONFIG}' OPENCLAW_STATE_DIR='${REMOTE_PROD_STATE}' OPENCLAW_GATEWAY_TOKEN=\"\$PROD_TOKEN\"; if [[ -x '${REMOTE_PROD_BIN}' ]]; then '${REMOTE_PROD_BIN}' status --deep; else '${REMOTE_NODE_BIN}' '${REMOTE_PROD_BIN}' status --deep; fi"

echo "  -> Remote prod channel probe"
run_ssh "PROD_TOKEN=\"\$(/usr/bin/plutil -extract EnvironmentVariables.OPENCLAW_GATEWAY_TOKEN raw -o - '${REMOTE_PROD_PLIST}')\"; OPENCLAW_CONFIG_PATH='${REMOTE_PROD_CONFIG}' OPENCLAW_STATE_DIR='${REMOTE_PROD_STATE}' OPENCLAW_GATEWAY_TOKEN=\"\$PROD_TOKEN\"; if [[ -x '${REMOTE_PROD_BIN}' ]]; then '${REMOTE_PROD_BIN}' channels status --probe; else '${REMOTE_NODE_BIN}' '${REMOTE_PROD_BIN}' channels status --probe; fi"
