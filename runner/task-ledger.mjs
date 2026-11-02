#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import { randomUUID } from "node:crypto";

const [action, ...args] = process.argv.slice(2);
if (!action) {
  console.error("Usage: node runner/task-ledger.mjs <action> [--payload JSON | --payload-file PATH]");
  process.exit(2);
}
const readArg = (name) => {
  const index = args.indexOf(name);
  return index < 0 ? undefined : args[index + 1];
};
let payload = {};
try {
  const raw = readArg("--payload");
  const file = readArg("--payload-file");
  if (raw) payload = JSON.parse(raw);
  else if (file) payload = JSON.parse(await readFile(file, "utf8"));
  if (!payload || Array.isArray(payload) || typeof payload !== "object") throw new Error("Payload must be an object.");
} catch (error) {
  console.error(String(error));
  process.exit(2);
}

const base = (process.env.SUPABASE_URL ?? process.env.AGENT_TASK_LEDGER_URL)?.replace(/\/$/, "");
const apiKey = process.env.SUPABASE_ANON_KEY ?? process.env.AGENT_TASK_LEDGER_ANON_KEY;
const jwt = process.env.SUPABASE_AGENT_JWT ?? process.env.AGENT_TASK_LEDGER_JWT;
if (!base || !apiKey || !jwt) {
  console.error("Set SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_AGENT_JWT.");
  process.exit(2);
}

