# Agent Instructions

Supabase is the source of truth for goals, tasks, dependencies, ownership, heartbeats, skills and workflow memory. Never rely on another chat's history.

## New chat
1. For shallow conversation, answer directly; do not load skills/task infrastructure.
2. For substantive requests, load the current Task Ledger and semantic-resource-resolution skill.
3. Before answering what remains, call `goal_ledger_overview(null)`. Show ALL planning, ready, active and blocked goals: readable key, status, counts, agents/heartbeat age, queued work, blockers and verification.
4. Compare the request with persisted tasks. If meaningful work is missing, propose ONE task and ask **“Should I add this as a task?”** Show goal, title, scope, criteria, dependencies and proposed slug. Do not insert before yes.
5. After yes, create via task-tree RPC with loop, criteria and verification plan. New keys: `task-<descriptive-kebab-case>-<8-hex-suffix>`. Never invent IDs; preserve old keys.
6. To resume, load context via `goal_ledger_resume_by_key`, then atomically claim one task.

## Execution
- Use unique agent/session IDs; heartbeat active claims.
- Reclaim only after 60 minutes without heartbeat; lease expiry alone is insufficient. Never reclaim blocked tasks or unresolved dependencies.
- Preserve iterations, events, evidence and commits. Workers submit; another agent verifies.
- Supabase is data/coordination; GitHub Actions is finite compute. Never expose secrets or edit ownership directly.
- Ask before destructive, costly, publishing, deployment or merge actions. Verify with tests/evidence.

## Semantic resource + obstacle memory
For substantive work, semantically search the indexed resource layer before selecting skills/resources, then resolve results to canonical Supabase records. The vector index is an index, never the source of truth.
When a workflow obstacle materially blocks, delays or changes work, search obstacle memory first. Deduplicate similar obstacles semantically; update the canonical obstacle and append an occurrence with goal/task, evidence and resolution. Do not create duplicate memories. Reuse prior solutions before retrying.

## Universal task decomposition law
Every new task, in every domain, must contain an explicit `actions` array with **1–4 actions**. This is a universal planning invariant, not a coding rule. If more are needed, split into additional tasks. Every substantive task also requires a domain-appropriate `general_pattern`.

## General pattern visibility
Every substantive task must include `general_pattern`, describing its conceptual execution shape. Worker progress/results must expose it. Coding patterns are only one specialization.

## Coding
Any coding implementation must route through **Coding Router** and the narrowest specialist skill before execution. For substantive work, Coding Workflow is mandatory. Verify at the observable layer: tests/typecheck/lint/build; browser/runtime inspection for rendered behavior; CI for repository integration.

## Omni Loop ontology
- Every new goal: exactly one `goal_type`, one `target`, non-empty `behavior_inputs` and `expected_outputs`, acceptance criteria and goal-level Omni Loop.
- Every new task: exactly one `task_type`, one `target`, acceptance criteria and its own Omni Loop.
- Task target is immutable and must equal its parent target. Child tasks refine execution, never retarget it.
- Omni Loop input is an `edit`; output is observed target behavior after that edit.
- Closed vocabularies live in `schemas/ontology.ts` and are enforced at the Supabase boundary.
- New persistent goals use `goal_ledger_create_omni_hierarchical` with mandatory `vision_id` and `vision_target_id` metadata. The database rejects canonical Omni goal creation without an attached tldraw board and matching Vision target.
- A Vision has one root target, a component-target decomposition graph and goal links; its tldraw board is mandatory as the visual projection of Supabase state.
- Canonical planning is **Vision → Target(s) → Goal(s) → Task(s) → Omni Loop(s)**. Use tldraw for the visual projection and Supabase for canonical state.
- For diagrams, load Diagram Engineering and tldraw Agent; inspect both structured canvas state and rendered output, then lint and revise layout.
