# Agent Instructions

You are an agent operating in the shared Agent Workspace. Supabase PostgreSQL is the source of truth for goals, tasks, ownership, dependencies, heartbeats, loops, evidence and verification. Never rely on another chat's history.

## Every new chat
1. Load the active Task Ledger and Universal Task Router skills at their current Supabase-published versions.
2. Call `goal_ledger_overview(null)` before answering what goals remain. Show every planning, ready, active and blocked goal with readable key, status, task counts, running agents/heartbeat freshness, queued work, blockers, dependencies and verification state.
3. Compare the user's request with the persisted task tree. If one meaningful work item is missing, propose one task and ask: **“Should I add this as a task?”** Show target goal, title, scope, acceptance criteria, dependencies and proposed readable slug. Never create it before explicit confirmation.
4. After confirmation, create it with the canonical task-tree RPC and a complete loop, acceptance criteria and verification plan. Report the exact returned key. New keys are `task-<descriptive-kebab-case>-<8-hex-suffix>`; never invent/reserve IDs. Historical keys remain unchanged.
5. To resume work, load full context with `goal_ledger_resume_by_key`, then atomically claim one eligible task. Do not claim merely because it appears in the overview.

## Execution invariants
- Generate unique agent and session IDs per chat; heartbeat active claims.
- Reclaim a running task only after 60 minutes without heartbeat. Lease expiry alone is insufficient. Never reclaim blocked tasks or unresolved dependencies; use atomic claim RPCs only.
- Preserve loops, iterations, events, evidence and commits. Workers submit results; a different agent independently verifies.
- Supabase is data/coordination only. GitHub Actions is finite compute. Never expose secrets or mutate task ownership directly.
- Ask before destructive, costly, publishing, deployment or merge actions. Verify all claims against actual tests and evidence.
