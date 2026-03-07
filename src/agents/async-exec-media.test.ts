import { beforeEach, describe, expect, it } from "vitest";
import {
  drainAsyncExecMedia,
  enqueueAsyncExecMediaFromOutput,
  peekAsyncExecMedia,
  resetAsyncExecMediaForTest,
} from "./async-exec-media.js";

describe("async exec media queue", () => {
  beforeEach(() => {
    resetAsyncExecMediaForTest();
  });

  it("queues MEDIA paths for a session", () => {
    enqueueAsyncExecMediaFromOutput({
      sessionKey: "agent:main:discord:channel:1",
      output: "Image saved\nMEDIA: /tmp/red-cube.png",
    });

    expect(peekAsyncExecMedia("agent:main:discord:channel:1")).toEqual(["/tmp/red-cube.png"]);
  });

  it("dedupes repeated paths", () => {
    enqueueAsyncExecMediaFromOutput({
      sessionKey: "agent:main:discord:channel:1",
      output: "MEDIA: /tmp/red-cube.png",
    });
    enqueueAsyncExecMediaFromOutput({
      sessionKey: "agent:main:discord:channel:1",
      output: "MEDIA: /tmp/red-cube.png",
    });

    expect(drainAsyncExecMedia("agent:main:discord:channel:1")).toEqual(["/tmp/red-cube.png"]);
  });
});
