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

case "$ENV" in
  prod)
    LABEL="ai.openclaw.gateway"
    PLIST="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
    PORT=18789
    ;;
  dev)
    LABEL="ai.openclaw.dev"
    PLIST="$HOME/Library/LaunchAgents/ai.openclaw.dev.plist"
    PORT=19001
    ;;
  *)
    echo "Usage: gateway-ctl <prod|dev> <start|stop|status>"
    exit 1
    ;;
esac

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
      echo "✅ $ENV is not loaded"
      exit 0
    fi

    echo "  → Stopping $ENV gateway..."
    launchctl bootout "$GUI/$LABEL" 2>/dev/null || true
    sleep 1
    echo "✅ $ENV gateway stopped"
    ;;

  restart)
    echo "  → Restarting $ENV gateway..."
    if is_loaded; then
      launchctl bootout "$GUI/$LABEL" 2>/dev/null || true
      sleep 3
    fi

    launchctl bootstrap "$GUI" "$PLIST"
    sleep 1
    launchctl kickstart "$GUI/$LABEL"
    sleep 3

    if is_running; then
      echo "✅ $ENV gateway restarted (port $PORT)"
    else
      echo "❌ $ENV gateway failed to restart. Check logs."
      exit 1
    fi
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
    echo "Usage: gateway-ctl <prod|dev> <start|stop|restart|status>"
    exit 1
    ;;
esac
