import type { User } from "@buape/carbon";
import { describe, expect, it } from "vitest";
import { resolveDiscordSenderIdentity } from "./sender-identity.js";

describe("slash command user resolution", () => {
  const testUserId = "225674175312953344";
  const testUsername = "testuser";

  it("should extract user from interaction.member.user in guild contexts", () => {
    // Simulate a guild interaction (like in a forum thread)
    const mockGuildInteraction = {
      user: undefined, // In guild contexts, this may be undefined or incomplete
      member: {
        user: {
          id: testUserId,
          username: testUsername,
        } as User,
        nickname: null,
      },
    };

    // This is what the fix should do: prefer interaction.member.user
    const user = mockGuildInteraction.member?.user ?? mockGuildInteraction.user;

    expect(user).toBeDefined();
    expect(user?.id).toBe(testUserId);

    // Verify the sender identity resolution works correctly
    const sender = resolveDiscordSenderIdentity({
      author: user!,
      member: mockGuildInteraction.member,
      pluralkitInfo: null,
    });

    expect(sender.id).toBe(testUserId);
    expect(sender.name).toBe(testUsername);
  });

  it("should fallback to interaction.user in DM contexts", () => {
    // Simulate a DM interaction
    const mockDmInteraction = {
      user: {
        id: testUserId,
        username: testUsername,
      } as User,
      member: undefined, // No member in DM contexts
    };

    // This is what the fix should do: fallback to interaction.user when member is undefined
    const user = mockDmInteraction.member?.user ?? mockDmInteraction.user;

    expect(user).toBeDefined();
    expect(user?.id).toBe(testUserId);

    // Verify the sender identity resolution works correctly
    const sender = resolveDiscordSenderIdentity({
      author: user!,
      member: mockDmInteraction.member,
      pluralkitInfo: null,
    });

    expect(sender.id).toBe(testUserId);
    expect(sender.name).toBe(testUsername);
  });

  it("should return undefined when both user sources are unavailable", () => {
    const mockBrokenInteraction = {
      user: undefined,
      member: undefined,
    };

    const user = mockBrokenInteraction.member?.user ?? mockBrokenInteraction.user;

    expect(user).toBeUndefined();
  });
});
