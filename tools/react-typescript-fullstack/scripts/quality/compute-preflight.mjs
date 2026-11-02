import { spawnSync } from "node:child_process";

function run(command, args, env = process.env) {
  process.stdout.write("$ " + command + " " + args.join(" ") + "\n");
  const result = spawnSync(command, args, { cwd: process.cwd(), env, stdio: "inherit", timeout: 600000 });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(command + " exited with " + result.status);
}

const env = {
  ...process.env,
  QUALITY_TARGET_ROOT: "examples/quality-sample",
  QUALITY_GATES_MANIFEST: "examples/quality-sample/.agent-workspace/quality-gates.json",
  QUALITY_REPORT_DIR: "artifacts/quality"
};

run("npm", ["ci", "--prefix", "tools/react-typescript-fullstack", "--ignore-scripts", "--no-audit", "--no-fund"], env);
run("tools/react-typescript-fullstack/node_modules/.bin/vitest", [
  "run", "--config", "tools/react-typescript-fullstack/vitest.quality.config.mjs", "--coverage"
], env);
run("node", ["tools/react-typescript-fullstack/scripts/quality/coverage-gate.mjs"], env);
process.stdout.write("Agent Workspace Compute quality preflight passed.\n");
