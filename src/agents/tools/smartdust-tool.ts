import { Type } from "@sinclair/typebox";
import type { GatewayMessageChannel } from "../../utils/message-channel.js";
import { stringEnum } from "../schema/typebox.js";
import {
  type AnyAgentTool,
  ToolInputError,
  jsonResult,
  readNumberParam,
  readStringParam,
} from "./common.js";

const SMARTDUST_ACTIONS = [
  "fleet.status",
  "order.submit",
  "order.get",
  "order.list",
  "order.cancel",
  "batch.submit",
  "batch.get",
  "stats",
] as const;

const SmartdustToolSchema = Type.Object({
  action: stringEnum(SMARTDUST_ACTIONS),
  baseUrl: Type.Optional(Type.String()),
  apiKey: Type.Optional(Type.String()),
  timeoutMs: Type.Optional(Type.Number()),
  verbose: Type.Optional(Type.Boolean()),

  orderId: Type.Optional(Type.String()),
  batchId: Type.Optional(Type.String()),
  status: Type.Optional(Type.String()),

  order: Type.Optional(Type.Object({}, { additionalProperties: true })),
  batch: Type.Optional(Type.Object({}, { additionalProperties: true })),

  // Convenience fields for order.submit when `order` is omitted.
  requestId: Type.Optional(Type.String()),
  submittedBy: Type.Optional(Type.String()),
  source: Type.Optional(Type.Object({}, { additionalProperties: true })),
  name: Type.Optional(Type.String()),
  modelName: Type.Optional(Type.String()),
  messages: Type.Optional(Type.Array(Type.Any())),
  tools: Type.Optional(Type.Array(Type.Any())),
  requirements: Type.Optional(Type.Object({}, { additionalProperties: true })),
  priority: Type.Optional(Type.String()),
  syncWaitMs: Type.Optional(Type.Number()),

  // Convenience fields for batch.submit when `batch` is omitted.
  parallel: Type.Optional(Type.Number()),
});

type SmartdustCallOptions = {
  baseUrl: string;
  apiKey?: string;
  timeoutMs: number;
};

function resolveSmartdustCallOptions(params: Record<string, unknown>): SmartdustCallOptions {
  const baseUrl =
    readStringParam(params, "baseUrl") ??
    process.env.SMARTDUST_BASE_URL?.trim() ??
    "http://127.0.0.1:7777";
  const apiKey =
    readStringParam(params, "apiKey") ?? process.env.SMARTDUST_API_KEY?.trim() ?? undefined;
  const timeoutMs = readNumberParam(params, "timeoutMs") ?? 30_000;
  if (!Number.isFinite(timeoutMs) || timeoutMs < 1) {
    throw new ToolInputError("timeoutMs must be a positive number");
  }
  return {
    baseUrl,
    apiKey,
    timeoutMs: Math.floor(timeoutMs),
  };
}

function parseLooseObject(value: unknown, field: string): Record<string, unknown> | undefined {
  if (value === undefined) {
    return undefined;
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new ToolInputError(`${field} must be an object`);
  }
  return { ...(value as Record<string, unknown>) };
}

function withSourceDefaults(params: {
  source: Record<string, unknown> | undefined;
  channel?: GatewayMessageChannel;
  groupId?: string | null;
  groupSpace?: string | null;
  requesterSenderId?: string | null;
  sessionKey?: string;
}) {
  const source = { ...params.source };
  if (source.channel === undefined && params.channel) {
    source.channel = params.channel;
  }
  if (source.channelId === undefined && params.groupId) {
    source.channelId = params.groupId;
  }
  if (source.guildId === undefined && params.groupSpace) {
    source.guildId = params.groupSpace;
  }
  if (source.requesterId === undefined && params.requesterSenderId) {
    source.requesterId = params.requesterSenderId;
  }
  if (source.sessionKey === undefined && params.sessionKey) {
    source.sessionKey = params.sessionKey;
  }
  return Object.keys(source).length > 0 ? source : undefined;
}

