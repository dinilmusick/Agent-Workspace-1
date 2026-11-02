import test from "node:test";
import assert from "node:assert/strict";
import { parseRuntimeCommand, normalizeRuntimeOutput } from "../agent-worker.mjs";

test("runtime command is an argv array, never a shell string", () => {
  assert.deepEqual(parseRuntimeCommand('["node","adapter.mjs"]'), ["node", "adapter.mjs"]);
  assert.throws(() => parseRuntimeCommand("node adapter.mjs"), /JSON/);
  assert.throws(() => parseRuntimeCommand('["node",""]'), /non-empty string array/);
});

test("runtime output requires a known terminal task status", () => {
  assert.deepEqual(normalizeRuntimeOutput({
    status: "completed",
    result: { ok: true },
    result_summary: "verified by runtime",
    tools_used: ["unit-test"],
    evidence: [{ type: "test", passed: true }],
  }), {
    status: "completed",
    result: { ok: true },
    result_summary: "verified by runtime",
    tools_used: ["unit-test"],
    evidence: [{ type: "test", passed: true }],
    observation: {},
  });
  assert.throws(() => normalizeRuntimeOutput({ result: {} }), /status/);
  assert.throws(() => normalizeRuntimeOutput({ status: "running" }), /status/);
  assert.throws(() => normalizeRuntimeOutput({ status: "completed", tools_used: "test" }), /array/);
});
