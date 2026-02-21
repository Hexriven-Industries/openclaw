#!/usr/bin/env bash
# config-surface-diff.sh
# Compare OpenClaw config key surface between two git refs/tags.
#
# Usage:
#   ./scripts/config-surface-diff.sh <old-ref> <new-ref>
# Example:
#   ./scripts/config-surface-diff.sh v2026.2.18 v2026.2.19

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <old-ref> <new-ref>" >&2
  exit 1
fi

OLD_REF="$1"
NEW_REF="$2"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

OLD_KEYS="$TMP_DIR/old.keys"
NEW_KEYS="$TMP_DIR/new.keys"
ADDED="$TMP_DIR/added.keys"
REMOVED="$TMP_DIR/removed.keys"
ADDED_MUST="$TMP_DIR/added.must.keys"
ADDED_OTHER="$TMP_DIR/added.other.keys"

require_ref() {
  local ref="$1"
  if ! git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
    echo "Ref not found locally: ${ref}" >&2
    echo "Tip: fetch tags/refs first (for example: git fetch --tags origin)." >&2
    exit 1
  fi
}

require_ref "$OLD_REF"
require_ref "$NEW_REF"

extract_keys_from_labels() {
  local ref="$1"
  local path="src/config/schema.labels.ts"
  if ! git cat-file -e "${ref}:${path}" 2>/dev/null; then
    return 1
  fi

  git show "${ref}:${path}" \
    | sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*:[[:space:]]*".*$/\1/p' \
    | sed '/^[[:space:]]*$/d' \
    | sort -u
}

extract_keys_from_help() {
  local ref="$1"
  local path="src/config/schema.help.ts"
  if ! git cat-file -e "${ref}:${path}" 2>/dev/null; then
    return 1
  fi

  git show "${ref}:${path}" \
    | sed -n 's/^[[:space:]]*"\([^"]*\)"[[:space:]]*:[[:space:]]*".*$/\1/p' \
    | sed '/^[[:space:]]*$/d' \
    | sort -u
}

extract_keys() {
  local ref="$1"
  if extract_keys_from_labels "$ref"; then
    return 0
  fi
  if extract_keys_from_help "$ref"; then
    return 0
  fi
  echo "No supported config key source found at ref '${ref}'" >&2
  return 1
}

is_must_review_key() {
  local key="$1"
  case "$key" in
    tools.*) return 0 ;;
    approvals.*) return 0 ;;
    browser.ssrfPolicy*|browser.hostnameAllowlist*) return 0 ;;
    gateway.auth*|gateway.remote*|gateway.bind*|gateway.http*|gateway.controlUi*) return 0 ;;
    channels.*.execApprovals*|channels.*.dmPolicy*|channels.*.allowFrom*) return 0 ;;
    auth.*|models.providers*|providers.*) return 0 ;;
    sandbox.*|nodeHost.*) return 0 ;;
    *) return 1 ;;
  esac
}

extract_keys "$OLD_REF" > "$OLD_KEYS"
extract_keys "$NEW_REF" > "$NEW_KEYS"

comm -13 "$OLD_KEYS" "$NEW_KEYS" > "$ADDED" || true
comm -23 "$OLD_KEYS" "$NEW_KEYS" > "$REMOVED" || true

> "$ADDED_MUST"
> "$ADDED_OTHER"
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  if is_must_review_key "$key"; then
    echo "$key" >> "$ADDED_MUST"
  else
    echo "$key" >> "$ADDED_OTHER"
  fi
done < "$ADDED"

sort -u -o "$ADDED_MUST" "$ADDED_MUST"
sort -u -o "$ADDED_OTHER" "$ADDED_OTHER"

count_lines() {
  local file="$1"
  if [[ -s "$file" ]]; then
    wc -l < "$file" | tr -d '[:space:]'
  else
    echo "0"
  fi
}

TOTAL_OLD="$(count_lines "$OLD_KEYS")"
TOTAL_NEW="$(count_lines "$NEW_KEYS")"
TOTAL_ADDED="$(count_lines "$ADDED")"
TOTAL_REMOVED="$(count_lines "$REMOVED")"
TOTAL_ADDED_MUST="$(count_lines "$ADDED_MUST")"

echo "OpenClaw config surface diff"
echo "old: $OLD_REF ($TOTAL_OLD keys)"
echo "new: $NEW_REF ($TOTAL_NEW keys)"
echo "added: $TOTAL_ADDED"
echo "removed: $TOTAL_REMOVED"
echo "must-review added: $TOTAL_ADDED_MUST"
echo

print_section() {
  local title="$1"
  local file="$2"
  echo "$title"
  if [[ ! -s "$file" ]]; then
    echo "  (none)"
    echo
    return
  fi
  while IFS= read -r key; do
    echo "  - $key"
  done < "$file"
  echo
}

print_section "Added (must-review)" "$ADDED_MUST"
print_section "Added (other)" "$ADDED_OTHER"
print_section "Removed" "$REMOVED"

cat <<EOF
Suggested next step:
  1) Copy added keys into your release-config-review checklist.
  2) Decide per key: accept default vs explicit override (dev/prod/both).
EOF
