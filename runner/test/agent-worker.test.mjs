import test from "node:test";
import assert from "node:assert/strict";
import { parseRuntimeCommand, normalizeRuntimeOutput } from "../agent-worker.mjs";

test("runtime command is an argv array, never a shell string", () => {
  assert.deepEqual(parseRuntimeCommand('["node","adapter.mjs"]'), ["node", "adapter.mjs"]);
  assert.throws(() => parseRuntimeCommand("node adapter.mjs"), /JSON/);
  assert.throws(() => parseRuntimeCommand('["node",""]'), /non-empty string array/);
});

test("completed runtime output must pass every loop criterion with evidence", () => {
  assert.deepEqual(normalizeRuntimeOutput({
    status: "completed",
    result: { ok: true },
    result_summary: "all acceptance criteria satisfied",
    tools_used: ["unit-test"],
    evidence: [{ type: "test", passed: true }],
    criterion_results: [{ criterion: "build", status: "satisfied" }],
    loop_state: { iteration: 1 },
  }), {
    status: "completed",
    result: { ok: true },
    result_summary: "all acceptance criteria satisfied",
    tools_used: ["unit-test"],
    evidence: [{ type: "test", passed: true }],
    observation: {},
    criterion_results: [{ criterion: "build", status: "satisfied" }],
    loop_state: { iteration: 1 },
    verdict: "pass",
    next_action: null,
  });
  assert.throws(() => normalizeRuntimeOutput({ status: "completed", evidence: [{ type: "test" }] }), /criterion_results/);
  assert.throws(() => normalizeRuntimeOutput({
    status: "completed",
    criterion_results: [{ criterion: "build", status: "unsatisfied" }],
    evidence: [{ type: "test" }],
  }), /every criterion satisfied/);
  assert.throws(() => normalizeRuntimeOutput({
    status: "completed",
    criterion_results: [{ criterion: "build", status: "satisfied" }],
    evidence: [],
  }), /evidence/);
});

test("non-terminal loop output records a continue/error verdict", () => {
  assert.equal(normalizeRuntimeOutput({
    status: "blocked",
    criterion_results: [{ criterion: "credentials available", status: "unknown" }],
    evidence: [{ type: "blocker" }],
  }).verdict, "blocked");
  assert.throws(() => normalizeRuntimeOutput({ result: {} }), /status/);
  assert.throws(() => normalizeRuntimeOutput({ status: "running" }), /status/);
  assert.throws(() => normalizeRuntimeOutput({ status: "completed", tools_used: "test" }), /array/);
});
