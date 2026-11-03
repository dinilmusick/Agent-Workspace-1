#!/usr/bin/env node
import { readFile, writeFile, mkdir, rename } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { randomUUID } from "node:crypto";

const TERMINAL = new Set(["completed", "blocked", "cancelled", "max_iterations"]);
const fail = (message) => { console.error(message); process.exit(2); };
const readJson = async (path) => JSON.parse(await readFile(path, "utf8"));
const validateShape = (contract, value, label) => {
  if (!contract) return;
  if (value === undefined || value === null) fail(`${label} is required by its contract.`);
  if (contract.type === "object" && (typeof value !== "object" || Array.isArray(value))) fail(`${label} must be an object.`);
  if (contract.type === "array" && !Array.isArray(value)) fail(`${label} must be an array.`);
  if (contract.type === "string" && typeof value !== "string") fail(`${label} must be a string.`);
  if (contract.type === "number" && typeof value !== "number") fail(`${label} must be a number.`);
  if (contract.type === "boolean" && typeof value !== "boolean") fail(`${label} must be a boolean.`);
  for (const key of contract.required ?? []) {
    if (typeof value !== "object" || value === null || !(key in value)) fail(`${label} is missing required field: ${key}`);
  }
  for (const [key, property] of Object.entries(contract.properties ?? {})) {
    if (value?.[key] === undefined || property?.type === undefined) continue;
    const actual = Array.isArray(value[key]) ? "array" : value[key] === null ? "null" : typeof value[key];
    if (actual !== property.type) fail(`${label}.${key} must be ${property.type}, received ${actual}.`);
  }
};
const writeJson = async (path, value) => {
  const target = resolve(path);
  await mkdir(dirname(target), { recursive: true });
  const temp = `${target}.${process.pid}.tmp`;
  await writeFile(temp, JSON.stringify(value, null, 2) + "\n", { mode: 0o600 });
  await rename(temp, target);
};
const args = process.argv.slice(2);
const [command, first, second] = args;
const usage = "looper init <contract.json> [state.json] | looper record <state.json> <iteration.json> | looper status <state.json>";
if (!command || !first) fail(usage);

