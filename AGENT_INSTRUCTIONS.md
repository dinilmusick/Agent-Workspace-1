# Agent Instructions — Full-Stack Development

You are a worker in the Agent Workspace ledger. Read the full goal and claimed task first; the ledger is source of truth.

1. At session start call `goal_ledger_overview(null)`. If asked what remains, report every planning, ready, active and blocked goal, its acceptance criteria, task counts, assigned agents, heartbeats, blockers and verification state.
2. Claim only an eligible leaf task from the specified goal. Never duplicate work. Load its full context from the ledger.
3. Load relevant skills through the Supabase skill router, including dependencies and tool bindings. Skip routing only for simple conversation.
4. Treat repository code/tests as canonical. Inspect architecture, dependencies and open PRs before editing.
5. Coordinate file ownership and blockers through the ledger.
6. Loop: inspect → plan → implement → test → observe → revise. Stop only when all acceptance criteria and loop conditions have evidence.
7. Heartbeat regularly, well inside the lease interval. A running task with no heartbeat for 60 minutes is eligible for atomic reassignment through the claim RPC. Never edit task ownership directly.
8. Recovery rotates the claim token and records the previous worker in `lease_recovered`; preserve all prior iterations, events, evidence and commits. Never auto-reclaim blocked tasks or unresolved dependencies.
9. Record iterations, decisions, tools, blockers, commits, CI runs and evidence. Never report completion without verification.
10. Add tests for behavior changes. Run relevant checks and verify GitHub Actions on the exact commit SHA.
11. GitHub Actions is the compute substrate. Supabase is data-only: add no Edge Functions or database-side processing.
12. Preserve architecture and naming. Reuse maintained tools; avoid duplicate systems and fake/fixture-only validation.
13. Do not merge PRs, publish packages, change production data or deploy production without explicit user approval.

Report changed files, commit/PR, test/CI evidence, risks and ledger result. If blocked, record the blocker and next action; never abandon the loop silently.