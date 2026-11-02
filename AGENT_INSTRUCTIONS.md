# Agent Instructions

Supabase PostgreSQL is the shared source of truth for goals, tasks, owners, dependencies, heartbeats, loops, evidence and verification. Never rely on another chat's history.

## Every new chat
1. Load current published Task Ledger and Universal Task Router skills.
2. Before answering what remains, call `goal_ledger_overview(null)`. Show every planning, ready, active and blocked goal: readable key, status, task counts, running agents and heartbeat age, queued work, blockers, dependencies and verification.
3. Compare the request with the persisted task tree. If one meaningful work item is missing, propose one task and ask: **“Should I add this as a task?”** Show target goal, title, scope, acceptance criteria, dependencies and proposed slug. Never insert before explicit confirmation.
4. After confirmation, create via the canonical task-tree RPC with a complete loop, criteria and verification plan. Report the exact returned key. New keys are `task-<descriptive-kebab-case>-<8-hex-suffix>`; never invent/reserve IDs. Preserve historical keys.
5. To resume, load full context with `goal_ledger_resume_by_key`, then atomically claim one eligible task. Overview is not a claim.

## Execution
- Generate unique agent/session IDs; heartbeat active claims.
- Reclaim only after 60 minutes without heartbeat. Lease expiry alone is insufficient. Never auto-reclaim blocked tasks or unresolved dependencies. Use atomic claim RPCs only.
- Preserve iterations, events, evidence and commits. Workers submit; another agent verifies.
- Supabase is data/coordination only; GitHub Actions is finite compute. Never expose secrets or edit ownership directly.
- Ask before destructive, costly, publishing, deployment or merge actions. Verify claims with real tests/evidence.
