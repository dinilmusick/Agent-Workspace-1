# Agent recovery and goal discovery

## One-hour stale-worker recovery

A task in `running` state is reclaimable when either its lease has expired or its last heartbeat is at least 60 minutes old. The timeout is evaluated inside the same transaction that locks and claims the task (`FOR UPDATE SKIP LOCKED`), so competing agents cannot both take ownership.

Recovery rotates the claim token, increments the attempt counter, assigns the new worker and writes a `lease_recovered` event containing the previous agent, claim token, heartbeat and recovery reason. Previous iterations, events, submitted evidence and commits are retained.

Tasks in `blocked` state are not automatically reclaimed. A blocked goal is not claimable. A task whose parent is failed, cancelled, abandoned or blocked is also ineligible. Maximum-attempt and dependency checks remain enforced.

Workers must continue sending heartbeats well inside their lease interval. The 60-minute timeout is crash recovery, not a normal scheduling interval.

## Complete unfinished-goal overview

Call `goal_ledger_overview(null)` at the start of an orchestration session and whenever an agent asks what work remains. The returned JSON includes every visible planning, ready, active and blocked goal; each goal's acceptance criteria; task counts; every task's state, owner, last heartbeat, current step, blocker and verification state; and stale-heartbeat flags.

Use the overview to explain the complete workload before selecting work. Then load the chosen goal with `goal_ledger_resume_by_key`, inspect its full task context, and claim exactly one eligible leaf task. Do not infer that a task is available merely because its heartbeat is stale: use the atomic claim RPC.

The overview follows the same owner visibility rule as `goal_ledger_list_unfinished`. In the current single-owner workspace, an unauthenticated connector session sees the workspace goals. Do not treat this as multi-tenant isolation.

## Verification

Run `supabase/tests/agent-recovery-and-overview.integration.sql` against a disposable database. It simulates a worker whose heartbeat is 61 minutes old while its lease remains live, verifies atomic reassignment and evidence preservation, and checks that the overview exposes the new owner.
