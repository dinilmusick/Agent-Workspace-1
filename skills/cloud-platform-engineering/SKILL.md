---
name: "Cloud Platform and Infrastructure Engineering"
slug: cloud-platform-engineering
version: 1.0.0
source: Supabase Skills Database
sourceId: 26
status: active
---

# Cloud Platform and Infrastructure Engineering

Implement and troubleshoot cloud infrastructure, networking, containers, edge runtimes, and platform integrations.

## Linked tools

- No tool links currently registered.

## Instructions

# Cloud Platform and Infrastructure Engineering

1. Discover the actual provider, account/project scope, region, runtime, resource graph, and existing configuration.
2. Read current provider documentation for version-sensitive APIs and platform behavior.
3. Map ingress, DNS, TLS, routing, ports, identity, secrets, storage, compute, and observability.
4. Establish the failure boundary with logs, health checks, network probes, and configuration inspection.
5. Prefer declarative, version-controlled infrastructure and least-privilege access.
6. Design for retries, timeouts, resource limits, cold starts, and graceful failure.
7. Implement the smallest scoped change and preserve existing environment separation.
8. Verify both control-plane configuration and data-plane behavior from the client/runtime.
9. Record cost, security, availability, and rollback implications.

Do not assume a feature is available on a plan or region without verification. Never expose account tokens or private origin details.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "microsoft/skills"
}
```


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.