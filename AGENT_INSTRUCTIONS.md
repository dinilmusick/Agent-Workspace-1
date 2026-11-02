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
