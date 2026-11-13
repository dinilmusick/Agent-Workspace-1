---
name: "tldraw"
slug: tldraw
version: 1.1.0
source: Supabase Skills Database
sourceId: 1
status: active
---

# tldraw

Use tldraw as the mandatory visual projection layer for Vision decomposition, not as the source of truth. Every persisted Vision must have a synchronized tldraw representation unless the user explicitly declines visual projection for that Vision.

## Vision board protocol

A Vision has exactly one root target and a persisted target-decomposition graph. When a Vision is created:

1. Ask the user which tldraw workspace to use.
2. Create a new board in that workspace.
3. Create/identify the **Vision Overview** page.
4. Create one page for every component target.
5. On the overview page, render component targets as rectangles and place their goals beneath them.
6. Connect parent/component targets with arrows; keep arrows clear of shapes.
7. On each component page, render the target, its goals, and current task/verification state.
8. Persist board/workspace/page identifiers in Supabase.
9. Treat Supabase goal/task state as canonical; tldraw is a synchronized projection.

## Diagram-quality protocol
Use the tldraw Agent patterns: inspect both structured shape data and a visual/screenshot representation; reason about spatial relationships; use typed/sanitized actions; keep a clear hierarchy; and perform a post-write visual lint pass. Prefer explicit node types, consistent geometry, directional connectors, readable labels, grouping, alignment and whitespace. For architecture/process diagrams, show dependencies and flow direction rather than decorative shapes. Use the smallest diagram that fully represents the planning graph.

External references: tldraw Agent Starter Kit and AI integration guidance; AgentsORG design-engineering diagram-design principles. Reuse concepts; do not copy proprietary code or unlicensed material.

## Layout invariants

- Check for overlapping elements after every write.
- Use uniform symmetric spacing.
- Never route arrows through shapes.
- Keep one clear visual hierarchy: Vision → target → goals → tasks.
- Do not duplicate canonical status into an independently editable data model.

## Required persistent metadata

\`visions\` stores the tldraw workspace, board and board URL.
\`vision_canvas_pages\` stores the overview and component page identities.


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.