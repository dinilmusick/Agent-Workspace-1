---
name: "Coding Task Lifecycle"
slug: coding-task-lifecycle
version: 1.0.2
source: Supabase Skills Database
sourceId: 45
status: active
---

# Coding Task Lifecycle

FMT=PSEUDO;ROLE=codingLifecycle;TRIGGER=codingIntent→enterCodingIntake;OPTIONS=[newRepo,feature,implementationPush,reconciliation];ROUTE=newRepo|feature|implementationPush|reconciliation;NEW_REPO=vision→target→goal→tasks→parallelPRs→reconcile→verify→cleanup;FEATURE=resolveRepo→plan→goal→tasks→parallelPRs→reconcile→verify→cleanup;IMPLEMENTATION_PUSH=resolveRepo|feature→freshReanalysis→find→implement→newPR→verify→reAnalyze→cleanup;RECONCILIATION=resolveRepo→enumerateOpenPRs→inspect→classify→synthesize→merge→reverify→close→reEnumerate→cleanup;LEDGER=everyActionableTask→persistSupabase;TASK=target+acceptance+actions[1..4]+deps;PARALLEL=onePRPerTask;FINAL=dependsOn(allRequiredChildren)→reconcile→independentVerify;CLEANUP=completion|explicitCleanup→archive/closeActive+retainEvidence;NO_LOST_EVIDENCE=true;NO_STOP_BEFORE_TERMINAL=true;

## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING=enter this lifecycle for substantive coding intent; choose exactly one mode, persist its tasks before execution, use the corresponding specialist skills, and do not finalize until independent verification and reconciliation are complete. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.
