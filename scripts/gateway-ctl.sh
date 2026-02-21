#!/usr/bin/env bash
# gateway-ctl.sh — Start/stop/status for OpenClaw gateways
#
# Usage:
#   gateway-ctl prod start
#   gateway-ctl prod stop
#   gateway-ctl prod status
#   gateway-ctl dev start
#   gateway-ctl dev stop
#   gateway-ctl dev status

set -euo pipefail

ENV="${1:-}"
ACTION="${2:-}"
GUI="gui/$(id -u)"
PLUTIL_BIN="${PLUTIL_BIN:-/usr/bin/plutil}"

case "$ENV" in
  prod)
    LABEL="ai.openclaw.gateway"
    PLIST="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
    PORT=18789
    DEPLOY_DIR="$HOME/Deployments/openclaw-prod"
    EXPECTED_PROFILE="prod"
    EXPECTED_CONFIG_PATH="$HOME/Deployments/openclaw-config/prod.json5"
    EXPECTED_STATE_DIR="$HOME/.openclaw"
    ;;
  dev)
    LABEL="ai.openclaw.dev"
    PLIST="$HOME/Library/LaunchAgents/ai.openclaw.dev.plist"
    PORT=19001
    DEPLOY_DIR="$HOME/Deployments/openclaw-dev"
    EXPECTED_PROFILE="dev"
    EXPECTED_CONFIG_PATH="$HOME/Deployments/openclaw-config/dev.json5"
    EXPECTED_STATE_DIR="$HOME/.openclaw-dev"
    ;;
  *)
    echo "Usage: gateway-ctl <prod|dev> <start|stop|status>"
    exit 1
    ;;
esac

require_explicit_profile_pin() {
  case "$ACTION" in
    start|stop|restart|tui) ;;
    *) return 0 ;;
  esac

  local profile="${OPENCLAW_PROFILE:-}"
  if [[ "$profile" != "$EXPECTED_PROFILE" ]]; then
    echo "❌ Refusing $ENV $ACTION without explicit profile pinning."
    echo "   Expected: OPENCLAW_PROFILE=$EXPECTED_PROFILE"
    echo "   Example: OPENCLAW_PROFILE=$EXPECTED_PROFILE gateway-ctl $ENV $ACTION"
    exit 1
  fi
}

