---
name: "Persistent Multi-Agent Execution"
slug: persistent-multi-agent-execution
version: 1.1.0
source: Supabase Skills Database
sourceId: 46
status: active
---

# Persistent Multi-Agent Execution

Use for parallel coding execution where ChatGPT worker conversations may pause, lose conversational continuity, or require a bulk resume signal.

## Canonical boundary

- Supabase: goals, parent tasks, dependencies, leases, non-coding coordination and durable cross-task evidence.
- GitHub Issue: detailed execution state and worker/orchestrator communication for each coding task.
- GitHub PR: implementation artifact for that task.
- GitHub Actions/CI: verification evidence.

## Orchestrator

1. Create one Issue for each independent coding task.
2. Put objective, acceptance criteria, dependencies and initial Current Implementation State in the Issue.
3. Assign/spawn one worker per Issue and one dedicated PR per worker.
4. Poll active Issues, linked PRs and CI continuously.
5. When a worker asks a question, answer it in the Issue; never keep the decision only in chat.
6. Continue polling until all tasks are terminal or have a genuine external blocker.
7. Reconcile Issues and PRs before finalization.

## Worker

Before every action, read the complete Issue and latest comments. Maintain Current Implementation State:

Status
Completed work
Current work
Next action
Blocker
Question for orchestrator
Orchestrator response
Resume point
Files/tests/evidence

When blocked: persist the blocker, exact question, attempted resolution and resume point to the Issue, then poll for the orchestrator response. Never disappear with unresolved state.

## Global continuation

"continue" or "proceed" is a global resume signal, not a new task. Every worker rereads its own Issue:

- terminal → no-op; do not invent work
- active → continue current task
- blocker resolved → resume from recorded resume point
- blocker unresolved → remain waiting/polling
- new orchestrator instruction → follow it

The user never needs to identify which workers are complete or blocked.

## Safety

No duplicate work. No unrelated changes. Preserve evidence. Never claim completion without verification. User intervention is required only for genuine external decisions, permissions, unavailable capabilities or unrecoverable blockers.


## Goal-phase dependency gates

Before dispatching workers for a phase, inspect its parent goal's `goal_dependencies`. A blocking edge means the dependent phase remains locked until its prerequisite goal is completed and all prerequisite descendants are independently verified. Do not dispatch or manually start tasks in a locked phase; the database rejects task transitions to `running` regardless of the claim route. Advisory edges are informational and must not serialize work. Orchestrators must create all blocking edges before worker dispatch and report the exact prerequisite preventing a phase from starting.


## SUBSTRATE_PROTOCOL_V3
All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill for persistent multi-agent execution; workers must re-read their canonical Issue after any material state change and before resuming. Continue/proceed resumes the existing task, not a new task. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.