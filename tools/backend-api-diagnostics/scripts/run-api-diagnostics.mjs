import { randomUUID } from "node:crypto";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import process from "node:process";

const MAX_BODY = 12000;
const SECRET_HEADER = /authorization|cookie|token|secret|password|api[-_]?key/i;
const args = Object.fromEntries(process.argv.slice(2).reduce((all, value, index, list) => {
  if (value.startsWith("--")) all.push([value.slice(2), list[index + 1]]);
  return all;
}, []));
const manifestPath = resolve(args.manifest ?? ".agent-workspace/api-tests.json");
const outputDir = resolve(args.output ?? "artifacts/api");
const report = { version: 1, startedAt: new Date().toISOString(), baseUrl: null, requests: [], failures: [] };

function expandEnv(value) {
  if (Array.isArray(value)) return value.map(expandEnv);
  if (value && typeof value === "object") {
    if (typeof value.$env === "string") {
      const secret = process.env[value.$env];
      if (secret === undefined) throw new Error(`Required environment variable ${value.$env} is missing`);
      return secret;
    }
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, expandEnv(item)]));
  }
  return value;
}

function redactHeaders(headers) {
  return Object.fromEntries(Object.entries(headers).map(([key, value]) =>
    [key, SECRET_HEADER.test(key) ? "[REDACTED]" : value]));
}

function validateSchema(value, schema, path = "$") {
  const errors = [];
  if (!schema || typeof schema !== "object") return errors;
  const type = Array.isArray(value) ? "array" : value === null ? "null" : typeof value;
  if (schema.type && type !== schema.type) return [`${path}: expected ${schema.type}, received ${type}`];
  if (schema.enum && !schema.enum.some(item => JSON.stringify(item) === JSON.stringify(value)))
    errors.push(`${path}: value is not in enum`);
  if (schema.type === "object" && value && typeof value === "object" && !Array.isArray(value)) {
    for (const key of schema.required ?? []) if (!(key in value)) errors.push(`${path}.${key}: required property missing`);
    for (const [key, child] of Object.entries(schema.properties ?? {}))
      if (key in value) errors.push(...validateSchema(value[key], child, `${path}.${key}`));
  }
  if (schema.type === "array" && Array.isArray(value) && schema.items)
    value.forEach((item, index) => errors.push(...validateSchema(item, schema.items, `${path}[${index}]`)));
  return errors;
}

function assertEqual(actual, expected, label) {
  if (String(actual).toLowerCase() !== String(expected).toLowerCase())
    return `${label}: expected ${expected}, received ${actual}`;
  return null;
}

async function readCorrelatedLogs(path, ids) {
  if (!path) return [];
  const content = await readFile(path, "utf8").catch(() => "");
  return content.split(/\r?\n/).filter(Boolean).flatMap(line => {
    try {
      const entry = JSON.parse(line);
      const id = entry.correlationId ?? entry.correlation_id ?? entry.requestId ?? entry.request_id ?? entry.request?.id;
      return ids.has(id) ? [redactValue({ ...entry, message: String(entry.message ?? "").slice(0, 2000) })] : [];
    } catch { return []; }
  });
}

