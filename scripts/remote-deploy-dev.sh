#!/usr/bin/env bash
# remote-deploy-dev.sh — Sync local openclaw source to a remote host and run dev deploy there.
#
# Usage:
#   OPENCLAW_REMOTE_HOST=hexmini.local ./scripts/remote-deploy-dev.sh
#   OPENCLAW_REMOTE_HOST=hexmini.local ./scripts/remote-deploy-dev.sh --skip-build
#   OPENCLAW_REMOTE_HOST=hexmini.local ./scripts/remote-deploy-dev.sh --skip-sync --no-restart
#
# Required env:
#   OPENCLAW_REMOTE_HOST         SSH host (or host alias) for the runtime machine.
#
# Optional env:
#   OPENCLAW_REMOTE_USER         SSH user (defaults to current $USER)
#   OPENCLAW_REMOTE_ROOT         Remote home root (default: /Users/<user>)
#   OPENCLAW_REMOTE_OPENCLAW_DIR Remote source repo path (default: <root>/Development/openclaw)
#   OPENCLAW_REMOTE_SSH_OPTS     Extra ssh options (example: "-i ~/.ssh/id_ed25519")

set -euo pipefail

REMOTE_HOST="${OPENCLAW_REMOTE_HOST:-}"
if [[ -z "$REMOTE_HOST" ]]; then
  echo "OPENCLAW_REMOTE_HOST is required (example: OPENCLAW_REMOTE_HOST=hexmini.local)." >&2
  exit 64
fi

REMOTE_USER="${OPENCLAW_REMOTE_USER:-$USER}"
REMOTE_ROOT="${OPENCLAW_REMOTE_ROOT:-/Users/${REMOTE_USER}}"
REMOTE_OPENCLAW_DIR="${OPENCLAW_REMOTE_OPENCLAW_DIR:-${REMOTE_ROOT}/Development/openclaw}"
REMOTE_SSH_OPTS="${OPENCLAW_REMOTE_SSH_OPTS:-}"
REMOTE_TARGET="${REMOTE_USER}@${REMOTE_HOST}"

SKIP_SYNC=0
PASS_ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--skip-sync" ]]; then
    SKIP_SYNC=1
  else
    PASS_ARGS+=("$arg")
  fi
done

run_ssh() {
  if [[ -n "$REMOTE_SSH_OPTS" ]]; then
    # shellcheck disable=SC2086
    ssh $REMOTE_SSH_OPTS "$REMOTE_TARGET" "$@"
  else
    ssh "$REMOTE_TARGET" "$@"
  fi
}

if [[ "$SKIP_SYNC" -ne 1 ]]; then
  echo "  -> Syncing source to ${REMOTE_TARGET}:${REMOTE_OPENCLAW_DIR}"
  RSYNC_RSH="ssh${REMOTE_SSH_OPTS:+ $REMOTE_SSH_OPTS}" \
    rsync -az --delete \
      --exclude '.git/' \
      --exclude 'node_modules/' \
      --exclude 'dist/' \
      --exclude '.DS_Store' \
      --exclude '.turbo/' \
      --exclude '.cache/' \
      ./ "${REMOTE_TARGET}:${REMOTE_OPENCLAW_DIR}/"
fi

REMOTE_DEPLOY_CMD="cd '${REMOTE_OPENCLAW_DIR}' && ./scripts/deploy-dev.sh"
for arg in "${PASS_ARGS[@]}"; do
  REMOTE_DEPLOY_CMD+=" '$(printf "%s" "$arg" | sed "s/'/'\\''/g")'"
done

echo "  -> Running remote dev deploy"
run_ssh "$REMOTE_DEPLOY_CMD"

echo "  -> Remote gateway status"
run_ssh "OPENCLAW_PROFILE=dev gateway-ctl dev status"
