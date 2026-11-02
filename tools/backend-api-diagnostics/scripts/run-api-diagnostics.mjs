import { randomUUID } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import process from "node:process";

const MAX_BODY = 12000;
const SECRET_KEY = /authorization|cookie|token|secret|password|api[-_]?key/i;
const args = {};
for (let index = 2; index < process.argv.length; index += 1) {
  if (process.argv[index].startsWith("--")) args[process.argv[index].slice(2)] = process.argv[index + 1];
}
const manifestPath = resolve(args.manifest ?? ".agent-workspace/api-tests.json");
const outputDir = resolve(args.output ?? "artifacts/api");
const report = { version: 1, startedAt: new Date().toISOString(), baseUrl: null, requests: [], failures: [] };

function expandEnv(value) {
  if (Array.isArray(value)) return value.map(expandEnv);
  if (value && typeof value === "object") {
    if (typeof value.$env === "string") {
      if (process.env[value.$env] === undefined) throw new Error(`Required environment variable ${value.$env} is missing`);
      return process.env[value.$env];
    }
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, expandEnv(item)]));
  }
  return value;
}

function redact(value) {
  if (Array.isArray(value)) return value.map(redact);
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).map(([key, item]) =>
    [SECRET_KEY.test(key) ? key : key, SECRET_KEY.test(key) ? "[REDACTED]" : redact(item)]));
  return value;
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

function equal(actual, expected, label) {
  return String(actual).toLowerCase() === String(expected).toLowerCase()
    ? null : `${label}: expected ${expected}, received ${actual}`;
}

function correlationId(entry) {
  return entry.correlationId ?? entry.correlation_id ?? entry.requestId ?? entry.request_id ?? entry.request?.id;
}

async function readCorrelatedLogs(path, ids) {
  if (!path) return [];
  const content = await readFile(path, "utf8").catch(() => "");
  return content.split(/\r?\n/).filter(Boolean).flatMap(line => {
    try {
      const entry = JSON.parse(line);
      return ids.has(correlationId(entry)) ? [redact(entry)] : [];
    } catch { return []; }
  });
}

async function main() {
  const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
  if (manifest.version !== 1 || !Array.isArray(manifest.requests) || !manifest.requests.length)
    throw new Error("Manifest must use version 1 and contain a non-empty requests array");
  const baseURL = new URL(process.env.API_BASE_URL ?? manifest.baseUrl ?? "");
  if (!["localhost", "127.0.0.1", "::1"].includes(baseURL.hostname) || baseURL.username || baseURL.password)
    throw new Error("API_BASE_URL must target localhost or a loopback address without embedded credentials");
  report.baseUrl = baseURL.origin;
  const ids = new Set();

  for (const scenario of manifest.requests) {
    const started = Date.now();
    const id = randomUUID();
    ids.add(id);
    const result = { id: scenario.id ?? id, correlationId: id, method: scenario.method ?? "GET",
      path: scenario.path, durationMs: null, status: null, responseHeaders: {}, responseBody: null,
      requestHeaders: {}, serverLogs: [], assertions: [], passed: false };
    try {
      if (typeof scenario.path !== "string" || !scenario.path.startsWith("/") || scenario.path.startsWith("//"))
        throw new Error("path must be an absolute path relative to API_BASE_URL");
      const url = new URL(scenario.path, baseURL);
      if (url.origin !== baseURL.origin) throw new Error("request path cannot change API_BASE_URL origin");
      const headers = expandEnv(scenario.headers ?? {});
      if (scenario.body !== undefined && typeof scenario.body !== "string" &&
          !Object.keys(headers).some(key => key.toLowerCase() === "content-type"))
        headers["content-type"] = "application/json";
      headers["x-correlation-id"] = id;
      result.requestHeaders = redact(headers);
      const timeout = scenario.timeoutMs ?? manifest.timeoutMs ?? 10000;
      const response = await fetch(url, {
        method: result.method, headers,
        body: scenario.body === undefined ? undefined :
          (typeof scenario.body === "string" ? scenario.body : JSON.stringify(expandEnv(scenario.body))),
        signal: AbortSignal.timeout(timeout)
      });
      result.status = response.status;
      result.responseHeaders = redact(Object.fromEntries(response.headers.entries()));
      const text = await response.text();
      let body;
      try { body = text ? JSON.parse(text) : null; } catch { body = undefined; }
      result.responseBody = body === undefined ? "[non-JSON response omitted]" : JSON.stringify(redact(body)).slice(0, MAX_BODY);
      const expected = scenario.expect ?? {};
      const statuses = expected.status ?? [200];
      const allowed = Array.isArray(statuses) ? statuses : [statuses];
      if (!allowed.includes(response.status))
        result.assertions.push(`status: expected ${allowed.join(" or ")}, received ${response.status}`);
      for (const [key, value] of Object.entries(expected.headers ?? {})) {
        const error = equal(response.headers.get(key), value, `header ${key}`);
        if (error) result.assertions.push(error);
      }
      if (expected.jsonSchema) {
        if (body === undefined) result.assertions.push("body: expected JSON response");
        else result.assertions.push(...validateSchema(body, expected.jsonSchema));
      }
      for (const [key, value] of Object.entries(expected.jsonPath ?? {})) {
        const actual = key.split(".").reduce((current, part) => current?.[part], body);
        const error = equal(actual, value, `jsonPath ${key}`);
        if (error) result.assertions.push(error);
      }
      const responseId = response.headers.get("x-correlation-id") ?? response.headers.get("x-request-id");
      if (responseId && responseId !== id) result.assertions.push(`correlation id mismatch: sent ${id}, received ${responseId}`);
    } catch (error) {
      const timedOut = ["AbortError", "TimeoutError"].includes(error.name);
      result.assertions.push(timedOut ? `timeout after ${scenario.timeoutMs ?? manifest.timeoutMs ?? 10000}ms` : error.message);
      result.error = { name: error.name, message: error.message };
    }
    result.durationMs = Date.now() - started;
    result.passed = result.assertions.length === 0;
    report.requests.push(result);
    if (!result.passed) report.failures.push({ id: result.id, assertions: result.assertions });
  }

  const logs = await readCorrelatedLogs(args["server-log"] ?? process.env.SERVER_LOG_PATH, ids);
  for (const request of report.requests)
    request.serverLogs = logs.filter(entry => correlationId(entry) === request.correlationId);
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
