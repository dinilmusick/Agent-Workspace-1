---
name: "Feature Implementation"
slug: feature-implementation
version: 2.0.0
source: Supabase Skills Database
sourceId: 19
status: active
---

# Feature Implementation

Translate a feature request into a coherent implementation across existing interfaces, data flows, UI, and tests.

## Linked tools

- No tool links currently registered.

## Instructions

# Feature Implementation

Use for adding or extending a user-visible or system capability.

1. Convert the request into observable outcomes and edge cases.
2. Locate the existing entrypoint, domain model, service/API, state, UI, persistence, and event path relevant to the feature.
3. Identify the smallest complete vertical slice. Reuse established abstractions and dependencies; do not create parallel infrastructure.
4. Define contracts before wiring layers: input, output, validation, errors, authorization, loading/empty/success states, and side effects.
5. Implement the vertical slice in dependency order. Keep each module cohesive and respect existing dependency direction.
6. Add tests for normal behavior, boundary conditions, failure paths, and authorization.
7. Verify integration across all affected layers. For UI, inspect the rendered result; for APIs, exercise real requests; for persistence, verify stored state.
8. Check backward compatibility, migrations, configuration, and release implications.
9. Report what is implemented and what remains unverified.

Never substitute mock behavior for a requested working feature. Clearly label any unavoidable stub and its blocker.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "obra/superpowers"
}
```


## Persistent parallel execution

For independent feature tasks, create one GitHub Issue per task and one dedicated PR per worker. Workers read and update the Issue as their durable execution context. Blockers require a persisted question and resume point; workers poll for the orchestrator response. A global continue/proceed prompt is safe: terminal workers no-op, active workers continue, and resolved blockers resume.


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.