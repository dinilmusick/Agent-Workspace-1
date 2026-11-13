# Goal and task ledger integration

## Canonical integration

ChatGPT conversations use the connected Supabase PostgreSQL tools directly. Supabase PostgreSQL is the only persistent state and coordination system. No Edge Function, repository-hosted API proxy, CLI worker or verifier daemon is required.

## Goal identity and hierarchy

- `goals.name`: descriptive, human-readable title shown to the user.
- `goals.goal_key`: stable readable identifier generated from the title.
- `goals.id`: internal UUID used for relational integrity only.
- `goals.tags`: searchable classification labels.
- A goal has its own Loop Generator contract, state and history in `goal_loop_definition`, `goal_loop_state`, `goal_loop_iteration` and `goal_iterations`.
- Top-level tasks are direct children of the goal. Nested tasks link through `parent_task_id`. Do not create a synthetic root task.
- Every task at every depth has its own loop contract and iteration history. Task parameters and completion values are persisted separately.

## Orchestrator flow

1. Agree on a concrete outcome.
2. Create a descriptive title, readable key, tags, context, acceptance criteria and goal-level loop contract.
3. Decompose into direct top-level tasks. Each task needs its own loop, acceptance criteria, output contract and independent verification plan; add a parameter contract where needed.
4. Call `goal_ledger_create_hierarchical` to create the goal and task tree atomically.
5. Inspect dependencies and ready leaf-task parallelism. Recommend worker-chat count.
6. The user manually opens worker chats. Each worker loads the goal and claims one task by readable key.
7. Record goal-loop iterations as tasks progress. Goal-loop pass requires every descendant task independently verified, goal criteria satisfied and non-empty evidence.

## New-chat resume

1. Call `goal_ledger_list_unfinished`.
2. If one unfinished goal exists, resume it. If several exist, show titles, readable keys, tags and statuses, then ask which to continue.
3. Call `goal_ledger_resume_by_key` to load the goal, task tree, dependencies, task iterations, goal iterations and events.
4. Tell the user `Loaded goal: <title>`. Never display the internal UUID as the goal identity.
5. Claim one available leaf task with `goal_ledger_claim_task_by_key`, using unique agent and chat-session IDs.

## Worker and verification flow

1. Load the selected goal and task context from Supabase.
2. Atomically claim one eligible leaf task; exclusive claims use row locking and leases.
3. Execute the persisted task loop. Use GitHub Actions Agent Compute only when finite code execution is required.
4. Record each iteration with actual inputs, outputs, observations, criterion results, loop state, tools and evidence.
5. Submit result values, including `parameter_values`, through `task_ledger_submit_result`. Database validation rejects missing or invalid required values.
6. A different chat independently verifies the result. Do not self-verify.
7. Record the goal-loop evaluation and finalize only when all database-enforced completion criteria pass.

## Completion invariants

```text
TaskComplete =
  TaskLoopPassed
  AND RequiredParametersSatisfied
  AND ResultSubmitted
  AND IndependentlyVerified

GoalComplete =
  GoalLoopPassed
  AND GoalAcceptanceCriteriaSatisfied
  AND EveryDescendantTaskIndependentlyVerified
  AND GoalEvidenceNonEmpty
```

## Compute boundary

- ChatGPT: reasoning, planning, implementation, tool selection and verification.
- Supabase PostgreSQL: persistence, claims, leases, iteration history and guarded transitions.
- GitHub Actions: finite code execution, builds, tests and generated artifacts.
- Supabase Edge Functions: not used and not required.

See [architecture](architecture.md), [chat worker protocol](chat-agent-workflow.md) and [compute request contract](compute-request.md).

## Workspace identity and security

The connected project currently has no rows in `auth.users`. ChatGPT browser conversations therefore use unique `agent_id` and `session_id` values within one project-scoped workspace where `owner_user_id` is null. A different conversation can independently verify and finalize; the database rejects self-verification and finalization by a task worker.

