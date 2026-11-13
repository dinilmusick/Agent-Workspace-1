---
name: "Code Documentation and Developer Handoff"
slug: documentation-engineering
version: 1.0.0
source: Supabase Skills Database
sourceId: 21
status: active
---

# Code Documentation and Developer Handoff

Produce accurate technical documentation, API references, architecture notes, and actionable developer handoffs from verified code.

## Linked tools

- No tool links currently registered.

## Instructions

# Code Documentation and Developer Handoff

1. Inspect implementation and public interfaces before writing. Treat code as canonical.
2. Identify the intended reader, task, prerequisites, environment, and expected outcome.
3. Document actual setup, configuration, commands, API contracts, data flows, errors, and operational behavior.
4. Include runnable examples only when verified against the current implementation.
5. Distinguish required configuration from optional configuration; never fabricate secrets or placeholder values that look real.
6. Update the nearest canonical documentation and avoid duplicating conflicting explanations.
7. Validate links, commands, code snippets, and version references where tools permit.
8. Report what was documented and any behavior that remains undocumented or ambiguous.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "github/awesome-copilot"
}
```


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.