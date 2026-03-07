import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { OpenClawPluginDefinition } from "../../src/plugins/types.js";

/**
 * Tool Response Limiter Plugin
 *
 * This plugin hooks into tool_result_persist to enforce size limits on tool responses.
 * Large responses are truncated with a clear message indicating the original and truncated sizes.
 *
 * Configuration:
 * - enabled: Enable/disable the plugin (default: true)
 * - maxResponseSizeKb: Maximum size in KB (default: 30)
 * - exemptTools: Array of tool names to exempt from limits (default: [])
 */

type PluginConfig = {
  enabled?: boolean;
  maxResponseSizeKb?: number;
  exemptTools?: string[];
};

type ToolResultMessage = Extract<AgentMessage, { role: "toolResult" }>;
type TextBlock = Extract<ToolResultMessage["content"][number], { type: "text" }>;
type PluginLogger = { info: (message: string) => void };

/**
 * Serialize a message to JSON and get its byte size
 */
function getMessageSize(message: unknown): number {
  try {
    return new TextEncoder().encode(JSON.stringify(message)).length;
  } catch {
    return 0;
  }
}

/**
 * Truncate message content to fit within size limit
 */
function truncateMessage(
  message: ToolResultMessage,
  maxBytes: number,
  originalSize: number,
): ToolResultMessage {
  const truncationMessage = `[Response truncated from ${formatBytes(originalSize)} to ~${formatBytes(maxBytes)}]`;

  // Try to preserve the message structure while truncating content
  const truncated = { ...message };

  // If there's text content, truncate it
  const textBlocks = truncated.content.filter((c): c is TextBlock => c.type === "text");
  if (textBlocks.length > 0) {
    const nonTextContent = truncated.content.filter((c) => c.type !== "text");
    const overhead = getMessageSize({ ...truncated, content: nonTextContent });
    const availableForText = Math.max(0, maxBytes - overhead - truncationMessage.length - 100); // 100 byte buffer

    // Truncate the first text block
    const firstText = textBlocks[0];
    const truncatedText = firstText.text.substring(0, availableForText);

    truncated.content = [
      ...nonTextContent,
      {
        type: "text",
        text: truncatedText + "\n\n" + truncationMessage,
      },
    ];
  }

  // Remove or truncate large details objects
  if (truncated.details) {
    truncated.details = {
      _truncated: true,
      _note: "Details removed due to size constraints",
    };
  }

  return truncated;
}

/**
 * Format bytes into human-readable string
 */
function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} bytes`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function isToolResultMessage(message: AgentMessage): message is ToolResultMessage {
  return message.role === "toolResult";
}

export function createToolResponseLimiterTransform(config: PluginConfig, logger: PluginLogger) {
  const enabled = config.enabled !== false;
  const maxResponseSizeKb = config.maxResponseSizeKb || 30;
  const exemptTools = new Set(config.exemptTools || []);
  const maxBytes = maxResponseSizeKb * 1024;

  if (!enabled) {
    logger.info("[tool-response-limiter] Plugin is disabled");
    return undefined;
  }

  logger.info(
    `[tool-response-limiter] Registered with ${maxResponseSizeKb}KB limit` +
      (exemptTools.size > 0 ? `, exempt tools: ${Array.from(exemptTools).join(", ")}` : ""),
  );

  return (event: { toolName?: string; message: AgentMessage }) => {
    const { toolName, message } = event;
    if (!isToolResultMessage(message)) {
      return;
    }
    if (toolName && exemptTools.has(toolName)) {
      return;
    }

    const messageSize = getMessageSize(message);
    if (messageSize > maxBytes) {
      logger.info(
        `[tool-response-limiter] Truncating ${toolName || "unknown"} response: ` +
          `${formatBytes(messageSize)} -> ${formatBytes(maxBytes)}`,
      );
      return {
        message: truncateMessage(message, maxBytes, messageSize),
      };
    }
    return;
  };
}

const plugin: OpenClawPluginDefinition = {
  id: "tool-response-limiter",

  register(api) {
    const config = (api.pluginConfig ?? {}) as PluginConfig;
    const transform = createToolResponseLimiterTransform(config, api.logger);
    if (!transform) {
      return;
    }

    api.on(
      "tool_result_persist",
      (event) => {
        return transform(event);
      },
      { priority: 100 }, // High priority to run before other transforms
    );
  },
};

export default plugin;