async function main() {
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  if (manifest.version !== 1 || !Array.isArray(manifest.requests) || !manifest.requests.length)
    throw new Error("Manifest must use version 1 and contain a non-empty requests array");
  const base = process.env.API_BASE_URL ?? manifest.baseUrl;
  if (!base) throw new Error("Set API_BASE_URL or manifest.baseUrl");
  const baseURL = new URL(base);
  report.baseUrl = baseURL.origin;
  const ids = new Set();
  for (const scenario of manifest.requests) {
    const started = Date.now();
    const id = randomUUID();
    ids.add(id);
    const result = { id: scenario.id ?? id, correlationId: id, method: scenario.method ?? "GET",
      path: scenario.path, durationMs: null, status: null, responseHeaders: {}, responseBody: null,
      serverLogs: [], assertions: [], passed: false };
    try {
      if (typeof scenario.path !== "string" || !scenario.path.startsWith("/") || scenario.path.startsWith("//"))
        throw new Error("path must be an absolute path relative to API_BASE_URL");
      const url = new URL(scenario.path, baseURL);
      if (url.origin !== baseURL.origin) throw new Error("request path cannot change API_BASE_URL origin");
      const headers = expandEnv(scenario.headers ?? {});
      headers["x-correlation-id"] = id;
      const timeout = scenario.timeoutMs ?? manifest.timeoutMs ?? 10000;
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeout);
      let response;
      try {
        response = await fetch(url, { method: result.method, headers, body: scenario.body === undefined ? undefined :
          (typeof scenario.body === "string" ? scenario.body : JSON.stringify(expandEnv(scenario.body))), signal: controller.signal });
      } finally { clearTimeout(timer); }
      result.status = response.status;
      result.responseHeaders = Object.fromEntries(response.headers.entries());
      const text = await response.text();
      result.responseBody = text.slice(0, MAX_BODY);
      let body;
      try { body = text ? JSON.parse(text) : null; } catch { body = undefined; }
      const expected = scenario.expect ?? {};
      const statuses = expected.status ?? [200];
      const allowed = Array.isArray(statuses) ? statuses : [statuses];
      if (!allowed.includes(response.status)) result.assertions.push(`status: expected ${allowed.join(" or ")}, received ${response.status}`);
      for (const [key, value] of Object.entries(expected.headers ?? {})) {
        const error = assertEqual(response.headers.get(key), value, `header ${key}`);
        if (error) result.assertions.push(error);
      }
      if (expected.jsonSchema) {
        if (body === undefined) result.assertions.push("body: expected JSON response");
        else result.assertions.push(...validateSchema(body, expected.jsonSchema));
      }
      if (expected.jsonPath) {
        for (const [key, value] of Object.entries(expected.jsonPath)) {
          const actual = key.split(".").reduce((current, part) => current?.[part], body);
          const error = assertEqual(actual, value, `jsonPath ${key}`);
          if (error) result.assertions.push(error);
        }
      }
      const responseId = response.headers.get("x-correlation-id") ?? response.headers.get("x-request-id");
      if (responseId && responseId !== id) result.assertions.push(`correlation id mismatch: sent ${id}, received ${responseId}`);
      result.requestHeaders = redactHeaders(headers);
    } catch (error) {
      result.assertions.push(["AbortError", "TimeoutError"].includes(error.name) ? `timeout after ${scenario.timeoutMs ?? manifest.timeoutMs ?? 10000}ms` : error.message);
      result.error = { name: error.name, message: error.message };
    }
    result.durationMs = Date.now() - started;
    result.passed = result.assertions.length === 0;
    report.requests.push(result);
    if (!result.passed) report.failures.push({ id: result.id, assertions: result.assertions });
  }
  const logPath = args["server-log"] ?? process.env.SERVER_LOG_PATH;
  const logs = await readCorrelatedLogs(logPath, ids);
  for (const request of report.requests) {
    request.serverLogs = logs.filter(entry => {
      const id = entry.correlationId ?? entry.correlation_id ?? entry.requestId ?? entry.request_id ?? entry.request?.id;
      return id === request.correlationId;
    });
  }
  report.serverLogRecordsMatched = logs.length;
  report.completedAt = new Date().toISOString();
  report.summary = { total: report.requests.length, passed: report.requests.filter(item => item.passed).length,
    failed: report.failures.length, serverLogRecordsMatched: logs.length };
  await mkdir(outputDir, { recursive: true });
  await writeFile(resolve(outputDir, "api-diagnostics.json"), JSON.stringify(report, null, 2) + "\n");
  const lines = ["# API diagnostics", "", `- Base URL: ${report.baseUrl}`,
    `- Passed: ${report.summary.passed}/${report.summary.total}`,
    `- Failed: ${report.summary.failed}`,
    `- Correlated server log records: ${logs.length}`, ""];
  for (const request of report.requests) lines.push(`## ${request.id} — ${request.passed ? "PASS" : "FAIL"}`,
    `- ${request.method} ${request.path} → ${request.status ?? "no response"} (${request.durationMs}ms)`,
    `- Correlation ID: ${request.correlationId}`,
    ...request.assertions.map(error => `- Failure: ${error}`),
    `- Server log records: ${request.serverLogs.length}`, "");
  await writeFile(resolve(outputDir, "api-diagnostics.md"), lines.join("\n"));
  console.log(JSON.stringify(report.summary, null, 2));
  if (report.failures.length) process.exitCode = 1;
}

main().catch(async error => {
  report.fatalError = error.message;
  report.completedAt = new Date().toISOString();
  await mkdir(outputDir, { recursive: true });
  await writeFile(resolve(outputDir, "api-diagnostics.json"), JSON.stringify(report, null, 2) + "\n");
  console.error(error.message);
  process.exitCode = 1;
});
