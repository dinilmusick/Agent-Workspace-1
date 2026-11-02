# Agent recovery and goal discovery

## One-hour stale-worker recovery

A running task is reclaimable when its lease has expired or its last heartbeat is at least 60 minutes old. The condition is evaluated inside the same transaction that locks and claims the task with `FOR UPDATE SKIP LOCKED`; competing agents cannot both take ownership.

All supported claim entry points must apply the same rule, including `goal_ledger_claim_task_by_key` (the standard ChatGPT worker path), `goal_ledger_claim_task`, `task_ledger_claim_next` and `task_ledger_claim_goal_next`.

Recovery rotates the claim token, increments the attempt counter, assigns the new worker/session and appends a `lease_recovered` event containing the previous agent, token, heartbeat and recovery reason. Existing iterations, task events, submitted evidence and commits are retained.

Tasks already in `blocked` state are never auto-reclaimed. A blocked goal is not claimable. A child of a failed, cancelled, abandoned or blocked parent is ineligible. Maximum-attempt and dependency checks remain enforced.

Workers must heartbeat well inside their lease interval. The 60-minute threshold is crash recovery, not a normal scheduling interval. A stale heartbeat only makes a task eligible; it does not reassign ownership until an agent performs the atomic claim.

## Complete unfinished-goal overview

Call `goal_ledger_overview(null)` at the start of an orchestration session and whenever an agent asks what goals remain. The result includes every visible planning, ready, active and blocked goal; goal acceptance criteria; task counts; task state, owner, heartbeat, current step, blocker and verification status; and stale-heartbeat flags.

Use the overview to explain all running and outstanding goals before selecting work. Then load the chosen goal with `goal_ledger_resume_by_key`, inspect its full context and task tree, and claim exactly one eligible leaf task. Never infer availability from the overview alone: use the atomic claim RPC.

The overview follows the workspace owner visibility boundary. The current connected project is single-owner and has no Supabase Auth users; this is not multi-tenant isolation.

## Verification

Run `supabase/tests/agent-recovery-and-overview.integration.sql` against a disposable database. It simulates a worker whose heartbeat is 61 minutes old while its lease remains live, verifies reassignment through the normal goal-key claim entry point, checks token rotation and append-only recovery evidence, and checks that the overview exposes the new owner and task aggregates.
