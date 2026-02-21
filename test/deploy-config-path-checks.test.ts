import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";

function writeExecutable(filePath: string, body: string) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, body, "utf8");
  fs.chmodSync(filePath, 0o755);
}

function runScript(scriptPath: string, env: NodeJS.ProcessEnv) {
  return spawnSync("bash", [scriptPath], {
    env,
    encoding: "utf8",
  });
}

describe("deploy config-path verification", () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });

  it("blocks dev deploy when LaunchAgent OPENCLAW_CONFIG_PATH mismatches expected", () => {
    const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), "openclaw-deploy-dev-check-"));
    tempDirs.push(tempHome);

    const devPlist = path.join(tempHome, "Library", "LaunchAgents", "ai.openclaw.dev.plist");
    fs.mkdirSync(path.dirname(devPlist), { recursive: true });
    fs.writeFileSync(devPlist, "/tmp/not-the-expected-dev-config.json5\n", "utf8");

    const fakePlutil = path.join(tempHome, "bin", "fake-plutil");
    writeExecutable(
      fakePlutil,
      `#!/usr/bin/env bash
set -euo pipefail
file="\${@: -1}"
cat "$file"
`,
    );

    const scriptPath = path.resolve("scripts", "deploy-dev.sh");
    const result = runScript(scriptPath, {
      ...process.env,
      HOME: tempHome,
      PLUTIL_BIN: fakePlutil,
      OPENCLAW_SOURCE: path.join(tempHome, "missing-source"),
    });

    const output = `${result.stdout}${result.stderr}`;
    expect(result.status).not.toBe(0);
    expect(output).toContain("Dev config-path verification failed");
    expect(output).not.toContain("Source dir not found");
  });

  it("does not block prod deploy on config-path mismatch (warn-only)", () => {
    const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), "openclaw-deploy-prod-check-"));
    tempDirs.push(tempHome);

    const prodPlist = path.join(tempHome, "Library", "LaunchAgents", "ai.openclaw.gateway.plist");
    fs.mkdirSync(path.dirname(prodPlist), { recursive: true });
    fs.writeFileSync(prodPlist, "/tmp/not-the-expected-prod-config.json5\n", "utf8");

    const fakePlutil = path.join(tempHome, "bin", "fake-plutil");
    writeExecutable(
      fakePlutil,
      `#!/usr/bin/env bash
set -euo pipefail
file="\${@: -1}"
cat "$file"
`,
    );

    const scriptPath = path.resolve("scripts", "deploy-prod.sh");
    const result = runScript(scriptPath, {
      ...process.env,
      HOME: tempHome,
      PLUTIL_BIN: fakePlutil,
      OPENCLAW_SOURCE: path.join(tempHome, "missing-source"),
    });

    const output = `${result.stdout}${result.stderr}`;
    expect(result.status).not.toBe(0);
    expect(output).toContain("Prod config-path info mismatch");
    // Proves we continued past informational check into normal preflight.
    expect(output).toContain("Source dir not found");
  });
});