function buildOrderPayload(params: {
  toolArgs: Record<string, unknown>;
  requesterAgentId?: string;
  channel?: GatewayMessageChannel;
  groupId?: string | null;
  groupSpace?: string | null;
  requesterSenderId?: string | null;
  sessionKey?: string;
}) {
  const inlineOrder = parseLooseObject(params.toolArgs.order, "order");
  const order = inlineOrder ?? {};

  if (!inlineOrder) {
    const name = readStringParam(params.toolArgs, "name");
    const modelName = readStringParam(params.toolArgs, "modelName");
    const messages = params.toolArgs.messages;
    if (!name || !modelName || !Array.isArray(messages)) {
      throw new ToolInputError("order.submit requires order object or name + modelName + messages");
    }
    order.name = name;
    order.modelName = modelName;
    order.messages = messages;
  }

  if (order.requestId === undefined) {
    const requestId = readStringParam(params.toolArgs, "requestId");
    if (requestId) {
      order.requestId = requestId;
    }
  }
  if (order.submittedBy === undefined) {
    const submittedBy =
      readStringParam(params.toolArgs, "submittedBy") ??
      (params.requesterAgentId ? `agent:${params.requesterAgentId}` : undefined);
    if (submittedBy) {
      order.submittedBy = submittedBy;
    }
  }

  if (order.source === undefined) {
    order.source = parseLooseObject(params.toolArgs.source, "source");
  }
  order.source = withSourceDefaults({
    source: parseLooseObject(order.source, "order.source"),
    channel: params.channel,
    groupId: params.groupId,
    groupSpace: params.groupSpace,
    requesterSenderId: params.requesterSenderId,
    sessionKey: params.sessionKey,
  });

  const optionalKeys = ["tools", "requirements", "priority", "syncWaitMs"] as const;
  for (const key of optionalKeys) {
    if (order[key] === undefined && params.toolArgs[key] !== undefined) {
      order[key] = params.toolArgs[key];
    }
  }

  return order;
}

function buildBatchPayload(params: {
  toolArgs: Record<string, unknown>;
  requesterAgentId?: string;
  channel?: GatewayMessageChannel;
  groupId?: string | null;
  groupSpace?: string | null;
  requesterSenderId?: string | null;
  sessionKey?: string;
}) {
  const inlineBatch = parseLooseObject(params.toolArgs.batch, "batch");
  const batch = inlineBatch ?? {};

  if (!inlineBatch) {
    const name = readStringParam(params.toolArgs, "name");
    const modelName = readStringParam(params.toolArgs, "modelName");
    const messages = params.toolArgs.messages;
    const parallel = readNumberParam(params.toolArgs, "parallel", { integer: true });
    if (!name || !modelName || !Array.isArray(messages) || !parallel || parallel < 1) {
      throw new ToolInputError(
        "batch.submit requires batch object or name + modelName + messages + parallel>=1",
      );
    }
    batch.name = name;
    batch.modelName = modelName;
    batch.messages = messages;
    batch.parallel = parallel;
  }

  if (batch.requestId === undefined) {
    const requestId = readStringParam(params.toolArgs, "requestId");
    if (requestId) {
      batch.requestId = requestId;
    }
  }
  if (batch.submittedBy === undefined) {
    const submittedBy =
      readStringParam(params.toolArgs, "submittedBy") ??
      (params.requesterAgentId ? `agent:${params.requesterAgentId}` : undefined);
    if (submittedBy) {
      batch.submittedBy = submittedBy;
    }
  }

  if (batch.source === undefined) {
    batch.source = parseLooseObject(params.toolArgs.source, "source");
  }
  batch.source = withSourceDefaults({
    source: parseLooseObject(batch.source, "batch.source"),
    channel: params.channel,
    groupId: params.groupId,
    groupSpace: params.groupSpace,
    requesterSenderId: params.requesterSenderId,
    sessionKey: params.sessionKey,
  });

  const optionalKeys = ["tools", "requirements", "priority"] as const;
  for (const key of optionalKeys) {
    if (batch[key] === undefined && params.toolArgs[key] !== undefined) {
      batch[key] = params.toolArgs[key];
    }
  }

  return batch;
}

function describeErrorPayload(value: unknown, fallback: string): string {
  if (typeof value === "string" && value.trim()) {
    return value;
  }
  if (value instanceof Error && value.message.trim()) {
    return value.message;
  }
  return fallback;
}

