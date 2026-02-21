#!/usr/bin/env bash
# deploy.sh — Deploy OpenClaw to a target environment
#
# Base deploy script. Use the environment wrappers instead of calling directly:
#   ./scripts/deploy-prod.sh              # Deploy to production
#   ./scripts/deploy-dev.sh               # Deploy to development
#
# Or call directly with --env:
#   ./scripts/deploy.sh --env prod
#   ./scripts/deploy.sh --env dev --skip-build --dry-run
#
# Flags:
#   --env <name>     Environment to deploy to (required unless called via wrapper)
#   --skip-build     Deploy existing dist without rebuilding
#   --backup         Backup previous deployment first
#   --dry-run        Show what would be synced without doing it
#   --no-restart     Deploy without restarting the gateway (default: restart after deploy)
#
# To deploy without restarting (e.g., staging for later activation):
#   ./scripts/deploy-prod.sh --no-restart

set -euo pipefail

# ── Environment definitions ───────────────────────────────────────────
# Add new environments here. Update resolve_env() below.
resolve_env() {
  case "$1" in
    prod)
      DEPLOY_DIR="$HOME/Deployments/openclaw-prod"
      ENV_LABEL="Production"
      LAUNCHD_LABEL="ai.openclaw.gateway"
      PLIST_FILE="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
      ;;
    dev)
      DEPLOY_DIR="$HOME/Deployments/openclaw-dev"
      ENV_LABEL="Development"
      LAUNCHD_LABEL="ai.openclaw.dev"
      PLIST_FILE="$HOME/Library/LaunchAgents/ai.openclaw.dev.plist"
      ;;
    *)
      die "Unknown environment: $1 (known: prod, dev)"
      ;;
  esac
}

# ── Configuration ─────────────────────────────────────────────────────
SOURCE_DIR="${OPENCLAW_SOURCE:-$HOME/Development/openclaw}"
# Expected Dev config path for LaunchAgent verification.
# Override if your dev config repo lives elsewhere.
DEV_EXPECTED_CONFIG_PATH="${OPENCLAW_DEV_CONFIG_PATH:-$HOME/Deployments/openclaw-config/dev.json5}"
PROD_EXPECTED_CONFIG_PATH="${OPENCLAW_PROD_CONFIG_PATH:-$HOME/Deployments/openclaw-config/prod.json5}"
# Plutil binary path (override in tests/non-mac environments).
PLUTIL_BIN="${PLUTIL_BIN:-/usr/bin/plutil}"

# Runtime artifacts the gateway needs (and nothing else).
# If upstream adds new runtime requirements, update this list.
# See: ~/.openclaw/workspace/scratch/runtime-requirements.md
RUNTIME_DIRS=(
  dist/
  node_modules/
  skills/
  assets/
  extensions/
)
RUNTIME_FILES=(
  package.json
)

# ── Flags ─────────────────────────────────────────────────────────────
ENV_NAME="${DEPLOY_ENV:-}"
SKIP_BUILD=false
BACKUP=false
DRY_RUN=false
RESTART=true

for arg in "$@"; do
  case "$arg" in
    --env)       shift_next=env ;;
    --skip-build) SKIP_BUILD=true ;;
    --backup)     BACKUP=true ;;
    --dry-run)    DRY_RUN=true ;;
    --no-restart) RESTART=false ;;
    --help|-h)
      head -20 "$0" | tail -18
      exit 0
      ;;
    *)
      if [ "${shift_next:-}" = "env" ]; then
        ENV_NAME="$arg"
        shift_next=""
      else
        echo "Unknown flag: $arg (try --help)"
        exit 1
      fi
      ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────
info()  { echo "  → $*"; }
warn()  { echo "  ⚠ $*" >&2; }
die()   { echo "  ✖ $*" >&2; exit 1; }

verify_dev_config_path() {
  local plist_file="$1"
  local expected_path="$2"
  local actual_path

  [ -f "$plist_file" ] || die "Dev plist not found: $plist_file"

  # Read EnvironmentVariables.OPENCLAW_CONFIG_PATH from launchd plist.
  # If missing or mismatched, fail fast before restart so we don't boot with
  # the wrong config source.
  actual_path=$("$PLUTIL_BIN" -extract EnvironmentVariables.OPENCLAW_CONFIG_PATH raw -o - "$plist_file" 2>/dev/null || true)

  if [ -z "$actual_path" ]; then
    die "Dev config-path verification failed: OPENCLAW_CONFIG_PATH is missing in $plist_file"
  fi

  local expected_abs actual_abs
  expected_abs="$(cd "$(dirname "$expected_path")" && pwd)/$(basename "$expected_path")"
  actual_abs="$(cd "$(dirname "$actual_path")" && pwd 2>/dev/null)/$(basename "$actual_path")"

  if [ "$actual_abs" != "$expected_abs" ]; then
    die "Dev config-path verification failed:
  expected: $expected_abs
  actual:   $actual_abs
Fix the LaunchAgent EnvironmentVariables.OPENCLAW_CONFIG_PATH before deploying."
  fi

  info "Dev config-path verified ✓ ($actual_abs)"
}

