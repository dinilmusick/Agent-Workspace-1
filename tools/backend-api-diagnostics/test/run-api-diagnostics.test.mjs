import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const runner = resolve("tools/backend-api-diagnostics/scripts/run-api-diagnostics.mjs");

async function fixture(t) {
  const dir = await mkdtemp(join(tmpdir(), "api-diagnostics-"));
  const logs = join(dir, "server.jsonl");
  const server = createServer(async (request, response) => {
    const id = request.headers["x-correlation-id"];
    const failure = request.url === "/explode";
    await writeFile(logs, JSON.stringify({ level: failure ? "error" : "info", correlationId: id,
      message: failure ? "handler failed" : "request handled",
      ...(failure ? { exception: { name: "Error", message: "fixture exception" } } : {}) }) + "\n", { flag: "a" });
    response.setHeader("x-correlation-id", id);
    response.setHeader("content-type", "application/json");
    if (request.url === "/private" && request.headers.authorization !== "Bearer valid") {
      response.statusCode = request.headers.authorization ? 403 : 401;
      response.end(JSON.stringify({ error: "unauthorized" }));
    } else if (request.url === "/invalid") {
      response.statusCode = 422;
      response.end(JSON.stringify({ error: "invalid payload" }));
    } else if (request.url === "/explode") {
      response.statusCode = 500;
      response.end(JSON.stringify({ error: "internal error", token: "must-not-leak" }));
    } else if (request.url === "/slow") {
      await new Promise(resolve => setTimeout(resolve, 150));
      response.end(JSON.stringify({ ok: true }));
    } else response.end(JSON.stringify({ ok: true, count: 2 }));
  });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  t.after(async () => { await new Promise(resolve => server.close(resolve)); await rm(dir, { recursive: true, force: true }); });
  return { dir, logs, baseUrl: `http://127.0.0.1:${server.address().port}` };
}

async function run(dir, baseUrl, requests, logs) {
  const manifest = join(dir, "manifest.json");
  const output = join(dir, "out");
  await writeFile(manifest, JSON.stringify({ version: 1, baseUrl, requests }));
  const result = spawnSync(process.execPath, [runner, "--manifest", manifest, "--output", output],
    { encoding: "utf8", env: { ...process.env, SERVER_LOG_PATH: logs ?? "" } });
  return { ...result, output };
}

test("validates endpoints, auth outcomes and correlates structured server exceptions", async t => {
  const { dir, logs, baseUrl } = await fixture(t);
  const result = await run(dir, baseUrl, [
    { id: "health", path: "/health", expect: { status: 200, headers: { "content-type": "application/json" },
      jsonSchema: { type: "object", required: ["ok", "count"], properties: { ok: { type: "boolean" }, count: { type: "number" } } } } },
    { id: "anonymous", path: "/private", expect: { status: 401, jsonPath: { error: "unauthorized" } } },
    { id: "forbidden", path: "/private", headers: { authorization: "Bearer invalid" }, expect: { status: 403 } },
    { id: "authorized", path: "/private", headers: { authorization: "Bearer valid" }, expect: { status: 200, jsonPath: { ok: true } } },
    { id: "validation", path: "/invalid", method: "POST", body: { malformed: true }, expect: { status: 422 } },
    { id: "exception", path: "/explode", expect: { status: 500 } }
  ], logs);
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(await readFile(join(result.output, "api-diagnostics.json"), "utf8"));
  assert.equal(report.summary.passed, 6);
  assert.equal(report.summary.serverLogRecordsMatched, 6);
  assert.equal(report.requests[2].requestHeaders.authorization, "[REDACTED]");
  assert.match(report.requests[5].serverLogs[0].exception.message, /fixture exception/);
  assert.doesNotMatch(report.requests[5].responseBody, /must-not-leak/);
  assert.match(await readFile(join(result.output, "api-diagnostics.md"), "utf8"), /authorized — PASS/);
});

test("fails contract assertions and request timeouts with diagnostic evidence", async t => {
  const { dir, baseUrl } = await fixture(t);
  const result = await run(dir, baseUrl, [
    { id: "bad-schema", path: "/health", expect: { status: 201, jsonSchema: { type: "object", required: ["missing"] } } },
    { id: "timeout", path: "/slow", timeoutMs: 10, expect: { status: 200 } }
  ]);
  assert.equal(result.status, 1);
  const report = JSON.parse(await readFile(join(result.output, "api-diagnostics.json"), "utf8"));
  assert.equal(report.summary.failed, 2);
  assert.match(report.requests[0].assertions.join(" "), /status|missing/);
  assert.match(report.requests[1].assertions.join(" "), /timeout/);
});
