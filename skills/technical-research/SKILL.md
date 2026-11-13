---
name: "Technical Research and Documentation Discovery"
slug: technical-research
version: 1.0.0
source: Supabase Skills Database
sourceId: 15
status: active
---

# Technical Research and Documentation Discovery

Research implementation choices using authoritative, version-matched documentation and reproducible evidence.

## Linked tools

- No tool links currently registered.

## Instructions

# Technical Research and Documentation Discovery

1. Translate the engineering question into decision criteria and constraints.
2. Identify authoritative sources: official documentation, release notes, canonical repositories, standards, and maintained examples.
3. Verify current versions, maintenance activity, compatibility, license, platform support, and known limitations.
4. Prefer primary sources over derivative summaries. Use independent benchmarks or community reports only with methodology caveats.
5. Compare alternatives against the actual use case, not popularity alone.
6. Separate verified facts, source claims, measured evidence, and inference.
7. Provide citations or exact source links for material claims and note publication/update dates.
8. Recommend a practical choice with migration cost, operational risk, and validation steps.

Never invent APIs, benchmark results, package capabilities, or compatibility claims.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "anthropics/skills"
}
```


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.