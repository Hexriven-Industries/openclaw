---
name: session-logs
description: Inspect older/parent conversations using session tools first, with jq-based log archaeology only as fallback.
metadata: { "openclaw": { "emoji": "📜", "requires": { "bins": ["jq", "rg"] } } }
---

# session-logs

Inspect older or parent conversations when a user asks what was said before. Prefer structured tools first; only fall back to raw session-log archaeology when the built-in tools cannot answer the question.

Never start with shell pipelines for routine recall when `sessions_history`, `sessions_list`, or `memory_search` can answer the question.

## Trigger

Use this skill when the user asks about prior chats, parent conversations, or historical context that is not already answered by memory files.

## Default Order

Always use these lanes in order:

1. `sessions_list` to find the relevant session key/session id.
2. `sessions_history` to fetch the transcript you need.
3. `memory_search` / `memory_get` for durable recall from `MEMORY.md` + `memory/*.md`.
4. Raw shell archaeology (`jq`, `rg`, `grep`, loops over `.jsonl`) only when the structured tools truly cannot answer the question.

Do not jump straight to `exec` for routine session recall if `sessions_list` / `sessions_history` can answer it.

## Location

Session logs live at: `~/.openclaw/agents/<agentId>/sessions/` (use the `agent=<id>` value from the system prompt Runtime line).

- **`sessions.json`** - Index mapping session keys to session IDs
- **`<session-id>.jsonl`** - Full conversation transcript per session

## Preferred Structured Queries

### Find likely sessions first

Use `sessions_list` with a small limit and, when useful, recency filters to identify the right conversation.

### Pull the transcript you actually need

Use `sessions_history` on the selected `sessionKey` or `sessionId` and keep the limit narrow. Expand only if the first pull is insufficient.

### Use memory for durable recall

If the question is about long-term preferences, decisions, identity, or prior work that should live in memory files, prefer:

- `memory_search`
- then `memory_get`

This keeps context smaller and avoids transcript archaeology when the answer is already in memory.

## Structure

Each `.jsonl` file contains messages with:

- `type`: "session" (metadata) or "message"
- `timestamp`: ISO timestamp
- `message.role`: "user", "assistant", or "toolResult"
- `message.content[]`: Text, thinking, or tool calls (filter `type=="text"` for human-readable content)
- `message.usage.cost.total`: Cost per response

## Fallback Log Archaeology

Only use the shell recipes below when `sessions_list` / `sessions_history` cannot answer the question or when you explicitly need raw JSONL inspection.

## Common Fallback Queries

### List all sessions by date and size

```bash
for f in ~/.openclaw/agents/<agentId>/sessions/*.jsonl; do
  date=$(head -1 "$f" | jq -r '.timestamp' | cut -dT -f1)
  size=$(ls -lh "$f" | awk '{print $5}')
  echo "$date $size $(basename $f)"
done | sort -r
```

### Find sessions from a specific day

```bash
for f in ~/.openclaw/agents/<agentId>/sessions/*.jsonl; do
  head -1 "$f" | jq -r '.timestamp' | grep -q "2026-01-06" && echo "$f"
done
```

### Extract user messages from a session

```bash
jq -r 'select(.message.role == "user") | .message.content[]? | select(.type == "text") | .text' <session>.jsonl
```

### Search for keyword in assistant responses

```bash
jq -r 'select(.message.role == "assistant") | .message.content[]? | select(.type == "text") | .text' <session>.jsonl | rg -i "keyword"
```

### Get total cost for a session

```bash
jq -s '[.[] | .message.usage.cost.total // 0] | add' <session>.jsonl
```

### Daily cost summary

```bash
for f in ~/.openclaw/agents/<agentId>/sessions/*.jsonl; do
  date=$(head -1 "$f" | jq -r '.timestamp' | cut -dT -f1)
  cost=$(jq -s '[.[] | .message.usage.cost.total // 0] | add' "$f")
  echo "$date $cost"
done | awk '{a[$1]+=$2} END {for(d in a) print d, "$"a[d]}' | sort -r
```

### Count messages and tokens in a session

```bash
jq -s '{
  messages: length,
  user: [.[] | select(.message.role == "user")] | length,
  assistant: [.[] | select(.message.role == "assistant")] | length,
  first: .[0].timestamp,
  last: .[-1].timestamp
}' <session>.jsonl
```

### Tool usage breakdown

```bash
jq -r '.message.content[]? | select(.type == "toolCall") | .name' <session>.jsonl | sort | uniq -c | sort -rn
```

### Search across ALL sessions for a phrase

```bash
rg -l "phrase" ~/.openclaw/agents/<agentId>/sessions/*.jsonl
```

## Tips

- Sessions are append-only JSONL (one JSON object per line)
- Large sessions can be several MB - use `head`/`tail` for sampling
- The `sessions.json` index maps chat providers (discord, whatsapp, etc.) to session IDs
- Deleted sessions have `.deleted.<timestamp>` suffix

## Fast text-only hint (low noise)

```bash
jq -r 'select(.type=="message") | .message.content[]? | select(.type=="text") | .text' ~/.openclaw/agents/<agentId>/sessions/<id>.jsonl | rg 'keyword'
```
