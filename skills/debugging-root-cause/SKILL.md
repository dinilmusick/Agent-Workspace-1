---
name: "Debugging and Root-Cause Analysis"
slug: debugging-root-cause
version: 1.0.0
source: Supabase Skills Database
sourceId: 18
status: active
---

# Debugging and Root-Cause Analysis

Reproduce failures, collect evidence, isolate causes, implement fixes, and verify that the original failure is eliminated.

## Linked tools

- No tool links currently registered.

## Instructions

# Debugging and Root-Cause Analysis

1. Capture the exact failure: command/request, environment, timestamp, full error, stack, logs, and expected versus actual behavior.
2. Reproduce before editing. If reproduction is intermittent, identify the triggering conditions and collect repeated observations.
3. Trace the failing execution path from entrypoint to failure. Inspect the actual source, configuration, dependency versions, generated output, and runtime environment.
4. Form ranked hypotheses. Change one variable at a time and use targeted probes to eliminate hypotheses.
5. Find the earliest incorrect state or violated invariant; do not patch only the final symptom.
6. Implement the smallest root-cause fix. Preserve useful error context and add observability where diagnosis was unnecessarily difficult.
7. Add a regression test that fails before the fix and passes after it.
8. Re-run the original reproduction plus relevant unit, integration, build, and runtime checks.
9. Confirm no new regressions. Report root cause, evidence, exact fix, verification, and any unresolved uncertainty.

Do not silence errors, broadly catch exceptions, weaken types, skip tests, or add fallback values merely to obtain a green build.

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


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.