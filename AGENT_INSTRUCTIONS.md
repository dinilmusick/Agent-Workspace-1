# Agent Instructions

Supabase is the source of truth for goals, tasks, dependencies, ownership and heartbeats. Never rely on another chat's history.

## New chat
1. Load current Task Ledger and Universal Task Router skills.
2. Before answering what remains, call `goal_ledger_overview(null)`. Show ALL planning, ready, active and blocked goals: readable key, status, counts, agents/heartbeat age, queued work, blockers and verification.
3. Compare the request with persisted tasks. If meaningful work is missing, propose ONE task and ask **“Should I add this as a task?”** Show goal, title, scope, criteria, dependencies and proposed slug. Do not insert before yes.
4. After yes, create via task-tree RPC with loop, criteria and verification plan. Report returned key. New keys: `task-<descriptive-kebab-case>-<8-hex-suffix>`. Never invent IDs; preserve old keys.
5. To resume, load context via `goal_ledger_resume_by_key`, then atomically claim one task.

## Execution
- Use unique agent/session IDs; heartbeat active claims.
- Reclaim only after 60 minutes without heartbeat; lease expiry alone is insufficient. Never reclaim blocked tasks or unresolved dependencies.
- Preserve iterations, events, evidence and commits. Workers submit; another agent verifies.
- Supabase is data/coordination; GitHub Actions is finite compute. Never expose secrets or edit ownership directly.
- Ask before destructive, costly, publishing, deployment or merge actions. Verify with tests/evidence.


## Task decomposition law
Every newly created task must contain an explicit `actions` array with **1–4 actions**.

If the work requires more than four actions, **do not create a larger task**. Split the work into another task (or additional tasks) with their own 1–4 actions. This is enforced at the canonical task-tree database boundary.

```text
Goal
├── Task A
│   ├── Action 1
│   ├── Action 2
│   └── Action 3
├── Task B
│   ├── Action 1
│   └── Action 2
└── Task C
    └── Action 1
```

## General pattern visibility
For every substantive coding task, the task definition must include a `general_pattern` describing the architectural/code pattern being applied. Worker progress and results must expose that pattern in user-facing reporting.

Example:
```text
general_pattern:
  input → validate → transform → persist → verify
```

The pattern is the conceptual execution shape, not a file-by-file activity log.

## Coding skill requirement
Any coding implementation must route through **Coding Router** and then the narrowest specialist skill before code execution. For substantive work, Coding Workflow is mandatory. Verify at the observable layer: tests/typecheck/lint/build for code, browser/runtime inspection for rendered behavior, and CI for repository-level integration.

## GitHub repository tooling
Permanent GitHub repository-management helpers live under `tools/github/`. They authenticate only through an environment-provided GitHub token, never contain credentials, support explicit repository visibility and initialization options, fail closed on missing credentials/API errors, and require no global third-party package. See `tools/github/README.md`.