This is suitable for the current single-owner project. It is not multi-tenant isolation. If the project is shared with other human owners, provision Supabase Auth users, bind goals to `owner_user_id`, and enforce JWT/RLS owner boundaries before enabling shared access.


## Goal-level prerequisite dependencies (blocking gates)

Goals may depend on other goals through `public.goal_dependencies`:

- `goal_id` is the dependent goal; `depends_on_goal_id` is its prerequisite.
- `dependency_type='blocking'` prevents the dependent goal from becoming active/completed and prevents every task in that goal from transitioning to `running` until every blocking prerequisite has status `completed` and all of its descendant tasks are verified (or explicitly `not_required`).
- `dependency_type='advisory'` is recorded and shown to agents but never blocks activation, claims or completion.
- Self-dependencies, duplicate edges and blocking cycles are rejected. Graph writes are serialized with a transaction-scoped advisory lock so concurrent edge insertions cannot create a cycle.
- A dependency may not cross Vision boundaries: if either goal is attached to a Vision, both must be attached to the same Vision.
- Goal completion is independently guarded by the database, even when an agent bypasses the normal finalize RPC.

Use the trusted Supabase service-role database connector for dependency mutations. The canonical helper is:

```sql
select * from public.goal_ledger_add_dependency(
  '<dependent-goal-key>',
  '<prerequisite-goal-key>',
  'blocking', -- or 'advisory'
  '<agent-id>'
);
```

The helper validates both readable goal keys, persists the edge and appends a goal event. Do not grant this operation to anon/authenticated API roles: `goal_dependencies` is a service-controlled coordination table. Never rely on prompts or client-side checks for enforcement.

### Required multi-phase planning pattern

For sequential project phases, create all goals first, then add explicit blocking edges before any worker starts:

```text
Research goal
  └─ verified completion unlocks Repository acquisition goal
       └─ verified completion unlocks Ecosystem absorption goal
```

Add edges from the later goal to its prerequisite (dependent → prerequisite). Parallel work within a phase remains parallel; only later phases are gated. Advisory edges express useful context without serializing execution.

### Verification

Run the rollback-only regression script in `supabase/tests/task-ledger-goal-dependencies.integration.sql` against the trusted Supabase connector. It proves that blocking prerequisites prevent goal activation and task claims, blocking cycles are rejected, and advisory edges remain non-blocking. The script rolls back its fixtures. Also inspect the database triggers on `goals`, `tasks` and `goal_dependencies` after schema changes.


## Bounded v2 completion model

The canonical execution hierarchy is now a bounded loop model:

```
Vision -> 1..N Goals -> 1..4 direct Tasks -> 1..4 Checkpoints
```

- A Vision may contain any number of Goals.
- A Goal may contain at most four direct Tasks. Its `completion_parameters` projection is maintained from those tasks.
- A Task may contain no new nested tasks in bounded-v2; additional work becomes another Task or Goal.
- Every bounded-v2 Task has 1-4 completion parameters and exactly one Checkpoint for each parameter.
- A Checkpoint records `parameter_id`, `objective`, `status`, `result`, `context` and `evidence`.
- A bounded-v2 Task cannot transition to `completed` until every Checkpoint has `status=succeeded`.
- The database triggers enforce these limits; prompts are not the authority.
- Legacy rows remain readable so existing work can be resumed while all newly created task trees use bounded-v2.

Resume therefore means loading the unfinished Goal, selecting an incomplete Task, and continuing at its persisted `current_checkpoint_index` rather than reconstructing conversational context.


Bounded-v2 is the creation contract. Existing pre-v2 goals that already contain more than four direct tasks are explicitly retained as `legacy` rather than being silently split or discarded; a later reconciliation pass can safely migrate their work into multiple bounded goals. This preserves existing execution context while making the four-task invariant absolute for new bounded goals.
