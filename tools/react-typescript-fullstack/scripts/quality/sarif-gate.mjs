import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export function evaluateSarif(sarif, thresholds = { high: 7, critical: 9 }) {
  const findings = [];
  for (const run of sarif.runs ?? []) {
    const rules = new Map((run.tool?.driver?.rules ?? []).map(rule => [
      rule.id,
      Number(rule.properties?.["security-severity"] ?? rule.properties?.securitySeverity ?? 0)
    ]));
    for (const result of run.results ?? []) {
      const severity = Number(result.properties?.["security-severity"] ?? rules.get(result.ruleId) ?? 0);
      if (severity >= thresholds.high) {
        findings.push({
          ruleId: result.ruleId,
          severity,
          level: result.level ?? "warning",
          message: result.message?.text ?? "",
          locations: result.locations ?? []
        });
      }
    }
  }
  return {
    passed: findings.length === 0,
    findings,
    thresholds,
    counts: {
      high: findings.filter(item => item.severity >= thresholds.high && item.severity < thresholds.critical).length,
      critical: findings.filter(item => item.severity >= thresholds.critical).length
    }
  };
}

async function sarifFiles(directory) {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await sarifFiles(path));
    else if (entry.isFile() && entry.name.endsWith(".sarif")) files.push(path);
  }
  return files;
}

async function main() {
  const directory = resolve(process.env.CODEQL_SARIF_DIR ?? "artifacts/codeql");
  const files = await sarifFiles(directory);
  if (!files.length) throw new Error("No CodeQL SARIF reports found in " + directory);
  const thresholds = {
    high: Number(process.env.CODEQL_HIGH_THRESHOLD ?? 7),
    critical: Number(process.env.CODEQL_CRITICAL_THRESHOLD ?? 9)
  };
  const results = [];
  for (const file of files) results.push({ file, ...evaluateSarif(JSON.parse(await readFile(file, "utf8")), thresholds) });
  const report = { passed: results.every(item => item.passed), results };
  const output = resolve("artifacts/security/codeql-gate.json");
  await mkdir(resolve(output, ".."), { recursive: true });
  await writeFile(output, JSON.stringify(report, null, 2));
  process.stdout.write(JSON.stringify(report, null, 2) + "\n");
  if (!report.passed) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => { process.stderr.write(error.stack + "\n"); process.exitCode = 1; });
}
