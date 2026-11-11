# Chat-Driven Goal and Worker Workflow

## Goal identity

- The goal title is the user-facing identity.
- The readable `goal_key` is the stable handoff identifier.
- Tags classify and filter goals.
- The internal UUID is used only for database relationships.

## Orchestrator

1. Discuss the desired outcome until a concrete goal is agreed.
2. Load Task Ledger and Loop Generator.
3. Create a descriptive title, tags, context, goal acceptance criteria and a complete goal-level loop contract.
4. Decompose the goal into direct top-level tasks. Every task and nested task has its own loop contract, acceptance criteria, verification plan and task-specific parameter contract where needed.
5. Call `goal_ledger_create_hierarchical`. Do not create a synthetic root task.
6. Inspect ready leaf tasks and dependencies. Recommend worker-chat count.
7. The user manually opens worker conversations.

## Worker: start or resume an unfinished goal

1. Call `goal_ledger_list_unfinished`.
2. If one unfinished goal exists, select it. If several exist, show their titles, readable keys, tags and statuses, then ask which to continue.
3. Call `goal_ledger_resume_by_key` and load complete context, task tree, dependencies, task iterations, goal iterations and evidence.
4. Tell the user **Loaded goal: <title>**. Use the title whenever asked which goal is loaded.
5. Claim one task with `goal_ledger_claim_task_by_key`, using a unique agent ID and chat-session ID.
6. Execute only the assigned task loop. Record every iteration and submit parameter values and evidence.
7. Do not claim another task unless explicitly instructed.

## Goal loop

The goal loop coordinates task loops and records its own iterations in `goal_iterations`. It evaluates overall progress, dependencies, goal-level acceptance criteria and evidence. A goal loop can pass only after all descendant tasks are independently verified and all goal criteria have evidence.

## Task loop and parameters

Every task has a separate loop definition and `task_iterations`. Task-specific parameters use:
- `parameters`: configuration/input values.
- `parameter_contract.required`: mandatory values.
- `parameter_contract.properties`: expected JSON types and optional enum values.
- `result_in.parameter_values`: worker-supplied completion values.

The database rejects completed submissions when required parameters are missing or invalid.

## Compute

Use `.github/workflows/agent-compute.yml` for finite computation on an ephemeral GitHub-hosted runner. It supports Python, Node.js, TypeScript, Bash, Go, Rust, Java, C, C++, C#, Ruby, PHP, Perl, R and PowerShell. It has read-only repository permission, does not persist checkout credentials, receives no application secrets, and returns an artifact. To invoke from a ChatGPT conversation when workflow_dispatch is unavailable, create a GitHub issue with title `[agent-compute] <goal-key> <runtime>` and a JSON body containing `ref`, `runtime`, `source_file`, `arguments` (string array) and `timeout_seconds`. The issue trigger accepts only repository owners, members and collaborators. Track the issue's Actions run and retrieve its artifact. Do not claim execution without a real completed run.

## Completion

```text
GoalComplete =
  GoalLoopPassed
  AND GoalCriteriaSatisfied
  AND EveryDescendantTaskIndependentlyVerified
  AND GoalEvidenceNonEmpty
```

Supabase stores state and performs atomic database coordination. GitHub Actions performs finite compute. ChatGPT conversations remain the manually launched reasoning agents. Supabase Edge Functions are not used.


## New conversation: global goals and proposed tasks

A new agent must query `goal_ledger_overview(null)` before answering what goals need completion. Show every visible unfinished goal and its task status, running agent/heartbeat, blockers, dependencies and verification. The overview is global; never assume the previous chat's selected goal is the only goal.

When a clear missing work item is discovered, the agent proposes it rather than inserting it silently. It asks **“Should I add this as a task?”** and presents the target goal, title, scope, acceptance criteria, dependencies and proposed readable ID. Only after user confirmation does it call the task-tree creation RPC. The database returns the canonical `task_key`; the agent repeats that exact key. New IDs follow `task-<descriptive-kebab-case>-<8-hex-suffix>`. Existing IDs are preserved.


## Persistent GitHub-Issue-backed coding workers

For coding goals with parallel workers, the user should not be the scheduler. The orchestrator creates one Issue per independent coding task and one dedicated PR per worker, then continuously polls Issues, PRs and CI.

Each worker reads its complete Issue before acting and maintains a Current Implementation State with status, completed work, current work, next action, blockers, questions, orchestrator response, resume point and evidence. A blocker is written to the Issue and the worker waits/polls for a response. The orchestrator answers by updating the Issue, preserving the decision for recovery.

A global continue or proceed prompt is safe to send to every worker. Each worker rereads its own Issue: terminal workers do nothing; resolved blockers resume; unresolved blockers remain waiting; active work continues. The user therefore does not need to track which agents are finished or blocked.

Supabase remains the durable goal/non-coding coordination layer. GitHub Issues are the detailed coding execution ledger; PRs are implementation artifacts; CI is verification evidence.
