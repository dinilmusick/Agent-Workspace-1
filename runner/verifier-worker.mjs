#!/usr/bin/env node
import { spawn } from "node:child_process";
import { setTimeout as sleep } from "node:timers/promises";
import { callLedger, parseRuntimeCommand, runtimeEnvironment } from "./agent-worker.mjs";

const MAX_OUTPUT = 1_000_000;

export function normalizeVerificationOutput(value) {
  const output = typeof value === "string" ? JSON.parse(value) : value;
  if (!output || Array.isArray(output) || typeof output !== "object" || typeof output.verified !== "boolean") {
    throw new Error("Verifier output must be a JSON object with a boolean verified field.");
  }
  if (!output.verification_report || Array.isArray(output.verification_report) || typeof output.verification_report !== "object") {
    throw new Error("verification_report must be a JSON object.");
  }
  return {
    verified: output.verified,
    verification_report: output.verification_report,
    outcome: String(output.outcome ?? (output.verified ? "Independent verification passed" : "Independent verification rejected the result")).slice(0, 4000),
  };
}

export async function runVerification(task, iterations, command) {
  const timeoutMs = Number(process.env.AGENT_VERIFIER_TIMEOUT_MS ?? 600_000);
  let stdout = "";
  let stderr = "";
  const child = spawn(command[0], command.slice(1), {
    shell: false,
    stdio: ["pipe", "pipe", "pipe"],
    env: runtimeEnvironment(),
  });
  const timeout = setTimeout(() => child.kill("SIGTERM"), timeoutMs);
  const output = new Promise((resolve, reject) => {
    child.stdout.on("data", chunk => { stdout = (stdout + chunk.toString()).slice(-MAX_OUTPUT); });
    child.stderr.on("data", chunk => { stderr = (stderr + chunk.toString()).slice(-MAX_OUTPUT); });
    child.on("error", reject);
    child.on("close", code => resolve(code));
  });
  try {
    child.stdin.end(JSON.stringify({ task, iterations }));
    const exitCode = await output;
    if (exitCode !== 0) throw new Error(`Verifier runtime exited with code ${exitCode}: ${stderr.slice(-4000)}`);
    return normalizeVerificationOutput(stdout);
  } finally {
    clearTimeout(timeout);
  }
}

async function finalizeVerifiedAncestors(task, verifierReport) {
  let parentId = task.parent_task_id;
  while (parentId) {
    const summary = await callLedger("task.children", { task_id: parentId });
    if (summary?.all_verified !== true) break;
    const parentData = await callLedger("task.get", { task_id: parentId });
    await callLedger("task.finalize", {
      task_id: parentId,
      outcome: "All child tasks independently verified",
      verification_report: { verifier_agent: true, children: summary, source_report: verifierReport },
    });
    parentId = parentData.task?.parent_task_id ?? null;
  }
}

export async function runVerifier({ maxTasks = Infinity, pollMs = 5000 } = {}) {
  const command = parseRuntimeCommand();
  let processed = 0;
  while (processed < maxTasks) {
    const pending = await callLedger("task.pending_verification");
    const task = Array.isArray(pending) ? pending[0] : null;
    if (!task) { await sleep(pollMs); continue; }
    try {
      const details = await callLedger("task.get", { task_id: task.id });
      const verification = await runVerification(details.task, details.iterations ?? [], command);
      await callLedger("task.verify", {
        task_id: task.id,
        verified: verification.verified,
        verification_report: verification.verification_report,
      });
      if (verification.verified) await finalizeVerifiedAncestors(details.task, verification.verification_report);
      console.log(JSON.stringify({ task_id: task.id, verified: verification.verified, outcome: verification.outcome }));
      processed += 1;
    } catch (error) {
      console.error(JSON.stringify({ task_id: task.id, verification_error: String(error) }));
      await sleep(pollMs);
    }
  }
  return processed;
}

if (process.argv[1] && new URL(import.meta.url).href === new URL(process.argv[1], "file:").href) {
  const maxTasks = process.argv.includes("--once") ? 1 : Number(process.env.AGENT_MAX_TASKS ?? 0) || Infinity;
  const pollMs = Number(process.env.AGENT_POLL_MS ?? 5000);
  runVerifier({ maxTasks, pollMs }).then(count => {
    console.log(JSON.stringify({ verifiedTasks: count }));
  }).catch(error => {
    console.error(String(error));
    process.exitCode = 1;
  });
}
