# Agent recovery and goal discovery

## One-hour stale-worker recovery

A task in `running` state becomes reclaimable only when its last heartbeat is at least 60 minutes old. An expired claim lease alone does not permit reassignment. Claim RPCs enforce this rule inside the same transaction that locks the task (`FOR UPDATE SKIP LOCKED`), so concurrent agents cannot both acquire it.

New claims and heartbeat renewals receive a minimum 60-minute lease. A worker can renew an expired lease while its claim token is still current; if another worker has already reclaimed the task, the token has rotated and the old worker can no longer update it.

Recovery rotates the claim token, increments the attempt counter, assigns the new worker and writes a `lease_recovered` event containing the previous agent, claim token, heartbeat and recovery reason. Previous iterations, events, submitted evidence and commits are retained.

Tasks in `blocked` state are never automatically reclaimed. A blocked goal is not claimable. Tasks under failed, cancelled, abandoned or blocked parents, unresolved blocking dependencies, and exhausted attempt budgets are also ineligible.

Workers must heartbeat regularly and well inside the lease interval. The 60-minute timeout is crash recovery, not a normal scheduling interval.

## Complete unfinished-goal overview

Call `goal_ledger_overview(null)` at the start of an orchestration session and whenever an agent asks what work remains. The returned JSON includes every visible planning, ready, active and blocked goal; full goal context and acceptance criteria; goal-loop definition/state/iteration; task counts; each task's acceptance criteria, verification plan, loop state, parameters, owner, heartbeat freshness, blocker, dependencies and recent events.

Use the overview to explain the complete workload before selecting work. Then load the chosen goal with `goal_ledger_resume_by_key`, inspect its full task context, and claim exactly one eligible leaf task. Do not infer that a task is available merely because its heartbeat is stale: use the atomic claim RPC.

The overview follows the same owner visibility rule as `goal_ledger_list_unfinished`. In the current single-owner workspace, an unauthenticated connector session sees the workspace goals. Do not treat this as multi-tenant isolation.

## Verification

Run `supabase/tests/agent-recovery-and-overview.integration.sql` against a disposable database. It proves that a worker with an expired lease but a 59-minute-old heartbeat cannot be reclaimed, while a worker with a 61-minute-old heartbeat can be reclaimed even if its lease has not expired. It also verifies claim-token rotation, previous-worker evidence and full goal overview output.
