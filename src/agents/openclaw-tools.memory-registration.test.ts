import { describe, expect, it } from "vitest";
import type { OpenClawConfig } from "../config/config.js";
import { createOpenClawTools } from "./openclaw-tools.js";

describe("createOpenClawTools memory registration", () => {
  it("includes memory tools when config is available", () => {
    const cfg = {} as OpenClawConfig;
    const tools = createOpenClawTools({
      config: cfg,
      agentSessionKey: "agent:main:discord:channel:test",
    });
    const names = new Set(tools.map((tool) => tool.name));
    expect(names.has("memory_search")).toBe(true);
    expect(names.has("memory_get")).toBe(true);
  });
});
