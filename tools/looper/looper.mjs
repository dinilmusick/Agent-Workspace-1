#!/usr/bin/env node
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { randomUUID } from "node:crypto";

const usage = "looper init <contract.json> [state.json] | looper record <state.json> <iteration-output.json> | looper status <state.json>";
const fail = (message) => { console.error(message); process.exit(2); };
const readJson = async (path) => JSON.parse(await readFile(path, "utf8"));
const writeJson = async (path, value) => {
  await mkdir(dirname(resolve(path)), { recursive: true });
  await writeFile(path, JSON.stringify(value, null, 2) + "\n");
};
const [command, first, second] = process.argv.slice(2);
if (!command || !first) fail(usage);

if (command === "init") {
  const contract = await readJson(first);
  if (!contract.goal || !Array.isArray(contract.successCriteria) || !contract.successCriteria.length) fail("Contract requires goal and non-empty successCriteria.");
  const maxIterations = Number(contract.maxIterations ?? 8);
  if (!Number.isInteger(maxIterations) || maxIterations < 1 || maxIterations > 100) fail("maxIterations must be an integer from 1 to 100.");
  const state = {
    schemaVersion: 1, loopId: randomUUID(), goal: contract.goal,
    successCriteria: contract.successCriteria, maxIterations,
    iteration: 0, status: "ready", history: [], createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(), stopReason: null
  };
  const out = second ?? "loop-state.json";
  await writeJson(out, state);
  console.log(JSON.stringify({ status: state.status, loopId: state.loopId, iteration: 0, maxIterations, stateFile: out, next: "Run one iteration, then call looper record." }, null, 2));
} else if (command === "record") {
  if (!second) fail(usage);
  const state = await readJson(first), result = await readJson(second);
  if (state.schemaVersion !== 1) fail("Unsupported loop state schema.");
  if (["completed","blocked","failed","cancelled","max_iterations"].includes(state.status)) fail(`Loop is terminal: ${state.status}`);
  if (state.iteration >= state.maxIterations) fail("Iteration budget already exhausted.");
  const verdict = result.verdict;
  if (!["continue","pass","blocked","fail","cancelled"].includes(verdict)) fail("verdict must be continue, pass, blocked, fail, or cancelled.");
  const entry = {
    iteration: state.iteration + 1, verdict,
    summary: String(result.summary ?? ""), evidence: Array.isArray(result.evidence) ? result.evidence : [],
    nextAction: result.nextAction ?? null, timestamp: new Date().toISOString()
  };
  state.iteration++;
  state.history.push(entry);
  state.updatedAt = entry.timestamp;
  if (verdict === "pass") {
    const unmet = state.successCriteria.filter(c => c.required !== false && !result.satisfiedCriteria?.includes(c.id));
    if (unmet.length) {
      state.status = "continue";
      state.stopReason = null;
      entry.unmetCriteria = unmet.map(c => c.id);
    } else {
      state.status = "completed";
      state.stopReason = "all_required_criteria_verified";
    }
  } else if (verdict === "blocked") {
    state.status = "blocked"; state.stopReason = result.blocker ?? "human_or_external_intervention_required";
  } else if (verdict === "fail") {
    state.status = "failed"; state.stopReason = result.failureReason ?? "iteration_failed";
  } else if (verdict === "cancelled") {
    state.status = "cancelled"; state.stopReason = "cancelled_by_request";
  } else if (state.iteration >= state.maxIterations) {
    state.status = "max_iterations"; state.stopReason = "iteration_budget_exhausted";
  } else {
    state.status = "continue";
  }
  await writeJson(first, state);
  console.log(JSON.stringify({
    loopId: state.loopId, status: state.status, finished: ["completed","blocked","failed","cancelled","max_iterations"].includes(state.status),
    continue: state.status === "continue", iteration: state.iteration, maxIterations: state.maxIterations,
    stopReason: state.stopReason, nextAction: state.status === "continue" ? (entry.nextAction ?? "Plan the next smallest action and run another iteration.") : null
  }, null, 2));
} else if (command === "status") {
  const state = await readJson(first);
  console.log(JSON.stringify({ loopId: state.loopId, status: state.status, finished: ["completed","blocked","failed","cancelled","max_iterations"].includes(state.status), iteration: state.iteration, maxIterations: state.maxIterations, stopReason: state.stopReason }, null, 2));
} else fail(usage);
