#!/usr/bin/env node
import { spawn } from "node:child_process";
import { setTimeout as sleep } from "node:timers/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const MAX_OUTPUT = 1_000_000;
const VALID_STATUSES = new Set(["completed", "failed", "blocked", "waiting"]);

export function parseRuntimeCommand(value = process.env.AGENT_RUNTIME_COMMAND_JSON) {
  if (!value) throw new Error("Set AGENT_RUNTIME_COMMAND_JSON to a JSON argv array.");
  const command = JSON.parse(value);
  if (!Array.isArray(command) || command.length === 0 || command.some(x => typeof x !== "string" || !x)) {
    throw new Error("AGENT_RUNTIME_COMMAND_JSON must be a non-empty string array.");
  }
  return command;
}

export function normalizeRuntimeOutput(value) {
  const output = typeof value === "string" ? JSON.parse(value) : value;
  if (!output || Array.isArray(output) || typeof output !== "object") throw new Error("Runtime output must be a JSON object.");
  if (!VALID_STATUSES.has(output.status)) throw new Error("Runtime output status must be completed, failed, blocked, or waiting.");
  if (output.result !== undefined && (output.result === null || typeof output.result !== "object")) throw new Error("Runtime result must be an object or array.");
  if (output.tools_used !== undefined && !Array.isArray(output.tools_used)) throw new Error("tools_used must be an array.");
  if (output.evidence !== undefined && !Array.isArray(output.evidence)) throw new Error("evidence must be an array.");
  return {
    status: output.status,
    result: output.result ?? {},
    result_summary: String(output.result_summary ?? "").slice(0, 4000),
    tools_used: output.tools_used ?? [],
    evidence: output.evidence ?? [],
    observation: output.observation ?? {},
  };
}

function runtimeEnvironment() {
  const allow = new Set((process.env.AGENT_RUNTIME_ENV_ALLOWLIST ?? "").split(",").map(x => x.trim()).filter(Boolean));
  const safeDefaults = new Set(["PATH", "HOME", "TMPDIR", "TEMP", "TMP", "SYSTEMROOT", "WINDIR", "LANG", "LC_ALL"]);
  return Object.fromEntries(Object.entries(process.env).filter(([key]) =>
    (safeDefaults.has(key) || allow.has(key)) && !/^(SUPABASE_|GITHUB_|ACTIONS_|INPUT_|RUNNER_)/i.test(key)
  ));
}

export async function callLedger(action, payload = {}) {
  const base = process.env.SUPABASE_URL?.replace(/\/$/, "");
  const apiKey = process.env.SUPABASE_ANON_KEY;
  const jwt = process.env.SUPABASE_AGENT_JWT;
  if (!base || !apiKey || !jwt) throw new Error("Set SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_AGENT_JWT.");
  const response = await fetch(`${base}/functions/v1/task-ledger`, {
    method: "POST",
    headers: { "content-type": "application/json", apikey: apiKey, authorization: `Bearer ${jwt}` },
    body: JSON.stringify({ action, payload }),
    signal: AbortSignal.timeout(30_000),
  });
  const body = await response.json();
  if (!response.ok || !body.ok) throw new Error(`Task Ledger ${action} failed: ${JSON.stringify(body)}`);
  return body.result;
}

export async function executeTask(task, command = parseRuntimeCommand()) {
  const leaseSeconds = Number(process.env.AGENT_LEASE_SECONDS ?? 900);
  const timeoutMs = Number(process.env.AGENT_TASK_TIMEOUT_MS ?? 1_800_000);
  let heartbeatError;
  let stdout = "";
  let stderr = "";
  const child = spawn(command[0], command.slice(1), {
    shell: false,
    stdio: ["pipe", "pipe", "pipe"],
    env: runtimeEnvironment(),
  });
  const heartbeat = setInterval(() => {
    callLedger("task.heartbeat", {
      task_id: task.id,
      claim_token: task.claim_token,
      current_step: "agent runtime executing",
      lease_seconds: leaseSeconds,
    }).catch(error => { heartbeatError = error; child.kill("SIGTERM"); });
  }, Math.max(15_000, Math.floor(leaseSeconds * 500)));
  const timeout = setTimeout(() => child.kill("SIGTERM"), timeoutMs);
  const output = new Promise((resolve, reject) => {
    child.stdout.on("data", chunk => { stdout = (stdout + chunk.toString()).slice(-MAX_OUTPUT); });
    child.stderr.on("data", chunk => { stderr = (stderr + chunk.toString()).slice(-MAX_OUTPUT); });
    child.on("error", reject);
    child.on("close", code => resolve(code));
  });
  try {
    child.stdin.end(JSON.stringify({ task, task_definition: task.task_definition ?? {} }));
    const exitCode = await output;
    if (heartbeatError) throw heartbeatError;
    if (exitCode !== 0) throw new Error(`Agent runtime exited with code ${exitCode}. stderr: ${stderr.slice(-4000)}`);
    return normalizeRuntimeOutput(stdout);
  } catch (error) {
    return {
      status: "failed",
      result: { error: String(error), stdout: stdout.slice(-4000), stderr: stderr.slice(-4000) },
      result_summary: String(error).slice(0, 4000),
      tools_used: [],
      evidence: [{ type: "runtime-error", stderr: stderr.slice(-4000) }],
      observation: { exit_failure: true },
    };
  } finally {
    clearInterval(heartbeat);
    clearTimeout(timeout);
  }
}

export async function runWorker({ maxTasks = Infinity, pollMs = 5000 } = {}) {
  const command = parseRuntimeCommand();
  let completed = 0;
  while (completed < maxTasks) {
    const claimed = await callLedger("task.claim", { lease_seconds: Number(process.env.AGENT_LEASE_SECONDS ?? 900) });
    const task = Array.isArray(claimed) ? claimed[0] : claimed;
    if (!task) { await sleep(pollMs); continue; }
    const result = await executeTask(task, command);
    await callLedger("task.iteration", {
      task_id: task.id,
      claim_token: task.claim_token,
      iteration_no: task.attempt_count ?? 1,
      input_payload: { task_name: task.task_name, task_definition: task.task_definition ?? {} },
      output_payload: result.result,
      observation: result.observation,
      decision: result.result_summary,
      tools_used: result.tools_used,
      evidence: result.evidence,
      status: result.status === "completed" ? "completed" : "failed",
    });
    await callLedger("task.submit", {
      task_id: task.id,
      claim_token: task.claim_token,
      result: result.result,
      result_summary: result.result_summary,
      tools_used: result.tools_used,
      evidence: result.evidence,
      status: result.status,
    });
    completed += 1;
  }
  return completed;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const maxTasks = process.argv.includes("--once") ? 1 : Number(process.env.AGENT_MAX_TASKS ?? 0) || Infinity;
  const pollMs = Number(process.env.AGENT_POLL_MS ?? 5000);
  runWorker({ maxTasks, pollMs }).then(count => {
    console.log(JSON.stringify({ processedTasks: count }));
  }).catch(error => {
    console.error(String(error));
    process.exitCode = 1;
  });
}
