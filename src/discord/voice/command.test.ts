import { describe, expect, it, vi } from "vitest";
import type { OpenClawConfig } from "../../config/config.js";
import type { DiscordAccountConfig } from "../../config/types.js";
import { createDiscordVoiceCommand } from "./command.js";

describe("createDiscordVoiceCommand", () => {
  it("replies with an access error when join channel resolution throws", async () => {
    const command = createDiscordVoiceCommand({
      cfg: {} as OpenClawConfig,
      discordConfig: {} as DiscordAccountConfig,
      accountId: "default",
      groupPolicy: "allowlist",
      useAccessGroups: true,
      getManager: () => null,
      ephemeralDefault: true,
    });

    const join = (
      command.subcommands as Array<{ name: string; run: (i: unknown) => Promise<void> }>
    ).find((subcommand) => subcommand.name === "join");
    expect(join).toBeDefined();

    const reply = vi.fn(async () => undefined);
    const interaction = {
      options: {
        getChannel: vi.fn(async () => {
          throw new Error("Missing Access");
        }),
      },
      reply,
    };

    await join!.run(interaction);

    expect(reply).toHaveBeenCalledWith({
      content: "Unable to access that voice channel (Missing Access).",
      ephemeral: true,
    });
  });
});
