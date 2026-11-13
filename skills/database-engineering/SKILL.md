---
name: "Database Engineering"
slug: database-engineering
version: 1.0.0
source: Supabase Skills Database
sourceId: 27
status: active
---

# Database Engineering

Model data, write safe SQL, design migrations and indexes, and verify database security and query behavior.

## Linked tools

- No tool links currently registered.

## Instructions

# Database Engineering

1. Inspect the live schema, constraints, indexes, policies, triggers, functions, views, and migration history before changing anything.
2. Model entities, ownership, cardinality, lifecycle, uniqueness, nullability, and retention explicitly.
3. Design migrations to be safe, repeatable where possible, and compatible with deployed application versions. Separate backfills from schema transitions when needed.
4. Use transactions for coupled changes. Avoid destructive operations without explicit authorization and a recovery plan.
5. Add indexes based on actual query predicates, joins, sort order, and cardinality; verify with query plans.
6. Review RLS, grants, view security, function security mode, and privilege boundaries. Do not expose service-role credentials to clients.
7. Test migrations against representative data and verify constraints, policies, and query results after applying them.
8. Check rollback/recovery options and deployment ordering.
9. Report schema changes, migration identifiers, verification, and unresolved operational risks.

For Supabase, consult current official documentation and run security/performance advisors after material schema changes.

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