async function request(path, { method = "GET", body, prefer } = {}) {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      apikey: apiKey,
      authorization: `Bearer ${jwt}`,
      "content-type": "application/json",
      ...(prefer ? { Prefer: prefer } : {}),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    signal: AbortSignal.timeout(30_000),
  });
  const text = await response.text();
  let data;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${JSON.stringify(data)}`);
  return data;
}
const rpc = (name, body) => request(`/rest/v1/rpc/${name}`, { method: "POST", body });
const query = (table, params) => request(`/rest/v1/${table}?${new URLSearchParams(params)}`);

try {
  const user = await request("/auth/v1/user");
  if (!user?.id) throw new Error("The supplied Supabase JWT has no authenticated user.");
  const registered = await query("agent_registry", {
    select: "user_id,agent_id,agent_name,agent_type,capabilities,enabled",
    user_id: `eq.${user.id}`,
    enabled: "eq.true",
    limit: "1",
  });
  const agent = registered?.[0];
  if (!agent) throw new Error("No enabled agent is registered for this authenticated user.");
  const p = payload;
  let result;

  switch (action) {
    case "skills.list": {
      const skills = await query("skills", {
        select: "id,name,slug,description,status,current_version_id",
        status: "eq.active",
        order: "name.asc",
      });
      const versions = await query("skill_versions", {
        select: "id,skill_id,version,instructions,manifest,is_published,published_at",
        is_published: "eq.true",
      });
      const byId = new Map(versions.map((version) => [version.id, version]));
      result = skills.filter((skill) => byId.has(skill.current_version_id))
        .map((skill) => ({ ...skill, current_version: byId.get(skill.current_version_id) }));
      break;
    }
    case "goal.create":
      if (!["orchestrator", "supervisor"].includes(agent.agent_type)) throw new Error("Orchestrator role required.");
      result = await rpc("goal_ledger_create_hierarchical", {
        title_in: p.title ?? p.name,
        description_in: p.description ?? "",
        context_in: p.context ?? {},
        instructions_in: p.instructions ?? "",
        acceptance_criteria_in: p.acceptance_criteria ?? [],
        tags_in: p.tags ?? [],
        goal_loop_definition_in: p.goal_loop_definition,
        task_definitions_in: p.tasks,
        created_by_agent_id_in: agent.agent_id,
        owner_user_id_in: user.id,
        metadata_in: p.metadata ?? {},
      });
      break;
    case "goal.get":
      result = p.goal_key
        ? await rpc("goal_ledger_get_by_key", { goal_key_in: p.goal_key })
        : await rpc("goal_ledger_get", { goal_id_in: p.goal_id ?? null, name_in: p.name ?? null });
      break;
    case "goal.resume":
      result = p.goal_key
        ? await rpc("goal_ledger_resume_by_key", { goal_key_in: p.goal_key })
        : await rpc("goal_ledger_resume", { name_in: p.name });
      break;
    case "goal.summary":
      result = await rpc("goal_ledger_summary", { goal_id_in: p.goal_id });
      break;
    case "goal.list":
      result = p.unfinished === true
        ? await rpc("goal_ledger_list_unfinished", { tags_in: p.tags ?? null })
        : await rpc("goal_ledger_list_filtered", { status_in: p.status ?? null, tags_in: p.tags ?? null });
      break;
    case "goal.iteration":
      result = await rpc("goal_ledger_record_loop_iteration", {
        goal_id_in: p.goal_id,
        agent_id_in: agent.agent_id,
        iteration_no_in: p.iteration_no,
        input_payload_in: p.input_payload ?? {},
        output_payload_in: p.output_payload ?? {},
        observation_in: p.observation ?? {},
        criterion_results_in: p.criterion_results ?? [],
        loop_state_in: p.loop_state ?? {},
        tools_used_in: p.tools_used ?? [],
        evidence_in: p.evidence ?? [],
        verdict_in: p.verdict ?? "continue",
        next_action_in: p.next_action ?? null,
      });
      break;
    case "goal.finalize":
      result = p.goal_key
        ? await rpc("goal_ledger_finalize_by_key", {
          goal_key_in: p.goal_key,
          finalized_by_agent_id_in: agent.agent_id,
          verification_report_in: p.verification_report ?? {},
        })
        : await rpc("goal_ledger_finalize", {
          goal_name_in: p.name,
          finalized_by_agent_id_in: agent.agent_id,
          verification_report_in: p.verification_report ?? {},
        });
      break;
    case "goal.update":
      result = await rpc("goal_ledger_update", {
        goal_id_in: p.goal_id,
        changed_by_agent_id_in: agent.agent_id,
        description_in: p.description ?? null,
        context_in: p.context ?? null,
        instructions_in: p.instructions ?? null,
        acceptance_criteria_in: p.acceptance_criteria ?? null,
        status_in: p.status ?? null,
        metadata_patch_in: p.metadata_patch ?? {},
        change_reason_in: p.change_reason ?? null,
      });
      break;
    case "task.create":
      if (!["orchestrator", "supervisor"].includes(agent.agent_type)) throw new Error("Orchestrator role required.");
      result = await rpc("task_ledger_create_tree", {
        agent_id_in: agent.agent_id,
        agent_name_in: agent.agent_name,
        task_definition_in: p.task_definition,
        parent_task_id_in: p.parent_task_id ?? null,
        session_id_in: p.session_id ?? null,
        agent_type_in: agent.agent_type,
      });
      break;
    case "task.claim":
      result = p.goal_key
        ? await rpc("goal_ledger_claim_task_by_key", {
          goal_key_in: p.goal_key,
          agent_id_in: agent.agent_id,
          agent_name_in: agent.agent_name,
          agent_type_in: agent.agent_type,
          capabilities_in: agent.capabilities ?? [],
          session_id_in: p.session_id ?? process.env.AGENT_SESSION_ID ?? randomUUID(),
          lease_seconds_in: p.lease_seconds ?? 900,
        })
        : p.goal_name
        ? await rpc("goal_ledger_claim_task", {
          goal_name_in: p.goal_name,
          agent_id_in: agent.agent_id,
          agent_name_in: agent.agent_name,
          agent_type_in: agent.agent_type,
          capabilities_in: agent.capabilities ?? [],
          session_id_in: p.session_id ?? process.env.AGENT_SESSION_ID ?? randomUUID(),
          lease_seconds_in: p.lease_seconds ?? 900,
        })
        : await rpc("task_ledger_claim_next", {
          agent_id_in: agent.agent_id,
          agent_name_in: agent.agent_name,
          agent_type_in: agent.agent_type,
          capabilities_in: agent.capabilities ?? [],
          lease_seconds_in: p.lease_seconds ?? 900,
        });
      break;
    case "task.heartbeat":
      result = await rpc("task_ledger_heartbeat_claim", {
        task_id_in: p.task_id,
        agent_id_in: agent.agent_id,
        claim_token_in: p.claim_token,
        current_step_in: p.current_step ?? null,
        lease_seconds_in: p.lease_seconds ?? 900,
      });
      break;
    case "task.iteration":
      result = await rpc("task_ledger_record_loop_iteration", {
        task_id_in: p.task_id, agent_id_in: agent.agent_id, claim_token_in: p.claim_token,
        iteration_no_in: p.iteration_no, input_payload_in: p.input_payload ?? {},
        output_payload_in: p.output_payload ?? {}, observation_in: p.observation ?? {},
        criterion_results_in: p.criterion_results ?? p.observation?.criterionResults ?? [],
        loop_state_in: p.loop_state ?? {}, tools_used_in: p.tools_used ?? [],
        evidence_in: p.evidence ?? [], verdict_in: p.verdict ?? "continue",
        next_action_in: p.next_action ?? null,
      });
      break;
    case "task.submit":
      result = await rpc("task_ledger_submit_result", {
        task_id_in: p.task_id, agent_id_in: agent.agent_id, claim_token_in: p.claim_token,
        result_in: p.result ?? {}, result_summary_in: p.result_summary ?? null,
        tools_used_in: p.tools_used ?? [], evidence_in: p.evidence ?? [],
        status_in: p.status ?? "completed",
      });
      break;
    case "task.claim_verification":
      result = await rpc("task_ledger_claim_verification", {
        verifier_agent_id_in: agent.agent_id,
        lease_seconds_in: p.lease_seconds ?? 900,
      });
      break;
    case "task.verify":
      result = await rpc("task_ledger_verify_result_claimed", {
        task_id_in: p.task_id, verifier_agent_id_in: agent.agent_id,
        verification_claim_token_in: p.verification_claim_token,
        verified_in: p.verified === true, verification_report_in: p.verification_report ?? {},
      });
      break;
    case "task.finalize":
      if (!["verifier", "orchestrator", "supervisor"].includes(agent.agent_type)) throw new Error("Finalizer role required.");
      result = await rpc("task_ledger_finalize_parent", {
        task_id_in: p.task_id, verifier_agent_id_in: agent.agent_id,
        outcome_in: p.outcome, verification_report_in: p.verification_report ?? {},
      });
      break;
    case "task.get": {
      const tasks = await query("tasks", { select: "*", id: `eq.${p.task_id}`, limit: "1" });
      if (!tasks[0]) throw new Error("Task not found.");
      const iterations = await query("task_iterations", {
        select: "*", task_id: `eq.${p.task_id}`, order: "iteration_no.asc",
      });
      result = { task: tasks[0], iterations };
      break;
    }
    case "task.pending_verification":
      if (!["verifier", "orchestrator", "supervisor"].includes(agent.agent_type)) throw new Error("Verifier role required.");
      result = await rpc("task_ledger_pending_verification", {});
      break;
    case "task.children":
      result = await rpc("task_ledger_children_summary", { parent_task_id_in: p.task_id });
      break;
    case "task.dependency":
      result = await rpc("task_ledger_add_dependency", {
        task_id_in: p.task_id, depends_on_task_id_in: p.depends_on_task_id,
        created_by_agent_id_in: agent.agent_id, dependency_type_in: p.dependency_type ?? "blocking",
      });
      break;
    case "task.update":
      result = await rpc("task_ledger_update", {
        task_id_in: p.task_id, agent_id_in: agent.agent_id,
        status_in: p.status ?? null, current_step_in: p.current_step ?? null,
        context_summary_in: p.context_summary ?? null, blocker_in: p.blocker ?? null,
        outcome_in: p.outcome ?? null, tags_in: p.tags ?? null,
        message_in: p.message ?? null, metadata_patch_in: p.metadata_patch ?? {},
      });
      break;
    default:
      throw new Error(`Unknown action: ${action}`);
  }
  process.stdout.write(JSON.stringify({ ok: true, action, agent_id: agent.agent_id, result }, null, 2) + "\n");
} catch (error) {
  console.error(String(error));
  process.exit(1);
}
