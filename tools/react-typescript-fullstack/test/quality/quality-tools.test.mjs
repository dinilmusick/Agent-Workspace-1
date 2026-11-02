import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { evaluateCoverage } from "../../scripts/quality/coverage-gate.mjs";
import { evaluateLighthouseRuns } from "../../scripts/quality/lighthouse-budget.mjs";
import { loadQualityManifest } from "../../scripts/quality/quality-manifest.mjs";
import { evaluateSarif } from "../../scripts/quality/sarif-gate.mjs";

const temporary = [];
const thresholds = { lines: 85, statements: 85, functions: 85, branches: 75 };
const summary = { total: Object.fromEntries(Object.keys(thresholds).map(key => [key, { pct: 90 }])) };

afterEach(async () => {
  await Promise.all(temporary.splice(0).map(path => rm(path, { recursive: true, force: true })));
});

describe("coverage thresholds", () => {
  it("passes when every metric meets its configured minimum", () => {
    expect(evaluateCoverage(summary, thresholds).passed).toBe(true);
  });

  it("fails low or missing metrics with explicit reasons", () => {
    const result = evaluateCoverage({ total: { ...summary.total, branches: { pct: 40 } } }, thresholds);
    expect(result.passed).toBe(false);
    expect(result.failures.join(" ")).toContain("branches coverage 40%");
  });
});

describe("quality manifest", () => {
  it("loads the sample manifest and confines report paths", async () => {
    const root = resolve("examples/quality-sample");
    const config = await loadQualityManifest({ targetRoot: root });
    expect(config.manifest.version).toBe(1);
    expect(config.lighthouseUrls).toEqual(["/", "/about", "/login"]);
    expect(config.coverageSummaryPath.startsWith(root)).toBe(true);
  });

  it("uses secure defaults for optional scanner settings", async () => {
    const root = await mkdtemp(join(tmpdir(), "quality-manifest-"));
    temporary.push(root);
    await mkdir(join(root, ".agent-workspace"));
    await writeFile(join(root, ".agent-workspace/quality-gates.json"), JSON.stringify({
      version: 1,
      coverage: { summaryFile: "coverage.json", thresholds },
      security: {},
      lighthouse: { enabled: false }
    }));
    const config = await loadQualityManifest({ targetRoot: root });
    expect(config.manifest.security.npmAuditLevel ?? "high").toBe("high");
    expect(config.lighthouseUrls).toEqual([]);
  });

  it("rejects invalid thresholds and paths outside the target", async () => {
    const root = await mkdtemp(join(tmpdir(), "quality-manifest-"));
    temporary.push(root);
    await mkdir(join(root, ".agent-workspace"));
    const path = join(root, ".agent-workspace/quality-gates.json");
    await writeFile(path, JSON.stringify({
      version: 1,
      coverage: { summaryFile: "../../outside.json", thresholds: { ...thresholds, lines: 101 } },
      security: {},
      lighthouse: { enabled: false }
    }));
    await expect(loadQualityManifest({ targetRoot: root })).rejects.toThrow("coverage.thresholds.lines");
    await writeFile(path, JSON.stringify({
      version: 1,
      coverage: { summaryFile: "../../outside.json", thresholds },
      security: {},
      lighthouse: { enabled: false }
    }));
    await expect(loadQualityManifest({ targetRoot: root })).rejects.toThrow("escapes quality target root");
  });
});

describe("Lighthouse budgets", () => {
  const config = {
    categoryThresholds: { performance: 0.9, accessibility: 0.9 },
    metricBudgets: { "largest-contentful-paint": 2500, "total-byte-weight": 300000 }
  };
  const report = {
    categories: { performance: { score: 0.95 }, accessibility: { score: 1 } },
    audits: { "largest-contentful-paint": { numericValue: 1800 }, "total-byte-weight": { numericValue: 5000 } }
  };

  it("passes category and metric budgets across runs", () => {
    expect(evaluateLighthouseRuns([report, report], config).passed).toBe(true);
  });

  it("fails category scores and missing or exceeded metrics", () => {
    const bad = { ...report, categories: { performance: { score: 0.5 }, accessibility: { score: 1 } }, audits: {} };
    const result = evaluateLighthouseRuns([bad], config);
    expect(result.passed).toBe(false);
    expect(result.failures.join(" ")).toContain("performance score");
    expect(result.failures.join(" ")).toContain("largest-contentful-paint median missing");
  });
});

describe("CodeQL SARIF severity gate", () => {
  it("fails high and critical findings but ignores informational rules", () => {
    const sarif = { runs: [{
      tool: { driver: { rules: [
        { id: "HIGH", properties: { "security-severity": "7.5" } },
        { id: "CRITICAL", properties: { "security-severity": "9.5" } },
        { id: "INFO", properties: { "security-severity": "2.0" } }
      ] } },
      results: [{ ruleId: "HIGH" }, { ruleId: "CRITICAL" }, { ruleId: "INFO" }]
    }] };
    const result = evaluateSarif(sarif);
    expect(result.passed).toBe(false);
    expect(result.counts).toEqual({ high: 1, critical: 1 });
  });

  it("passes when no security findings meet the threshold", () => {
    expect(evaluateSarif({ runs: [{ tool: { driver: { rules: [] } }, results: [] }] }).passed).toBe(true);
  });
});
