---
name: "Obstacle Memory Management"
slug: obstacle-memory-management
version: 1.2.0
status: active
---

# Obstacle Memory Management

Obstacle capture is a mandatory engineering reflex. Treat every non-trivial failure, unexpected behavior, blocked step, workaround, or repeated friction as potentially reusable knowledge.

## Mandatory obstacle reflex

At the first sign of an obstacle, stop and classify it before continuing:

```text
observe
  -> normalize symptoms
  -> semantic-search canonical obstacle memory
  -> reuse matching verified solution OR create/update canonical obstacle
  -> record occurrence against current goal/task/agent
  -> continue execution
  -> capture evidence
  -> update resolution/status
```

Do this during repository work, CI work, agent-workspace work, deployment work, testing, and infrastructure work. Do not wait until the end of a task.

## What counts as an obstacle

Record any issue that:
- causes a command, test, build, deployment, workflow, or verification step to fail;
- requires a workaround or deviation from the intended path;
- reveals an architectural mismatch, missing dependency, stale assumption, or tool limitation;
- consumes meaningful debugging effort;
- could plausibly recur in another repository, task, agent, or future run;
- exposes a weakness in an Agent-Workspace skill, workflow, tool, or substrate.

Do not record ordinary expected outcomes or trivial one-off observations.

## Required lifecycle

For every material obstacle:

1. **Normalize**
   - problem
   - symptoms/error
   - root cause or current hypothesis
   - affected repo/substrate
   - current workaround/solution
   - prevention opportunity

2. **Search before write**
   - semantically search existing canonical obstacles;
   - inspect prior verified resolutions;
   - never create a duplicate because the wording differs.

3. **Canonicalize**
   - matching obstacle -> update canonical record;
   - new obstacle -> create canonical record.

4. **Record occurrence**
   - attach goal/task/agent;
   - record exact evidence/run/commit when available;
   - record resolution and next action;
   - distinguish recurrence from a new root cause.

5. **Close the loop**
   - mark resolved only after evidence verifies the solution;
   - preserve the reusable prevention rule;
   - if the obstacle exposes a reusable agent behavior, update the relevant skill/workflow too.

## Agent-Workspace self-improvement rule

If the obstacle is caused by the Agent-Workspace substrate itself, record it twice conceptually but never duplicate the canonical obstacle:
- occurrence against the user task/repository where it surfaced;
- occurrence against the Agent-Workspace substrate as the affected system.

Then improve the substrate when appropriate:
```text
failure
  -> obstacle memory
  -> root-cause analysis
  -> skill/workflow/tool improvement
  -> verify improvement
  -> record evidence
  -> reuse on next task
```

This makes obstacles a feedback loop for progressive substrate improvement rather than passive notes.

## Evidence standard

An obstacle record is incomplete without concrete evidence when evidence is available:
- command output/error;
- workflow run/job ID;
- commit SHA;
- test name;
- file/path;
- deployment/runtime observation.

Separate observed facts from hypotheses. Do not encode an unverified hypothesis as the root cause.

## Anti-patterns

Never:
- debug repeatedly without searching obstacle memory;
- create duplicate canonical obstacles;
- wait until task completion to record a material failure;
- mark an obstacle resolved merely because the error disappeared;
- fix a downstream symptom while leaving a reusable substrate weakness undocumented;
- update a skill from speculation without evidence.

The relational obstacle record is canonical; vectors are retrieval indexes.

## Deterministic checkpoint-blocker promotion

Checkpoint blockers are automatically promoted into durable `obstacles` memory when either threshold is crossed:
- **more than 5 distinct agents** have reported the same canonical blocker; or
- **notoriety > 10**.

Promotion happens synchronously when a new blocker occurrence is recorded. The promotion is idempotent: the canonical blocker stores the resulting `obstacle_id` in metadata, so later occurrences do not create duplicate obstacle records. The obstacle receives the blocker text, occurrence context/evidence, current task/goal/agent linkage when available, severity based on the threshold, and a `checkpoint-blocker` tag.

## SUBSTRATE_PROTOCOL_V3

All agents are ephemeral workers. Supabase is canonical coordination state; chat is not durable state. Before acting, load the current Task Ledger and the narrowest applicable specialist skill. Persist every meaningful checkpoint: current_step, activity, progress, discoveries, blockers, evidence and next_action.
WORKER=discover->resolve->route->plan->persist->claim->execute->evidence->independentVerify->finalize. Claims MUST use the atomic ledger claim path. HEARTBEAT~2m->checkpoint+renew lease. OWNERSHIP_CHECK~5m->if fence is lost: append final handoff note, stop immediately, and never overwrite the new owner. Recovery is allowed after heartbeat silence>=5m; the new worker reads the task row, checkpoint and task events before continuing. Use fenced release for queued/blocked/abandoned work.
LOOPS=separateAuthor->readyContract->independentExecutor. A loop-authoring worker defines and validates success parameters/checkpoints, persists the loop contract, then releases/requeues the task. It MUST NOT execute the resulting task. An execution worker may claim only a ready contract authored by another agent and MUST execute against those persisted parameters. No worker may redefine its own success conditions. Verification is independent.
CODING=GitHubIssueCanonicalExecutionState; one independent coding task->one worker->one Issue->one PR. ASYNC=started->wait/poll->inspect->repair/retry->poll->verify; never stop while a started/pollable process remains. OBSTACLE=normalize->semanticSearch->reuseOrCreate->record->resolve->verify. Never keep essential context only in chat or secrets in task records/logs.
SKILL TIMING: use this skill when its trigger matches; load supporting skills before their required action, not after. Prefer the narrowest specialist skill plus only necessary support skills. If the substrate changes, update the canonical Supabase skill and repository copy, then independently verify parity.

## Checkpoint blocker integration

Checkpoint blockers are a durable substrate obstacle surface. Normalize blocker text, reuse an existing blocker identity when semantically identical, record an occurrence tied to task/checkpoint/agent/attempt, and let notoriety count distinct failure occurrences. Do not create duplicate blockers for wording variants. A blocker is not resolved until resolution evidence is recorded.
