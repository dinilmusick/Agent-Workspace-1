---
name: "Testing Strategy"
slug: testing-strategy
version: 1.0.0
source: Supabase Skills Database
sourceId: 25
status: active
---

# Testing Strategy

Design and execute layered tests that verify behavior from units through integration and end-to-end workflows.

## Linked tools

- No tool links currently registered.

## Instructions

# Testing Strategy

1. Derive tests from observable requirements, invariants, and failure modes.
2. Choose the lowest layer that can prove each property: unit for pure logic, integration for boundaries and persistence, end-to-end for user workflows.
3. Test behavior and contracts, not private implementation details.
4. Cover valid inputs, invalid inputs, boundaries, empty states, permission failures, retries, concurrency, and partial failure as applicable.
5. Use deterministic fixtures and isolated test data. Avoid shared mutable state and timing-dependent assertions.
6. Prefer real implementations for the boundary under test; mock only external systems or nondeterministic dependencies that cannot be controlled.
7. Ensure regression tests reproduce the reported bug.
8. Run tests and inspect failures. Do not equate test discovery or compilation with test success.
9. Report command, test count, pass/fail/skip status, coverage gaps, and untested risks.

Do not inflate coverage with assertions that do not prove meaningful behavior.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "addyosmani/agent-skills"
}
```


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.