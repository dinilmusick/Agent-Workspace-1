import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.0";

const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS", "Content-Type": "application/json" };
type Agent = { user_id: string; agent_id: string; agent_name: string; agent_type: string; capabilities: string[]; enabled: boolean };
const response = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: corsHeaders });
function requiredString(value: unknown, name: string): string { if (typeof value !== "string" || !value.trim()) throw new Error(`${name} is required`); return value.trim(); }
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return response(405, { error: "method_not_allowed" });
  const authorization = req.headers.get("Authorization") ?? "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
  if (!token) return response(401, { error: "missing_bearer_token" });
  let body: Record<string, unknown>;
  try { const raw = await req.text(); if (raw.length > 1_000_000) return response(413, { error: "request_too_large" }); body = JSON.parse(raw); if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error("body must be an object"); }
  catch (error) { return response(400, { error: "invalid_json", detail: String(error) }); }
  const url = Deno.env.get("SUPABASE_URL"), serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return response(503, { error: "server_configuration_missing" });
  const db = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
  const { data: authData, error: authError } = await db.auth.getUser(token);
  if (authError || !authData.user) return response(401, { error: "invalid_or_expired_token" });
  const { data: agent, error: agentError } = await db.from("agent_registry").select("user_id,agent_id,agent_name,agent_type,capabilities,enabled").eq("user_id", authData.user.id).eq("enabled", true).maybeSingle();
  if (agentError || !agent) return response(403, { error: "agent_not_registered_or_disabled" });
  const identity = agent as Agent;
  await db.from("agent_registry").update({ last_seen_at: new Date().toISOString() }).eq("user_id", identity.user_id);
  const action = typeof body.action === "string" ? body.action.trim() : "";
  if (!action) return response(400, { error: "action_required" });
  const payload = body.payload && typeof body.payload === "object" && !Array.isArray(body.payload) ? body.payload as Record<string, unknown> : {};
  const rpc = async (name: string, args: Record<string, unknown>) => { const { data, error } = await db.rpc(name, args); if (error) throw new Error(`${name}: ${error.message}`); return data; };
  try {
    let result: unknown;
    switch (action) {
      case "skills.list": {
        const [{ data: skills, error: se }, { data: versions, error: ve }] = await Promise.all([db.from("skills").select("id,name,slug,description,status,current_version_id").eq("status", "active").order("name"), db.from("skill_versions").select("id,skill_id,version,instructions,manifest,is_published,published_at").eq("is_published", true)]);
        if (se) throw se; if (ve) throw ve; const byId = new Map((versions ?? []).map((v) => [v.id, v]));
        result = (skills ?? []).filter((s) => byId.has(s.current_version_id)).map((s) => ({ ...s, current_version: byId.get(s.current_version_id) })); break;
      }
      case "goal.create": {
        if (!["orchestrator", "supervisor"].includes(identity.agent_type)) return response(403, { error: "orchestrator_role_required" });
        const goal = await rpc("goal_ledger_create", {
          name_in: requiredString(payload.name, "name"),
          description_in: payload.description ?? "",
          context_in: payload.context ?? {},
          instructions_in: payload.instructions ?? "",
          acceptance_criteria_in: payload.acceptance_criteria ?? [],
          created_by_agent_id_in: identity.agent_id,
          owner_user_id_in: authData.user.id,
          metadata_in: payload.metadata ?? {},
        });
        result = goal;
        break;
      }
      case "goal.get":
      case "goal.resume": {
        const goal = await rpc("goal_ledger_get", { goal_id_in: payload.goal_id ?? null, name_in: payload.name ?? null });
        if (action === "goal.resume") {
          await db.from("goal_events").insert({ goal_id: goal.id, event_type: "resumed", agent_id: identity.agent_id, message: "Goal resumed by orchestrator" });
        }
        const [{ data: tasks, error: taskError }, { data: versions, error: versionError }, { data: events, error: eventError }, summary] = await Promise.all([
          db.from("tasks").select("*").eq("goal_id", goal.id).order("started_at"),
          db.from("goal_versions").select("*").eq("goal_id", goal.id).order("version", { ascending: false }).limit(10),
          db.from("goal_events").select("*").eq("goal_id", goal.id).order("occurred_at", { ascending: false }).limit(100),
          rpc("goal_ledger_summary", { goal_id_in: goal.id }),
        ]);
        if (taskError) throw taskError; if (versionError) throw versionError; if (eventError) throw eventError;
        result = { goal, summary, tasks: tasks ?? [], versions: versions ?? [], events: events ?? [] };
        break;
      }
      case "goal.update": {
        if (!["orchestrator", "supervisor"].includes(identity.agent_type)) return response(403, { error: "orchestrator_role_required" });
        result = await rpc("goal_ledger_update", {
          goal_id_in: requiredString(payload.goal_id, "goal_id"),
          changed_by_agent_id_in: identity.agent_id,
          description_in: payload.description ?? null,
          context_in: payload.context ?? null,
          instructions_in: payload.instructions ?? null,
          acceptance_criteria_in: payload.acceptance_criteria ?? null,
          status_in: payload.status ?? null,
          metadata_patch_in: payload.metadata ?? {},
          change_reason_in: payload.change_reason ?? null,
        });
        break;
      }
      case "goal.summary":
        result = await rpc("goal_ledger_summary", { goal_id_in: requiredString(payload.goal_id, "goal_id") });
        break;
      case "task.create":
        if (!["orchestrator", "supervisor"].includes(identity.agent_type)) return response(403, { error: "orchestrator_role_required" });
        result = await rpc("task_ledger_create_tree", { agent_id_in: identity.agent_id, agent_name_in: identity.agent_name, task_definition_in: payload.task_definition, parent_task_id_in: payload.parent_task_id ?? null, session_id_in: payload.session_id ?? null, agent_type_in: identity.agent_type });
        break;
      case "task.claim": result = await rpc("task_ledger_claim_next", { agent_id_in: identity.agent_id, agent_name_in: identity.agent_name, agent_type_in: identity.agent_type, capabilities_in: identity.capabilities ?? [], lease_seconds_in: payload.lease_seconds ?? 900 }); break;
      case "task.heartbeat": result = await rpc("task_ledger_heartbeat_claim", { task_id_in: requiredString(payload.task_id, "task_id"), agent_id_in: identity.agent_id, claim_token_in: requiredString(payload.claim_token, "claim_token"), current_step_in: payload.current_step ?? null, lease_seconds_in: payload.lease_seconds ?? 900 }); break;
      case "task.iteration": result = await rpc("task_ledger_record_iteration", { task_id_in: requiredString(payload.task_id, "task_id"), agent_id_in: identity.agent_id, claim_token_in: requiredString(payload.claim_token, "claim_token"), iteration_no_in: payload.iteration_no, input_payload_in: payload.input_payload ?? {}, output_payload_in: payload.output_payload ?? {}, observation_in: payload.observation ?? {}, decision_in: payload.decision ?? null, tools_used_in: payload.tools_used ?? [], evidence_in: payload.evidence ?? [], status_in: payload.status ?? "completed" }); break;
      case "task.submit": result = await rpc("task_ledger_submit_result", { task_id_in: requiredString(payload.task_id, "task_id"), agent_id_in: identity.agent_id, claim_token_in: requiredString(payload.claim_token, "claim_token"), result_in: payload.result ?? {}, result_summary_in: payload.result_summary ?? null, tools_used_in: payload.tools_used ?? [], evidence_in: payload.evidence ?? [], status_in: payload.status ?? "completed" }); break;
      case "task.verify": if (!["verifier", "orchestrator", "supervisor"].includes(identity.agent_type)) return response(403, { error: "verifier_role_required" }); result = await rpc("task_ledger_verify_result", { task_id_in: requiredString(payload.task_id, "task_id"), verifier_agent_id_in: identity.agent_id, verified_in: payload.verified === true, verification_report_in: payload.verification_report ?? {} }); break;
      case "task.finalize": if (!["verifier", "orchestrator", "supervisor"].includes(identity.agent_type)) return response(403, { error: "finalizer_role_required" }); result = await rpc("task_ledger_finalize_parent", { task_id_in: requiredString(payload.task_id, "task_id"), verifier_agent_id_in: identity.agent_id, outcome_in: requiredString(payload.outcome, "outcome"), verification_report_in: payload.verification_report ?? {} }); break;
      case "task.get": {
        const { data: task, error: taskError } = await db.from("tasks").select("*").eq("id", requiredString(payload.task_id, "task_id")).maybeSingle();
        if (taskError) throw taskError;
        if (!task) return response(404, { error: "task_not_found" });
        const { data: iterations, error: iterationError } = await db.from("task_iterations").select("*").eq("task_id", task.id).order("iteration_no");
        if (iterationError) throw iterationError;
        result = { task, iterations: iterations ?? [] };
        break;
      }
      case "task.pending_verification": {
        if (!["verifier", "orchestrator", "supervisor"].includes(identity.agent_type)) return response(403, { error: "verifier_role_required" });
        const { data: pending, error: pendingError } = await db.rpc("task_ledger_pending_verification");
        if (pendingError) throw pendingError;
        result = pending ?? [];
        break;
      }
      case "task.children": result = await rpc("task_ledger_children_summary", { parent_task_id_in: requiredString(payload.task_id, "task_id") }); break;
      case "task.dependency": result = await rpc("task_ledger_add_dependency", { task_id_in: requiredString(payload.task_id, "task_id"), depends_on_task_id_in: requiredString(payload.depends_on_task_id, "depends_on_task_id"), created_by_agent_id_in: identity.agent_id, dependency_type_in: payload.dependency_type ?? "blocking" }); break;
      case "task.update": result = await rpc("task_ledger_update", { task_id_in: requiredString(payload.task_id, "task_id"), agent_id_in: identity.agent_id, status_in: payload.status ?? null, current_step_in: payload.current_step ?? null, context_summary_in: payload.context_summary ?? null, blocker_in: payload.blocker ?? null, outcome_in: payload.outcome ?? null, tags_in: payload.tags ?? null, message_in: payload.message ?? null, metadata_patch_in: payload.metadata_patch ?? {} }); break;
      default: return response(400, { error: "unknown_action", action });
    }
    return response(200, { ok: true, action, agent_id: identity.agent_id, result });
  } catch (error) { return response(400, { error: "task_operation_failed", detail: String(error) }); }
});
