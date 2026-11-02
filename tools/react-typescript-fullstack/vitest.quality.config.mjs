import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { defineConfig } from "vitest/config";

const targetRoot = resolve(process.env.QUALITY_TARGET_ROOT ?? "examples/quality-sample");
const manifestPath = process.env.QUALITY_GATES_MANIFEST
  ? resolve(process.env.QUALITY_GATES_MANIFEST)
  : resolve(targetRoot, ".agent-workspace/quality-gates.json");
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
const root = process.cwd();

export default defineConfig({
  root,
  test: {
    include: ["tools/react-typescript-fullstack/test/quality/**/*.test.mjs"],
    environment: "node",
    coverage: {
      provider: "v8",
      include: [
        "examples/quality-sample/app.mjs"
      ],
      exclude: ["**/*.test.mjs"],
      reporter: ["text", "json-summary", "lcov"],
      reportsDirectory: resolve(targetRoot, "artifacts/coverage"),
      thresholds: manifest.coverage.thresholds
    }
  }
});
