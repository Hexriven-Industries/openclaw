#!/usr/bin/env bash
# deploy-palace.sh — Deploy OpenClaw to Palace
# Thin wrapper around deploy.sh. See deploy.sh for full docs.
#
# Usage:
#   ./scripts/deploy-palace.sh              # Build + deploy + restart gateway
#   ./scripts/deploy-palace.sh --skip-build # Deploy existing dist + restart
#   ./scripts/deploy-palace.sh --backup     # Backup previous deploy first
#   ./scripts/deploy-palace.sh --no-restart # Deploy without restarting
#   ./scripts/deploy-palace.sh --dry-run    # Show what would be synced

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export DEPLOY_ENV=palace
exec "$SCRIPT_DIR/deploy.sh" "$@"
