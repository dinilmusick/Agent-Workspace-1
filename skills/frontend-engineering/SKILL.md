---
name: "Frontend Engineering"
slug: frontend-engineering
version: 1.0.0
source: Supabase Skills Database
sourceId: 16
status: active
---

# Frontend Engineering

Build accessible, coherent frontend interfaces with correct state, responsive layout, and verified browser rendering.

## Linked tools

- No tool links currently registered.

## Instructions

# Frontend Engineering

1. Inspect the framework version, routing, component conventions, design tokens, state model, and existing UI patterns.
2. Trace data from the backend/API to the rendered component. Define loading, empty, error, success, and permission states.
3. Implement semantic, accessible markup and keyboard-operable interactions. Use labels, focus management, and appropriate contrast.
4. Match the existing design system. Avoid arbitrary styles, generic placeholder content, and invented data.
5. Make layouts responsive and test realistic viewport sizes.
6. Keep component responsibilities cohesive and state ownership explicit. Avoid unnecessary global state and prop-driven boolean explosions.
7. Test interaction behavior, not just screenshots.
8. Inspect the actual rendered page in a browser. Capture console errors, failed network requests, layout overflow, hydration issues, and visual mismatch.
9. Compare implementation against acceptance criteria and correct discrepancies.

Source code is not evidence that the page looks or behaves correctly. Report browser, viewport, routes, and observed results when available.

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