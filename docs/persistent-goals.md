# Persistent Goal and Task Ledger

Supabase PostgreSQL is the canonical persistent ledger. GitHub is the source for versioned implementation and the execution host for automated jobs; GitHub is not the task database. No Supabase Edge Function is required for database persistence or atomic task claiming. The existing authenticated `task-ledger` Edge Function remains a compatibility gateway until direct authenticated RPC clients are provisioned and verified.

## Goal model

- `public.goals`: stable UUID, globally case-insensitive unique name, description, full JSON context, instructions, acceptance criteria, status and context version.
- `public.goal_versions`: immutable snapshots each time the goal's substantive context changes.
- `public.goal_events`: append-only lifecycle and orchestration events.
- `public.tasks.goal_id`: associates every task and recursively-created child task with its goal.

Goal statuses: planning, ready, active, blocked, completed, cancelled, archived.

## Database operations

All goal operations are PostgreSQL transactions/RPCs, not Edge Function compute:

- `goal_ledger_create(name_in, description_in, context_in, instructions_in, acceptance_criteria_in, created_by_agent_id_in, owner_user_id_in, metadata_in)`
- `goal_ledger_get(goal_id_in, name_in)`
- `goal_ledger_update(goal_id_in, changed_by_agent_id_in, ...)`
- `goal_ledger_summary(goal_id_in)`

The task-tree RPC accepts `goal_id` in the root task definition. Children inherit the same goal ID, and cross-goal parent/child relationships are rejected. Task claims use PostgreSQL row locking with `FOR UPDATE SKIP LOCKED`, leases and claim tokens. Only leaf tasks are claimable; decomposition-only parent tasks are never assigned to execution workers. Verification has its own atomic claim and expiring verifier lease, so concurrent verifiers cannot process the same result.

## Orchestrator protocol

1. Resolve an existing goal by UUID or case-insensitive unique name before creating a new one.
2. For a new goal, persist the complete problem context, constraints, instructions and acceptance criteria.
3. Decompose the goal into a root task and independently executable subtasks. Include `goal_id` on the root definition; children inherit it.
4. Persist blocking dependencies before marking the goal ready.
5. Query `goal_ledger_summary` and recommend workers based on ready, dependency-unblocked tasks.
6. On resume, retrieve the goal, latest version, task tree, events, iterations and evidence. Continue from ledger state, not chat history.
7. Re-plan only when evidence or changed requirements justify it. Version every substantive context update.

## Worker protocol

1. Authenticate as a registered agent.
2. Atomically claim one eligible task. A claim is exclusive until lease expiry and carries a claim token.
3. Retrieve the task, its goal context and required skill definitions.
4. Execute only the claimed task; heartbeat with the claim token.
5. Persist iterations, result and evidence.
6. Submit for independent verification. Do not self-verify or finalize the parent.
7. Claim another eligible task until none is ready.

A task's self-contained execution context should include goal ID/version, task definition, relevant constraints, required skills, inputs, acceptance criteria and output contract. Store references to large artifacts rather than copying large binaries into JSONB.

## Security and compute boundary

- Keep RLS enabled. Goal, version and event tables are not directly readable/writable by anon or authenticated roles; privileged access is limited to the authenticated server boundary.
- Never place a service-role key in GitHub source, artifacts, model prompts or public workflows.
- Supabase PostgreSQL performs durable storage and short atomic transactions only. No LLM inference, code execution, task planning loops or worker polling in Supabase Edge Functions.
- GitHub Actions may run automated workers and verifiers. ChatGPT connector sessions can act as interactive orchestrators/workers through an authenticated database interface.
- The existing Edge Function is still deployed as a legacy gateway. Do not remove it until direct authenticated RPC access is implemented and tested end-to-end.
