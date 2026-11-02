import { spawnSync } from "node:child_process";
import { mkdir, writeFile, access } from "node:fs/promises";
import { resolve, join } from "node:path";
import { fileURLToPath } from "node:url";

const toolRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const repoRoot = resolve(toolRoot, "../..");
const targetRoot = resolve(repoRoot, "workspaces/target", process.env.PROJECT_PATH ?? ".");
const outputRoot = resolve(repoRoot, "artifacts/quality");
const binRoot = resolve(toolRoot, "node_modules/.bin");
const exists = async (path) => access(path).then(() => true).catch(() => false);
const configs = {
  typescript: ["tsconfig.json"],
  eslint: ["eslint.config.js", "eslint.config.mjs", "eslint.config.cjs", ".eslintrc", ".eslintrc.json", ".eslintrc.js"],
  biome: ["biome.json", "biome.jsonc"],
  prettier: [".prettierrc", ".prettierrc.json", ".prettierrc.js", "prettier.config.js", "prettier.config.mjs"],
  knip: ["knip.json", "knip.jsonc", "knip.ts", "knip.config.ts"],
  dependencyCruiser: [".dependency-cruiser.cjs", ".dependency-cruiser.js", ".dependency-cruiser.mjs", ".dependency-cruiser.json"]
};
const results = [];
await mkdir(outputRoot, { recursive: true });
if (!(await exists(join(targetRoot, "package.json")))) {
  throw new Error(`package.json not found in target project: ${targetRoot}`);
}
const findConfig = async (names) => {
  for (const name of names) if (await exists(join(targetRoot, name))) return name;
  return null;
};
const run = (name, command, args, extraEnv = {}) => {
  const result = spawnSync(command, args, {
    cwd: targetRoot,
    encoding: "utf8",
    env: { ...process.env, PATH: `${binRoot}:${process.env.PATH ?? ""}`, CI: "true", ...extraEnv },
    timeout: 10 * 60 * 1000,
    maxBuffer: 20 * 1024 * 1024
  });
  const record = {
    name,
    command: [command, ...args],
    exitCode: result.status,
    signal: result.signal ?? null,
    error: result.error?.message ?? null,
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? ""
  };
  results.push(record);
  const log = [record.stdout, record.stderr].filter(Boolean).join("\n");
  return writeFile(join(outputRoot, `${name}.log`), log);
};
const checks = [
  { name: "typescript", binary: "tsc", args: ["--noEmit", "--pretty", "false"], config: configs.typescript },
  { name: "eslint", binary: "eslint", args: [".", "--max-warnings=0"], config: configs.eslint },
  { name: "biome", binary: "biome", args: ["check", "."], config: configs.biome },
  { name: "prettier", binary: "prettier", args: ["--check", "."], config: configs.prettier },
  { name: "knip", binary: "knip", args: ["--no-progress"], config: configs.knip },
  { name: "dependency-cruiser", binary: "depcruise", args: ["src"], config: configs.dependencyCruiser }
];
for (const check of checks) {
  const config = await findConfig(check.config);
  if (!config) {
    results.push({ name: check.name, status: "skipped", reason: "No project configuration found" });
    continue;
  }
  const binary = join(binRoot, check.binary);
  if (!(await exists(binary))) {
    results.push({ name: check.name, status: "unavailable", reason: `Tool not installed: ${check.binary}` });
    continue;
  }
  await run(check.name, binary, check.args, check.name === "eslint" && config.startsWith(".eslintrc") ? { ESLINT_USE_FLAT_CONFIG: "false" } : {});
}
const failed = results.filter((x) => x.exitCode !== undefined && x.exitCode !== 0);
const summary = {
  projectPath: targetRoot,
  completedAt: new Date().toISOString(),
  checks: results.map(({ stdout, stderr, ...x }) => x),
  failed: failed.map((x) => x.name),
  passed: results.filter((x) => x.exitCode === 0).map((x) => x.name)
};
await writeFile(join(outputRoot, "summary.json"), JSON.stringify(summary, null, 2) + "\n");
console.log(JSON.stringify(summary, null, 2));
if (failed.length) process.exitCode = 1;
