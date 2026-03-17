import { splitMediaFromOutput } from "../media/parse.js";
import { filterToolResultMediaUrls } from "./pi-embedded-subscribe.tools.js";

const queues = new Map<string, string[]>();

function normalizeSessionKey(key?: string | null): string | null {
  const trimmed = typeof key === "string" ? key.trim() : "";
  return trimmed || null;
}

export function enqueueAsyncExecMediaFromOutput(params: {
  sessionKey?: string | null;
  output: string;
}): string[] {
  const sessionKey = normalizeSessionKey(params.sessionKey);
  if (!sessionKey) {
    return [];
  }
  const parsed = splitMediaFromOutput(params.output);
  const mediaUrls = filterToolResultMediaUrls("exec", parsed.mediaUrls ?? []);
  if (mediaUrls.length === 0) {
    return [];
  }

  const existing = queues.get(sessionKey) ?? [];
  const seen = new Set(existing.map((entry) => entry.trim()));
  const next = existing.slice();
  for (const mediaUrl of mediaUrls) {
    const normalized = mediaUrl.trim();
    if (!normalized || seen.has(normalized)) {
      continue;
    }
    seen.add(normalized);
    next.push(mediaUrl);
  }
  queues.set(sessionKey, next);
  return mediaUrls;
}

export function drainAsyncExecMedia(sessionKey?: string | null): string[] {
  const normalized = normalizeSessionKey(sessionKey);
  if (!normalized) {
    return [];
  }
  const queued = queues.get(normalized) ?? [];
  queues.delete(normalized);
  return queued.slice();
}

export function peekAsyncExecMedia(sessionKey?: string | null): string[] {
  const normalized = normalizeSessionKey(sessionKey);
  if (!normalized) {
    return [];
  }
  return (queues.get(normalized) ?? []).slice();
}

export function resetAsyncExecMediaForTest() {
  queues.clear();
}