verify_prod_config_path_info() {
  local plist_file="$1"
  local expected_path="$2"
  local actual_path

  if [ ! -f "$plist_file" ]; then
    warn "Prod plist not found: $plist_file (skipping config-path info check)"
    return
  fi

  actual_path=$("$PLUTIL_BIN" -extract EnvironmentVariables.OPENCLAW_CONFIG_PATH raw -o - "$plist_file" 2>/dev/null || true)
  if [ -z "$actual_path" ]; then
    warn "Prod config-path info: OPENCLAW_CONFIG_PATH is not set in $plist_file"
    return
  fi

  local expected_abs actual_abs
  expected_abs="$(cd "$(dirname "$expected_path")" && pwd)/$(basename "$expected_path")"
  actual_abs="$(cd "$(dirname "$actual_path")" && pwd 2>/dev/null)/$(basename "$actual_path")"

  if [ "$actual_abs" = "$expected_abs" ]; then
    info "Prod config-path info ✓ ($actual_abs)"
    return
  fi

  warn "Prod config-path info mismatch:
  expected: $expected_abs
  actual:   $actual_abs"
}

# ── Resolve environment ──────────────────────────────────────────────
[ -n "$ENV_NAME" ] || die "No environment specified. Use --env prod|dev or call via wrapper script."

resolve_env "$ENV_NAME"

# Dev-only safety check: ensure launchd service points at the expected
# config-repo path before we restart.
if [ "$ENV_NAME" = "dev" ] && [ "$DRY_RUN" = false ]; then
  info "Verifying dev LaunchAgent OPENCLAW_CONFIG_PATH..."
  verify_dev_config_path "$PLIST_FILE" "$DEV_EXPECTED_CONFIG_PATH"
  echo ""
fi

# Prod informational check: warn on mismatch, but do not block deploy.
if [ "$ENV_NAME" = "prod" ] && [ "$DRY_RUN" = false ]; then
  info "Checking prod LaunchAgent OPENCLAW_CONFIG_PATH (informational)..."
  verify_prod_config_path_info "$PLIST_FILE" "$PROD_EXPECTED_CONFIG_PATH"
  echo ""
fi

# ── Pre-flight checks ────────────────────────────────────────────────
echo "╔══════════════════════════════════════╗"
echo "║   OpenClaw $ENV_LABEL Deploy"
echo "╚══════════════════════════════════════╝"
echo ""

[ -d "$SOURCE_DIR" ]              || die "Source dir not found: $SOURCE_DIR"
[ -f "$SOURCE_DIR/package.json" ] || die "Not an OpenClaw repo: $SOURCE_DIR"

# Capture git info for version tracking
cd "$SOURCE_DIR"
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
GIT_DIRTY=""
if ! git diff --quiet 2>/dev/null; then
  GIT_DIRTY="-dirty"
fi

info "Source:  $SOURCE_DIR ($GIT_BRANCH @ $GIT_HASH$GIT_DIRTY)"
info "Target:  $DEPLOY_DIR"
info "Env:     $ENV_LABEL"
echo ""

# ── Build ─────────────────────────────────────────────────────────────
if [ "$SKIP_BUILD" = true ]; then
  info "Skipping build (--skip-build)"
  [ -d "$SOURCE_DIR/dist" ] || die "No dist/ found — can't skip build without existing dist"
else
  info "Building..."
  cd "$SOURCE_DIR"
  pnpm build --quiet 2>&1 | tail -3
  info "Build complete"
fi
echo ""

# Verify dist exists and looks sane
[ -f "$SOURCE_DIR/dist/index.js" ] || die "dist/index.js not found after build"

# ── Backup previous deployment ────────────────────────────────────────
if [ "$BACKUP" = true ] && [ -d "$DEPLOY_DIR/dist" ]; then
  BACKUP_NAME="$DEPLOY_DIR.backup-$(date +%Y%m%d-%H%M%S)"
  info "Backing up previous deployment → $BACKUP_NAME"
  if [ "$DRY_RUN" = false ]; then
    cp -a "$DEPLOY_DIR" "$BACKUP_NAME"
  fi
fi

# ── Deploy ────────────────────────────────────────────────────────────
mkdir -p "$DEPLOY_DIR"

RSYNC_FLAGS=(-a --delete)
if [ "$DRY_RUN" = true ]; then
  RSYNC_FLAGS+=(--dry-run)
  info "DRY RUN — showing what would be synced:"
fi

# Directories where custom (non-upstream) content should be preserved.
# rsync --delete would remove anything not in the source tree, which
# nukes custom extensions deployed separately (e.g., Beanstalk).
PRESERVE_CUSTOM_DIRS=(extensions/)

