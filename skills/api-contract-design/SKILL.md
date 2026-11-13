---
name: "API Contract and Integration Design"
slug: api-contract-design
version: 1.0.0
source: Supabase Skills Database
sourceId: 22
status: active
---

# API Contract and Integration Design

Design stable contracts and integrations between services, packages, clients, and external providers.

## Linked tools

- No tool links currently registered.

## Instructions

# API Contract and Integration Design

1. Identify producers, consumers, ownership, trust boundaries, and lifecycle of the contract.
2. Define names, types, required/optional fields, validation, defaults, errors, and compatibility rules.
3. Specify idempotency, ordering, pagination, retries, timeouts, and event delivery semantics where relevant.
4. Prefer explicit versioning and additive evolution. Identify breaking changes before implementation.
5. Generate or validate types from a canonical schema when possible.
6. Test producer and consumer behavior against the same contract, including malformed and older-version inputs.
7. Verify integration in the real deployment/runtime and document migration requirements.

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