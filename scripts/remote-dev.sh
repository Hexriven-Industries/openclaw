#!/usr/bin/env bash
# remote-dev.sh — Human-friendly wrapper for Dev remote workflows.
#
# Usage:
#   ./scripts/remote-dev.sh set-host <host> [user]
#   ./scripts/remote-dev.sh show
#   ./scripts/remote-dev.sh deploy [args passed to remote-deploy-dev.sh]
#   ./scripts/remote-dev.sh config [args passed to remote-deploy-config-dev.sh]
#   ./scripts/remote-dev.sh check
#
# Defaults are loaded from:
#   ${OPENCLAW_REMOTE_DEV_ENV_FILE:-$HOME/.openclaw-remote-dev.env}
#
# Example env file contents:
#   OPENCLAW_REMOTE_HOST=hexmini.local
#   OPENCLAW_REMOTE_USER=ehrenweerheim
#   OPENCLAW_REMOTE_ROOT=/Users/ehrenweerheim
#   # optional:
#   # OPENCLAW_REMOTE_SSH_OPTS=-i ~/.ssh/id_ed25519

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${OPENCLAW_REMOTE_DEV_ENV_FILE:-$HOME/.openclaw-remote-dev.env}"

load_env_file() {
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  fi
}

usage() {
  cat <<USAGE
Usage:
  ./scripts/remote-dev.sh set-host <host> [user]
  ./scripts/remote-dev.sh show
  ./scripts/remote-dev.sh deploy [deploy args]
  ./scripts/remote-dev.sh config [config deploy args]
  ./scripts/remote-dev.sh check

Examples:
  ./scripts/remote-dev.sh set-host hexmini.local ehrenweerheim
  ./scripts/remote-dev.sh deploy --skip-build
  ./scripts/remote-dev.sh config
  ./scripts/remote-dev.sh check
USAGE
}

require_host() {
  if [[ -z "${OPENCLAW_REMOTE_HOST:-}" ]]; then
    echo "Remote host not configured." >&2
    echo "Run: ./scripts/remote-dev.sh set-host <host> [user]" >&2
    echo "Or set OPENCLAW_REMOTE_HOST for one command." >&2
    exit 64
  fi
}

cmd_set_host() {
  local host="${1:-}"
  local user="${2:-$USER}"
  if [[ -z "$host" ]]; then
    echo "set-host requires <host>" >&2
    exit 64
  fi

  cat > "$ENV_FILE" <<ENV
OPENCLAW_REMOTE_HOST=$host
OPENCLAW_REMOTE_USER=$user
OPENCLAW_REMOTE_ROOT=/Users/$user
ENV

  chmod 600 "$ENV_FILE"
  echo "Saved remote Dev defaults to $ENV_FILE"
  echo "  OPENCLAW_REMOTE_HOST=$host"
  echo "  OPENCLAW_REMOTE_USER=$user"
}

cmd_show() {
  load_env_file
  echo "ENV file: $ENV_FILE"
  echo "OPENCLAW_REMOTE_HOST=${OPENCLAW_REMOTE_HOST:-<unset>}"
  echo "OPENCLAW_REMOTE_USER=${OPENCLAW_REMOTE_USER:-<unset>}"
  echo "OPENCLAW_REMOTE_ROOT=${OPENCLAW_REMOTE_ROOT:-<unset>}"
  echo "OPENCLAW_REMOTE_OPENCLAW_DIR=${OPENCLAW_REMOTE_OPENCLAW_DIR:-<default>}"
  echo "OPENCLAW_REMOTE_CONFIG_DIR=${OPENCLAW_REMOTE_CONFIG_DIR:-<default>}"
  echo "OPENCLAW_REMOTE_SSH_OPTS=${OPENCLAW_REMOTE_SSH_OPTS:-<unset>}"
}

cmd_deploy() {
  load_env_file
  require_host
  "$SCRIPT_DIR/remote-deploy-dev.sh" "$@"
}

cmd_config() {
  load_env_file
  require_host
  "$SCRIPT_DIR/remote-deploy-config-dev.sh" "$@"
}

cmd_check() {
  load_env_file
  require_host
  "$SCRIPT_DIR/remote-check-dev.sh"
}

subcmd="${1:-}"
if [[ -z "$subcmd" ]]; then
  usage
  exit 64
fi
shift || true

case "$subcmd" in
  set-host)
    cmd_set_host "$@"
    ;;
  show)
    cmd_show
    ;;
  deploy)
    cmd_deploy "$@"
    ;;
  config)
    cmd_config "$@"
    ;;
  check)
    cmd_check
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown subcommand: $subcmd" >&2
    usage
    exit 64
    ;;
esac