if (command === "init") {
  const contract = await readJson(first);
  if (!contract.goal || !Array.isArray(contract.successCriteria) || !contract.successCriteria.length) fail("Contract requires goal and non-empty successCriteria.");
  if (contract.loopKind === "omni") {
    if (!contract.target || typeof contract.target !== "object" || Array.isArray(contract.target)) fail("Omni Loop requires a single target object.");
    if (typeof contract.target.type !== "string" || typeof contract.target.id !== "string" || !contract.target.type.trim() || !contract.target.id.trim()) fail("Omni Loop target requires type and id.");
    if (!Array.isArray(contract.edits) || contract.edits.length === 0) fail("Omni Loop requires at least one edit.");
    for (const edit of contract.edits) {
      if (!edit || typeof edit !== "object" || typeof edit.id !== "string" || typeof edit.description !== "string" || !("change" in edit)) fail("Every Omni Loop edit requires id, description and change.");
    }
    if (!contract.inputContract || typeof contract.inputContract !== "object") fail("Omni Loop requires inputContract.");
    if (!contract.outputContract || typeof contract.outputContract !== "object") fail("Omni Loop requires outputContract.");
  }
  const ids = contract.successCriteria.map((c) => c?.id);
  if (ids.some((id) => typeof id !== "string" || !id.trim()) || new Set(ids).size !== ids.length) fail("Every success criterion needs a unique non-empty string id.");
  const maxIterations = Number(contract.iterationPolicy?.maxIterations ?? contract.maxIterations ?? 8);
  const repeatedFailureThreshold = Number(contract.iterationPolicy?.repeatedFailureThreshold ?? 2);
  if (!Number.isInteger(maxIterations) || maxIterations < 1 || maxIterations > 100) fail("maxIterations must be an integer from 1 to 100.");
  if (!Number.isInteger(repeatedFailureThreshold) || repeatedFailureThreshold < 1 || repeatedFailureThreshold > 10) fail("repeatedFailureThreshold must be an integer from 1 to 10.");
  const state = {
    schemaVersion: 1, loopId: contract.loopId ?? randomUUID(), loopKind: contract.loopKind ?? "standard", target: contract.target ?? null, edits: Array.isArray(contract.edits) ? contract.edits : [], goal: contract.goal,
    inputContract: contract.inputContract ?? null, outputContract: contract.outputContract ?? null,
    tools: Array.isArray(contract.tools) ? contract.tools : [], successCriteria: contract.successCriteria,
    iterationPolicy: { maxIterations, repeatedFailureThreshold }, iteration: 0, status: "ready",
    currentInput: contract.initialInput ?? null, currentOutput: null, history: [],
    consecutiveFailureCount: 0, lastFailureKey: null, createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(), stopReason: null
  };
  const out = second ?? "loop-state.json";
  await writeJson(out, state);
  console.log(JSON.stringify({ loopId: state.loopId, status: state.status, iteration: 0, maxIterations, stateFile: out, finished: false }, null, 2));
} else if (command === "record") {
  if (!second) fail(usage);
  const state = await readJson(first), result = await readJson(second);
  if (state.schemaVersion !== 1) fail("Unsupported loop state schema.");
  if (TERMINAL.has(state.status)) fail(`Loop is terminal: ${state.status}`);
  if (state.iteration >= state.iterationPolicy.maxIterations) fail("Iteration budget already exhausted.");
  const verdict = result.verdict;
  if (!["continue", "pass", "error", "blocked", "cancelled"].includes(verdict)) fail("verdict must be continue, pass, error, blocked, or cancelled.");
  const input = result.input ?? state.currentInput;
  validateShape(state.inputContract, input, "input");
  if (state.loopKind === "omni") {
    if (!input || typeof input !== "object" || Array.isArray(input) || !input.edit) fail("Omni Loop iteration input must contain an edit.");
    if (typeof input.edit.id !== "string" || !state.edits.some((edit) => edit.id === input.edit.id)) fail("Omni Loop iteration references an unknown edit.");
  }
  validateShape(state.outputContract, result.output, "output");
  const criterionResults = Array.isArray(result.criterionResults) ? result.criterionResults : [];
  const validStatuses = new Set(["satisfied", "unsatisfied", "unknown"]);
  for (const item of criterionResults) {
    if (!state.successCriteria.some((c) => c.id === item.criterionId) || !validStatuses.has(item.status)) fail(`Invalid criterion result: ${JSON.stringify(item)}`);
    if (!Array.isArray(item.evidence)) fail("criterionResults[].evidence must be an array.");
  }
  const satisfied = new Set(criterionResults.filter((x) => x.status === "satisfied" && x.evidence.length > 0).map((x) => x.criterionId));
  const unmet = state.successCriteria.filter((c) => c.required !== false && !satisfied.has(c.id));
  const timestamp = new Date().toISOString();
  const entry = {
    iteration: state.iteration + 1, input, output: result.output ?? null,
    observation: result.observation ?? null, verdict, criterionResults,
    toolsUsed: Array.isArray(result.toolsUsed) ? result.toolsUsed : [],
    evidence: Array.isArray(result.evidence) ? result.evidence : [],
    failureKey: result.failureKey ?? null, nextAction: result.nextAction ?? null, timestamp
  };
  state.iteration += 1;
  state.history.push(entry);
  state.currentInput = result.nextInput ?? entry.output ?? state.currentInput;
  state.currentOutput = entry.output;
  state.updatedAt = timestamp;
  state.stopReason = null;

  if (verdict === "pass" && unmet.length === 0) {
    state.status = "completed"; state.stopReason = "all_required_criteria_verified_with_evidence"; state.consecutiveFailureCount = 0;
  } else if (verdict === "blocked") {
    state.status = "blocked"; state.stopReason = result.blocker ?? "external_action_or_permission_required";
  } else if (verdict === "cancelled") {
    state.status = "cancelled"; state.stopReason = "cancelled_by_request";
  } else {
    if (verdict === "error" || verdict === "pass") {
      const key = result.failureKey ?? (unmet.length ? "unmet-success-criteria" : "iteration-error");
      state.consecutiveFailureCount = key === state.lastFailureKey ? state.consecutiveFailureCount + 1 : 1;
      state.lastFailureKey = key;
    } else { state.consecutiveFailureCount = 0; state.lastFailureKey = null; }
    if (state.iteration >= state.iterationPolicy.maxIterations) {
      state.status = "max_iterations"; state.stopReason = "iteration_budget_exhausted";
    } else if (state.consecutiveFailureCount >= state.iterationPolicy.repeatedFailureThreshold) {
      state.status = "research_required"; state.stopReason = "same_failure_repeated";
    } else { state.status = "continue"; }
  }
  await writeJson(first, state);
  const finished = TERMINAL.has(state.status);
  console.log(JSON.stringify({
    loopId: state.loopId, status: state.status, finished, continue: !finished,
    researchRequired: state.status === "research_required", iteration: state.iteration,
    maxIterations: state.iterationPolicy.maxIterations, unmetCriteria: unmet.map((c) => c.id),
    stopReason: state.stopReason,
    nextAction: finished ? null : (state.status === "research_required"
      ? "Research the exact repeated failure, then record a new iteration with the revised approach."
      : entry.nextAction ?? "Plan the next smallest action and run another iteration.")
  }, null, 2));
} else if (command === "status") {
  const state = await readJson(first);
  console.log(JSON.stringify({
    loopId: state.loopId, status: state.status, finished: TERMINAL.has(state.status),
    continue: !TERMINAL.has(state.status), iteration: state.iteration,
    maxIterations: state.iterationPolicy.maxIterations, stopReason: state.stopReason
  }, null, 2));
} else fail(usage);
