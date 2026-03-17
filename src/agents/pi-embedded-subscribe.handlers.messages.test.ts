import { describe, expect, it } from "vitest";
import {
  filterAlreadySentBlockReplyMediaUrls,
  resolveSilentReplyFallbackText,
} from "./pi-embedded-subscribe.handlers.messages.js";

describe("resolveSilentReplyFallbackText", () => {
  it("replaces NO_REPLY with latest messaging tool text when available", () => {
    expect(
      resolveSilentReplyFallbackText({
        text: "NO_REPLY",
        messagingToolSentTexts: ["first", "final delivered text"],
      }),
    ).toBe("final delivered text");
  });

  it("keeps original text when response is not NO_REPLY", () => {
    expect(
      resolveSilentReplyFallbackText({
        text: "normal assistant reply",
        messagingToolSentTexts: ["final delivered text"],
      }),
    ).toBe("normal assistant reply");
  });

  it("keeps NO_REPLY when there is no messaging tool text to mirror", () => {
    expect(
      resolveSilentReplyFallbackText({
        text: "NO_REPLY",
        messagingToolSentTexts: [],
      }),
    ).toBe("NO_REPLY");
  });
});

describe("filterAlreadySentBlockReplyMediaUrls", () => {
  it("strips duplicate block-reply media while preserving unsent entries", () => {
    expect(
      filterAlreadySentBlockReplyMediaUrls({
        mediaUrls: ["/tmp/a.png", "file:///tmp/b.png", "/tmp/c.png"],
        sentMediaUrls: ["file:///tmp/a.png", "/tmp/b.png"],
      }),
    ).toEqual(["/tmp/c.png"]);
  });

  it("returns undefined when all block-reply media were already sent", () => {
    expect(
      filterAlreadySentBlockReplyMediaUrls({
        mediaUrls: ["/tmp/a.png"],
        sentMediaUrls: ["file:///tmp/a.png"],
      }),
    ).toBeUndefined();
  });

  it("keeps media list unchanged when no sent-media state exists", () => {
    expect(
      filterAlreadySentBlockReplyMediaUrls({
        mediaUrls: ["/tmp/a.png", "/tmp/b.png"],
        sentMediaUrls: [],
      }),
    ).toEqual(["/tmp/a.png", "/tmp/b.png"]);
  });
});