async function smartdustRequest(params: {
  options: SmartdustCallOptions;
  method: "GET" | "POST" | "DELETE";
  path: string;
  query?: Record<string, string | number | boolean | undefined>;
  body?: unknown;
}) {
  const url = new URL(
    params.path,
    params.options.baseUrl.endsWith("/") ? params.options.baseUrl : `${params.options.baseUrl}/`,
  );
  if (params.query) {
    for (const [key, value] of Object.entries(params.query)) {
      if (value === undefined) {
        continue;
      }
      url.searchParams.set(key, String(value));
    }
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), params.options.timeoutMs);
  try {
    const headers: Record<string, string> = {};
    if (params.options.apiKey) {
      headers.Authorization = `Bearer ${params.options.apiKey}`;
    }
    if (params.body !== undefined) {
      headers["Content-Type"] = "application/json";
    }

    const res = await fetch(url, {
      method: params.method,
      headers,
      body: params.body !== undefined ? JSON.stringify(params.body) : undefined,
      signal: controller.signal,
    });

    const contentType = res.headers.get("content-type") ?? "";
    const payload = contentType.includes("application/json") ? await res.json() : await res.text();

    if (!res.ok) {
      const message =
        payload && typeof payload === "object" && !Array.isArray(payload)
          ? describeErrorPayload(
              (payload as { error?: unknown }).error,
              `${res.status} ${res.statusText}`,
            )
          : `${res.status} ${res.statusText}`;
      throw new Error(`Smartdust request failed: ${message}`);
    }
    return payload;
  } catch (error) {
    if ((error as { name?: string })?.name === "AbortError") {
      throw new Error(`Smartdust request timed out after ${params.options.timeoutMs}ms`, {
        cause: error,
      });
    }
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

export function createSmartdustTool(opts?: {
  agentSessionKey?: string;
  requesterAgentId?: string;
  agentChannel?: GatewayMessageChannel;
  agentGroupId?: string | null;
  agentGroupSpace?: string | null;
  requesterSenderId?: string | null;
}): AnyAgentTool {
  return {
    label: "Smartdust",
    name: "smartdust",
    ownerOnly: true,
    description:
      "Submit and monitor Smartdust orders/batches. Defaults to fire-and-return semantics while attaching request metadata (requestId/submittedBy/source) from session context.",
    parameters: SmartdustToolSchema,
    execute: async (_toolCallId, args) => {
      const params = args as Record<string, unknown>;
      const action = readStringParam(params, "action", { required: true });
      const callOptions = resolveSmartdustCallOptions(params);
      const verbose = params.verbose === true;

      if (action === "fleet.status") {
        const result = await smartdustRequest({
          options: callOptions,
          method: "GET",
          path: "/api/fleet/machines",
        });
        return jsonResult({ ok: true, action, result });
      }

      if (action === "order.submit") {
        const payload = buildOrderPayload({
          toolArgs: params,
          requesterAgentId: opts?.requesterAgentId,
          channel: opts?.agentChannel,
          groupId: opts?.agentGroupId,
          groupSpace: opts?.agentGroupSpace,
          requesterSenderId: opts?.requesterSenderId,
          sessionKey: opts?.agentSessionKey,
        });
        const result = await smartdustRequest({
          options: callOptions,
          method: "POST",
          path: "/api/orders",
          body: payload,
          query: verbose ? { verbose: true } : undefined,
        });
        return jsonResult({ ok: true, action, result });
      }

      if (action === "order.get") {
        const orderId = readStringParam(params, "orderId", { required: true });
        const result = await smartdustRequest({
          options: callOptions,
          method: "GET",
          path: `/api/orders/${encodeURIComponent(orderId)}`,
          query: verbose ? { verbose: true } : undefined,
        });
        return jsonResult({ ok: true, action, result });
      }

      if (action === "order.list") {
        const status = readStringParam(params, "status");
        const result = await smartdustRequest({
          options: callOptions,
          method: "GET",
          path: "/api/orders",
          query: {
            status,
            verbose: verbose ? true : undefined,
          },
        });
        return jsonResult({ ok: true, action, result });
      }

      if (action === "order.cancel") {
        const orderId = readStringParam(params, "orderId", { required: true });
        const result = await smartdustRequest({
          options: callOptions,
          method: "DELETE",
          path: `/api/orders/${encodeURIComponent(orderId)}`,
        });
        return jsonResult({ ok: true, action, result });
      }

      if (action === "batch.submit") {
        const payload = buildBatchPayload({
          toolArgs: params,
          requesterAgentId: opts?.requesterAgentId,
          channel: opts?.agentChannel,
          groupId: opts?.agentGroupId,
          groupSpace: opts?.agentGroupSpace,
          requesterSenderId: opts?.requesterSenderId,
          sessionKey: opts?.agentSessionKey,
        });
        const result = await smartdustRequest({
          options: callOptions,
          method: "POST",
          path: "/api/batches",
          body: payload,
          query: verbose ? { verbose: true } : undefined,
        });
        return jsonResult({ ok: true, action, result });
      }

      if (action === "batch.get") {
        const batchId = readStringParam(params, "batchId", { required: true });
        const result = await smartdustRequest({
          options: callOptions,
          method: "GET",
          path: `/api/batches/${encodeURIComponent(batchId)}`,
          query: verbose ? { verbose: true } : undefined,
        });
        return jsonResult({ ok: true, action, result });
      }

      if (action === "stats") {
        const result = await smartdustRequest({
          options: callOptions,
          method: "GET",
          path: "/api/stats",
        });
        return jsonResult({ ok: true, action, result });
      }

      throw new ToolInputError(`unsupported action: ${action}`);
    },
  };
}
