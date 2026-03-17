import type { OpenClawConfig } from "../../../config/config.js";
import {
  getThreadBindingManager,
  type ThreadBindingRecord,
} from "../../../discord/monitor/thread-bindings.js";
import {
  sendMessageDiscord,
  sendPollDiscord,
  sendWebhookMessageDiscord,
} from "../../../discord/send.js";
import { isTruthyEnvValue } from "../../../infra/env.js";
import type { OutboundIdentity } from "../../../infra/outbound/identity.js";
import { createSubsystemLogger } from "../../../logging/subsystem.js";
import { normalizeDiscordOutboundTarget } from "../normalize/discord.js";
import type { ChannelOutboundAdapter } from "../types.js";
import { sendTextMediaPayload } from "./direct-text-media.js";

const outboundLog = createSubsystemLogger("discord/delivery-debug");

function logDiscordOutboundDebug(message: string, meta?: Record<string, unknown>) {
  if (!isTruthyEnvValue(process.env.OPENCLAW_DISCORD_DELIVERY_DEBUG)) {
    return;
  }
  outboundLog.debug(message, meta);
}

function resolveDiscordOutboundTarget(params: {
  to: string;
  threadId?: string | number | null;
}): string {
  if (params.threadId == null) {
    return params.to;
  }
  const threadId = String(params.threadId).trim();
  if (!threadId) {
    return params.to;
  }
  return `channel:${threadId}`;
}

function resolveDiscordWebhookIdentity(params: {
  identity?: OutboundIdentity;
  binding: ThreadBindingRecord;
}): { username?: string; avatarUrl?: string } {
  const usernameRaw = params.identity?.name?.trim();
  const fallbackUsername = params.binding.label?.trim() || params.binding.agentId;
  const username = (usernameRaw || fallbackUsername || "").slice(0, 80) || undefined;
  const avatarUrl = params.identity?.avatarUrl?.trim() || undefined;
  return { username, avatarUrl };
}

async function maybeSendDiscordWebhookText(params: {
  cfg?: OpenClawConfig;
  text: string;
  threadId?: string | number | null;
  accountId?: string | null;
  identity?: OutboundIdentity;
  replyToId?: string | null;
}): Promise<{ messageId: string; channelId: string } | null> {
  if (params.threadId == null) {
    return null;
  }
  const threadId = String(params.threadId).trim();
  if (!threadId) {
    return null;
  }
  const manager = getThreadBindingManager(params.accountId ?? undefined);
  if (!manager) {
    return null;
  }
  const binding = manager.getByThreadId(threadId);
  if (!binding?.webhookId || !binding?.webhookToken) {
    return null;
  }
  const persona = resolveDiscordWebhookIdentity({
    identity: params.identity,
    binding,
  });
  const result = await sendWebhookMessageDiscord(params.text, {
    webhookId: binding.webhookId,
    webhookToken: binding.webhookToken,
    accountId: binding.accountId,
    threadId: binding.threadId,
    cfg: params.cfg,
    replyTo: params.replyToId ?? undefined,
    username: persona.username,
    avatarUrl: persona.avatarUrl,
  });
  logDiscordOutboundDebug("discord outbound webhook text success", {
    threadId,
    accountId: params.accountId,
    replyToId: params.replyToId,
    messageId: result.messageId,
    channelId: result.channelId,
  });
  return result;
}

export const discordOutbound: ChannelOutboundAdapter = {
  deliveryMode: "direct",
  chunker: null,
  textChunkLimit: 2000,
  pollMaxOptions: 10,
  resolveTarget: ({ to }) => normalizeDiscordOutboundTarget(to),
  sendPayload: async (ctx) =>
    await sendTextMediaPayload({ channel: "discord", ctx, adapter: discordOutbound }),
  sendText: async ({ cfg, to, text, accountId, deps, replyToId, threadId, identity, silent }) => {
    if (!silent) {
      const webhookResult = await maybeSendDiscordWebhookText({
        cfg,
        text,
        threadId,
        accountId,
        identity,
        replyToId,
      }).catch(() => null);
      if (webhookResult) {
        logDiscordOutboundDebug("discord outbound sendText used webhook", {
          to,
          threadId,
          accountId,
          replyToId,
          messageId: webhookResult.messageId,
          channelId: webhookResult.channelId,
        });
        return { channel: "discord", ...webhookResult };
      }
    }
    const send = deps?.sendDiscord ?? sendMessageDiscord;
    const target = resolveDiscordOutboundTarget({ to, threadId });
    const result = await send(target, text, {
      verbose: false,
      replyTo: replyToId ?? undefined,
      accountId: accountId ?? undefined,
      silent: silent ?? undefined,
      cfg,
    });
    logDiscordOutboundDebug("discord outbound sendText used bot send", {
      to,
      target,
      threadId,
      accountId,
      replyToId,
      messageId: result.messageId,
      channelId: result.channelId,
    });
    return { channel: "discord", ...result };
  },
  sendMedia: async ({
    cfg,
    to,
    text,
    mediaUrl,
    mediaLocalRoots,
    accountId,
    deps,
    replyToId,
    threadId,
    silent,
  }) => {
    const send = deps?.sendDiscord ?? sendMessageDiscord;
    const target = resolveDiscordOutboundTarget({ to, threadId });
    const result = await send(target, text, {
      verbose: false,
      mediaUrl,
      mediaLocalRoots,
      replyTo: replyToId ?? undefined,
      accountId: accountId ?? undefined,
      silent: silent ?? undefined,
      cfg,
    });
    logDiscordOutboundDebug("discord outbound sendMedia used bot send", {
      to,
      target,
      threadId,
      accountId,
      replyToId,
      mediaUrl,
      messageId: result.messageId,
      channelId: result.channelId,
    });
    return { channel: "discord", ...result };
  },
  sendPoll: async ({ cfg, to, poll, accountId, threadId, silent }) => {
    const target = resolveDiscordOutboundTarget({ to, threadId });
    return await sendPollDiscord(target, poll, {
      accountId: accountId ?? undefined,
      silent: silent ?? undefined,
      cfg,
    });
  },
};
