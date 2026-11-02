import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { loadQualityManifest, resolveInside } from "./quality-manifest.mjs";

const METRICS = ["lines", "statements", "functions", "branches"];

export function evaluateCoverage(summary, thresholds) {
  const results = {};
  const failures = [];
  for (const metric of METRICS) {
    const actual = summary.total?.[metric]?.pct;
    const minimum = thresholds[metric];
    const passed = typeof actual === "number" && Number.isFinite(actual) && actual >= minimum;
    results[metric] = { actual: actual ?? null, minimum, passed };
    if (!passed) failures.push(metric + " coverage " + (actual ?? "missing") + "% is below " + minimum + "%");
  }
  return { passed: failures.length === 0, metrics: results, failures };
}

async function main() {
  const config = await loadQualityManifest();
  const summaryPath = process.env.COVERAGE_SUMMARY_PATH
    ? resolveInside(config.root, process.env.COVERAGE_SUMMARY_PATH, "coverage summary")
    : config.coverageSummaryPath;
  const summary = JSON.parse(await readFile(summaryPath, "utf8"));
  const result = evaluateCoverage(summary, config.manifest.coverage.thresholds);
  const output = resolve(process.env.QUALITY_REPORT_DIR ?? "artifacts/quality", "coverage-gate.json");
  await mkdir(resolve(output, ".."), { recursive: true });
  await writeFile(output, JSON.stringify({ summaryPath, thresholds: config.manifest.coverage.thresholds, ...result }, null, 2));
  process.stdout.write(JSON.stringify(result, null, 2) + "\n");
  if (!result.passed) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => { process.stderr.write(error.stack + "\n"); process.exitCode = 1; });
}
