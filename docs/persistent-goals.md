# Persistent Goal and Task Ledger

Supabase PostgreSQL is the canonical persistent ledger. GitHub is the canonical source for implementation, CI and optional finite compute; it is not the task database. Browser ChatGPT conversations use the connected Supabase database tools directly. No Supabase Edge Function is part of their claim/execute/verify path.

## Goal model

- `public.goals`: stable UUID, case-insensitive unique name, complete context, instructions, acceptance criteria, lifecycle status and context version.
- `public.goal_versions`: immutable context snapshots.
- `public.goal_events`: append-only lifecycle history.
- `public.tasks.goal_id`: links every root, parent and child task to its goal.
- `public.task_dependencies`: blocking/advisory dependency edges.
- `public.task_iterations`: append-only execution observations, criteria results, loop state and evidence.
- `public.task_events`: append-only task lifecycle history.

Goal statuses: planning, ready, active, blocked, completed, cancelled, archived.

## Orchestrator operations

- `goal_ledger_create_with_tasks(...)`: atomically creates a goal and validated loop-backed task tree.
- `goal_ledger_list(status)`: discovers goals to resume.
- `goal_ledger_resume(name)`: returns goal, progress summary, all tasks and iterations, dependency edges, version snapshots, latest version and events.
- `goal_ledger_summary(goal_id)`: returns leaf-task progress and recommended worker count.
- `goal_ledger_update(...)`: updates goal context/status and versions substantive changes.
- `goal_ledger_finalize(name, agent_id, report)`: finalizes parent rows bottom-up and completes the goal only after all tasks are independently verified.

Every task, including root/intermediate parents, must contain a valid Loop Generator contract: enabled, objective, input/output contracts, non-empty cycle, evaluation, non-empty stop conditions and bounded max_iterations (1–100), plus observable acceptance criteria and a verification plan.

## Worker operations

- `goal_ledger_claim_task(goal_name, agent_id, agent_name, agent_type, capabilities, session_id, lease_seconds)`: atomically claims one eligible leaf task using `FOR UPDATE SKIP LOCKED`. It records a unique session ID, claim token and lease.
- `task_ledger_heartbeat_claim(...)`: renews the lease. A stale worker must stop writing when its token is rejected.
- `task_ledger_record_loop_iteration(...)`: records actual input/output, observations, criterion results, loop state, tools and evidence.
- `task_ledger_submit_result(...)`: submits the result. A completed leaf task is rejected unless the latest loop iteration passed every criterion with evidence.
- `task_ledger_claim_verification(...)` and `task_ledger_verify_result_claimed(...)`: atomically lease and verify pending results. A worker cannot verify its own result.
- `goal_ledger_finalize(...)`: completes parents and goal only after all leaf work is verified.

## Conversation protocol

The orchestrator chat creates or resumes the goal, decomposes it, persists context and dependencies, and reports ready leaf count plus recommended worker chats. Each manually opened worker chat is given only:

```text
Claim and complete one task from goal: <GOAL NAME>.
Load all context from the Supabase Goal and Task Ledger. Do not ask me to restate the goal. Execute the task's persisted Loop Generator contract, record each iteration and evidence, and submit for independent verification. Do not claim another task unless I tell you to continue.
```

A replacement orchestrator uses:

```text
Resume goal: <GOAL NAME>.
Load its canonical context, latest version, task tree, dependencies, loop states, iterations, evidence and verification status from Supabase. Reconcile current state, report progress and recommend worker chats based on ready independent leaf tasks.
```

Full interaction contract: [ChatGPT goal/worker protocol](chat-agent-workflow.md).

## Compute and security boundary

- Supabase PostgreSQL stores state and performs short atomic transactions only.
- No LLM inference, repository builds, code execution, planning loops or continuous polling run in Supabase Edge Functions.
- Browser ChatGPT conversations use Supabase connector operations directly; the deployed `task-ledger` Edge Function remains only as a legacy gateway for the repository CLI worker.
- GitHub Actions may run finite CI, tests, repository workers and verifiers. It never launches ChatGPT browser conversations.
- RLS is enabled. Authenticated API access is owner-scoped; goal versions and goal/task events and iterations are append-only for authenticated clients.
- Never put service-role keys or agent credentials in source, prompts, task context, results or artifacts.