resolve_abs_path_no_fs() {
  local input="$1"
  local path_in="$input"
  case "$path_in" in
    "~")
      path_in="$HOME"
      ;;
    "~/"*)
      path_in="$HOME/${path_in#~/}"
      ;;
  esac
  if [[ "$path_in" = /* ]]; then
    printf "%s\n" "$path_in"
  else
    printf "%s\n" "$PWD/$path_in"
  fi
}

plist_read_raw() {
  local key="$1"
  "$PLUTIL_BIN" -extract "$key" raw -o - "$PLIST" 2>/dev/null || true
}

verify_plist_binding() {
  case "$ACTION" in
    start|restart|tui) ;;
    *) return 0 ;;
  esac

  if [ ! -f "$PLIST" ]; then
    echo "❌ Missing plist: $PLIST"
    echo "   Reinstall service using the $ENV runtime before retrying."
    exit 1
  fi

  local actual_config actual_state actual_entry actual_port
  actual_config="$(plist_read_raw EnvironmentVariables.OPENCLAW_CONFIG_PATH)"
  actual_state="$(plist_read_raw EnvironmentVariables.OPENCLAW_STATE_DIR)"
  actual_entry="$(plist_read_raw ProgramArguments.1)"
  actual_port="$(plist_read_raw ProgramArguments.3)"

  local expected_config expected_state expected_entry
  expected_config="$(resolve_abs_path_no_fs "$EXPECTED_CONFIG_PATH")"
  expected_state="$(resolve_abs_path_no_fs "$EXPECTED_STATE_DIR")"
  expected_entry="$(resolve_abs_path_no_fs "$DEPLOY_DIR/dist/index.js")"

  local actual_config_abs actual_state_abs actual_entry_abs
  actual_config_abs="$(resolve_abs_path_no_fs "$actual_config")"
  actual_state_abs="$(resolve_abs_path_no_fs "$actual_state")"
  actual_entry_abs="$(resolve_abs_path_no_fs "$actual_entry")"

  if [[ "$actual_config_abs" != "$expected_config" ]] || \
     [[ "$actual_state_abs" != "$expected_state" ]] || \
     [[ "$actual_entry_abs" != "$expected_entry" ]] || \
     [[ "$actual_port" != "$PORT" ]]; then
    echo "❌ Refusing $ENV $ACTION due to service binding drift."
    echo "   Expected config: $expected_config"
    echo "   Actual config:   $actual_config_abs"
    echo "   Expected state:  $expected_state"
    echo "   Actual state:    $actual_state_abs"
    echo "   Expected entry:  $expected_entry"
    echo "   Actual entry:    $actual_entry_abs"
    echo "   Expected port:   $PORT"
    echo "   Actual port:     ${actual_port:-<missing>}"
    echo "   Fix the LaunchAgent wiring before retrying."
    exit 1
  fi
}

require_explicit_profile_pin
verify_plist_binding

is_loaded() {
  launchctl print "$GUI/$LABEL" &>/dev/null
}

is_running() {
  launchctl print "$GUI/$LABEL" 2>/dev/null | grep -q "state = running"
}

case "$ACTION" in
  start)
    if is_running; then
      echo "✅ $ENV is already running"
      exit 0
    fi

    if ! is_loaded; then
      echo "  → Loading service..."
      launchctl bootstrap "$GUI" "$PLIST"
      sleep 1
    fi

    echo "  → Starting $ENV gateway..."
    launchctl kickstart "$GUI/$LABEL"
    sleep 3

    if is_running; then
      echo "✅ $ENV gateway started (port $PORT)"
    else
      echo "❌ $ENV gateway failed to start. Check logs."
      exit 1
    fi
    ;;

  stop)
    if ! is_loaded; then
      # Even if not loaded, check for orphan processes
      ORPHAN=$(lsof -ti tcp:$PORT 2>/dev/null || true)
      if [[ -n "$ORPHAN" ]]; then
        echo "  → Service not loaded but found orphan on port $PORT: $ORPHAN"
        kill $ORPHAN 2>/dev/null || true
        sleep 1
        kill -9 $(lsof -ti tcp:$PORT 2>/dev/null || true) 2>/dev/null || true
        echo "✅ $ENV orphan killed"
      else
        echo "✅ $ENV is not loaded"
      fi
      exit 0
    fi

    echo "  → Stopping $ENV gateway..."
    launchctl bootout "$GUI/$LABEL" 2>/dev/null || true
    sleep 2

    # Clean up orphans that survived bootout
    ORPHAN=$(lsof -ti tcp:$PORT 2>/dev/null || true)
    if [[ -n "$ORPHAN" ]]; then
      echo "  → Killing orphan process(es) on port $PORT: $ORPHAN"
      kill $ORPHAN 2>/dev/null || true
      sleep 1
      kill -9 $(lsof -ti tcp:$PORT 2>/dev/null || true) 2>/dev/null || true
    fi
    echo "✅ $ENV gateway stopped"
    ;;

  restart)
    echo "  → Restarting $ENV gateway..."
    if is_loaded; then
      launchctl bootout "$GUI/$LABEL" 2>/dev/null || true
      sleep 2
    fi

    # Kill any orphan process still holding the port (launchd may have lost track)
    ORPHAN=$(lsof -ti tcp:$PORT 2>/dev/null || true)
    if [[ -n "$ORPHAN" ]]; then
      echo "  → Killing orphan process(es) on port $PORT: $ORPHAN"
      kill $ORPHAN 2>/dev/null || true
      sleep 2
      # Force kill if still alive
      STUBBORN=$(lsof -ti tcp:$PORT 2>/dev/null || true)
      if [[ -n "$STUBBORN" ]]; then
        echo "  → Force killing stubborn process(es): $STUBBORN"
        kill -9 $STUBBORN 2>/dev/null || true
        sleep 1
      fi
    fi

    launchctl bootstrap "$GUI" "$PLIST"
    sleep 1
    launchctl kickstart "$GUI/$LABEL"
    sleep 3

    if is_running; then
      PID=$(launchctl print "$GUI/$LABEL" 2>/dev/null | grep "pid = " | head -1 | awk '{print $3}')
      echo "✅ $ENV gateway restarted (pid $PID, port $PORT)"
    else
      echo "❌ $ENV gateway failed to restart. Check logs."
      exit 1
    fi
    ;;

  tui)
    echo "  → Launching $ENV TUI from $DEPLOY_DIR..."
    cd "$DEPLOY_DIR"
    exec node dist/index.js tui --port "$PORT"
    ;;

  status)
    if is_running; then
      PID=$(launchctl print "$GUI/$LABEL" 2>/dev/null | grep "pid = " | head -1 | awk '{print $3}')
      echo "✅ $ENV is RUNNING (pid $PID, port $PORT)"
    elif is_loaded; then
      echo "⏸️  $ENV is LOADED but not running"
    else
      echo "⏹️  $ENV is STOPPED"
    fi
    ;;

  *)
    echo "Usage: gateway-ctl <prod|dev> <start|stop|restart|status|tui>"
    exit 1
    ;;
esac
