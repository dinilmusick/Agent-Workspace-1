---
name: "Backend and API Engineering"
slug: backend-api-engineering
version: 1.0.0
source: Supabase Skills Database
sourceId: 24
status: active
---

# Backend and API Engineering

Design and implement robust service boundaries, APIs, validation, authorization, error semantics, and distributed workflows.

## Linked tools

- No tool links currently registered.

## Instructions

# Backend and API Engineering

1. Trace the existing service facade, routes, handlers, domain logic, persistence, and external adapters.
2. Define the API contract: method, path, request/response schema, validation, errors, idempotency, pagination, and versioning.
3. Enforce authorization at the server boundary. Never rely on frontend visibility as access control.
4. Separate transport concerns from domain behavior. Keep domain invariants in the owning service/module.
5. Handle timeouts, retries, cancellation, duplicate delivery, partial failure, and rate limits where relevant.
6. Validate untrusted input and return stable, non-sensitive error responses with useful internal diagnostics.
7. Add contract and integration tests for success, invalid input, unauthorized access, and downstream failure.
8. Verify with real requests and inspect logs and persisted effects.
9. Document compatibility and operational implications.

Never expose credentials, internal stack traces, or privileged service operations through public endpoints.

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