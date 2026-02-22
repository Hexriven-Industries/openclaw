import { beforeEach, describe, expect, it, vi } from "vitest";

const mockResolveAgentRoute = vi.fn();
const mockJoinVoiceChannel = vi.fn();
const mockEntersState = vi.fn();
const mockCreateAudioPlayer = vi.fn();

vi.mock("../../routing/resolve-route.js", () => ({
  resolveAgentRoute: mockResolveAgentRoute,
}));

vi.mock("@discordjs/voice", () => ({
  AudioPlayerStatus: { Playing: "playing", Idle: "idle" },
  EndBehaviorType: { AfterSilence: "AfterSilence" },
  VoiceConnectionStatus: {
    Ready: "ready",
    Disconnected: "disconnected",
    Signalling: "signalling",
    Connecting: "connecting",
    Destroyed: "destroyed",
  },
  joinVoiceChannel: mockJoinVoiceChannel,
  entersState: mockEntersState,
  createAudioPlayer: mockCreateAudioPlayer,
  createAudioResource: vi.fn(),
}));

describe("DiscordVoiceManager.join", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("cleans up connection when post-connect setup fails", async () => {
    const connection = {
      receiver: { speaking: { on: vi.fn() } },
      on: vi.fn(),
      subscribe: vi.fn(),
      destroy: vi.fn(),
    };
    const player = {
      stop: vi.fn(),
      on: vi.fn(),
      play: vi.fn(),
    };
    mockJoinVoiceChannel.mockReturnValue(connection);
    mockEntersState.mockResolvedValue(undefined);
    mockCreateAudioPlayer.mockReturnValue(player);
    mockResolveAgentRoute.mockImplementation(() => {
      throw new Error("route failed");
    });

    const { DiscordVoiceManager } = await import("./manager.js");
    const manager = new DiscordVoiceManager({
      client: {
        fetchChannel: vi.fn(async () => ({
          id: "1456457229430685750",
          type: 2,
          guildId: "1456457228734435391",
        })),
        getPlugin: vi.fn(() => ({
          getGatewayAdapterCreator: () => vi.fn(),
        })),
      } as never,
      cfg: {} as never,
      discordConfig: { voice: { enabled: true } } as never,
      accountId: "default",
      runtime: {} as never,
    });

    const result = await manager.join({
      guildId: "1456457228734435391",
      channelId: "1456457229430685750",
    });

    expect(result.ok).toBe(false);
    expect(result.message).toContain("Failed to join voice channel: route failed");
    expect(connection.destroy).toHaveBeenCalledTimes(1);
    expect(manager.status()).toEqual([]);
  });
});
