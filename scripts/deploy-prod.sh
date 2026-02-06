#!/usr/bin/env bash
# deploy-prod.sh — Deploy OpenClaw to production
# Thin wrapper around deploy.sh. See deploy.sh for full docs.
#
# Usage:
#   ./scripts/deploy-prod.sh              # Build + deploy + restart gateway
#   ./scripts/deploy-prod.sh --skip-build # Deploy existing dist + restart
#   ./scripts/deploy-prod.sh --backup     # Backup previous deploy first
#   ./scripts/deploy-prod.sh --no-restart # Deploy without restarting
#   ./scripts/deploy-prod.sh --dry-run    # Show what would be synced

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export DEPLOY_ENV=prod
exec "$SCRIPT_DIR/deploy.sh" "$@"