# Sync directories
for dir in "${RUNTIME_DIRS[@]}"; do
  if [ -d "$SOURCE_DIR/$dir" ]; then
    local_flags=("${RSYNC_FLAGS[@]}")
    for preserve_dir in "${PRESERVE_CUSTOM_DIRS[@]}"; do
      if [ "$dir" = "$preserve_dir" ]; then
        # Remove --delete for dirs that may contain custom content
        local_flags=(-a)
        if [ "$DRY_RUN" = true ]; then
          local_flags+=(--dry-run)
        fi
        info "Syncing $dir (preserving custom content)"
        break
      fi
    done
    if [[ ! " ${PRESERVE_CUSTOM_DIRS[*]} " =~ " ${dir} " ]]; then
      info "Syncing $dir"
    fi
    rsync "${local_flags[@]}" "$SOURCE_DIR/$dir" "$DEPLOY_DIR/$dir"
  else
    warn "Directory not found, skipping: $dir"
  fi
done

# Copy individual files
for file in "${RUNTIME_FILES[@]}"; do
  if [ -f "$SOURCE_DIR/$file" ]; then
    info "Copying $file"
    if [ "$DRY_RUN" = false ]; then
      cp "$SOURCE_DIR/$file" "$DEPLOY_DIR/$file"
    fi
  else
    warn "File not found, skipping: $file"
  fi
done

# Write version stamp
if [ "$DRY_RUN" = false ]; then
  cat > "$DEPLOY_DIR/VERSION" <<EOF
environment: $ENV_NAME
branch: $GIT_BRANCH
commit: $GIT_HASH$GIT_DIRTY
deployed: $(date -u +%Y-%m-%dT%H:%M:%SZ)
deployed_by: $(whoami)
source: $SOURCE_DIR
EOF
  info "Version stamp written"
fi

echo ""

# ── Post-deploy verification ─────────────────────────────────────────
if [ "$DRY_RUN" = false ]; then
  [ -f "$DEPLOY_DIR/dist/index.js" ]  || die "VERIFICATION FAILED: dist/index.js missing from deployment!"
  [ -d "$DEPLOY_DIR/node_modules" ]    || die "VERIFICATION FAILED: node_modules/ missing from deployment!"
  [ -f "$DEPLOY_DIR/package.json" ]    || die "VERIFICATION FAILED: package.json missing from deployment!"

  DEPLOY_SIZE=$(du -sh "$DEPLOY_DIR" 2>/dev/null | cut -f1)
  info "Deployment verified ✓ ($DEPLOY_SIZE)"
fi

# ── Restart gateway ───────────────────────────────────────────────────
if [ "$RESTART" = true ] && [ "$DRY_RUN" = false ]; then
  echo ""
  info "Restarting gateway ($LAUNCHD_LABEL)..."

  # Check if service is loaded
  if launchctl print "gui/$(id -u)/$LAUNCHD_LABEL" &>/dev/null; then
    info "Stopping service (bootout)..."
    launchctl bootout "gui/$(id -u)/$LAUNCHD_LABEL" 2>/dev/null || true

    # Critical: sleep to let launchd finish cleanup.
    # Without this, bootstrap can hit a race condition ("Input/output error").
    info "Waiting for launchd cleanup..."
    sleep 3
  fi

  if [ ! -f "$PLIST_FILE" ]; then
    die "Plist not found: $PLIST_FILE — cannot restart"
  fi

  info "Starting service (bootstrap)..."
  if ! launchctl bootstrap "gui/$(id -u)" "$PLIST_FILE" 2>&1; then
    warn "Bootstrap failed! Retrying in 5 seconds..."
    sleep 5
    if ! launchctl bootstrap "gui/$(id -u)" "$PLIST_FILE" 2>&1; then
      die "Bootstrap failed twice. Manual recovery needed:
  launchctl bootstrap gui/\$(id -u) $PLIST_FILE
  OR: node $DEPLOY_DIR/dist/index.js gateway --port 18789"
    fi
  fi

  # Verify the service started with the correct path
  sleep 2
  LOADED_PATH=$(launchctl print "gui/$(id -u)/$LAUNCHD_LABEL" 2>/dev/null | grep -o "$DEPLOY_DIR[^ ]*" | head -1)
  if [ -n "$LOADED_PATH" ]; then
    info "Gateway running from correct path ✓"
  else
    warn "Gateway path mismatch! Expected: $DEPLOY_DIR, Got: $LOADED_PATH"
  fi

  info "Gateway restarted ✓"
fi

echo ""
if [ "$RESTART" = true ] && [ "$DRY_RUN" = false ]; then
  echo "╔══════════════════════════════════════╗"
  echo "║   Deploy + restart complete          ║"
  echo "║   ($ENV_LABEL)                       ║"
  echo "╚══════════════════════════════════════╝"
else
  echo "╔══════════════════════════════════════╗"
  echo "║   Deploy complete ($ENV_LABEL)"
  echo "║                                      ║"
  echo "║   Restart the gateway to activate.   ║"
  echo "╚══════════════════════════════════════╝"
fi
