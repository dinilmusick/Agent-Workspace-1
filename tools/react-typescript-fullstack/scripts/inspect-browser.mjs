import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const toolRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const repositoryRoot = resolve(toolRoot, "../..");
const playwright = resolve(toolRoot, "node_modules/.bin/playwright");
const config = resolve(toolRoot, "playwright.config.mjs");
const result = spawnSync(playwright, ["test", "--config", config], {
  cwd: repositoryRoot,
  env: { ...process.env, TARGET_ROOT: process.env.TARGET_ROOT ?? resolve(repositoryRoot, "workspaces/target") },
  stdio: "inherit"
});
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
