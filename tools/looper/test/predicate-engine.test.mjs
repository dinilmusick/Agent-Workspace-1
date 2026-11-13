import test from "node:test";
import assert from "node:assert/strict";
import { evaluatePredicate, registerScriptPredicate } from "../predicate-engine.mjs";

test("builtin predicates are deterministic", async () => {
  const predicate = {
    key: "builtin.evidence_present",
    version: 1,
    type: "builtin",
    expectedResult: true,
    definition: {},
    inputSchema: { type: "object" },
  };
  assert.equal((await evaluatePredicate(predicate, { evidence: [{ ref: "test" }] })).passed, true);
  assert.equal((await evaluatePredicate(predicate, { evidence: [] })).passed, false);
});

test("CEL predicates evaluate against explicit inputs", async () => {
  const predicate = {
    key: "task.tests_pass",
    version: 1,
    type: "cel",
    definition: { expression: "result.exitCode == 0" },
    inputSchema: { type: "object" },
    expectedResult: true,
  };
  assert.equal((await evaluatePredicate(predicate, { result: { exitCode: 0 } })).passed, true);
  assert.equal((await evaluatePredicate(predicate, { result: { exitCode: 1 } })).passed, false);
});

test("script predicates require explicit registration", async () => {
  const handlers = {};
  registerScriptPredicate(handlers, "repo.tests_pass", async ({ exitCode }) => exitCode === 0);
  const predicate = {
    key: "repo.tests_pass",
    version: 1,
    type: "script",
    definition: { handler: "repo.tests_pass" },
    inputSchema: { type: "object" },
    expectedResult: true,
  };
  assert.equal((await evaluatePredicate(predicate, { exitCode: 0 }, handlers)).passed, true);
  await assert.rejects(
    () => evaluatePredicate({ ...predicate, key: "repo.unknown" }, { exitCode: 0 }, handlers),
    /No registered handler/,
  );
});
