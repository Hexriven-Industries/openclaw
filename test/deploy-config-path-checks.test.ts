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
    expect(output).toContain(`${tempHome}/Deployments/openclaw-config/dev.json5`);
    expect(output).not.toContain("Source dir not found");
  });

  it("blocks prod deploy when LaunchAgent config drifts from tracked config", () => {
    const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), "openclaw-deploy-prod-check-"));
    tempDirs.push(tempHome);

    const prodPlist = path.join(tempHome, "Library", "LaunchAgents", "ai.openclaw.gateway.plist");
    fs.mkdirSync(path.dirname(prodPlist), { recursive: true });
    const mismatchedConfigPath = path.join(tempHome, "runtime", "prod-runtime.json5");
    fs.mkdirSync(path.dirname(mismatchedConfigPath), { recursive: true });
    fs.writeFileSync(mismatchedConfigPath, '{"mode":"runtime"}\n', "utf8");
    fs.writeFileSync(prodPlist, `${mismatchedConfigPath}\n`, "utf8");

    const expectedConfigPath = path.join(tempHome, "Deployments", "openclaw-config", "prod.json5");
    fs.mkdirSync(path.dirname(expectedConfigPath), { recursive: true });
    fs.writeFileSync(expectedConfigPath, '{"mode":"tracked"}\n', "utf8");

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
    expect(output).toContain("Config drift detected for prod LaunchAgent");
    expect(output).toContain("Refusing to deploy with config drift");
    expect(output).not.toContain("Source dir not found");
  });

  it("allows deploy to continue on prod config drift when --allow-drift is set", () => {
    const tempHome = fs.mkdtempSync(path.join(os.tmpdir(), "openclaw-deploy-prod-allow-drift-"));
    tempDirs.push(tempHome);

    const prodPlist = path.join(tempHome, "Library", "LaunchAgents", "ai.openclaw.gateway.plist");
    fs.mkdirSync(path.dirname(prodPlist), { recursive: true });
    const mismatchedConfigPath = path.join(tempHome, "runtime", "prod-runtime.json5");
    fs.mkdirSync(path.dirname(mismatchedConfigPath), { recursive: true });
    fs.writeFileSync(prodPlist, `${mismatchedConfigPath}\n`, "utf8");

    const fakePlutil = path.join(tempHome, "bin", "fake-plutil");
    writeExecutable(
      fakePlutil,
      `#!/usr/bin/env bash
set -euo pipefail
file="\${@: -1}"
cat "$file"
`,
    );

    fs.writeFileSync(mismatchedConfigPath, '{"mode":"runtime"}\n', "utf8");

    const expectedConfigPath = path.join(tempHome, "Deployments", "openclaw-config", "prod.json5");
    fs.mkdirSync(path.dirname(expectedConfigPath), { recursive: true });
    fs.writeFileSync(expectedConfigPath, '{"mode":"tracked"}\n', "utf8");

    const scriptPath = path.resolve("scripts", "deploy-prod.sh");
    const result = spawnSync("bash", [scriptPath, "--allow-drift"], {
      env: {
        ...process.env,
        HOME: tempHome,
        PLUTIL_BIN: fakePlutil,
        OPENCLAW_SOURCE: path.join(tempHome, "missing-source"),
      },
      encoding: "utf8",
    });

    const output = `${result.stdout}${result.stderr}`;
    expect(result.status).not.toBe(0);
    expect(output).toContain("Proceeding because --allow-drift was set");
    expect(output).toContain("Source dir not found");
  });
});
