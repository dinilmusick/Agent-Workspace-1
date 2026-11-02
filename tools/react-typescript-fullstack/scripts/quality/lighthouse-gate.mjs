import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";
import { loadQualityManifest } from "./quality-manifest.mjs";
import { evaluateLighthouseRuns } from "./lighthouse-budget.mjs";

function slug(path) {
  return path === "/" ? "home" : path.replace(/^\/+|\/+$/g, "").replaceAll("/", "-").replace(/[^a-zA-Z0-9_-]/g, "_");
}

async function auditUrl(url, count, outputDir) {
  const reports = [];
  const artifacts = [];
  for (let index = 1; index <= count; index++) {
    const base = join(outputDir, slug(new URL(url).pathname) + "-run-" + index);
    const args = [
      "--yes", "lighthouse@13.4.1", url,
      "--quiet",
      "--only-categories=performance",
      "--only-categories=accessibility",
      "--only-categories=best-practices",
      "--only-categories=seo",
      "--chrome-flags=--headless --no-sandbox --disable-dev-shm-usage",
      "--output=json",
      "--output=html",
      "--output-path=" + base
    ];
    const result = spawnSync("npx", args, { cwd: process.cwd(), env: process.env, stdio: "inherit", timeout: 240000 });
    if (result.error) throw result.error;
    if (result.status !== 0) throw new Error("Lighthouse failed for " + url + " run " + index + " (exit " + result.status + ")");
    const jsonPath = base + ".report.json";
    reports.push(JSON.parse(await readFile(jsonPath, "utf8")));
    artifacts.push({ json: jsonPath, html: base + ".report.html" });
  }
  return { url, reports, artifacts };
}

async function main() {
  const config = await loadQualityManifest();
  const lighthouse = config.manifest.lighthouse;
  if (!lighthouse.enabled) {
    process.stdout.write("Lighthouse disabled by quality-gates.json\n");
    return;
  }
  const baseUrl = process.env.QUALITY_BASE_URL ?? config.manifest.baseUrl;
  if (!baseUrl) throw new Error("Set QUALITY_BASE_URL or baseUrl in quality-gates.json");
  if (!process.env.CHROME_PATH) throw new Error("CHROME_PATH must point to an installed Chrome/Chromium binary");

  const outputDir = resolve(process.env.LIGHTHOUSE_OUTPUT_DIR ?? "artifacts/lighthouse");
  await mkdir(outputDir, { recursive: true });
  const results = [];
  for (const path of config.lighthouseUrls) {
    const url = new URL(path, baseUrl).toString();
    const audited = await auditUrl(url, lighthouse.numberOfRuns ?? 1, outputDir);
    results.push({
      url,
      artifacts: audited.artifacts,
      ...evaluateLighthouseRuns(audited.reports, lighthouse)
    });
  }

  const report = { passed: results.every(item => item.passed), lighthouseVersion: "13.4.1", results };
  const reportPath = resolve(process.env.QUALITY_REPORT_DIR ?? "artifacts/quality", "lighthouse-summary.json");
  await mkdir(resolve(reportPath, ".."), { recursive: true });
  await writeFile(reportPath, JSON.stringify(report, null, 2));
  process.stdout.write(JSON.stringify(report, null, 2) + "\n");
  if (!report.passed) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => { process.stderr.write(error.stack + "\n"); process.exitCode = 1; });
}
