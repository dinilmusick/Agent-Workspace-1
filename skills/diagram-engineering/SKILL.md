---
name: "Diagram Engineering"
slug: diagram-engineering
version: 1.0.0
status: active
---

# Diagram Engineering

Domain-independent visual reasoning and diagram construction skill.

## Purpose
Turn a Vision, architecture, workflow, state model, dependency graph or explanation into a precise, readable diagram. Use for planning and communication across coding, research, learning, design, operations, business and general work.

## Procedure
1. Identify the diagram's purpose, audience, target, node types, relationships and required decisions.
2. Choose the smallest representation that preserves the important structure.
3. Establish hierarchy, grouping, direction, labels, spacing and connector semantics before drawing.
4. Render through the canonical tldraw projection when a Vision or persistent planning graph is involved.
5. Inspect both structured geometry and a visual representation.
6. Run a visual lint pass: overlap, crossings, ambiguous direction, unreadable labels, inconsistent spacing, orphan nodes and missing relationships.
7. Revise and re-check until the diagram communicates the intended structure.

## Design rules
Prefer deletion over decoration. Use consistent node geometry, explicit connector direction, meaningful proximity, whitespace, alignment and progressive disclosure. Never use color as the only semantic channel. Do not create a second editable source of truth outside Supabase.

## Agent references
Use the official tldraw Agent Starter Kit/AI integration patterns for structured canvas actions, visual context and post-write inspection. Use AgentsORG design-engineering's diagram-design concepts as a companion reference. Reuse principles, not copied implementation.

## Routing
Primary for diagram generation, visual decomposition and diagram critique. Pair with Prompt Map for complex graph extraction and tldraw for persistent canvas projection.


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.