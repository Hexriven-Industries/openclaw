#!/usr/bin/env bash
set -euo pipefail

# Dev-only hardening smoke check.
# Verifies high-signal guardrails against a rendered config file.
#
# Usage:
#   OPENCLAW_CONFIG_PATH=~/Deployments/openclaw-config/dev.json5 \
#   OPENCLAW_STATE_DIR=~/.openclaw-dev \
#   ./scripts/check-dev-hardening.sh
#
# Optional:
#   OPENCLAW_BIN=/path/to/dist/index.js
#   OPENCLAW_OPERATOR_DISCORD_ID=225674175312953344
#   OPENCLAW_DEV_VOICE_CHANNEL_ID=1456457229430685750

OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$HOME/Deployments/openclaw-config/dev.json5}"
OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-$HOME/.openclaw-dev}"
OPENCLAW_BIN="${OPENCLAW_BIN:-$HOME/Deployments/openclaw-dev/dist/index.js}"

if [[ ! -f "$OPENCLAW_BIN" ]]; then
  echo "openclaw binary not found: $OPENCLAW_BIN" >&2
  exit 1
fi

if [[ ! -f "$OPENCLAW_CONFIG_PATH" ]]; then
  echo "config file not found: $OPENCLAW_CONFIG_PATH" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for check-dev-hardening.sh" >&2
  exit 1
fi

_cfg_get() {
  OPENCLAW_CONFIG_PATH="$OPENCLAW_CONFIG_PATH" \
    OPENCLAW_STATE_DIR="$OPENCLAW_STATE_DIR" \
    node "$OPENCLAW_BIN" config get "$1" --json 2>/dev/null
}

_ok() { printf '  ✓ %s\n' "$1"; }
_fail() {
  printf '  ✖ %s\n' "$1" >&2
  FAILED=1
}

echo "  -> Checking Dev hardening guardrails..."
echo "     config: $OPENCLAW_CONFIG_PATH"
echo "     state:  $OPENCLAW_STATE_DIR"
echo "     bin:    $OPENCLAW_BIN"

FAILED=0

# 1) Plugin allowlist must include discord + tool-size-guard.
plugins_allow="$(_cfg_get "plugins.allow" || true)"
if [[ -z "$plugins_allow" ]] || ! jq -e 'index("discord") and index("tool-size-guard")' >/dev/null <<<"$plugins_allow"; then
  _fail 'plugins.allow must include both "discord" and "tool-size-guard"'
else
  _ok 'plugins.allow includes discord and tool-size-guard'
fi

# 2) Exec approvals must be enabled for Discord.
exec_approvals="$(_cfg_get "channels.discord.execApprovals" || true)"
if [[ -z "$exec_approvals" ]] || ! jq -e '.enabled == true' >/dev/null <<<"$exec_approvals"; then
  _fail "channels.discord.execApprovals.enabled must be true"
else
  _ok "Discord exec approvals enabled"
fi

# 3) Exec policy must remain allowlisted.
exec_cfg="$(_cfg_get "tools.exec" || true)"
if [[ -z "$exec_cfg" ]] || ! jq -e '.security == "allowlist"' >/dev/null <<<"$exec_cfg"; then
  _fail 'tools.exec.security must be "allowlist"'
else
  _ok 'tools.exec.security is allowlist'
fi

# 4) Command authorization sources should be present.
commands_allow_from="$(_cfg_get "commands.allowFrom.discord" || true)"
discord_allow_from="$(_cfg_get "channels.discord.allowFrom" || true)"
if [[ -z "$commands_allow_from" ]]; then
  _fail "commands.allowFrom.discord is missing"
else
  _ok "commands.allowFrom.discord exists"
fi
if [[ -z "$discord_allow_from" ]]; then
  _fail "channels.discord.allowFrom is missing"
else
  _ok "channels.discord.allowFrom exists"
fi

# 5) Optional: ensure operator id is explicitly authorized in both lists.
if [[ -n "${OPENCLAW_OPERATOR_DISCORD_ID:-}" ]]; then
  operator_tag="discord:${OPENCLAW_OPERATOR_DISCORD_ID}"
  if ! jq -e --arg x "$operator_tag" 'index($x)' >/dev/null <<<"${commands_allow_from:-[]}"; then
    _fail "commands.allowFrom.discord missing $operator_tag"
  else
    _ok "commands.allowFrom.discord includes $operator_tag"
  fi
  if ! jq -e --arg x "$operator_tag" 'index($x)' >/dev/null <<<"${discord_allow_from:-[]}"; then
    _fail "channels.discord.allowFrom missing $operator_tag"
  else
    _ok "channels.discord.allowFrom includes $operator_tag"
  fi
fi

# 6) Optional: verify voice channel is explicitly allowlisted.
if [[ -n "${OPENCLAW_DEV_VOICE_CHANNEL_ID:-}" ]]; then
  voice_path="channels.discord.guilds.1456457228734435391.channels.${OPENCLAW_DEV_VOICE_CHANNEL_ID}"
  voice_cfg="$(_cfg_get "$voice_path" || true)"
  if [[ -z "$voice_cfg" ]] || ! jq -e '.allow == true' >/dev/null <<<"$voice_cfg"; then
    _fail "voice channel ${OPENCLAW_DEV_VOICE_CHANNEL_ID} is not explicitly allowlisted"
  else
    _ok "voice channel ${OPENCLAW_DEV_VOICE_CHANNEL_ID} allowlisted"
  fi
fi

if [[ "$FAILED" -ne 0 ]]; then
  echo
  echo "Dev hardening smoke check FAILED." >&2
  exit 1
fi

echo
echo "Dev hardening smoke check passed."
