import type { CommandInteraction, CommandWithSubcommands } from "@buape/carbon";
import { describe, expect, it, vi } from "vitest";
import { createDiscordVoiceCommand } from "./command.js";
import type { DiscordVoiceManager } from "./manager.js";

function findVoiceSubcommand(command: CommandWithSubcommands, name: string) {
  const subcommands = (
    command as unknown as { subcommands?: Array<{ name: string; run: unknown }> }
  ).subcommands;
  const subcommand = subcommands?.find((entry) => entry.name === name) as
    | { run: (interaction: CommandInteraction) => Promise<void> }
    | undefined;
  if (!subcommand) {
    throw new Error(`Missing vc ${name} subcommand`);
  }
  return subcommand;
}

function createVoiceCommandHarness(params?: {
  manager?: DiscordVoiceManager | null;
  groupPolicy?: "open" | "disabled" | "allowlist";
  useAccessGroups?: boolean;
}) {
  const command = createDiscordVoiceCommand({
    cfg: {},
    discordConfig: {},
    accountId: "default",
    groupPolicy: params?.groupPolicy ?? "allowlist",
    useAccessGroups: params?.useAccessGroups ?? true,
    getManager: () => params?.manager ?? null,
    ephemeralDefault: true,
  });
  return {
    command,
    join: findVoiceSubcommand(command, "join"),
    leave: findVoiceSubcommand(command, "leave"),
    status: findVoiceSubcommand(command, "status"),
  };
}

function createInteraction(overrides?: Partial<CommandInteraction>): {
  interaction: CommandInteraction;
  reply: ReturnType<typeof vi.fn>;
} {
  const reply = vi.fn(async () => undefined);
  const interaction = {
    guild: undefined,
    user: { id: "u1", username: "tester" },
    rawData: { member: { roles: [] } },
    reply,
    ...overrides,
  } as unknown as CommandInteraction;
  return { interaction, reply };
}

describe("createDiscordVoiceCommand", () => {
  it("replies with an access error when join channel resolution throws", async () => {
    const { join } = createVoiceCommandHarness();
    const { interaction, reply } = createInteraction({
      options: {
        getChannel: vi.fn(async () => {
          throw new Error("Missing Access");
        }),
      } as unknown as CommandInteraction["options"],
    });

    await join.run(interaction);

    expect(reply).toHaveBeenCalledTimes(1);
    expect(reply).toHaveBeenCalledWith({
      content: "Unable to access that voice channel (Missing Access).",
      ephemeral: true,
    });
  });

  it("vc leave reports missing guild before manager lookup", async () => {
    const { leave } = createVoiceCommandHarness();
    const { interaction, reply } = createInteraction();

    await leave.run(interaction);

    expect(reply).toHaveBeenCalledTimes(1);
    expect(reply).toHaveBeenCalledWith({
      content: "Unable to resolve guild for this command.",
      ephemeral: true,
    });
  });

  it("vc status reports unavailable voice manager", async () => {
    const { status } = createVoiceCommandHarness();
    const { interaction, reply } = createInteraction({
      guild: { id: "g1" } as CommandInteraction["guild"],
    });

    await status.run(interaction);

    expect(reply).toHaveBeenCalledTimes(1);
    expect(reply).toHaveBeenCalledWith({
      content: "Voice manager is not available yet.",
      ephemeral: true,
    });
  });

  it("vc status reports no active sessions when manager has none", async () => {
    const statusSpy = vi.fn(() => []);
    const manager = {
      status: statusSpy,
    } as unknown as DiscordVoiceManager;
    const { status } = createVoiceCommandHarness({
      manager,
      groupPolicy: "open",
      useAccessGroups: false,
    });
    const { interaction, reply } = createInteraction({
      guild: { id: "g1", name: "Guild" } as CommandInteraction["guild"],
    });

    await status.run(interaction);

    expect(statusSpy).toHaveBeenCalledTimes(1);
    expect(reply).toHaveBeenCalledTimes(1);
    expect(reply).toHaveBeenCalledWith({
      content: "No active voice sessions.",
      ephemeral: true,
    });
  });
});
