# Hierarchical Chat-Driven Goal and Task Ledger

ChatGPT conversations are the reasoning agents. The user manually opens the orchestrator and worker conversations. Supabase stores durable state and coordinates claims. GitHub Actions provides finite, ephemeral compute.

## Identity and hierarchy

- `goals.name`: descriptive, human-readable goal title shown in every user-facing response.
- `goals.goal_key`: stable readable identifier generated from the title, such as `refactor-agent-workflow`. Use this key in prompts and handoffs.
- `goals.id`: internal UUID for relational integrity; never use it as the displayed goal identity.
- `goals.tags`: searchable classification labels.
- A goal has its own Loop Generator contract, state and iteration history in `goal_loop_definition`, `goal_loop_state`, `goal_loop_iteration` and `goal_iterations`.
- Top-level tasks are direct children of the goal (`goal_id`, null `parent_task_id)). Nested tasks are rows in `tasks` linked by `parent_task_id`. Do not create a synthetic root task.
- Every task at every depth has its own loop contract and iteration history. Task parameters and completion values are persisted separately.

## Orchestrator flow

1. Keep ordinary conversation ordinary until a concrete actionable goal is agreed.
2. Generate a descriptive title, readable key, tags, complete context, goal acceptance criteria and a goal-level Loop Generator contract.
3. Decompose into direct top-level tasks. Each task and nested task needs its own loop contract, task-specific parameter contract where applicable, acceptance criteria, output contract and independent verification plan.
4. Call `goal_ledger_create_hierarchical` with the goal definition and array of top-level task definitions. It creates the goal and task tree atomically.
5. Add dependencies, then inspect the goal summary and ready leaf-task parallelism. Recommend worker-chat count.
6. The user manually opens worker chats. Each worker loads the selected goal and claims one task by readable goal key.
7. The orchestrator records goal-loop iterations as tasks progress. Goal-loop pass requires every task independently verified, goal criteria satisfied and non-empty evidence.

## New-chat unfinished-goal flow

1. Call `goal_ledger_list_unfinished` immediately when asked to continue an unfinished goal.
2. If one goal is available, load it. If several are available, display each title, readable key, tags and status, then ask which one to resume.
3. Call `goal_ledger_resume_by_key` to load the full goal, task tree, dependencies, task iterations, goal iterations and events.
4. Tell the user: **Loaded goal: <title>**. Use the title when asked what goal is loaded. Do not expose the internal UUID as the identity.
5. Claim one available leaf task with `goal_ledger_claim_task_by_key`, using unique agent and chat-session IDs.

## Worker flow

1. Load the selected goal and all relevant task context.
2. Atomically claim one eligible leaf task; exclusive claims use row locking and leases.
3. Execute the persisted task loop and renew its lease.
4. Record each iteration with actual inputs, outputs, observations, criterion results, loop state, tools and evidence.
5. Submit result values, including `parameter_values`, through `task_ledger_submit_result`. The database validates required parameter names, types and optional enums before accepting completion.
6. Do not self-verify. An independent verifier checks the result and evidence.
7. Do not claim another task unless instructed.

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

The database enforces these gates. A worker's assertion that work is complete is not sufficient.

## GitHub compute workspace

`.github/workflows/agent-compute.yml` executes a source file from a selected repository revision on an ephemeral GitHub-hosted Ubuntu runner. Supported runtimes: Python, Node.js, TypeScript, Bash, Go, Rust, Java, Ruby, PHP, C# and PowerShell. It accepts JSON string arguments, enforces a maximum 1,200-second execution timeout, and uploads bounded stdout/stderr/result evidence as a workflow artifact.

The job has read-only repository permission, checkout credentials are not persisted, and no application secrets are passed to the executed process. The runner is finite compute, not a persistent workspace or ChatGPT agent. The source file must exist in the selected repository revision. Do not place credentials in source files. The current GitHub connector may not expose workflow dispatch; use an authorized dispatch capability or the GitHub Actions UI, and never report an execution that was not actually run.

## Compute boundary

- ChatGPT: reasoning, planning, code authoring, tool selection and verification.
- GitHub Actions: finite code execution, builds, tests and generated artifacts.
- Supabase: persistence, owner-scoped reads/writes and atomic transactional coordination.
- PostgreSQL RPC: claims, leases, iteration append, result submission, verification and guarded finalization only.
- Supabase Edge Functions: not used.
