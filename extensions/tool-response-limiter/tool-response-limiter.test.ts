import type { AgentMessage } from "@mariozechner/pi-agent-core";
import { describe, expect, it, vi } from "vitest";
import { createToolResponseLimiterTransform } from "./tool-response-limiter.js";

type ToolResultMessage = Extract<AgentMessage, { role: "toolResult" }>;

function toolResultMessage(
  id: string,
  text: string,
  details?: Record<string, unknown>,
): ToolResultMessage {
  return {
    role: "toolResult",
    toolCallId: id,
    isError: false,
    content: [{ type: "text", text }],
    ...(details ? { details } : {}),
  } as ToolResultMessage;
}

describe("tool-response-limiter plugin", () => {
  it("persists large tool responses unchanged when no limiter hook is active", () => {
    const largeContent = "x".repeat(200_000);
    const message = toolResultMessage("call_1", largeContent, { metadata: "some data" });

    const persistedSize = JSON.stringify(message).length;
    expect(persistedSize).toBeGreaterThan(150_000);
    expect(message.content[0]?.type).toBe("text");
    expect(message.content[0] && "text" in message.content[0] ? message.content[0].text : "").toBe(
      largeContent,
    );
  });

  it("truncates large tool responses to configured limit", () => {
    const logger = { info: vi.fn() };
    const transform = createToolResponseLimiterTransform(
      { maxResponseSizeKb: 30, exemptTools: [] },
      logger,
    );

    const largeContent = "x".repeat(200_000);
    const toolResult = transform?.({
      toolName: "read",
      message: toolResultMessage("call_1", largeContent, {
        metadata: "some data",
        bigPayload: "y".repeat(10_000),
      }),
    })?.message;

    expect(toolResult).toBeTruthy();
    const persistedSize = JSON.stringify(toolResult).length;
    expect(persistedSize).toBeLessThan(30 * 1024 * 1.5);
    expect(toolResult?.content[0]?.type).toBe("text");
    const text =
      toolResult?.content[0] && "text" in toolResult.content[0] ? toolResult.content[0].text : "";
    expect(text).toContain("[Response truncated from");
    expect(text.length).toBeLessThan(largeContent.length);
    expect(toolResult?.details?._truncated).toBe(true);
    expect(toolResult?.details?.bigPayload).toBeUndefined();
  });

  it("respects exemptTools configuration", () => {
    const logger = { info: vi.fn() };
    const transform = createToolResponseLimiterTransform(
      { maxResponseSizeKb: 30, exemptTools: ["screenshot", "image"] },
      logger,
    );

    const exempt = transform?.({
      toolName: "screenshot",
      message: toolResultMessage("call_1", "x".repeat(200_000)),
    });
    const limited = transform?.({
      toolName: "read",
      message: toolResultMessage("call_2", "y".repeat(200_000)),
    });

    expect(exempt).toBeUndefined();
    expect(limited?.message).toBeTruthy();
  });

  it("does nothing when disabled", () => {
    const logger = { info: vi.fn() };
    const transform = createToolResponseLimiterTransform({ enabled: false }, logger);

    expect(transform).toBeUndefined();
    expect(logger.info).toHaveBeenCalledWith("[tool-response-limiter] Plugin is disabled");
  });
});
