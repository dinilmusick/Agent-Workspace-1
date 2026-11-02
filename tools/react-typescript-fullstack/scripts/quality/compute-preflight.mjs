import { cp, mkdir, readdir, rm, stat } from "node:fs/promises";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

function run(command, args, env = process.env, timeout = 600000) {
  process.stdout.write("$ " + command + " " + args.join(" ") + "\n");
  const result = spawnSync(command, args, { cwd: process.cwd(), env, stdio: "inherit", timeout });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(command + " exited with " + result.status);
}

async function waitForHealth(url) {
  for (let attempt = 0; attempt < 30; attempt++) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(1000) });
      if (response.ok) return;
    } catch {}
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  throw new Error("Quality sample did not become healthy: " + url);
}

async function findChrome(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      const found = await findChrome(path);
      if (found) return found;
    } else if (entry.isFile() && entry.name === "chrome" && ((await stat(path)).mode & 0o111)) {
      return path;
    }
  }
  return null;
}

async function main() {
  const root = process.cwd();
  const targetRoot = resolve("workspaces/target");
  await rm(targetRoot, { recursive: true, force: true });
  await mkdir(targetRoot, { recursive: true });
  const sampleRoot = resolve("examples/quality-sample");
  for (const entry of await readdir(sampleRoot)) {
    await cp(join(sampleRoot, entry), join(targetRoot, entry), { recursive: true, force: true });
  }
  if (!await stat(join(targetRoot, ".agent-workspace/quality-gates.json")).then(() => true, () => false)) {
    throw new Error("Quality manifest was not copied into workspaces/target");
  }

  const env = {
    ...process.env,
    QUALITY_TARGET_ROOT: "workspaces/target",
    QUALITY_GATES_MANIFEST: "workspaces/target/.agent-workspace/quality-gates.json",
    QUALITY_REPORT_DIR: "artifacts/quality",
    QUALITY_TEST_EMAIL: "qa@example.com",
    QUALITY_TEST_PASSWORD: "test",
    QUALITY_SESSION_TOKEN: "test-token"
  };

  for (const file of [
    "examples/quality-sample/app.mjs",
    "examples/quality-sample/server.mjs",
    "tools/react-typescript-fullstack/scripts/quality/quality-manifest.mjs",
    "tools/react-typescript-fullstack/scripts/quality/coverage-gate.mjs",
    "tools/react-typescript-fullstack/scripts/quality/lighthouse-budget.mjs",
    "tools/react-typescript-fullstack/scripts/quality/lighthouse-gate.mjs",
    "tools/react-typescript-fullstack/scripts/quality/sarif-gate.mjs"
  ]) run("node", ["--check", file], env);

  for (const workflow of [".github/workflows/quality-gates.yml", ".github/workflows/security-gates.yml"]) {
    run("ruby", ["-e", "require 'yaml'; YAML.load_file(ARGV[0])", workflow], env);
  }
  run("npm", ["ci", "--prefix", "tools/react-typescript-fullstack", "--ignore-scripts", "--no-audit", "--no-fund"], env);
  run("npm", ["audit", "--prefix", "tools/react-typescript-fullstack", "--audit-level=high"], env);
  run("npm", ["audit", "--prefix", "workspaces/target", "--audit-level=high"], env);
  run("tools/react-typescript-fullstack/node_modules/.bin/vitest", [
    "run", "--config", "tools/react-typescript-fullstack/vitest.quality.config.mjs", "--coverage"
  ], env);
  run("node", ["tools/react-typescript-fullstack/scripts/quality/coverage-gate.mjs"], env);

  run("python", ["runner/react-project.py", "prepare", "--project-path", "."], env);
  run("python", ["runner/react-project.py", "start", "--project-path", "."], env);
  try {
    await waitForHealth("http://127.0.0.1:4173/health");
    const apiEnv = {
      ...env,
      API_BASE_URL: "http://127.0.0.1:4173",
      SERVER_LOG_PATH: "artifacts/build/dev-server.log",
      QUALITY_VALID_AUTHORIZATION: "Bearer test-token"
    };
    run("node", [
      "tools/backend-api-diagnostics/scripts/run-api-diagnostics.mjs",
      "--manifest", "workspaces/target/.agent-workspace/api-tests.json",
      "--output", "artifacts/api"
    ], apiEnv);

    run("tools/react-typescript-fullstack/node_modules/.bin/playwright", ["install", "--with-deps", "chromium"], env);
    const chrome = await findChrome(join(process.env.HOME, ".cache/ms-playwright"));
    if (!chrome) throw new Error("Playwright Chromium executable not found");
    run("node", ["tools/react-typescript-fullstack/scripts/quality/lighthouse-gate.mjs"], {
      ...apiEnv,
      CHROME_PATH: chrome,
      QUALITY_BASE_URL: "http://127.0.0.1:4173"
    });
  } finally {
    run("python", ["runner/react-project.py", "stop", "--project-path", "."], env);
  }

  process.stdout.write("Agent Workspace Compute security and quality preflight passed.\n");
}

main().catch(error => {
  process.stderr.write(error.stack + "\n");
  process.exitCode = 1;
});
