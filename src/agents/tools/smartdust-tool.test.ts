import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createSmartdustTool } from "./smartdust-tool.js";

describe("smartdust tool", () => {
  const originalFetch = globalThis.fetch;
  const originalBase = process.env.SMARTDUST_BASE_URL;
  const originalKey = process.env.SMARTDUST_API_KEY;

  beforeEach(() => {
    process.env.SMARTDUST_BASE_URL = "http://127.0.0.1:7777";
    process.env.SMARTDUST_API_KEY = "test-key";
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    process.env.SMARTDUST_BASE_URL = originalBase;
    process.env.SMARTDUST_API_KEY = originalKey;
    vi.restoreAllMocks();
  });

  it("order.submit injects submittedBy/source defaults from context", async () => {
    const fetchMock = vi.fn(
      async () =>
        new Response(JSON.stringify({ ok: true, orderId: "ord_1" }), {
          status: 201,
          headers: { "Content-Type": "application/json" },
        }),
    );
    globalThis.fetch = fetchMock as unknown as typeof fetch;

    const tool = createSmartdustTool({
      requesterAgentId: "main",
      agentChannel: "discord",
      agentGroupId: "1474051914311274591",
      agentGroupSpace: "1456457228734435391",
      requesterSenderId: "225674175312953344",
      agentSessionKey: "agent:main:discord:channel:1474051914311274591",
    });

    const result = await tool.execute("call_1", {
      action: "order.submit",
      name: "render-test",
      modelName: "qwen3:0.6b",
      messages: [{ role: "user", content: "hi" }],
      requestId: "req-1",
    });

    expect(result.details).toMatchObject({
      ok: true,
      action: "order.submit",
      result: { ok: true, orderId: "ord_1" },
    });

    const [urlArg, initArg] = fetchMock.mock.calls[0] as unknown as [URL, RequestInit];
    expect(urlArg.toString()).toBe("http://127.0.0.1:7777/api/orders");
    expect(initArg.method).toBe("POST");
    expect(typeof initArg.body).toBe("string");
    const body = JSON.parse(initArg.body as string) as Record<string, unknown>;
    expect(body.submittedBy).toBe("agent:main");
    expect(body.source).toMatchObject({
      channel: "discord",
      channelId: "1474051914311274591",
      guildId: "1456457228734435391",
      requesterId: "225674175312953344",
      sessionKey: "agent:main:discord:channel:1474051914311274591",
    });
  });

  it("order.get sends verbose query when requested", async () => {
    const fetchMock = vi.fn(
      async () =>
        new Response(JSON.stringify({ ok: true, status: "completed" }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
    );
    globalThis.fetch = fetchMock as unknown as typeof fetch;

    const tool = createSmartdustTool();
    await tool.execute("call_2", {
      action: "order.get",
      orderId: "ord_abc",
      verbose: true,
    });

    const [urlArg] = fetchMock.mock.calls[0] as unknown as [URL, RequestInit];
    expect(urlArg.toString()).toBe("http://127.0.0.1:7777/api/orders/ord_abc?verbose=true");
  });

  it("order.list forwards status filter", async () => {
    const fetchMock = vi.fn(
      async () =>
        new Response(JSON.stringify([{ orderId: "ord_1" }]), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }),
    );
    globalThis.fetch = fetchMock as unknown as typeof fetch;

    const tool = createSmartdustTool();
    await tool.execute("call_3", {
      action: "order.list",
      status: "running",
    });

    const [urlArg] = fetchMock.mock.calls[0] as unknown as [URL, RequestInit];
    expect(urlArg.toString()).toBe("http://127.0.0.1:7777/api/orders?status=running");
  });

  it("order.submit rejects when required fields are missing", async () => {
    const tool = createSmartdustTool();
    await expect(
      tool.execute("call_4", {
        action: "order.submit",
        name: "missing-model-and-messages",
      }),
    ).rejects.toThrow(/order.submit requires order object or name \+ modelName \+ messages/i);
  });
});
