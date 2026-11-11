---
name: "Persistent Multi-Agent Execution"
slug: persistent-multi-agent-execution
version: 1.0.0
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
