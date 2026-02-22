#!/usr/bin/env bash
# remote-prod.sh — Human-friendly wrapper for Prod remote workflows.
#
# Usage:
#   ./scripts/remote-prod.sh set-host <host> [user]
#   ./scripts/remote-prod.sh show
#   ./scripts/remote-prod.sh deploy --confirm-prod [deploy args]
#   ./scripts/remote-prod.sh config --confirm-prod [config deploy args]
#   ./scripts/remote-prod.sh check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${OPENCLAW_REMOTE_PROD_ENV_FILE:-$HOME/.openclaw-remote-prod.env}"

load_env_file() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
  fi
}

usage() {
  cat <<USAGE
Usage:
  ./scripts/remote-prod.sh set-host <host> [user]
  ./scripts/remote-prod.sh show
  ./scripts/remote-prod.sh deploy --confirm-prod [deploy args]
  ./scripts/remote-prod.sh config --confirm-prod [config deploy args]
  ./scripts/remote-prod.sh check
USAGE
}

require_host() {
  if [[ -z "${OPENCLAW_REMOTE_HOST:-}" ]]; then
    echo "Remote host not configured." >&2
    echo "Run: ./scripts/remote-prod.sh set-host <host> [user]" >&2
    echo "Or set OPENCLAW_REMOTE_HOST for one command." >&2
    exit 64
  fi
}

require_confirm_prod() {
  if [[ "${1:-}" != "--confirm-prod" ]]; then
    echo "Refusing prod action without explicit confirmation." >&2
    echo "Add --confirm-prod after the subcommand." >&2
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
  echo "Saved remote Prod defaults to $ENV_FILE"
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
  require_confirm_prod "${1:-}"
  shift
  "$SCRIPT_DIR/remote-deploy-prod.sh" "$@"
}

cmd_config() {
  load_env_file
  require_host
  require_confirm_prod "${1:-}"
  shift
  "$SCRIPT_DIR/remote-deploy-config-prod.sh" "$@"
}

cmd_check() {
  load_env_file
  require_host
  "$SCRIPT_DIR/remote-check-prod.sh"
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
