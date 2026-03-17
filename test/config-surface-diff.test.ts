import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";

function sh(cwd: string, command: string, args: string[] = []) {
  return execFileSync(command, args, { cwd, encoding: "utf8" }).trim();
}

function initTempRepo(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "openclaw-config-surface-diff-"));
  sh(dir, "git", ["init"]);
  sh(dir, "git", ["config", "user.email", "test@example.com"]);
  sh(dir, "git", ["config", "user.name", "OpenClaw Test"]);
  return dir;
}

function writeSchemaLabels(repoDir: string, keys: string[]) {
  const schemaPath = path.join(repoDir, "src", "config", "schema.labels.ts");
  fs.mkdirSync(path.dirname(schemaPath), { recursive: true });
  const entries = keys.map((key) => `  "${key}": "${key}",`).join("\n");
  fs.writeFileSync(schemaPath, `export const labels = {\n${entries}\n};\n`, "utf8");
}

describe("scripts/config-surface-diff.sh", () => {
  const repos: string[] = [];

  afterEach(() => {
    for (const repo of repos) {
      fs.rmSync(repo, { recursive: true, force: true });
    }
  });

  it("classifies added keys into must-review vs other and lists removed keys", () => {
    const repo = initTempRepo();
    repos.push(repo);

    writeSchemaLabels(repo, ["tools.exec.ask", "messages.historyLimit"]);
    sh(repo, "git", ["add", "."]);
    sh(repo, "git", ["commit", "-m", "old"]);
    const oldRef = sh(repo, "git", ["rev-parse", "HEAD"]);

    writeSchemaLabels(repo, ["tools.exec.ask", "gateway.auth.token", "foo.bar"]);
    sh(repo, "git", ["add", "."]);
    sh(repo, "git", ["commit", "-m", "new"]);
    const newRef = sh(repo, "git", ["rev-parse", "HEAD"]);

    const scriptPath = path.resolve("scripts", "config-surface-diff.sh");
    const output = sh(repo, "bash", [scriptPath, oldRef, newRef]);

    expect(output).toContain("Added (must-review)");
    expect(output).toContain("- gateway.auth.token");
    expect(output).toContain("Added (other)");
    expect(output).toContain("- foo.bar");
    expect(output).toContain("Removed");
    expect(output).toContain("- messages.historyLimit");
  });

  it("fails fast with a helpful message when refs are missing", () => {
    const repo = initTempRepo();
    repos.push(repo);

    const scriptPath = path.resolve("scripts", "config-surface-diff.sh");
    let stderr = "";
    try {
      execFileSync("bash", [scriptPath, "missing-a", "missing-b"], {
        cwd: repo,
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      });
    } catch (error) {
      const err = error as { stderr?: string };
      stderr = String(err.stderr ?? "");
    }

    expect(stderr).toContain("Ref not found locally");
    expect(stderr).toContain("fetch --tags");
  });
});
