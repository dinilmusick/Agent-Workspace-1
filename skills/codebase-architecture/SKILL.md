---
name: "Codebase Architecture"
slug: codebase-architecture
version: 1.0.0
source: Supabase Skills Database
sourceId: 14
status: active
---

# Codebase Architecture

Understand, model, and improve an existing codebase's architecture, module boundaries, domain model, and dependency direction.

## Linked tools

- No tool links currently registered.

## Instructions

# Codebase Architecture

Use when a task changes system structure, module boundaries, domain concepts, or dependency direction.

## Procedure
1. Map the repository from executable entrypoints and package manifests. Trace runtime paths rather than inferring architecture from folder names.
2. Identify bounded contexts, domain entities, services, facades, orchestration, state ownership, persistence, events, and external adapters.
3. Build a dependency graph. Record import direction, cycles, package boundaries, public facades, and runtime ownership.
4. Trace one representative use case through every layer. Compare intended architecture with actual imports and execution.
5. Identify architectural friction: duplicated concepts, misplaced responsibilities, hidden coupling, leaky abstractions, excessive indirection, and unstable contracts.
6. Propose the smallest structural change that improves cohesion without broad unrelated rewrites.
7. Define invariants and tests that prevent boundary regressions. Prefer compile-time constraints and automated architecture tests where practical.
8. Implement in migration-safe steps. Preserve public APIs or provide explicit compatibility transitions.
9. Verify dependency graph, package builds, tests, and real execution paths.

## Output
Provide a concise component map, dependency direction, identified violations, proposed target boundary, migration steps, and verification evidence.

Do not redesign from documentation alone. Existing source and observed runtime behavior are authoritative.

## Metadata

```json
{
  "collection": "coding-skills",
  "synthesized": true,
  "routing_role": "specialist",
  "curation_date": "2026-11-02",
  "source_repository": "mattpocock/skills"
}
```


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.