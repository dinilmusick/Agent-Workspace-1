import { access, readFile } from "node:fs/promises";
import { isAbsolute, relative, resolve, sep } from "node:path";

export function resolveInside(root, value, label = "path") {
  const resolved = resolve(root, value);
  const rel = relative(root, resolved);
  if (rel === ".." || rel.startsWith(".." + sep) || isAbsolute(rel)) {
    throw new Error(label + " escapes quality target root: " + value);
  }
  return resolved;
}

function threshold(value, min, max, label) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    throw new Error(label + " must be between " + min + " and " + max);
  }
}

export async function loadQualityManifest(options = {}) {
  const root = resolve(options.targetRoot ?? process.env.QUALITY_TARGET_ROOT ?? "workspaces/target");
  const manifestFile = resolveInside(root, options.manifestPath ?? ".agent-workspace/quality-gates.json", "manifest");
  const manifest = JSON.parse(await readFile(manifestFile, "utf8"));
  if (manifest.version !== 1) throw new Error("Unsupported quality-gates manifest version");

  const coverage = manifest.coverage ?? {};
  const coverageMetrics = ["lines", "statements", "functions", "branches"];
  for (const metric of coverageMetrics) {
    threshold(coverage.thresholds?.[metric], 0, 100, "coverage.thresholds." + metric);
  }
  const coverageSummaryPath = resolveInside(root, coverage.summaryFile ?? "artifacts/coverage/coverage-summary.json", "coverage summary");

  const security = manifest.security ?? {};
  const auditLevel = security.npmAuditLevel ?? "high";
  if (!["low", "moderate", "high", "critical"].includes(auditLevel)) throw new Error("Invalid npm audit level");
  const staticSeverity = security.staticSeverity ?? { high: 7, critical: 9 };
  threshold(staticSeverity.high, 0, 10, "security.staticSeverity.high");
  threshold(staticSeverity.critical, staticSeverity.high, 10, "security.staticSeverity.critical");

  const lighthouse = manifest.lighthouse ?? { enabled: false };
  let lighthouseUrls = [];
  if (lighthouse.enabled) {
    if (!Array.isArray(lighthouse.urls) || lighthouse.urls.length === 0) throw new Error("Lighthouse requires at least one URL path");
    lighthouseUrls = lighthouse.urls.map(path => {
      if (typeof path !== "string" || !path.startsWith("/") || path.startsWith("//")) throw new Error("Lighthouse URLs must be local absolute paths");
      return path;
    });
    const runs = lighthouse.numberOfRuns ?? 1;
    if (!Number.isInteger(runs) || runs < 1 || runs > 5) throw new Error("Lighthouse numberOfRuns must be from 1 to 5");
    for (const [category, value] of Object.entries(lighthouse.categoryThresholds ?? {})) {
      threshold(value, 0, 1, "lighthouse.categoryThresholds." + category);
    }
    for (const [metric, value] of Object.entries(lighthouse.metricBudgets ?? {})) {
      threshold(value, 0, Number.MAX_SAFE_INTEGER, "lighthouse.metricBudgets." + metric);
    }
  }

  if (lighthouse.enabled && manifest.baseUrl) {
    const base = new URL(manifest.baseUrl);
    if (!["http:", "https:"].includes(base.protocol)) throw new Error("Quality baseUrl must use HTTP or HTTPS");
  }
  await access(manifestFile);
  return { root, manifestFile, manifest, coverageSummaryPath, lighthouseUrls };
}
