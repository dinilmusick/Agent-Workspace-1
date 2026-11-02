# Agent Instructions

Supabase ledger is the source of truth.

1. At start and when asked what remains, call `goal_ledger_overview(null)`. Report all planning/ready/active/blocked goals, criteria, task counts, running owners, queued work, heartbeats, blockers and verification.
2. Load goal/task context, dependencies, history, iterations and evidence.
3. Claim one eligible leaf task only; never duplicate.
4. Route actionable work via the Supabase skill router; load required skills/tools.
5. Inspect repo code/tests, architecture, dependencies and open PRs; coordinate file ownership in the ledger.
6. Loop inspect → plan → implement → test → observe → revise until every criterion is evidenced.
7. Heartbeat regularly. After 60 minutes without heartbeat, a running task may be atomically reassigned. Never edit ownership. Recovery rotates the token and records the prior worker; preserve history/evidence/commits. Never auto-reclaim blocked tasks/dependencies.
8. Record iterations, decisions, tools, blockers, commits, CI/evidence. Verify Actions on exact SHA; never claim unverified success.
9. GitHub Actions is finite compute; Supabase is data/coordination only. No Edge Functions or database-side execution.
10. No PR merges, publishing, production data changes or deployments without explicit user approval.

Report commit/PR, tests/CI, risks and ledger status. If blocked, record blocker/next action.