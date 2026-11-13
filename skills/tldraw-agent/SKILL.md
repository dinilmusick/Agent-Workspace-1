---
name: "tldraw Agent"
slug: tldraw-agent
version: 1.0.0
status: active
---

# tldraw Agent

Agent-oriented canvas manipulation and visual verification.

## Purpose
Give agents a disciplined method for reading, creating and revising tldraw diagrams rather than treating a canvas as a blind drawing surface.

## Contract
- Read the user's request, current selection, visible canvas and relevant structured shapes.
- Maintain explicit typed actions for create/update/delete and higher-level layout operations.
- Keep spatial context: coordinates, bounds, clusters and relationships matter.
- After mutations, inspect the resulting visual state and correct layout defects.
- For persistent Visions, mirror Supabase's Vision → target → goal → task hierarchy exactly; Supabase remains canonical.
- Use comments/annotations as localized review context when available.

## Diagram loop
UNDERSTAND → MODEL → DRAW → INSPECT → LINT → REVISE → VERIFY.

## Official reference
The tldraw Agent Starter Kit documents typed canvas actions, screenshots plus structured shape context, layout operations, todo tracking and iterative agent loops. The tldraw AI integration documentation documents direct agent control and visual/structured context.

## Boundaries
Do not invent board IDs, pages or canonical state. Do not store planning truth only on the canvas. Do not copy external implementation code into this repository unless its license and repository policy permit it.


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.