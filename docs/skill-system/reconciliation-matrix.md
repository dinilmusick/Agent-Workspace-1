# Skill System Reconciliation Matrix

This is the repository-side contract for the deterministic skill substrate. Supabase remains the canonical runtime state; this file intentionally contains no database mutation.

| Workflow | Trigger | Dependencies | Tools | Persistence | Verification | Cleanup |
|---|---|---|---|---|---|---|
| Universal routing | semantic request | domain routers | semantic resolver | goal/task | route reachability | n/a |
| Coding routing | coding intent | universal router | GitHub/container as needed | workflow selection | classification | n/a |
| New repository | new app/repo intent | coding lifecycle | GitHub + workspace | vision→target→goal→tasks | CI/integration | close/retain evidence |
| Existing feature | feature intent | coding lifecycle | repo tooling | vision→target→goal→tasks | unit/integration | close/retain evidence |
| Implementation push | fresh completion/debug pass | coding lifecycle | GitHub + container | goal/tasks/evidence | independent repo verification | close/supersede |
| Reconciliation pass | repo-state reconciliation | coding lifecycle | GitHub + container | synthesized state/evidence | post-reconciliation verification | merge/close/archive |
| “What remains?” | state query | task ledger + resource resolution | Supabase/GitHub | none unless requested | cross-source consistency | none |

## Readiness rule

READY = trigger ∧ dependencies ∧ tools ∧ capabilities ∧ input/output contract ∧ persistence ∧ verification ∧ evidence ∧ terminal cleanup.

Any missing mandatory term yields NOT READY.

## System invariants

- Exactly one primary coding workflow is selected for an actionable coding request.
- Workflow selection happens before implementation.
- Goals precede child tasks.
- Task target equals immutable parent goal target.
- Each task has ≤4 executable actions.
- Evidence is attached before terminal state.
- Independent verification is required before completion.
- Reconciliation is required when parallel/open PR state can affect correctness.
- Cleanup never deletes the evidence needed to explain the terminal decision.
- “What remains?” reports semantic state, not raw rows.

## Supabase boundary

This PR only defines repository-side contracts and validation. Database migrations, skill records, evaluations, triggers, dependencies, and canonical state changes belong to the separate Supabase PR.
