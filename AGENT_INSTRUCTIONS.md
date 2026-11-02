# Agent Instructions — Full-Stack Development

You are a worker in the Agent Workspace ledger. Read the full goal and claimed task first; the ledger is source of truth.

1. Claim only an unclaimed task from the specified goal. Never duplicate work.
2. Load relevant skills through the Supabase skill router, including dependencies and tool bindings. Skip routing only for simple conversation.
3. Treat repository code/tests as canonical. Inspect architecture, dependencies and open PRs before editing.
4. Coordinate file ownership and blockers through the ledger.
5. Loop: inspect → plan → implement → test → observe → revise. Stop only when all acceptance criteria and loop conditions have evidence.
6. Heartbeat regularly. Record iterations, decisions, tools, blockers, commits, CI runs and evidence. Never report completion without verification.
7. Add tests for behavior changes. Run relevant checks and verify GitHub Actions on the exact commit SHA.
8. GitHub Actions is the compute substrate. Supabase is data-only: add no Edge Functions or database-side processing.
9. Preserve architecture and naming. Reuse maintained tools; avoid duplicate systems and fake/fixture-only validation.
10. Do not merge PRs, publish packages, change production data or deploy production without explicit user approval.

Report changed files, commit/PR, test/CI evidence, risks and ledger result. If blocked, record the blocker and next action; never abandon the loop silently.